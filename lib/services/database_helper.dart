import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../models/budget_debt_models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('khata_expenses.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        raw_sms TEXT NOT NULL,
        amount REAL NOT NULL,
        merchant TEXT NOT NULL,
        category TEXT NOT NULL,
        recipient TEXT,
        purpose TEXT,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        account_type TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        sender_address TEXT
      )
    ''');

    await _createBudgetAndDebtTables(db);
  }

  Future<void> _createBudgetAndDebtTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        allocated_amount REAL NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        UNIQUE(category, month, year) ON CONFLICT REPLACE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person_name TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        is_settled INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE transactions ADD COLUMN sender_address TEXT');
    }
    if (oldVersion < 3) {
      await _createBudgetAndDebtTables(db);
    }
  }

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await instance.database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'date DESC');
    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  Future<TransactionModel?> getTransactionById(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return TransactionModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateTransactionDetails({
    required int id,
    required String purpose,
    required String recipient,
    String? category,
  }) async {
    final db = await instance.database;
    final Map<String, dynamic> values = {
      'purpose': purpose,
      'recipient': recipient,
    };
    if (category != null && category.isNotEmpty) {
      values['category'] = category;
    }
    return await db.update(
      'transactions',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateSyncStatus(int id, int isSynced) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      {'is_synced': isSynced},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<TransactionModel>> getUnsyncedTransactions() async {
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  Future<double> getMonthlySpend() async {
    final db = await instance.database;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total 
      FROM transactions 
      WHERE type = 'debit' AND date >= ?
    ''', [startOfMonth]);

    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  /// Returns debit and credit totals for a specific year+month.
  Future<Map<String, double>> getMonthSummary(int year, int month) async {
    final db = await instance.database;

    // Safe end date: roll over December → January of next year
    final startDt = DateTime(year, month, 1);
    final endDt   = (month == 12)
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);

    final start = startDt.toIso8601String();
    final end   = endDt.toIso8601String();

    final debitResult = await db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions
      WHERE type = 'debit' AND date >= ? AND date < ?
    ''', [start, end]);

    final creditResult = await db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions
      WHERE type = 'credit' AND date >= ? AND date < ?
    ''', [start, end]);

    return {
      'debit':  (debitResult.first['total']  as num?)?.toDouble() ?? 0.0,
      'credit': (creditResult.first['total'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// Updates all user-editable fields of a transaction.
  Future<int> updateFullTransaction(TransactionModel tx) async {
    if (tx.id == null) return 0;
    final db = await instance.database;
    return await db.update(
      'transactions',
      {
        'merchant':      tx.merchant,
        'amount':        tx.amount,
        'category':      tx.category,
        'purpose':       tx.purpose,
        'recipient':     tx.recipient,
        'type':          tx.type,
        'account_type':  tx.accountType,
        'date':          tx.date,
      },
      where: 'id = ?',
      whereArgs: [tx.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearAllTransactions() async {
    final db = await instance.database;
    return await db.delete('transactions');
  }

  /// Deletes only SMS-imported transactions (keeps manual entries intact).
  Future<int> clearSmsImportedTransactions() async {
    final db = await instance.database;
    return await db.delete(
      'transactions',
      where: "raw_sms != ?",
      whereArgs: ['Manual Entry'],
    );
  }

  /// Returns true if a transaction with the same raw SMS body already exists.
  /// Used for deduplication when scanning the SMS inbox.
  Future<bool> transactionExistsByRawSms(String rawSms) async {
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      columns: ['id'],
      where: 'raw_sms = ?',
      whereArgs: [rawSms],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Hybrid deduplication: Checks if a transaction with matching amount, type ('credit'/'debit'),
  /// and created within [windowMinutes] (default 5 mins) already exists.
  /// Prevents double counting when BOTH SMS and Push Notification arrive for the same payment.
  Future<bool> hasSimilarRecentTransaction({
    required double amount,
    required String type,
    int windowMinutes = 5,
  }) async {
    final db = await instance.database;
    final cutoff = DateTime.now().subtract(Duration(minutes: windowMinutes)).toIso8601String();

    final result = await db.query(
      'transactions',
      columns: ['id'],
      where: 'ABS(amount - ?) < 0.05 AND type = ? AND date >= ?',
      whereArgs: [amount, type, cutoff],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Export all transactions as a JSON string for user backups
  Future<String> exportBackupJson() async {
    final transactions = await getAllTransactions();
    final jsonList = transactions.map((t) => t.toMap()).toList();
    return jsonEncode(jsonList);
  }

  /// Import transactions from a JSON backup string with smart deduplication
  Future<int> restoreBackupJson(String jsonStr) async {
    final List<dynamic> decoded = jsonDecode(jsonStr);
    final db = await instance.database;
    int importedCount = 0;

    for (var item in decoded) {
      if (item is Map<String, dynamic>) {
        final Map<String, dynamic> cleanMap = Map<String, dynamic>.from(item);
        cleanMap.remove('id'); // Allow DB to generate new auto-increment ID
        final tx = TransactionModel.fromMap(cleanMap);

        // Deduplication Check 1: Check by raw_sms for SMS/Notification entries
        if (tx.rawSms.isNotEmpty && tx.rawSms != 'Manual Entry') {
          final exists = await transactionExistsByRawSms(tx.rawSms);
          if (exists) continue; // Skip duplicate
        } else {
          // Deduplication Check 2: Check by exact fingerprint (amount, type, date, merchant) for Manual entries
          final existing = await db.query(
            'transactions',
            columns: ['id'],
            where: 'ABS(amount - ?) < 0.01 AND type = ? AND date = ? AND merchant = ?',
            whereArgs: [tx.amount, tx.type, tx.date, tx.merchant],
            limit: 1,
          );
          if (existing.isNotEmpty) continue; // Skip duplicate
        }

        await insertTransaction(tx);
        importedCount++;
      }
    }
    return importedCount;
  }

  // ── Budget Operations ───────────────────────────────────────────────────
  Future<void> setCategoryBudget({
    required String category,
    required double allocatedAmount,
    required int month,
    required int year,
  }) async {
    final db = await instance.database;
    await db.insert(
      'budgets',
      {
        'category': category,
        'allocated_amount': allocatedAmount,
        'month': month,
        'year': year,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, double>> getCategoryBudgets(int month, int year) async {
    final db = await instance.database;
    final result = await db.query(
      'budgets',
      where: 'month = ? AND year = ?',
      whereArgs: [month, year],
    );

    final Map<String, double> map = {};
    for (var row in result) {
      map[row['category'] as String] = (row['allocated_amount'] as num).toDouble();
    }
    return map;
  }

  // ── Khatabook Debt/Lent Operations ──────────────────────────────────────
  Future<int> insertDebt(DebtModel debt) async {
    final db = await instance.database;
    return await db.insert('debts', debt.toMap());
  }

  Future<List<DebtModel>> getAllDebts() async {
    final db = await instance.database;
    final result = await db.query('debts', orderBy: 'is_settled ASC, date DESC');
    return result.map((json) => DebtModel.fromMap(json)).toList();
  }

  Future<void> toggleDebtSettled(int id, bool isSettled) async {
    final db = await instance.database;
    await db.update(
      'debts',
      {'is_settled': isSettled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDebt(int id) async {
    final db = await instance.database;
    await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }
}

