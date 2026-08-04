import 'package:flutter_test/flutter_test.dart';
import 'package:khata/services/notification_parser_service.dart';

void main() {
  final parser = NotificationParserService();

  group('PhonePe & UPI Notification Parser Tests', () {
    test('PhonePe Credit Notification', () {
      final res = parser.parseNotification(
        packageName: 'com.phonepe.app',
        title: 'Received ₹250.00',
        text: 'Ramesh Kumar sent you ₹250.00 via PhonePe',
      );
      expect(res.isParsedSuccessfully, isTrue);
      expect(res.type, equals('credit'));
      expect(res.amount, equals(250.00));
      expect(res.appName, equals('PhonePe'));
    });

    test('PhonePe Debit Notification', () {
      final res = parser.parseNotification(
        packageName: 'com.phonepe.app',
        title: 'Paid ₹120.00',
        text: 'Paid ₹120.00 to Swiggy using PhonePe',
      );
      expect(res.isParsedSuccessfully, isTrue);
      expect(res.type, equals('debit'));
      expect(res.amount, equals(120.00));
      expect(res.merchant, equals('Swiggy'));
    });

    test('PhonePe Business Notification', () {
      final res = parser.parseNotification(
        packageName: 'com.phonepe.app.business',
        title: 'Payment Received',
        text: 'Received ₹500 from Anil Sharma',
      );
      expect(res.isParsedSuccessfully, isTrue);
      expect(res.type, equals('credit'));
      expect(res.amount, equals(500.00));
      expect(res.merchant, equals('Anil Sharma'));
    });
  });
}
