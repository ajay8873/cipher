class NotificationParserResult {
  final double amount;
  final String merchant;
  final String category;
  final String type; // 'credit' or 'debit'
  final String accountType; // e.g. 'UPI (PhonePe)', 'UPI (Google Pay)', 'UPI (Navi)', etc.
  final String appName;
  final bool isParsedSuccessfully;

  NotificationParserResult({
    required this.amount,
    required this.merchant,
    required this.category,
    required this.type,
    required this.accountType,
    required this.appName,
    required this.isParsedSuccessfully,
  });
}

class NotificationParserService {
  /// Known package names for major Indian UPI payment apps
  static final Map<String, String> supportedUpiApps = {
    'com.phonepe.app': 'PhonePe',
    'com.google.android.apps.nbu.paisa.user': 'Google Pay',
    'net.one97.paytm': 'Paytm',
    'com.navi.passport': 'Navi UPI',
    'com.navi.app': 'Navi UPI',
    'com.navi.mobile': 'Navi UPI',
    'com.dreamplug.credpay': 'CRED',
    'in.org.npci.upiapp': 'BHIM',
    // Ind Money / Slice:
    'ind.money.slice': 'Slice',
    'money.jupiter': 'Jupiter',
    'com.mobikwik_new': 'MobiKwik',
    'money.super': 'Super.money',
    'in.amazon.mShop.android.shopping': 'Amazon Pay',
    'org.altruist.BajajPay': 'Bajaj Pay',
  };

  /// Check if the package is a recognized UPI application
  static bool isSupportedPackage(String packageName) {
    return supportedUpiApps.containsKey(packageName.toLowerCase());
  }

  /// Primary notification parser
  NotificationParserResult parseNotification({
    required String packageName,
    required String title,
    required String text,
  }) {
    final combinedText = '$title $text'.trim();
    final appName = supportedUpiApps[packageName.toLowerCase()] ?? 'UPI App';
    final lower = combinedText.toLowerCase();

    // ── 0. Anti-Spam / Non-Financial Filtering ────────────────────────────
    final promoKeywords = RegExp(
      r'\b(cashback\s+offer|discount|promo|coupon|scratch\s+card|recharge\s+reminder|loan\s+offer|apply\s+now|claim\s+your|win\s+up\s+to|reward|points|refer)\b',
      caseSensitive: false,
    );

    if (promoKeywords.hasMatch(lower) && !RegExp(r'\b(received|credited|sent|paid|debited)\b', caseSensitive: false).hasMatch(lower)) {
      return NotificationParserResult(
        amount: 0.0,
        merchant: 'Unknown',
        category: 'Non-financial',
        type: 'none',
        accountType: 'UPI ($appName)',
        appName: appName,
        isParsedSuccessfully: false,
      );
    }

    // ── 1. Amount Extraction ───────────────────────────────────────────────
    double amount = 0.0;
    final amountMatch = RegExp(
      r'(?:₹|RS\.?|INR\.?|Rs\.?)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(combinedText);

    if (amountMatch != null) {
      final amountStr = amountMatch.group(1)!.replaceAll(',', '');
      amount = double.tryParse(amountStr) ?? 0.0;
    }

    if (amount < 1.0) {
      return NotificationParserResult(
        amount: 0.0,
        merchant: 'Unknown',
        category: 'Non-financial',
        type: 'none',
        accountType: 'UPI ($appName)',
        appName: appName,
        isParsedSuccessfully: false,
      );
    }

    // ── 2. Credit vs Debit Detection ───────────────────────────────────────
    final isCredit = RegExp(
      r'\b(received|credited|added|got|sent\s+you|paid\s+you|credit|deposit)\b',
      caseSensitive: false,
    ).hasMatch(lower);

    final isDebit = RegExp(
      r'\b(sent|paid|debited|spent|transferred|debit|payment\s+to)\b',
      caseSensitive: false,
    ).hasMatch(lower);

    if (!isCredit && !isDebit) {
      return NotificationParserResult(
        amount: 0.0,
        merchant: 'Unknown',
        category: 'Non-financial',
        type: 'none',
        accountType: 'UPI ($appName)',
        appName: appName,
        isParsedSuccessfully: false,
      );
    }

    // If both keywords exist, check order (e.g., "Received payment from John" vs "You paid John")
    final type = isCredit ? 'credit' : 'debit';

    // ── 3. Merchant / Sender Name Extraction ───────────────────────────────
    final merchant = _extractNameFromNotification(title, text, isCredit);
    final category = _inferCategory(merchant, combinedText);

    return NotificationParserResult(
      amount: amount,
      merchant: merchant,
      category: category,
      type: type,
      accountType: 'UPI ($appName)',
      appName: appName,
      isParsedSuccessfully: amount > 0,
    );
  }

  String _extractNameFromNotification(String title, String text, bool isCredit) {
    final fullText = '$title $text'.trim();

    // 1. PhonePe / Navi / GPay common formats:
    // Credit: "Received ₹500 from Ramesh Kumar" / "Ramesh Kumar sent you ₹500"
    if (isCredit) {
      final fromMatch = RegExp(r'from\s+([A-Za-z0-9\s._-]+?)(?=\s+(?:via|thru|on|ref|for|using|\d)|$)', caseSensitive: false).firstMatch(fullText);
      if (fromMatch != null && fromMatch.group(1) != null) {
        final name = fromMatch.group(1)!.trim();
        if (name.isNotEmpty && name.length > 2 && !name.toLowerCase().startsWith('rs') && !name.toLowerCase().startsWith('₹')) {
          return name;
        }
      }

      final sentYouMatch = RegExp(r'([A-Za-z0-9\s._-]+?)\s+sent\s+(?:you\s+)?(?:₹|Rs)', caseSensitive: false).firstMatch(fullText);
      if (sentYouMatch != null && sentYouMatch.group(1) != null) {
        final name = sentYouMatch.group(1)!.trim();
        if (name.isNotEmpty && name.length > 2) {
          return name;
        }
      }
    } else {
      // Debit: "Paid ₹200 to Zomato" / "Payment of ₹150 to Swiggy successful"
      final toMatch = RegExp(r'to\s+([A-Za-z0-9\s._-]+?)(?=\s+(?:via|thru|on|ref|for|successful|using|\d)|$)', caseSensitive: false).firstMatch(fullText);
      if (toMatch != null && toMatch.group(1) != null) {
        final name = toMatch.group(1)!.trim();
        if (name.isNotEmpty && name.length > 2 && !name.toLowerCase().startsWith('rs') && !name.toLowerCase().startsWith('₹')) {
          return name;
        }
      }
    }

    // Fallback: title often contains the contact/merchant name (e.g. Title: "Ramesh Kumar", Body: "Received ₹500")
    if (title.isNotEmpty && !title.toLowerCase().contains('received') && !title.toLowerCase().contains('paid') && !title.toLowerCase().contains('payment')) {
      return title.trim();
    }

    return 'UPI Merchant';
  }

  String _inferCategory(String merchant, String text) {
    final lower = '$merchant $text'.toLowerCase();
    if (lower.contains('swiggy') || lower.contains('zomato') || lower.contains('food') || lower.contains('restaurant')) {
      return 'Food & Dining';
    } else if (lower.contains('uber') || lower.contains('ola') || lower.contains('irctc') || lower.contains('metro') || lower.contains('fuel') || lower.contains('petrol')) {
      return 'Transport';
    } else if (lower.contains('amazon') || lower.contains('flipkart') || lower.contains('mart') || lower.contains('store')) {
      return 'Shopping';
    } else if (lower.contains('bill') || lower.contains('electricity') || lower.contains('wifi') || lower.contains('recharge')) {
      return 'Bills & Utilities';
    }
    return 'General';
  }
}
