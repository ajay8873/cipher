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

  /// Primary strict SMS parser matching ONLY defined bank templates
  Future<SmsParserResult> parseSms(String smsBody) async {
    final cleanSms = smsBody.trim();

    // ── 0. Anti-spam / Fraud / Exclusion Filter ────────────────────────────
    final containsShortenedOrWebLink = RegExp(
      r'(?:bit\.ly|tinyurl\.com|t\.co|goo\.gl|is\.gd|buff\.ly|ow\.ly|http:\/\/|https:\/\/|www\.)',
      caseSensitive: false,
    ).hasMatch(cleanSms);

    final spamOrPromoRegExp = RegExp(
      r'\b(recharge|pack|validity|data|offer|cashback\s+offer|discount|promo|coupon|deal|plan|loan|apply\s+now|credit\s+card\s+limit|opt\s+out|pre-approved|finance\s+offer|claim\s+now|free|cashback\s+upto|earn|points|rewards|win|client\s+code|mapped\s+under|pine\s+labs|apay\s+balance|amazon\s+pay\s+balance|wallet)\b',
      caseSensitive: false,
    );

    final mobileNumberAccountPattern = RegExp(
      r'(?:a/c|acct|account)\s*(?:no\.?|num\.?)?\s*[:\s]*[6-9]\d{9}\b',
      caseSensitive: false,
    ).hasMatch(cleanSms);

    final isOtpOnly = RegExp(
      r'\b(otp|verification\s+code|secret\s+code|one\s+time\s+password)\b',
      caseSensitive: false,
    ).hasMatch(cleanSms) && !RegExp(r'\b(debited|credited|debit|credit)\b', caseSensitive: false).hasMatch(cleanSms);

    if (containsShortenedOrWebLink || spamOrPromoRegExp.hasMatch(cleanSms) || mobileNumberAccountPattern || isOtpOnly) {
      return _unparsed();
    }

    // ── Strict Template Pattern Matching ─────────────────────────────────────
    // Template 1: IPPB Debit
    // "A/C X6022 Debit Rs.20.00 for UPI to pankaj prakash on 03-08-26 Ref 563134185246. Avl Bal Rs.160.63. If not you? SMS FREEZE "full a/c" to 7669034700-IPPB"
    final ippbDebitPattern = RegExp(
      r'A/C\s+[\w\d]+\s+Debit\s+Rs\.?\s*([\d,]+(?:\.\d{1,2})?)\s+for\s+UPI\s+to\s+(.+?)\s+on\s+\d{2}[-/\.]\d{2}[-/\.]\d{2,4}(?:.*?(?:Ref|IPPB))?',
      caseSensitive: false,
    );
    final matchIppbDebit = ippbDebitPattern.firstMatch(cleanSms);
    if (matchIppbDebit != null && cleanSms.toUpperCase().contains('IPPB')) {
      final amtStr = matchIppbDebit.group(1)!.replaceAll(',', '');
      final amt = double.tryParse(amtStr) ?? 0.0;
      final merchant = matchIppbDebit.group(2)!.replaceAll(RegExp(r'\s+Ref.*', caseSensitive: false), '').trim();
      return _buildResult(
        amount: amt,
        merchant: merchant,
        category: _inferCategory(merchant, cleanSms),
        type: 'debit',
        accountType: 'UPI',
      );
    }

    // Template 2: IPPB Credit
    // "You have received a payment of Rs. 20.00 in a/c X6022 on 31/07/2026 19:22 from md ghulam moinuddin thru IPPB. Info: UPI/CREDIT/110332422882.-IPPB"
    final ippbCreditPattern = RegExp(
      r'You\s+have\s+received\s+a\s+payment\s+of\s+Rs\.?\s*([\d,]+(?:\.\d{1,2})?)\s+in\s+a/c\s+[\w\d]+\s+on\s+\d{2}[-/\.]\d{2}[-/\.]\d{2,4}(?:\s+\d{2}:\d{2})?\s+from\s+(.+?)\s+thru\s+IPPB',
      caseSensitive: false,
    );
    final matchIppbCredit = ippbCreditPattern.firstMatch(cleanSms);
    if (matchIppbCredit != null) {
      final amtStr = matchIppbCredit.group(1)!.replaceAll(',', '');
      final amt = double.tryParse(amtStr) ?? 0.0;
      final merchant = matchIppbCredit.group(2)!.trim();
      return _buildResult(
        amount: amt,
        merchant: merchant,
        category: _inferCategory(merchant, cleanSms),
        type: 'credit',
        accountType: 'UPI',
      );
    }

    // Template 3: Canara Bank Debited
    // "An amount of INR 654.00 has been DEBITED to your account XXXX5269 on 10/06/2026. Total Avail.bal INR 4,864.84.Dial 1930 to report cyber fraud - Canara Bank"
    final canaraDebitedPattern = RegExp(
      r'An\s+amount\s+of\s+INR\s*([\d,]+(?:\.\d{1,2})?)\s+has\s+been\s+DEBITED\s+to\s+your\s+account\s+[\w\d]+\s+on\s+\d{2}[-/\.]\d{2}[-/\.]\d{2,4}',
      caseSensitive: false,
    );
    final matchCanaraDebited = canaraDebitedPattern.firstMatch(cleanSms);
    if (matchCanaraDebited != null && cleanSms.toLowerCase().contains('canara')) {
      final amtStr = matchCanaraDebited.group(1)!.replaceAll(',', '');
      final amt = double.tryParse(amtStr) ?? 0.0;
      return _buildResult(
        amount: amt,
        merchant: 'Canara Bank Debit',
        category: 'General',
        type: 'debit',
        accountType: 'Bank Account',
      );
    }

    // Template 4: Canara Bank Credited
    // "An amount of INR 2,500.00 has been CREDITED to your account XXXX5269 on 20/06/2026.Total Avail.bal INR 4,293.88.- Canara Bank"
    final canaraCreditedPattern = RegExp(
      r'An\s+amount\s+of\s+INR\s*([\d,]+(?:\.\d{1,2})?)\s+has\s+been\s+CREDITED\s+to\s+your\s+account\s+[\w\d]+\s+on\s+\d{2}[-/\.]\d{2}[-/\.]\d{2,4}',
      caseSensitive: false,
    );
    final matchCanaraCredited = canaraCreditedPattern.firstMatch(cleanSms);
    if (matchCanaraCredited != null && cleanSms.toLowerCase().contains('canara')) {
      final amtStr = matchCanaraCredited.group(1)!.replaceAll(',', '');
      final amt = double.tryParse(amtStr) ?? 0.0;
      return _buildResult(
        amount: amt,
        merchant: 'Canara Bank Credit',
        category: 'General',
        type: 'credit',
        accountType: 'Bank Account',
      );
    }

    // Template 5: Canara Bank UPI Credit
    // "Dear Customer, Acct XXXX5269 credited with INR 244.00 on 04/08/26 from SHIVPAL  SIN; UPI:621632401455; Bal INR 4,975.19-CanaraBank"
    final canaraUpiCreditedPattern = RegExp(
      r'Dear\s+Customer,\s+Acct\s+[\w\d]+\s+credited\s+with\s+INR\s*([\d,]+(?:\.\d{1,2})?)\s+on\s+\d{2}[-/\.]\d{2}[-/\.]\d{2,4}\s+from\s+(.+?)(?:;|\s+UPI:)',
      caseSensitive: false,
    );
    final matchCanaraUpiCredited = canaraUpiCreditedPattern.firstMatch(cleanSms);
    if (matchCanaraUpiCredited != null && cleanSms.toLowerCase().contains('canarabank')) {
      final amtStr = matchCanaraUpiCredited.group(1)!.replaceAll(',', '');
      final amt = double.tryParse(amtStr) ?? 0.0;
      final merchant = matchCanaraUpiCredited.group(2)!.trim();
      return _buildResult(
        amount: amt,
        merchant: merchant,
        category: _inferCategory(merchant, cleanSms),
        type: 'credit',
        accountType: 'UPI',
      );
    }

    // Does not match any specified bank template
    return _unparsed();
  }

  SmsParserResult _unparsed() {
    return SmsParserResult(
      amount: 0.0,
      merchant: 'Unknown',
      category: 'Non-financial',
      type: 'none',
      accountType: 'Unknown',
      isParsedSuccessfully: false,
    );
  }

  SmsParserResult _buildResult({
    required double amount,
    required String merchant,
    required String category,
    required String type,
    required String accountType,
  }) {
    return SmsParserResult(
      amount: amount,
      merchant: merchant.isEmpty ? 'Bank Transaction' : merchant,
      category: category,
      type: type,
      accountType: accountType,
      isParsedSuccessfully: amount > 0,
    );
  }

  String _inferCategory(String merchant, String sms) {
    final lower = (merchant + " " + sms).toLowerCase();
    if (lower.contains('swiggy') || lower.contains('zomato') || lower.contains('food') || lower.contains('restaurant') || lower.contains('chai')) {
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
