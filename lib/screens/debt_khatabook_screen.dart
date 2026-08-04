import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget_debt_models.dart';
import '../services/database_helper.dart';

class DebtKhatabookScreen extends StatefulWidget {
  const DebtKhatabookScreen({Key? key}) : super(key: key);

  @override
  State<DebtKhatabookScreen> createState() => _DebtKhatabookScreenState();
}

class _DebtKhatabookScreenState extends State<DebtKhatabookScreen> {
  List<DebtModel> _debts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDebts();
  }

  Future<void> _loadDebts() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllDebts();
    setState(() {
      _debts = data;
      _isLoading = false;
    });
  }

  void _showAddDebtDialog({required String initialType}) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String type = initialType; // 'lent' (you gave) or 'borrowed' (you owe)

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type == 'lent' ? "Give Money / Credit (Lent)" : "Take Debt / Borrow Money",
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text("You Gave (Lent)")),
                        selected: type == 'lent',
                        selectedColor: const Color(0xFF00B894),
                        onSelected: (val) => setSheetState(() => type = 'lent'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text("You Owe (Debt)")),
                        selected: type == 'borrowed',
                        selectedColor: const Color(0xFFFF7675),
                        onSelected: (val) => setSheetState(() => type = 'borrowed'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Person Name",
                    prefixIcon: const Icon(Icons.person_rounded),
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
                    labelText: "Amount",
                    prefixText: "₹ ",
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2B2B3D) : const Color(0xFFF0F1F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Note / Description (Optional)",
                    prefixIcon: const Icon(Icons.notes_rounded),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2B2B3D) : const Color(0xFFF0F1F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final amountText = amountController.text.trim();
                      if (name.isEmpty || amountText.isEmpty) return;

                      final debt = DebtModel(
                        personName: name,
                        amount: double.tryParse(amountText) ?? 0.0,
                        type: type,
                        note: noteController.text.trim(),
                        date: DateTime.now().toIso8601String(),
                      );

                      await DatabaseHelper.instance.insertDebt(debt);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadDebts();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: type == 'lent' ? const Color(0xFF00B894) : const Color(0xFFFF7675),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("Save Entry", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: "₹", decimalDigits: 0);

    double totalYouWillGet = 0.0;
    double totalYouWillGive = 0.0;

    for (var d in _debts) {
      if (d.isSettled) continue;
      if (d.type == 'lent') {
        totalYouWillGet += d.amount;
      } else {
        totalYouWillGive += d.amount;
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const Text("Debt & Credit Tracker", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Summary Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text("You Will Get", style: TextStyle(color: Color(0xFF00B894), fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(currency.format(totalYouWillGet),
                                style: const TextStyle(color: Color(0xFF00B894), fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: isDark ? Colors.white12 : Colors.black12),
                      Expanded(
                        child: Column(
                          children: [
                            const Text("You Will Give", style: TextStyle(color: Color(0xFFFF7675), fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(currency.format(totalYouWillGive),
                                style: const TextStyle(color: Color(0xFFFF7675), fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Debt List
                Expanded(
                  child: _debts.isEmpty
                      ? Center(
                          child: Text("No entries yet. Tap below to add!",
                              style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _debts.length,
                          itemBuilder: (ctx, idx) {
                            final debt = _debts[idx];
                            final isLent = debt.type == 'lent';
                            final color = isLent ? const Color(0xFF00B894) : const Color(0xFFFF7675);

                            return Opacity(
                              opacity: debt.isSettled ? 0.5 : 1.0,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: color.withOpacity(0.12),
                                      child: Icon(
                                        isLent ? Icons.call_made_rounded : Icons.call_received_rounded,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            debt.personName,
                                            style: TextStyle(
                                              color: isDark ? Colors.white : Colors.black87,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              decoration: debt.isSettled ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                          if (debt.note.isNotEmpty)
                                            Text(debt.note,
                                                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "${isLent ? '+' : '-'}${currency.format(debt.amount)}",
                                          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            TextButton(
                                              onPressed: () async {
                                                await DatabaseHelper.instance.toggleDebtSettled(debt.id!, !debt.isSettled);
                                                _loadDebts();
                                              },
                                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 24)),
                                              child: Text(debt.isSettled ? "Reopen" : "Settle",
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                                              onPressed: () async {
                                                await DatabaseHelper.instance.deleteDebt(debt.id!);
                                                _loadDebts();
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showAddDebtDialog(initialType: 'lent'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B894),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                label: const Text("You Gave ₹", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showAddDebtDialog(initialType: 'borrowed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7675),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.arrow_downward_rounded, color: Colors.white),
                label: const Text("You Got ₹", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
