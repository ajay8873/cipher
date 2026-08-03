class TransactionModel {
  final int? id;
  final String rawSms;
  final double amount;
  final String merchant;
  final String category;
  final String? recipient;
  final String? purpose;
  final String date;
  final String type; // 'debit' or 'credit'
  final String accountType; // 'UPI', 'Bank Account', 'Credit Card', etc.
  final int isSynced; // 0 = false, 1 = true
  final String? senderAddress; // SMS sender e.g. "AD-HDFCBK", "VM-ICICIB"

  TransactionModel({
    this.id,
    required this.rawSms,
    required this.amount,
    required this.merchant,
    required this.category,
    this.recipient,
    this.purpose,
    required this.date,
    required this.type,
    required this.accountType,
    this.isSynced = 0,
    this.senderAddress,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'raw_sms': rawSms,
      'amount': amount,
      'merchant': merchant,
      'category': category,
      'recipient': recipient,
      'purpose': purpose,
      'date': date,
      'type': type,
      'account_type': accountType,
      'is_synced': isSynced,
      'sender_address': senderAddress,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      rawSms: map['raw_sms'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      merchant: map['merchant'] as String? ?? 'Unknown',
      category: map['category'] as String? ?? 'General',
      recipient: map['recipient'] as String?,
      purpose: map['purpose'] as String?,
      date: map['date'] as String? ?? DateTime.now().toIso8601String(),
      type: map['type'] as String? ?? 'debit',
      accountType: map['account_type'] as String? ?? 'Bank Account',
      isSynced: (map['is_synced'] as int?) ?? 0,
      senderAddress: map['sender_address'] as String?,
    );
  }

  TransactionModel copyWith({
    int? id,
    String? rawSms,
    double? amount,
    String? merchant,
    String? category,
    String? recipient,
    String? purpose,
    String? date,
    String? type,
    String? accountType,
    int? isSynced,
    String? senderAddress,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      rawSms: rawSms ?? this.rawSms,
      amount: amount ?? this.amount,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      recipient: recipient ?? this.recipient,
      purpose: purpose ?? this.purpose,
      date: date ?? this.date,
      type: type ?? this.type,
      accountType: accountType ?? this.accountType,
      isSynced: isSynced ?? this.isSynced,
      senderAddress: senderAddress ?? this.senderAddress,
    );
  }
}
