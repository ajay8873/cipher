import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_helper.dart';
import '../models/transaction_model.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._init();
  SupabaseClient? _client;

  SupabaseService._init();

  Future<void> initialize({required String url, required String anonKey}) async {
    if (url.isNotEmpty && anonKey.isNotEmpty && url != 'YOUR_SUPABASE_URL') {
      await Supabase.initialize(url: url, anonKey: anonKey);
      _client = Supabase.instance.client;
    }
  }

  /// Sync unsynced transactions from local SQLite to Supabase cloud database
  Future<int> syncLocalTransactionsToCloud() async {
    if (_client == null) {
      print('Supabase client not initialized.');
      return 0;
    }

    final db = DatabaseHelper.instance;
    final unsynced = await db.getUnsyncedTransactions();
    int syncedCount = 0;

    for (final tx in unsynced) {
      try {
        final payload = tx.toMap();
        payload.remove('id'); // Allow Supabase to assign primary key or use upsert
        payload['is_synced'] = 1;

        final response = await _client!.from('transactions').insert(payload).select();
        
        if (response.isNotEmpty && tx.id != null) {
          await db.updateSyncStatus(tx.id!, 1);
          syncedCount++;
        }
      } catch (e) {
        print('Error syncing transaction ID ${tx.id}: $e');
      }
    }

    return syncedCount;
  }
}
