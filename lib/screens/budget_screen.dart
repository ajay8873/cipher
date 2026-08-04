import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget_debt_models.dart';
import '../services/database_helper.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({Key? key}) : super(key: key);

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  DateTime _selectedMonth = DateTime.now();
  Map<String, double> _allocatedBudgets = {};
  Map<String, double> _actualExpenses = {};
  bool _isLoading = true;

  final List<String> _defaultCategories = [
    'Food & Dining',
    'Transport',
    'Shopping',
    'Bills & Utilities',
    'Entertainment',
    'Health',
    'General',
  ];

  List<String> get _allCategories {
    final set = <String>{..._defaultCategories, ..._allocatedBudgets.keys, ..._actualExpenses.keys};
    return set.toList();
  }

  @override
  void initState() {
    super.initState();
    _loadBudgetData();
  }

  Future<void> _loadBudgetData() async {
    setState(() => _isLoading = true);
    final month = _selectedMonth.month;
    final year = _selectedMonth.year;

    final budgets = await DatabaseHelper.instance.getCategoryBudgets(month, year);
    final transactions = await DatabaseHelper.instance.getAllTransactions();

    final monthStart = DateTime(year, month, 1);
    final monthEnd = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);

    final Map<String, double> actual = {};
    for (var tx in transactions) {
      if (tx.type != 'debit') continue;
      DateTime? d = DateTime.tryParse(tx.date);
      if (d == null) {
        final ms = int.tryParse(tx.date);
        if (ms != null) {
          d = DateTime.fromMillisecondsSinceEpoch(ms);
        }
      }
      if (d != null && d.year == year && d.month == month) {
        final catKey = (tx.category == 'Food') ? 'Food & Dining' : tx.category;
        actual[catKey] = (actual[catKey] ?? 0.0) + tx.amount;
      }
    }

    setState(() {
      _allocatedBudgets = budgets;
      _actualExpenses = actual;
      _isLoading = false;
    });
  }

  void _showAddCustomCategoryBudgetDialog() {
    final catController = TextEditingController();
    final amountController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Add Custom Budget Category",
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: catController,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: "Category Name (e.g. Rent, Gym, Travel)",
                filled: true,
                fillColor: isDark ? const Color(0xFF2B2B3D) : const Color(0xFFF0F1F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: "Allocated Budget",
                prefixText: "₹ ",
                filled: true,
                fillColor: isDark ? const Color(0xFF2B2B3D) : const Color(0xFFF0F1F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final cat = catController.text.trim();
              final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
              if (cat.isEmpty) return;

              await DatabaseHelper.instance.setCategoryBudget(
                category: cat,
                allocatedAmount: amount,
                month: _selectedMonth.month,
                year: _selectedMonth.year,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _loadBudgetData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Add Budget", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSetBudgetDialog(String category, double currentAllocated) {
    final controller = TextEditingController(
      text: currentAllocated > 0 ? currentAllocated.toStringAsFixed(0) : '',
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Set Budget for $category",
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Set allocated budget for ${DateFormat('MMMM yyyy').format(_selectedMonth)}:",
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: "₹ ",
                prefixStyle: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: isDark ? const Color(0xFF2B2B3D) : const Color(0xFFF0F1F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text.trim()) ?? 0.0;
              await DatabaseHelper.instance.setCategoryBudget(
                category: category,
                allocatedAmount: amount,
                month: _selectedMonth.month,
                year: _selectedMonth.year,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _loadBudgetData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Save Budget", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: "₹", decimalDigits: 0);

    double totalAllocated = _allocatedBudgets.values.fold(0.0, (a, b) => a + b);
    double totalSpent = _actualExpenses.values.fold(0.0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const Text("Monthly Budget Allocator", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Month Selector Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                          onPressed: () {
                            setState(() {
                              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                            });
                            _loadBudgetData();
                          },
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(_selectedMonth),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                          onPressed: () {
                            setState(() {
                              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                            });
                            _loadBudgetData();
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Overall Budget Summary Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Total Allocated", style: TextStyle(color: Colors.white70, fontSize: 13)),
                                Text(currency.format(totalAllocated),
                                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text("Total Expended", style: TextStyle(color: Colors.white70, fontSize: 13)),
                                Text(currency.format(totalSpent),
                                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        LinearProgressIndicator(
                          value: totalAllocated > 0 ? (totalSpent / totalAllocated).clamp(0.0, 1.0) : 0.0,
                          backgroundColor: Colors.white24,
                          color: (totalSpent > totalAllocated && totalAllocated > 0)
                              ? const Color(0xFFFF7675)
                              : const Color(0xFF55E6C1),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Category Budget List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _allCategories.length,
                    itemBuilder: (ctx, idx) {
                      final cat = _allCategories[idx];
                      final allocated = _allocatedBudgets[cat] ?? 0.0;
                      final spent = _actualExpenses[cat] ?? 0.0;
                      final percent = allocated > 0 ? (spent / allocated).clamp(0.0, 1.0) : 0.0;
                      final isOverBudget = spent > allocated && allocated > 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(cat, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)),
                                InkWell(
                                  onTap: () => _showSetBudgetDialog(cat, allocated),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6C5CE7).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF6C5CE7)),
                                        const SizedBox(width: 4),
                                        Text(allocated > 0 ? currency.format(allocated) : "Set Budget",
                                            style: const TextStyle(color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Expended: ${currency.format(spent)}",
                                    style: TextStyle(color: isOverBudget ? const Color(0xFFFF7675) : (isDark ? Colors.white60 : Colors.black54), fontSize: 12)),
                                Text(allocated > 0 ? "${(percent * 100).toStringAsFixed(0)}%" : "No limit",
                                    style: TextStyle(color: isOverBudget ? const Color(0xFFFF7675) : const Color(0xFF00B894), fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: percent,
                              backgroundColor: isDark ? const Color(0xFF2B2B3D) : const Color(0xFFF0F1F5),
                              color: isOverBudget ? const Color(0xFFFF7675) : const Color(0xFF00B894),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCustomCategoryBudgetDialog,
        backgroundColor: const Color(0xFF6C5CE7),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Custom Category Budget", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
