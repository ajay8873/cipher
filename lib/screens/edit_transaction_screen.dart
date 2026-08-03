import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';

class EditTransactionScreen extends StatefulWidget {
  final TransactionModel transaction;
  const EditTransactionScreen({Key? key, required this.transaction})
      : super(key: key);

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  late TextEditingController _amountController;
  late TextEditingController _merchantController;
  late TextEditingController _purposeController;
  late TextEditingController _recipientController;
  late TextEditingController _customCategoryController;

  late String _selectedCategory;
  late String _selectedType;
  late String _selectedAccountType;
  late DateTime _selectedDate;
  bool _isCustomCategory = false;
  bool _isSaving = false;

  static const List<String> _categories = [
    "Food", "Shopping", "Bills", "Transport",
    "Entertainment", "Grocery", "General", "Other",
  ];

  static const List<String> _accountTypes = [
    "UPI", "Cash", "Bank Account", "Credit Card",
  ];

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _amountController    = TextEditingController(text: tx.amount.toStringAsFixed(2));
    _merchantController  = TextEditingController(text: tx.merchant);
    _purposeController   = TextEditingController(text: tx.purpose ?? '');
    _recipientController = TextEditingController(text: tx.recipient ?? '');
    _customCategoryController = TextEditingController();
    _selectedType        = tx.type;
    _selectedAccountType = tx.accountType;
    _selectedDate        = DateTime.tryParse(tx.date) ?? DateTime.now();

    if (_categories.contains(tx.category)) {
      _selectedCategory = tx.category;
    } else {
      _selectedCategory = "Other";
      _isCustomCategory = true;
      _customCategoryController.text = tx.category;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _purposeController.dispose();
    _recipientController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty || double.tryParse(amountText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid amount")),
      );
      return;
    }
    final category = (_isCustomCategory && _customCategoryController.text.trim().isNotEmpty)
        ? _customCategoryController.text.trim()
        : _selectedCategory;

    setState(() => _isSaving = true);
    final updated = widget.transaction.copyWith(
      amount:      double.parse(amountText),
      merchant:    _merchantController.text.trim().isEmpty
                       ? widget.transaction.merchant
                       : _merchantController.text.trim(),
      category:    category,
      purpose:     _purposeController.text.trim(),
      recipient:   _recipientController.text.trim(),
      type:        _selectedType,
      accountType: _selectedAccountType,
      date:        _selectedDate.toIso8601String(),
      isSynced:    0,
    );

    await context.read<TransactionProvider>().updateTransaction(updated);
    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        title: const Text("Edit Transaction",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(color: Color(0xFF6C5CE7), strokeWidth: 2))
                : const Text("Save",
                    style: TextStyle(
                        color: Color(0xFF6C5CE7),
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(
              controller: _amountController,
              label: "Amount (₹)",
              icon: Icons.currency_rupee,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            _field(
              controller: _merchantController,
              label: "Merchant / Title",
              icon: Icons.store_rounded,
            ),
            const SizedBox(height: 14),

            // Date picker
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  builder: (ctx, child) => Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF6C5CE7),
                        surface: Color(0xFF1E1E2E),
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B2B3D),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: Color(0xFF6C5CE7), size: 20),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Transaction Date",
                            style: TextStyle(color: Colors.white60, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.edit_calendar_rounded,
                        color: Colors.white38, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Category + Account Type row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    dropdownColor: const Color(0xFF2B2B3D),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _dropDec("Category"),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCategory = val;
                          _isCustomCategory = val == "Other";
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedAccountType,
                    dropdownColor: const Color(0xFF2B2B3D),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _dropDec("Payment Via"),
                    items: _accountTypes
                        .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedAccountType = val);
                    },
                  ),
                ),
              ],
            ),

            if (_isCustomCategory) ...[
              const SizedBox(height: 14),
              _field(
                controller: _customCategoryController,
                label: "Custom Category",
                icon: Icons.label_outline_rounded,
              ),
            ],

            const SizedBox(height: 14),
            _field(
              controller: _purposeController,
              label: "Purpose / Description",
              icon: Icons.notes_rounded,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _recipientController,
              label: "Recipient / Paid To",
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 20),

            // Transaction type toggle
            const Text("Transaction Type",
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _typeButton("debit", "Expense",
                    Icons.arrow_upward_rounded, const Color(0xFFFF7675))),
                const SizedBox(width: 10),
                Expanded(child: _typeButton("credit", "Income",
                    Icons.arrow_downward_rounded, const Color(0xFF00B894))),
              ],
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                label: const Text("Save Changes",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _typeButton(
      String value, String label, IconData icon, Color color) {
    final active = _selectedType == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? color : const Color(0xFF2B2B3D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? color : Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : Colors.white38),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: active ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextStyle? style,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: style ?? const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF2B2B3D),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
      ),
    );
  }

  InputDecoration _dropDec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: const Color(0xFF2B2B3D),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
      );
}
