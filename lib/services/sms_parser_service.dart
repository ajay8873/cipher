import '../config/app_config.dart';
import 'deepseek_service.dart';

class SmsParserResult {
  final double amount;
  final String merchant;
  final String category;
  final String type; // 'debit' or 'credit'
  final String accountType; // 'UPI', 'Bank Account', 'Credit Card'
  final bool isParsedSuccessfully;

  SmsParserResult({
    required this.amount,
    required this.merchant,
    required this.category,
    required this.type,
    required this.accountType,
    required this.isParsedSuccessfully,
  });
}

class SmsParserService {
  final DeepSeekService? deepSeekService;

  SmsParserService({DeepSeekService? deepSeekService})
      : deepSeekService = deepSeekService ??
            (AppConfig.isDeepSeekConfigured
                ? DeepSeekService(apiKey: AppConfig.deepSeekApiKey)
                : null);


  /// Primary hybrid SMS parser
  Future<SmsParserResult> parseSms(String smsBody) async {
    final cleanSms = smsBody.trim();

    // ── 0. Anti-spam / Fraud / Exclusion Filter ────────────────────────────
    // 0a. Malicious / Shortened Links (e.g. bit.ly, tinyurl, t.co, http/https URLs)
    final containsShortenedOrWebLink = RegExp(
      r'(?:bit\.ly|tinyurl\.com|t\.co|goo\.gl|is\.gd|buff\.ly|ow\.ly|http:\/\/|https:\/\/|www\.)',
      caseSensitive: false,
    ).hasMatch(cleanSms);

    // 0b. Promotional, offer, recharge reminders, loan/finance offers, OTPs, wallet receipts (Pine Labs, Apay, etc.), client code promo
    final spamOrPromoRegExp = RegExp(
      r'\b(recharge|pack|validity|data|offer|cashback\s+offer|discount|promo|coupon|deal|plan|loan|apply\s+now|credit\s+card\s+limit|opt\s+out|pre-approved|finance\s+offer|claim\s+now|free|cashback\s+upto|earn|points|rewards|win|client\s+code|mapped\s+under|pine\s+labs|apay\s+balance|amazon\s+pay\s+balance|wallet|cashback)\b',
      caseSensitive: false,
    );

    // 0c. Mobile number in place of account number (e.g., A/C 9876543210 or 10-digit mobile numbers as sender/account)
    final mobileNumberAccountPattern = RegExp(
      r'(?:a/c|acct|account)\s*(?:no\.?|num\.?)?\s*[:\s]*[6-9]\d{9}\b',
      caseSensitive: false,
    ).hasMatch(cleanSms);

    // 0d. OTP / Verification code check
    final isOtpOnly = RegExp(r'\b(otp|verification\ +code|secret\ +code|one\ +time\ +password)\b', caseSensitive: false).hasMatch(cleanSms)
        && !RegExp(r'\b(debited|credited)\b', caseSensitive: false).hasMatch(cleanSms);

    if (containsShortenedOrWebLink || spamOrPromoRegExp.hasMatch(cleanSms) || mobileNumberAccountPattern || isOtpOnly) {
      return SmsParserResult(
        amount: 0.0,
        merchant: 'Unknown',
        category: 'Non-financial',
        type: 'none',
        accountType: 'Unknown',
        isParsedSuccessfully: false,
      );
    }

    // ── 1. Transaction Type Detection ──────────────────────────────────────
    final hasDebitKeyword = RegExp(
      r'\b(debited|debit|spent|paid|payment|sent|withdrawn|transferred|purchase)\b',
      caseSensitive: false,
    ).hasMatch(cleanSms);

    final hasCreditKeyword = RegExp(
      r'\b(credited|credit|received|deposited|added|refund)\b',
      caseSensitive: false,
    ).hasMatch(cleanSms);

    // Amount pattern: Rs / INR / Rs. followed by numbers
    final hasAmount = RegExp(
      r'(?:RS\.?|INR\.?|Rs\.?)\s*[\d,]+(?:\.\d{1,2})?',
      caseSensitive: false,
    ).hasMatch(cleanSms);

    // Must have BOTH a financial keyword AND an amount to proceed
    if ((!hasDebitKeyword && !hasCreditKeyword) || !hasAmount) {
      return SmsParserResult(
        amount: 0.0,
        merchant: 'Unknown',
        category: 'Non-financial',
        type: 'none',
        accountType: 'Unknown',
        isParsedSuccessfully: false,
      );
    }

    final type = hasDebitKeyword ? 'debit' : 'credit';

    // ── 2. Amount Extraction ───────────────────────────────────────────────
    double amount = 0.0;
    final amountMatch = RegExp(
      r'(?:RS\.?|INR\.?|Rs\.?)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(cleanSms);

    if (amountMatch != null) {
      final amountStr = amountMatch.group(1)!.replaceAll(',', '');
      amount = double.tryParse(amountStr) ?? 0.0;
    }

    if (amount < 1.0) {
      return SmsParserResult(
        amount: 0.0,
        merchant: 'Unknown',
        category: 'Non-financial',
        type: 'none',
        accountType: 'Unknown',
        isParsedSuccessfully: false,
      );
    }

    // ── 3. Account Type Extraction ─────────────────────────────────────────
    String accountType = 'Bank Account';
    if (cleanSms.toLowerCase().contains('upi')) {
      accountType = 'UPI';
    } else if (cleanSms.toLowerCase().contains('credit card') || cleanSms.toLowerCase().contains('card')) {
      accountType = 'Credit Card';
    }

    // ── 4. Merchant / Party Name Extraction ────────────────────────────────
    String merchant = _extractNativeMerchant(cleanSms);
    String category = _inferCategory(merchant, cleanSms);

    // AI Fallback Logic: If native parsing failed to get a clean merchant name
    if ((merchant == 'Unknown' || merchant.isEmpty) && deepSeekService != null) {
      final sanitizedSms = _sanitizeSmsForPrivacy(cleanSms);
      final aiResult = await deepSeekService!.parseSmsFallback(sanitizedSms);
      if (aiResult != null) {
        merchant = aiResult['merchant_name'] ?? merchant;
        category = aiResult['category'] ?? category;
      }
    }

    return SmsParserResult(
      amount: amount,
      merchant: merchant.isEmpty ? 'Unknown Merchant' : merchant,
      category: category,
      type: type,
      accountType: accountType,
      isParsedSuccessfully: amount > 0,
    );
  }

  /// Sanitizes SMS by redacting sensitive data (account numbers, balances) for privacy
  String _sanitizeSmsForPrivacy(String sms) {
    String clean = sms;
    clean = clean.replaceAll(RegExp(r'(?:A/C|Acct|Account|Card)\s*(?:no\.?|num\.?)?\s*[:\s]*[X*\d]{4,}', caseSensitive: false), 'A/C XXXX');
    clean = clean.replaceAll(RegExp(r'(?:avail|total)?\s*(?:bal|balance)\s*[:\s]*[\w.]+\s*[\d,]+(?:\.\d{2})?', caseSensitive: false), 'Bal: REDACTED');
    return clean;
  }

  String _extractNativeMerchant(String sms) {
    // Specific regex for IPPB / Indian Bank formats:
    // Format 1: "received a payment of Rs. 70.00 ... from mr mobashir umar ans thru IPPB"
    final creditFromMatch = RegExp(r'from\s+([A-Za-z0-9\s._-]+?)(?=\s+(?:thru|via|on|ref|info|a/c|\d)|$)', caseSensitive: false).firstMatch(sms);
    if (creditFromMatch != null && creditFromMatch.group(1) != null) {
      final m = creditFromMatch.group(1)!.trim();
      if (m.isNotEmpty && !m.toLowerCase().startsWith('ref') && !m.toLowerCase().startsWith('rs')) {
        return m;
      }
    }

    // Format 2: "Debit Rs.50.00 for UPI to aman kumar jai on..."
    final debitToMatch = RegExp(r'(?:for\s+UPI\s+)?to\s+([A-Za-z0-9\s._-]+?)(?=\s+(?:on|ref|via|val|bal|a/c|If\s+not|\d)|$)', caseSensitive: false).firstMatch(sms);
    if (debitToMatch != null && debitToMatch.group(1) != null) {
      final m = debitToMatch.group(1)!.trim();
      if (m.isNotEmpty && !m.toLowerCase().startsWith('ref') && !m.toLowerCase().startsWith('rs')) {
        return m;
      }
    }

    // Fallback standard patterns
    final patterns = [
      RegExp(r'(?:to|at|info:?|vpa:?)\s+([A-Za-z0-9\s._-]+?)(?=\s+(?:on|ref|via|val|bal|a/c|\d)|$)', caseSensitive: false),
      RegExp(r'transfer\s+to\s+([A-Za-z0-9\s._-]+)', caseSensitive: false),
      RegExp(r'spent\s+on\s+([A-Za-z0-9\s._-]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(sms);
      if (match != null && match.group(1) != null) {
        final found = match.group(1)!.trim();
        if (found.length > 2 && !found.toLowerCase().startsWith('ref') && !found.toLowerCase().startsWith('rs')) {
          return found;
        }
      }
    }
    return 'Unknown';
  }

  String _inferCategory(String merchant, String sms) {
    final lower = (merchant + " " + sms).toLowerCase();
    if (lower.contains('swiggy') || lower.contains('zomato') || lower.contains('food') || lower.contains('restaurant')) {
      return 'Food & Dining';
    } else if (lower.contains('uber') || lower.contains('ola') || lower.contains('irctc') || lower.contains('metro') || lower.contains('fuel') || lower.contains('petrol')) {
      return 'Transport';
    } else if (lower.contains('amazon') || lower.contains('flipkart') || lower.contains('mart') || lower.contains('store')) {
      return 'Shopping';
    } else if (lower.contains('bill') || lower.contains('electricity') || lower.contains('wifi')) {
      return 'Bills & Utilities';
    }
    return 'General';
  }
}
