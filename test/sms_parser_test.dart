import 'package:flutter_test/flutter_test.dart';
import 'package:khata/services/sms_parser_service.dart';

void main() {
  final parser = SmsParserService();

  group('Bank SMS Parser Strict Unit Tests', () {
    test('Canara Bank Format 1 - Credited', () async {
      const sms = 'Dear Customer, Acct XXXX5269 credited with INR 244.00 on 04/08/26 from SHIVPAL  SIN; UPI:621632401455; Bal INR 4,975.19-CanaraBank';
      final res = await parser.parseSms(sms);
      expect(res.isParsedSuccessfully, isTrue);
      expect(res.type, equals('credit'));
      expect(res.amount, equals(244.00));
      expect(res.merchant, equals('SHIVPAL  SIN'));
    });

    test('Canara Bank Format 2 - CREDITED', () async {
      const sms = 'An amount of INR 2,500.00 has been CREDITED to your account XXXX5269 on 20/06/2026.Total Avail.bal INR 4,293.88.- Canara Bank';
      final res = await parser.parseSms(sms);
      expect(res.isParsedSuccessfully, isTrue);
      expect(res.type, equals('credit'));
      expect(res.amount, equals(2500.00));
    });

    test('Canara Bank Format 3 - DEBITED', () async {
      const sms = 'An amount of INR 654.00 has been DEBITED to your account XXXX5269 on 10/06/2026. Total Avail.bal INR 4,864.84.Dial 1930 to report cyber fraud - Canara Bank';
      final res = await parser.parseSms(sms);
      expect(res.isParsedSuccessfully, isTrue);
      expect(res.type, equals('debit'));
      expect(res.amount, equals(654.00));
    });

    test('IPPB Format 1 - A/C Debit Rs.', () async {
      const sms = 'A/C X6022 Debit Rs.48.00 for UPI to arvind chai sa on 26-07-26 Ref 839044834000. Avl Bal Rs.139.48. If not you? SMS FREEZE "full a/c" to 7669034700-IPPB';
      final res = await parser.parseSms(sms);
      expect(res.isParsedSuccessfully, isTrue);
      expect(res.type, equals('debit'));
      expect(res.amount, equals(48.00));
      expect(res.merchant, equals('arvind chai sa'));
    });

    test('IPPB Format 2 - Received payment credit', () async {
      const sms = 'You have received a payment of Rs. 40.00 in a/c X6022 on 31/07/2026 19:22 from anchit xalxo thru IPPB. Info: UPI/CREDIT/103537480064.-IPPB';
      final res = await parser.parseSms(sms);
      expect(res.isParsedSuccessfully, isTrue);
      expect(res.type, equals('credit'));
      expect(res.amount, equals(40.00));
      expect(res.merchant, equals('anchit xalxo'));
    });

    test('IPPB Format 3 - Received payment credit 2', () async {
      const sms = 'You have received a payment of Rs. 20.00 in a/c X6022 on 31/07/2026 19:22 from md ghulam moinuddin thru IPPB. Info: UPI/CREDIT/110332422882.-IPPB';
      final res = await parser.parseSms(sms);
      expect(res.isParsedSuccessfully, isTrue);
      expect(res.type, equals('credit'));
      expect(res.amount, equals(20.00));
      expect(res.merchant, equals('md ghulam moinuddin'));
    });

    test('IPPB Format 4 - A/C Debit Rs. 2', () async {
      const sms = 'A/C X6022 Debit Rs.20.00 for UPI to pankaj prakash on 03-08-26 Ref 563134185246. Avl Bal Rs.160.63. If not you? SMS FREEZE "full a/c" to 7669034700-IPPB';
      final res = await parser.parseSms(sms);
      expect(res.isParsedSuccessfully, isTrue);
      expect(res.type, equals('debit'));
      expect(res.amount, equals(20.00));
      expect(res.merchant, equals('pankaj prakash'));
    });

    test('PNB Debited SMS Format', () async {
      const sms = '𝐀/𝐜 X5425 𝐝𝐞𝐛𝐢𝐭𝐞𝐝 𝐈𝐍𝐑 100.00 𝐃𝐭 10-08-26 17:25:25 𝐭𝐨 SONU PROFESSION 𝐭𝐡𝐫𝐮 𝐔𝐏𝐈:648945487357..𝐁𝐚𝐥 𝐈𝐍𝐑 3816.58 𝐍𝐨𝐭 𝐮?𝐅𝐰𝐝 𝐭𝐡𝐢𝐬 𝐒𝐌𝐒 𝐭𝐨 𝟗𝟐𝟔𝟴𝟎𝟗𝟐𝟔𝟴𝟎 𝐭𝐨 𝐛𝐥𝐨𝐜𝐤 𝐔𝐏𝐈.-𝐏𝐍𝐁';
      final res = await parser.parseSms(sms);
      expect(res.isParsedSuccessfully, isTrue);
      expect(res.type, equals('debit'));
      expect(res.amount, equals(100.00));
      expect(res.merchant, equals('SONU PROFESSION'));
    });

    test('PNB Credited SMS Format', () async {
      const sms = '𝐀/𝐜 X5425 𝐜𝐫𝐞𝐝𝐢𝐭𝐞𝐝 𝐟𝐨𝐫 𝐈𝐍𝐑 500.00 𝐨𝐧 07-08-26 14:35:29 𝐛𝐲 DEEKSHA TOMAR D 𝐭𝐡𝐫𝐮 𝐔𝐏𝐈.𝐀𝐯𝐥𝐁𝐚𝐥 𝐈𝐍𝐑 3255.58(𝐔𝐏𝐈:127519520469).-𝐏𝐍𝐁';
      final res = await parser.parseSms(sms);
      expect(res.isParsedSuccessfully, isTrue);
      expect(res.type, equals('credit'));
      expect(res.amount, equals(500.00));
      expect(res.merchant, equals('DEEKSHA TOMAR D'));
    });

    test('PNB Credited SMS Format 2 (Passbook / Cash deposit)', () async {
      const sms = '𝖠𝖼 XX5425 𝖢𝗋𝖾𝖽𝗂𝗍𝖾𝖽 𝗐𝗂𝗍𝗁 Rs.1150.00,07-08-2026 15:13:02.𝖠𝗏𝗅 𝖡𝖺𝗅 Rs.4405.58CR.𝖧𝖾𝗅𝗉𝗅𝗂𝗇𝖾 𝟣𝟪𝟢𝟢𝟣𝟪𝟢𝟢/𝟣𝟪𝟢𝟢𝟤𝟢𝟤𝟣.𝖢𝗁𝖾𝖼𝗄 𝖢𝖺𝗌𝗁 𝖽𝖾𝗉𝗈𝗌𝗂𝗍 𝖾𝗇𝗍𝗋𝗒 𝗂𝗇 𝖯𝖺𝗌𝗌𝖻𝗈𝗈𝗄/𝖯𝖭𝖡𝖮𝗇𝖾-𝖯𝖭𝖡.';
      final res = await parser.parseSms(sms);
      expect(res.isParsedSuccessfully, isTrue);
      expect(res.type, equals('credit'));
      expect(res.amount, equals(1150.00));
      expect(res.merchant, equals('Cash Deposit'));
    });

    test('Non-matching SMS template should be rejected strictly', () async {
      const sms = 'Your bank account has been debited with Rs. 100 for purchase at Store';
      final res = await parser.parseSms(sms);
      expect(res.isParsedSuccessfully, isFalse);
    });
  });
}
