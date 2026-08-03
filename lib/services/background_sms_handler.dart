import 'package:telephony/telephony.dart';
import '../models/transaction_model.dart';
import 'database_helper.dart';
import 'sms_parser_service.dart';
import 'overlay_service.dart';

/// Top-level background entry point required for background isolate execution
@pragma('vm:entry-point')
void backgroundSmsHandler(SmsMessage message) async {
  final body = message.body;
  if (body == null || body.isEmpty) return;

  // Skip if already stored (deduplication by raw SMS text)
  final alreadyExists = await DatabaseHelper.instance.transactionExistsByRawSms(body);
  if (alreadyExists) return;

  // Initialize SMS Parser Service
  final parser = SmsParserService();
  final result = await parser.parseSms(body);

  if (result.isParsedSuccessfully && result.amount > 0) {
    final newTransaction = TransactionModel(
      rawSms: body,
      amount: result.amount,
      merchant: result.merchant,
      category: result.category,
      date: DateTime.now().toIso8601String(),
      type: result.type,
      accountType: result.accountType,
      isSynced: 0,
      senderAddress: message.address,
    );

    // 2. Direct write to SQLite database
    final insertedId = await DatabaseHelper.instance.insertTransaction(newTransaction);

    // 3. Show System Overlay Window for purpose & recipient input
    await OverlayService.showTransactionOverlay(
      transactionId: insertedId,
      amount: result.amount,
      merchant: result.merchant,
      category: result.category,
    );
  }
}

class BackgroundSmsListenerService {
  final Telephony _telephony = Telephony.instance;

  /// Initialize foreground and background SMS listening
  Future<void> initializeSmsListener() async {
    final bool? permissionsGranted = await _telephony.requestPhoneAndSmsPermissions;

    if (permissionsGranted == true) {
      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          // Trigger when app is in foreground
          backgroundSmsHandler(message);
        },
        onBackgroundMessage: backgroundSmsHandler,
        listenInBackground: true,
      );
    }
  }

  /// Scans the device SMS inbox for the past [daysBack] days and imports any
  /// bank/financial SMS messages that haven't been recorded yet.
  /// Returns the count of newly imported transactions.
  Future<int> scanInboxForMissedTransactions({int daysBack = 30}) async {
    final parser = SmsParserService();
    int importedCount = 0;

    try {
      // Calculate the cutoff timestamp (milliseconds since epoch)
      final cutoffDate = DateTime.now().subtract(Duration(days: daysBack));
      final cutoffMs = cutoffDate.millisecondsSinceEpoch;

      // Read inbox SMS from telephony package
      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.DATE).greaterThanOrEqualTo(cutoffMs.toString()),
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      for (final message in messages) {
        final body = message.body;
        if (body == null || body.isEmpty) continue;

        // Skip non-financial SMS early (avoids expensive DB + parse calls)
        final isFinancial = RegExp(
          r'(debited|credited|spent|paid|sent|withdrawn|transferred|received|deposited)',
          caseSensitive: false,
        ).hasMatch(body);
        if (!isFinancial) continue;

        // Deduplication — skip if this exact SMS is already stored
        final alreadyExists = await DatabaseHelper.instance.transactionExistsByRawSms(body);
        if (alreadyExists) continue;

        // Parse the SMS
        final result = await parser.parseSms(body);
        if (!result.isParsedSuccessfully || result.amount <= 0) continue;

        // Use the SMS timestamp if available, otherwise fallback to now
        final smsDate = message.date != null
            ? DateTime.fromMillisecondsSinceEpoch(message.date!).toIso8601String()
            : DateTime.now().toIso8601String();

        final newTransaction = TransactionModel(
          rawSms: body,
          amount: result.amount,
          merchant: result.merchant,
          category: result.category,
          date: smsDate,
          type: result.type,
          accountType: result.accountType,
          isSynced: 0,
          senderAddress: message.address,
        );

        await DatabaseHelper.instance.insertTransaction(newTransaction);
        importedCount++;
      }
    } catch (e) {
      print('Error scanning SMS inbox: $e');
    }

    return importedCount;
  }
}
