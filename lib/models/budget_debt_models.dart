class CategoryBudgetModel {
  final int? id;
  final String category;
  final double allocatedAmount;
  final int month;
  final int year;

  CategoryBudgetModel({
    this.id,
    required this.category,
    required this.allocatedAmount,
    required this.month,
    required this.year,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'allocated_amount': allocatedAmount,
      'month': month,
      'year': year,
    };
  }

  factory CategoryBudgetModel.fromMap(Map<String, dynamic> map) {
    return CategoryBudgetModel(
      id: map['id'] as int?,
      category: map['category'] as String,
      allocatedAmount: (map['allocated_amount'] as num).toDouble(),
      month: map['month'] as int,
      year: map['year'] as int,
    );
  }
}

class DebtModel {
  final int? id;
  final String personName;
  final double amount;
  final String type; // 'lent' (you gave) or 'borrowed' (you owe)
  final String note;
  final String date;
  final bool isSettled;

  DebtModel({
    this.id,
    required this.personName,
    required this.amount,
    required this.type,
    required this.note,
    required this.date,
    this.isSettled = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'person_name': personName,
      'amount': amount,
      'type': type,
      'note': note,
      'date': date,
      'is_settled': isSettled ? 1 : 0,
    };
  }

  factory DebtModel.fromMap(Map<String, dynamic> map) {
    return DebtModel(
      id: map['id'] as int?,
      personName: map['person_name'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      note: map['note'] as String? ?? '',
      date: map['date'] as String,
      isSettled: (map['is_settled'] as int? ?? 0) == 1,
    );
  }
}
