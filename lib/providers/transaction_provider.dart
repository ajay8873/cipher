import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../services/database_helper.dart';
import '../services/supabase_service.dart';
import '../services/overlay_service.dart';
import '../services/sms_parser_service.dart';
import '../services/background_sms_handler.dart';

class TransactionProvider with ChangeNotifier {
  List<TransactionModel> _transactions = [];
  double _monthlySpend = 0.0;
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isScanning = false;
  int _lastScanCount = 0;
  bool _smsScanEnabled = false; // disabled by default
  bool _isDarkMode = false; // Light mode is default theme

  List<TransactionModel> get transactions => _transactions;
  double get monthlySpend => _monthlySpend;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isScanning => _isScanning;
  int get lastScanCount => _lastScanCount;
  bool get smsScanEnabled => _smsScanEnabled;
  bool get isDarkMode => _isDarkMode;

  /// Load scan preference and theme mode from SharedPreferences
  Future<void> loadSmsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _smsScanEnabled = prefs.getBool('sms_scan_enabled') ?? false;
    _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    notifyListeners();
  }

  /// Toggle Light/Dark Theme Mode
  Future<void> toggleThemeMode() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDarkMode);
    notifyListeners();
  }

  /// Toggle scan SMS on/off and persist the setting.
  /// When disabled, all transactions that were imported from SMS
  /// (raw_sms != 'Manual Entry') are deleted.
  Future<void> setSmsScanning(bool enabled) async {
    _smsScanEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sms_scan_enabled', enabled);

    if (!enabled) {
      // Clear all SMS-imported transactions — keep only manual entries
      await DatabaseHelper.instance.clearSmsImportedTransactions();
      await fetchTransactions();
    }

    notifyListeners();
  }

  Future<void> fetchTransactions() async {
    _isLoading = true;
    notifyListeners();

    try {
      _transactions = await DatabaseHelper.instance.getAllTransactions();
      _monthlySpend = await DatabaseHelper.instance.getMonthlySpend();
    } catch (e) {
      print('Error fetching transactions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncCloud() async {
    _isSyncing = true;
    notifyListeners();

    try {
      await SupabaseService.instance.syncLocalTransactionsToCloud();
      await fetchTransactions();
    } catch (e) {
      print('Error during sync: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Add a manual transaction directly from UI
  Future<void> addManualTransaction(TransactionModel tx) async {
    _isLoading = true;
    notifyListeners();

    try {
      await DatabaseHelper.instance.insertTransaction(tx);
      await fetchTransactions();
    } catch (e) {
      print('Error adding manual transaction: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteTransaction(int id) async {
    try {
      await DatabaseHelper.instance.deleteTransaction(id);
      await fetchTransactions();
    } catch (e) {
      print('Error deleting transaction: $e');
    }
  }

  /// Restores a previously deleted transaction (undo support).
  /// Re-inserts the full TransactionModel into the database.
  Future<void> restoreTransaction(TransactionModel tx) async {
    try {
      final restored = tx.copyWith(id: null);
      await DatabaseHelper.instance.insertTransaction(restored);
      await fetchTransactions();
    } catch (e) {
      print('Error restoring transaction: $e');
    }
  }

  /// Updates all editable fields of an existing transaction.
  Future<void> updateTransaction(TransactionModel tx) async {
    try {
      await DatabaseHelper.instance.updateFullTransaction(tx);
      await fetchTransactions();
    } catch (e) {
      print('Error updating transaction: $e');
    }
  }

  Future<void> clearAllTransactions() async {
    try {
      await DatabaseHelper.instance.clearAllTransactions();
      await fetchTransactions();
    } catch (e) {
      print('Error clearing transactions: $e');
    }
  }

  /// Simulate receiving a transaction SMS for manual testing & overlay verification
  Future<void> simulateTestSms(String rawSms) async {
    final parser = SmsParserService();
    final result = await parser.parseSms(rawSms);

    if (result.isParsedSuccessfully) {
      final tx = TransactionModel(
        rawSms: rawSms,
        amount: result.amount,
        merchant: result.merchant,
        category: result.category,
        date: DateTime.now().toIso8601String(),
        type: result.type,
        accountType: result.accountType,
      );

      final id = await DatabaseHelper.instance.insertTransaction(tx);
      await fetchTransactions();

      try {
        // Trigger System Alert Window Overlay
        await OverlayService.showTransactionOverlay(
          transactionId: id,
          amount: result.amount,
          merchant: result.merchant,
          category: result.category,
        );
      } catch (e) {
        print('Error displaying overlay: $e');
      }
    }
  }

  /// Scans the device SMS inbox for the past [daysBack] days and imports missed transactions.
  /// Safe to call repeatedly — deduplication prevents double-importing.
  /// Only runs if [_smsScanEnabled] is true.
  Future<void> scanSmsInbox({int daysBack = 30}) async {
    if (!_smsScanEnabled) return;
    _isScanning = true;
    _lastScanCount = 0;
    notifyListeners();

    try {
      final service = BackgroundSmsListenerService();
      _lastScanCount = await service.scanInboxForMissedTransactions(daysBack: daysBack);
      await fetchTransactions();
    } catch (e) {
      print('Error scanning SMS inbox: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }
}
