import 'dart:isolate';
import 'dart:ui';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import '../models/transaction_model.dart';
import 'database_helper.dart';
import 'notification_parser_service.dart';
import 'overlay_service.dart';

class BackgroundNotificationHandler {
  static final NotificationParserService _parser = NotificationParserService();

  /// Starts listening to system notification events
  static Future<void> startListening() async {
    final bool? isServiceRunning = await NotificationsListener.isRunning;
    if (isServiceRunning != true) {
      await NotificationsListener.startService(
        title: "Khata Transaction Monitor",
        description: "Listening for UPI & Bank payments...",
      );
    }

    // Register notification callback port
    ReceivePort port = ReceivePort();
    IsolateNameServer.registerPortWithName(port.sendPort, 'notification_listener_port');
    port.listen((dynamic data) {
      _onNotificationReceived(data);
    });

    NotificationsListener.initialize(callbackHandle: _onNotificationCallback);
  }

  /// Top-level or static callback required by flutter_notification_listener
  @pragma('vm:entry-point')
  static void _onNotificationCallback(NotificationEvent event) {
    SendPort? send = IsolateNameServer.lookupPortByName('notification_listener_port');
    if (send != null) {
      send.send(event);
    } else {
      _processEvent(event);
    }
  }

  static void _onNotificationReceived(dynamic data) {
    if (data is NotificationEvent) {
      _processEvent(data);
    }
  }

  static void _processEvent(NotificationEvent event) async {
    final packageName = event.packageName ?? '';
    final title = event.title ?? '';
    final text = event.message ?? event.text ?? '';

    if (packageName.isEmpty || (title.isEmpty && text.isEmpty)) return;

    // Check if notification is from a supported UPI payment app (PhonePe, GPay, Paytm, Navi, CRED, BHIM, etc.)
    if (!NotificationParserService.isSupportedPackage(packageName)) return;

    final result = _parser.parseNotification(
      packageName: packageName,
      title: title,
      text: text,
    );

    if (result.isParsedSuccessfully && result.amount > 0) {
      // ── Hybrid Deduplication Check ───────────────────────────────────────
      // If a transaction with matching amount & type ('credit'/'debit') arrived via SMS or Notification in the last 5 mins, skip!
      final isDuplicate = await DatabaseHelper.instance.hasSimilarRecentTransaction(
        amount: result.amount,
        type: result.type,
        windowMinutes: 5,
      );

      if (isDuplicate) return;

      final rawPayload = '[$packageName] $title: $text';

      final newTransaction = TransactionModel(
        rawSms: rawPayload,
        amount: result.amount,
        merchant: result.merchant,
        category: result.category,
        date: DateTime.now().toIso8601String(),
        type: result.type,
        accountType: result.accountType,
        isSynced: 0,
        senderAddress: result.appName,
      );

      // Insert transaction into local SQLite database
      final insertedId = await DatabaseHelper.instance.insertTransaction(newTransaction);

      // Trigger overlay window for purpose & recipient tagging
      await OverlayService.showTransactionOverlay(
        transactionId: insertedId,
        amount: result.amount,
        merchant: result.merchant,
        category: result.category,
      );
    }
  }
}
