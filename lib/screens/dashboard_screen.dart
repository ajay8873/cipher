import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction_model.dart';
import '../services/database_helper.dart';
import '../services/update_checker_service.dart';
import 'analytics_screen.dart';
import 'admin_profile_screen.dart';
import 'edit_transaction_screen.dart';
import 'budget_screen.dart';
import 'debt_khatabook_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _testSmsController = TextEditingController();

  // Manual Expense Controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _customCategoryController = TextEditingController();

  String _selectedCategory = "Food & Dining";
  String _selectedType = "debit";
  String _selectedAccountType = "UPI";
  DateTime _selectedDate = DateTime.now();
  bool _isCustomCategory = false;

  // Filter state: 'all' | 'debit' | 'credit'
  String _activeFilter = 'all';
  DateTime? _filterDate;

  // Banner month selector — defaults to current month
  DateTime _bannerMonth = DateTime(DateTime.now().year, DateTime.now().month);
  double _bannerDebit  = 0.0;
  double _bannerCredit = 0.0;
  bool _bannerLoading  = false;

  final List<String> _categories = [
    "Food & Dining",
    "Shopping",
    "Bills",
    "Transport",
    "Entertainment",
    "Grocery",
    "General",
    "Other",
  ];

  final List<String> _accountTypes = [
    "UPI",
    "Cash",
    "Bank Account",
    "Credit Card"
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<TransactionProvider>();
      await provider.fetchTransactions();
      await _loadBannerSummary();
      // Auto-scan inbox silently on every app open to catch missed bank SMS
      await provider.scanSmsInbox(daysBack: 30);

      // Check for app updates from GitHub Releases API
      _checkAppUpdates();
    });
  }

  Future<void> _checkAppUpdates() async {
    try {
      final release = await UpdateCheckerService.checkForUpdate();
      if (release != null && mounted) {
        await UpdateCheckerService.showUpdateDialog(context, release);
      }
    } catch (e) {
      print('Update check error: $e');
    }
  }

  Future<void> _loadBannerSummary() async {
    setState(() => _bannerLoading = true);
    try {
      final summary = await DatabaseHelper.instance
          .getMonthSummary(_bannerMonth.year, _bannerMonth.month);
      setState(() {
        _bannerDebit  = summary['debit']  ?? 0.0;
        _bannerCredit = summary['credit'] ?? 0.0;
      });
    } finally {
      setState(() => _bannerLoading = false);
    }
  }

  Future<void> _pickBannerMonth() async {
    int tempYear = _bannerMonth.year;
    int tempMonth = _bannerMonth.month;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final monthsList = [
      "Jan", "Feb", "Mar", "Apr",
      "May", "Jun", "Jul", "Aug",
      "Sep", "Oct", "Nov", "Dec"
    ];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final now = DateTime.now();
            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF6C5CE7), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Select Month & Year",
                    style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Year Selector Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Select Year", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2B2B3D) : const Color(0xFFF0F1F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<int>(
                          value: tempYear,
                          dropdownColor: dialogBg,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                          underline: const SizedBox.shrink(),
                          items: List.generate(10, (i) => 2020 + i).map((y) {
                            return DropdownMenuItem<int>(
                              value: y,
                              child: Text(y.toString()),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => tempYear = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Month Grid (12 Months)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.6,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, idx) {
                      final monthNum = idx + 1;
                      final isSelected = tempMonth == monthNum;
                      final isFuture = (tempYear == now.year && monthNum > now.month) || (tempYear > now.year);

                      return GestureDetector(
                        onTap: isFuture
                            ? null
                            : () {
                                setDialogState(() => tempMonth = monthNum);
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF6C5CE7)
                                : isFuture
                                    ? (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04))
                                    : (isDark ? const Color(0xFF2B2B3D) : const Color(0xFFF0F1F5)),
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: const Color(0xFF6C5CE7), width: 1.5)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            monthsList[idx],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : isFuture
                                      ? (isDark ? Colors.white24 : Colors.black26)
                                      : textColor,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _bannerMonth = DateTime(tempYear, tempMonth);
                    });
                    Navigator.pop(ctx);
                    _loadBannerSummary();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Apply", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _testSmsController.dispose();
    _amountController.dispose();
    _merchantController.dispose();
    _purposeController.dispose();
    _recipientController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  /// Deletes a transaction and shows an UNDO snackbar for 5 seconds.
  Future<void> _deleteWithUndo(TransactionModel tx) async {
    if (tx.id == null) return;
    final provider = context.read<TransactionProvider>();
    await provider.deleteTransaction(tx.id!);
    await _loadBannerSummary();

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        backgroundColor: const Color(0xFF2B2B3D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF7675), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Deleted ${tx.merchant} (₹${tx.amount.toStringAsFixed(2)})",
                style: const TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: "UNDO",
          textColor: const Color(0xFFA29BFE),
          onPressed: () async {
            await provider.restoreTransaction(tx);
            await _loadBannerSummary();
          },
        ),
      ),
    );
  }

  void _confirmDeleteTransaction(TransactionModel tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Expense?",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          "Remove ₹${tx.amount.toStringAsFixed(2)} at ${tx.merchant}?",
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteWithUndo(tx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7675)),
            child: const Text("Delete",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _scanSmsInbox() async {
    final provider = context.read<TransactionProvider>();
    await provider.scanSmsInbox(daysBack: 90);

    if (mounted) {
      final count = provider.lastScanCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? "✅ Imported $count new transaction${count == 1 ? '' : 's'} from SMS inbox"
                : "No new transactions found in SMS inbox",
          ),
          backgroundColor: count > 0 ? const Color(0xFF00B894) : const Color(0xFF636E72),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _confirmClearAllTransactions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Clear All Expenses?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          "This will permanently delete all recorded expenses from your phone database. This action cannot be undone.",
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<TransactionProvider>().clearAllTransactions();
              await _loadBannerSummary();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("All expenses cleared"),
                    backgroundColor: Color(0xFFFF7675),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7675)),
            child: const Text("Clear All", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup() async {
    try {
      final jsonStr = await DatabaseHelper.instance.exportBackupJson();

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final controller = TextEditingController(text: jsonStr);

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              "Export Backup JSON",
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Choose how you want to save your backup:",
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  readOnly: true,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 11, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2B2B3D) : const Color(0xFFF0F1F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Close", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: jsonStr));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("✅ Backup copied to clipboard!"),
                      backgroundColor: Color(0xFF00B894),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0984E3)),
                icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 16),
                label: const Text("Copy Text", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _trySaveBackupFile(jsonStr);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
                icon: const Icon(Icons.download_rounded, color: Colors.white, size: 16),
                label: const Text("Save File", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to generate backup: $e")),
        );
      }
    }
  }

  Future<void> _trySaveBackupFile(String jsonStr) async {
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
      final fileName = 'cipher_backup_$dateStr.json';

      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup File',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: utf8.encode(jsonStr),
      );

      if (outputFile != null) {
        final file = File(outputFile);
        try {
          await file.writeAsString(jsonStr);
        } catch (_) {
          // On Android SAF URI returned by FilePicker, bytes parameter already wrote the file
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Backup saved successfully!"),
              backgroundColor: Color(0xFF00B894),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("FilePicker save failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not save file directly. Please use 'Copy Text' option."),
            backgroundColor: Color(0xFFFF7675),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Restore Backup JSON", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['json', 'txt'],
                  );
                  if (result != null && result.files.single.path != null) {
                    final file = File(result.files.single.path!);
                    final content = await file.readAsString();
                    controller.text = content;
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error selecting file: $e")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.folder_open_rounded, color: Colors.white, size: 18),
              label: const Text("Pick Backup File (.json)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 14),
            const Text(
              "Or paste your exported JSON backup text below:",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 5,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Paste backup JSON here...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF2B2B3D),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final jsonStr = controller.text.trim();
              if (jsonStr.isEmpty) return;
              try {
                final count = await DatabaseHelper.instance.restoreBackupJson(jsonStr);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  await context.read<TransactionProvider>().fetchTransactions();
                  await _loadBannerSummary();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Successfully restored $count transactions!"),
                      backgroundColor: const Color(0xFF00B894),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Invalid backup format: $e"),
                      backgroundColor: const Color(0xFFFF7675),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B894)),
            icon: const Icon(Icons.file_download_done_rounded, color: Colors.white, size: 18),
            label: const Text("Restore", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddManualExpenseDialog() {
    _amountController.clear();
    _merchantController.clear();
    _purposeController.clear();
    _recipientController.clear();
    _customCategoryController.clear();
    _selectedCategory = "Food";
    _selectedType = "debit";
    _selectedAccountType = "UPI";
    _selectedDate = DateTime.now();
    _isCustomCategory = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final fieldBg = isDark ? const Color(0xFF2B2B3D) : const Color(0xFFF0F1F5);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white60 : Colors.black54;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Add Expense",
                          style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: subtextColor),
                          onPressed: () => Navigator.pop(ctx),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: "Amount (₹)",
                        labelStyle: const TextStyle(color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold),
                        prefixIcon: const Icon(Icons.currency_rupee, color: Color(0xFF6C5CE7)),
                        filled: true,
                        fillColor: fieldBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Merchant
                    TextField(
                      controller: _merchantController,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "Merchant / Store / Title",
                        labelStyle: TextStyle(color: subtextColor),
                        prefixIcon: Icon(Icons.store_rounded, color: subtextColor),
                        filled: true,
                        fillColor: fieldBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
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
                          builder: (context, child) {
                            return Theme(
                              data: isDark
                                  ? ThemeData.dark().copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: Color(0xFF6C5CE7),
                                        surface: Color(0xFF1E1E2E),
                                      ),
                                    )
                                  : ThemeData.light().copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: Color(0xFF6C5CE7),
                                        surface: Colors.white,
                                        onSurface: Colors.black87,
                                      ),
                                    ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setModalState(() => _selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: fieldBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, color: Color(0xFF6C5CE7), size: 20),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Transaction Date", style: TextStyle(color: subtextColor, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                                  style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Icon(Icons.edit_calendar_rounded, color: subtextColor, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category & Account Type
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            dropdownColor: sheetBg,
                            style: TextStyle(color: textColor, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: "Category",
                              labelStyle: TextStyle(color: subtextColor),
                              filled: true,
                              fillColor: fieldBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: textColor)))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
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
                            dropdownColor: sheetBg,
                            style: TextStyle(color: textColor, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: "Payment Via",
                              labelStyle: TextStyle(color: subtextColor),
                              filled: true,
                              fillColor: fieldBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                            items: _accountTypes.map((a) => DropdownMenuItem(value: a, child: Text(a, style: TextStyle(color: textColor)))).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => _selectedAccountType = val);
                            },
                          ),
                        ),
                      ],
                    ),

                    // Custom category field — only shown when "Other" is selected
                    if (_isCustomCategory) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _customCategoryController,
                        style: TextStyle(color: textColor, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: "Custom Category Name",
                          labelStyle: TextStyle(color: subtextColor),
                          prefixIcon: Icon(Icons.label_outline_rounded, color: subtextColor),
                          filled: true,
                          fillColor: fieldBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Purpose
                    TextField(
                      controller: _purposeController,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "Purpose / Description (Optional)",
                        labelStyle: TextStyle(color: subtextColor),
                        prefixIcon: Icon(Icons.notes_rounded, color: subtextColor),
                        filled: true,
                        fillColor: fieldBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Recipient
                    TextField(
                      controller: _recipientController,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "Recipient / Paid To (Optional)",
                        labelStyle: TextStyle(color: subtextColor),
                        prefixIcon: Icon(Icons.person_outline_rounded, color: subtextColor),
                        filled: true,
                        fillColor: fieldBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Transaction type toggle — full width, no overflow
                    Text(
                      "Transaction Type",
                      style: TextStyle(color: subtextColor, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => _selectedType = "debit"),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: _selectedType == "debit" ? const Color(0xFFFF7675) : fieldBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _selectedType == "debit" ? const Color(0xFFFF7675) : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_upward_rounded, size: 16,
                                      color: _selectedType == "debit" ? Colors.white : subtextColor),
                                  const SizedBox(width: 6),
                                  Text("Expense",
                                      style: TextStyle(
                                        color: _selectedType == "debit" ? Colors.white : subtextColor,
                                        fontWeight: FontWeight.bold, fontSize: 13,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => _selectedType = "credit"),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: _selectedType == "credit" ? const Color(0xFF00B894) : fieldBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _selectedType == "credit" ? const Color(0xFF00B894) : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_downward_rounded, size: 16,
                                      color: _selectedType == "credit" ? Colors.white : subtextColor),
                                  const SizedBox(width: 6),
                                  Text("Income",
                                      style: TextStyle(
                                        color: _selectedType == "credit" ? Colors.white : subtextColor,
                                        fontWeight: FontWeight.bold, fontSize: 13,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Save
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final amountText = _amountController.text.trim();
                          final merchant   = _merchantController.text.trim();
                          if (amountText.isEmpty || double.tryParse(amountText) == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please enter a valid amount")),
                            );
                            return;
                          }
                          final category = (_isCustomCategory && _customCategoryController.text.trim().isNotEmpty)
                              ? _customCategoryController.text.trim()
                              : _selectedCategory;

                          final tx = TransactionModel(
                            rawSms: "Manual Entry",
                            amount: double.parse(amountText),
                            merchant: merchant.isNotEmpty ? merchant : "Manual Expense",
                            category: category,
                            purpose: _purposeController.text.trim(),
                            recipient: _recipientController.text.trim(),
                            date: _selectedDate.toIso8601String(),
                            type: _selectedType,
                            accountType: _selectedAccountType,
                          );
                          context.read<TransactionProvider>().addManualTransaction(tx);
                          Navigator.pop(ctx);
                          _loadBannerSummary();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                        label: const Text("Save Expense",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSimulateSmsDialog() {
    _testSmsController.text = "Rs 450.00 debited from A/C XX1234 at SWIGGY BANGALORE on 02-Aug-26 via UPI. Ref 98765432";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Simulate Incoming SMS", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter mock bank SMS text to test the background parser & overlay:",
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _testSmsController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF2B2B3D),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final sms = _testSmsController.text.trim();
              if (sms.isNotEmpty) {
                final provider = context.read<TransactionProvider>();
                await provider.simulateTestSms(sms);
                await _loadBannerSummary();
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Simulated SMS parsed & added successfully!"),
                      backgroundColor: Color(0xFF00B894),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
            child: const Text("Trigger SMS & Overlay", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  /// Groups transactions by Day / Date with daily subtotal calculations
  Map<String, Map<String, dynamic>> _groupTransactionsByDate(List<TransactionModel> transactions) {
    final Map<String, Map<String, dynamic>> grouped = {};

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var tx in transactions) {
      final parsedDate = DateTime.tryParse(tx.date) ?? DateTime.now();
      final txDateOnly = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

      String dateHeader;
      if (txDateOnly == today) {
        dateHeader = "Today (${DateFormat('dd MMM').format(parsedDate)})";
      } else if (txDateOnly == yesterday) {
        dateHeader = "Yesterday (${DateFormat('dd MMM').format(parsedDate)})";
      } else {
        dateHeader = DateFormat('EEEE, dd MMM yyyy').format(parsedDate);
      }

      if (!grouped.containsKey(dateHeader)) {
        grouped[dateHeader] = {
          'dateStr': dateHeader,
          'dailyDebit': 0.0,
          'dailyCredit': 0.0,
          'items': <TransactionModel>[]
        };
      }

      (grouped[dateHeader]!['items'] as List<TransactionModel>).add(tx);
      if (tx.type == 'debit') {
        grouped[dateHeader]!['dailyDebit'] =
            (grouped[dateHeader]!['dailyDebit'] as double) + tx.amount;
      } else {
        grouped[dateHeader]!['dailyCredit'] =
            (grouped[dateHeader]!['dailyCredit'] as double) + tx.amount;
      }
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currencyFormat = NumberFormat.currency(symbol: "₹", decimalDigits: 2);

    // Apply type filter AND month filter together
    final allTx = provider.transactions;

    // Month boundaries for the selected banner month
    final monthStart = DateTime(_bannerMonth.year, _bannerMonth.month, 1);
    final monthEnd   = (_bannerMonth.month == 12)
        ? DateTime(_bannerMonth.year + 1, 1, 1)
        : DateTime(_bannerMonth.year, _bannerMonth.month + 1, 1);

    final monthTx = allTx.where((tx) {
      final d = DateTime.tryParse(tx.date);
      if (d == null) return false;
      return d.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
             d.isBefore(monthEnd);
    }).toList();

    final dateFilteredTx = _filterDate == null
        ? allTx
        : allTx.where((tx) {
            final d = DateTime.tryParse(tx.date);
            if (d == null) return false;
            return d.year == _filterDate!.year &&
                d.month == _filterDate!.month &&
                d.day == _filterDate!.day;
          }).toList();

    final filteredTx = _activeFilter == 'all'
        ? dateFilteredTx
        : dateFilteredTx.where((tx) => tx.type == _activeFilter).toList();

    final groupedData = _groupTransactionsByDate(filteredTx);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF6C5CE7)),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "Cipher",
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              provider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: provider.isDarkMode ? const Color(0xFFFDCB6E) : const Color(0xFF6C5CE7),
            ),
            tooltip: provider.isDarkMode ? "Switch to Light Mode" : "Switch to Dark Mode",
            onPressed: () => provider.toggleThemeMode(),
          ),
          IconButton(
            icon: Icon(Icons.sms_outlined, color: isDark ? Colors.white70 : Colors.black87),
            tooltip: "Simulate SMS Test",
            onPressed: _showSimulateSmsDialog,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : Colors.black87),
            color: Theme.of(context).colorScheme.surface,
            onSelected: (val) async {
              if (val == 'scan_inbox') {
                if (!provider.smsScanEnabled) {
                  await provider.setSmsScanning(true);
                }
                await _scanSmsInbox();
              } else if (val == 'clear_all') {
                _confirmClearAllTransactions();
              } else if (val == 'refresh') {
                provider.fetchTransactions();
                await _loadBannerSummary();
              } else if (val == 'admin') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProfileScreen()));
              } else if (val == 'export_backup') {
                _exportBackup();
              } else if (val == 'restore_backup') {
                _restoreBackup();
              } else if (val == 'budget') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetScreen()));
              } else if (val == 'debt_khatabook') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtKhatabookScreen()));
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'admin',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.4), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF6C5CE7), size: 18),
                      const SizedBox(width: 10),
                      Text(
                        "Admin Profile",
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF6C5CE7),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'scan_inbox',
                child: Row(
                  children: [
                    const Icon(Icons.document_scanner_rounded, color: Color(0xFF00CEC9), size: 18),
                    const SizedBox(width: 10),
                    Text("Scan SMS Inbox", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export_backup',
                child: Row(
                  children: [
                    const Icon(Icons.file_upload_rounded, color: Color(0xFF0984E3), size: 18),
                    const SizedBox(width: 10),
                    Text("Export Backup (JSON)", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'restore_backup',
                child: Row(
                  children: [
                    const Icon(Icons.file_download_rounded, color: Color(0xFF00B894), size: 18),
                    const SizedBox(width: 10),
                    Text("Restore Backup (JSON)", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'analytics',
                child: Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded, color: Color(0xFF6C5CE7), size: 18),
                    const SizedBox(width: 10),
                    Text("Analytics", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, color: isDark ? Colors.white70 : Colors.black87, size: 18),
                    const SizedBox(width: 10),
                    Text("Refresh Data", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded, color: Color(0xFFFF7675), size: 18),
                    SizedBox(width: 10),
                    Text("Clear All Expenses", style: TextStyle(color: Color(0xFFFF7675))),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddManualExpenseDialog,
        backgroundColor: const Color(0xFF6C5CE7),
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // 1. Home Icon
            InkWell(
              onTap: () {
                // Already on home
              },
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home_rounded, color: Color(0xFF6C5CE7), size: 20),
                    Text("Home", style: TextStyle(color: Color(0xFF6C5CE7), fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

            // 2. Analytics Icon
            InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 20),
                    Text("Analytics", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 9)),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 28), // Space for centered FAB

            // 3. Monthly Budget Icon
            InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetScreen()));
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pie_chart_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 20),
                    Text("Budget", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 9)),
                  ],
                ),
              ),
            ),

            // 4. Khatabook / Debt Icon
            InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtKhatabookScreen()));
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 20),
                    Text("Debt", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 9)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7)))
          : RefreshIndicator(
              onRefresh: () => provider.fetchTransactions(),
              color: const Color(0xFF6C5CE7),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Summary Banner ──────────────────────────────────
                    GestureDetector(
                      onTap: _pickBannerMonth,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: isDark
                              ? const LinearGradient(
                                  colors: [Color(0xFF1E1E2E), Color(0xFF2D2B55)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFFFFFFFF), Color(0xFFF3F0FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(24),
                          border: isDark
                              ? Border.all(
                                  color: const Color(0xFF6C5CE7).withOpacity(0.35),
                                  width: 1.5,
                                )
                              : Border.all(
                                  color: const Color(0xFF6C5CE7).withOpacity(0.12),
                                  width: 1.5,
                                ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? const Color(0xFF6C5CE7).withOpacity(0.15)
                                  : const Color(0xFF6C5CE7).withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: _bannerLoading
                            ? SizedBox(
                                height: 100,
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: isDark ? Colors.white : const Color(0xFF6C5CE7), strokeWidth: 2),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Month selector row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_month_rounded,
                                                color: isDark ? Colors.white70 : Colors.black87, size: 16),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                DateFormat('MMMM yyyy').format(_bannerMonth),
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color: isDark ? Colors.white : Colors.black87,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit_rounded,
                                                color: isDark ? Colors.white70 : Colors.black87, size: 12),
                                            const SizedBox(width: 4),
                                            Text("Change",
                                                style: TextStyle(
                                                    color: isDark ? Colors.white70 : Colors.black87, fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(color: isDark ? Colors.white24 : Colors.black12, height: 1),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildSummaryTile(
                                          label: "Spent",
                                          value: currencyFormat.format(_bannerDebit),
                                          icon: Icons.arrow_upward_rounded,
                                          color: const Color(0xFFFF7675),
                                        ),
                                      ),
                                      Container(
                                          width: 1, height: 48, color: isDark ? Colors.white24 : Colors.black12),
                                      Expanded(
                                        child: _buildSummaryTile(
                                          label: "Received",
                                          value: currencyFormat.format(_bannerCredit),
                                          icon: Icons.arrow_downward_rounded,
                                          color: const Color(0xFF00B894),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(color: isDark ? Colors.white24 : Colors.black12, height: 1),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Net Balance",
                                          style: TextStyle(
                                              color: isDark ? Colors.white70 : Colors.black87, fontSize: 13)),
                                      Text(
                                        "${(_bannerCredit - _bannerDebit) >= 0 ? '+' : ''}${currencyFormat.format(_bannerCredit - _bannerDebit)}",
                                        style: TextStyle(
                                          color: (_bannerCredit - _bannerDebit) >= 0
                                              ? const Color(0xFF00B894)
                                              : const Color(0xFFFF7675),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Today Expenses Overview ──────────────────────────────
                    _buildTodayExpensesCard(allTx, isDark),

                    const SizedBox(height: 16),

                    // ── Categorywise Expense Chart ───────────────────────────
                    _buildCategoryChartCard(monthTx, isDark),

                    const SizedBox(height: 20),

                    // ── Section Header ────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _activeFilter == 'all'
                              ? "All Transactions"
                              : _activeFilter == 'debit'
                                  ? "Expenses (Debits)"
                                  : "Income (Credits)",
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (allTx.isNotEmpty)
                          TextButton.icon(
                            onPressed: _confirmClearAllTransactions,
                            icon: const Icon(Icons.delete_sweep_rounded,
                                color: Color(0xFFFF7675), size: 16),
                            label: const Text("Clear All",
                                style: TextStyle(color: Color(0xFFFF7675), fontSize: 12)),
                          )
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Filter Chips Row ──────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _buildFilterChip(
                            label: "All",
                            icon: Icons.list_rounded,
                            value: 'all',
                            activeColor: const Color(0xFF6C5CE7),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildFilterChip(
                            label: "Debits",
                            icon: Icons.arrow_upward_rounded,
                            value: 'debit',
                            activeColor: const Color(0xFFFF7675),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildFilterChip(
                            label: "Credits",
                            icon: Icons.arrow_downward_rounded,
                            value: 'credit',
                            activeColor: const Color(0xFF00B894),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Compact Date Filter Chip with Easy Touch Clear Target
                        Expanded(
                          flex: _filterDate != null ? 1 : 1,
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _filterDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() => _filterDate = picked);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              decoration: BoxDecoration(
                                color: _filterDate != null
                                    ? const Color(0xFF00CEC9)
                                    : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _filterDate != null
                                      ? const Color(0xFF00CEC9)
                                      : (isDark ? Colors.white12 : Colors.black.withOpacity(0.1)),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 13,
                                    color: _filterDate != null ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _filterDate != null
                                            ? DateFormat('dd MMM').format(_filterDate!)
                                            : "Date",
                                        style: TextStyle(
                                          color: _filterDate != null ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_filterDate != null) ...[
                                    const SizedBox(width: 2),
                                    InkWell(
                                      onTap: () => setState(() => _filterDate = null),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Transaction List ──────────────────────────────────
                    filteredTx.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isDark
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  _activeFilter == 'debit'
                                      ? Icons.arrow_upward_rounded
                                      : _activeFilter == 'credit'
                                          ? Icons.arrow_downward_rounded
                                          : Icons.inbox_rounded,
                                  color: isDark ? Colors.white30 : Colors.black26,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _activeFilter == 'all'
                                      ? "No Transactions Recorded Yet"
                                      : _activeFilter == 'debit'
                                          ? "No Expenses Found"
                                          : "No Income Found",
                                  style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _activeFilter == 'all'
                                      ? "Tap '+' button below to log manually or wait for bank SMS."
                                      : _activeFilter == 'debit'
                                          ? "No debit transactions recorded yet."
                                          : "No credit transactions recorded yet.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: isDark ? Colors.white38 : Colors.black54, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: groupedData.keys.length,
                            itemBuilder: (ctx, idx) {
                              final groupKey = groupedData.keys.elementAt(idx);
                              final group = groupedData[groupKey]!;
                              final items = group['items'] as List<TransactionModel>;
                              final dailyDebit  = group['dailyDebit']  as double;
                              final dailyCredit = group['dailyCredit'] as double;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Date Header Row with Daily Total
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                      child: Row(
                                        children: [
                                          // Left: date label — shrinks if badges are wide
                                          const Icon(Icons.calendar_today_rounded,
                                              color: Color(0xFFA29BFE), size: 15),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              groupKey,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isDark ? Colors.white : Colors.black87,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Right: badges — never pushed off screen
                                          if (_activeFilter == 'credit')
                                            _buildDailyBadge(
                                                "+₹${dailyCredit.toStringAsFixed(2)}",
                                                const Color(0xFF00B894))
                                          else if (_activeFilter == 'debit')
                                            _buildDailyBadge(
                                                "-₹${dailyDebit.toStringAsFixed(2)}",
                                                const Color(0xFFFF7675))
                                          else
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                if (dailyDebit > 0)
                                                  _buildDailyBadge(
                                                      "-₹${dailyDebit.toStringAsFixed(2)}",
                                                      const Color(0xFFFF7675)),
                                                if (dailyCredit > 0)
                                                  _buildDailyBadge(
                                                      "+₹${dailyCredit.toStringAsFixed(2)}",
                                                      const Color(0xFF00B894)),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    // List of Items for this Date
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: items.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                                      itemBuilder: (context, itemIdx) {
                                        final tx = items[itemIdx];
                                        return Dismissible(
                                          key: Key("tx_${tx.id}_${tx.date}"),
                                          direction: DismissDirection.endToStart,
                                          background: Container(
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.only(right: 20),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF7675),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: const Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                Icon(Icons.delete_rounded, color: Colors.white),
                                                SizedBox(width: 8),
                                                Text(
                                                  "Delete",
                                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                                )
                                              ],
                                            ),
                                          ),
                                          onDismissed: (_) {
                                            if (tx.id != null) {
                                              setState(() {
                                                items.removeAt(itemIdx);
                                              });
                                              _deleteWithUndo(tx);
                                            }
                                          },
                                          child: _buildTransactionCard(tx),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  /// Compact colored badge used in date-group headers
  Widget _buildDailyBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// Split debit/credit summary tile inside the hero banner
  Widget _buildSummaryTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style:
                  TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  /// Animated filter chip — highlights when [value] matches [_activeFilter]
  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required String value,
    required Color activeColor,
  }) {
    final isActive = _activeFilter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final unselectedBorder = isDark ? Colors.white12 : Colors.black.withOpacity(0.1);
    final unselectedText = isDark ? Colors.white54 : Colors.black54;

    return GestureDetector(
      onTap: () => setState(() => _activeFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor : unselectedBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? activeColor : unselectedBorder,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? Colors.white : unselectedText),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : unselectedText,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel tx) {
    final isDebit = tx.type == 'debit';
    final parsedDate = DateTime.tryParse(tx.date) ?? DateTime.now();
    final formattedTime = DateFormat('hh:mm a').format(parsedDate);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Category Icon Badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDebit ? const Color(0xFFFF7675).withOpacity(0.15) : const Color(0xFF00B894).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDebit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: isDebit ? const Color(0xFFFF7675) : const Color(0xFF00B894),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Merchant & Category & Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.merchant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tx.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? const Color(0xFFA29BFE) : const Color(0xFF6C5CE7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(" • ", style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 12)),
                        Text(
                          formattedTime,
                          style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Amount & action icons — constrained to prevent overflow
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${isDebit ? '-' : '+'}₹${tx.amount.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: isDebit ? const Color(0xFFFF7675) : const Color(0xFF00B894),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditTransactionScreen(transaction: tx),
                            ),
                          );
                          if (mounted) _loadBannerSummary();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.edit_outlined, color: isDark ? Colors.white60 : Colors.black54, size: 20),
                        ),
                      ),
                      InkWell(
                        onTap: () => _confirmDeleteTransaction(tx),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.delete_outline_rounded, color: Color(0xFFFF7675), size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          if ((tx.purpose != null && tx.purpose!.isNotEmpty) || (tx.recipient != null && tx.recipient!.isNotEmpty)) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (tx.purpose != null && tx.purpose!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withOpacity(isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Purpose: ${tx.purpose}",
                      style: TextStyle(
                        color: isDark ? const Color(0xFFA29BFE) : const Color(0xFF5A49E0),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (tx.recipient != null && tx.recipient!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00CEC9).withOpacity(isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "To: ${tx.recipient}",
                      style: TextStyle(
                        color: isDark ? const Color(0xFF81ECEC) : const Color(0xFF008985),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Icon(
                  tx.isSynced == 1 ? Icons.cloud_done : Icons.cloud_off,
                  size: 16,
                  color: tx.isSynced == 1 ? const Color(0xFF00B894) : (isDark ? Colors.white24 : Colors.black26),
                )
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildTodayExpensesCard(List<TransactionModel> allTransactions, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayTx = allTransactions.where((tx) {
      final d = DateTime.tryParse(tx.date);
      if (d == null) return false;
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).toList();

    double todayDebit = 0.0;
    double todayCredit = 0.0;

    for (final tx in todayTx) {
      if (tx.type == 'debit') {
        todayDebit += tx.amount;
      } else {
        todayCredit += tx.amount;
      }
    }

    final currencyFmt = NumberFormat.currency(symbol: "₹", decimalDigits: 2);
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.today_rounded, color: Color(0xFF6C5CE7), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Overview",
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('EEEE, dd MMM yyyy').format(now),
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${todayTx.length} Txn${todayTx.length == 1 ? '' : 's'}",
                  style: const TextStyle(
                    color: Color(0xFF6C5CE7),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7675).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.arrow_upward_rounded, color: Color(0xFFFF7675), size: 14),
                          SizedBox(width: 4),
                          Text("Today Spent", style: TextStyle(color: Color(0xFFFF7675), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          currencyFmt.format(todayDebit),
                          style: const TextStyle(color: Color(0xFFFF7675), fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.arrow_downward_rounded, color: Color(0xFF00B894), size: 14),
                          SizedBox(width: 4),
                          Text("Today Received", style: TextStyle(color: Color(0xFF00B894), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          currencyFmt.format(todayCredit),
                          style: const TextStyle(color: Color(0xFF00B894), fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChartCard(List<TransactionModel> monthTx, bool isDark) {
    final debitTx = monthTx.where((tx) => tx.type == 'debit').toList();
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    if (debitTx.isEmpty) {
      return const SizedBox.shrink();
    }

    final Map<String, double> categorySums = {};
    double totalDebit = 0.0;

    for (final tx in debitTx) {
      categorySums[tx.category] = (categorySums[tx.category] ?? 0.0) + tx.amount;
      totalDebit += tx.amount;
    }

    final sortedCategories = categorySums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<Color> palette = [
      const Color(0xFF6C5CE7),
      const Color(0xFFFF7675),
      const Color(0xFF00B894),
      const Color(0xFFFDCB6E),
      const Color(0xFF74B9FF),
      const Color(0xFFE17055),
      const Color(0xFFA29BFE),
      const Color(0xFF55EFC4),
      const Color(0xFFFF9FF3),
      const Color(0xFF636E72),
    ];

    final currencyFmt = NumberFormat.currency(symbol: "₹", decimalDigits: 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.pie_chart_rounded, color: Color(0xFF6C5CE7), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Category Expenses",
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                currencyFmt.format(totalDebit),
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: List.generate(sortedCategories.length, (idx) {
                  final entry = sortedCategories[idx];
                  final pct = totalDebit > 0 ? (entry.value / totalDebit) * 100 : 0.0;
                  final color = palette[idx % palette.length];

                  return PieChartSectionData(
                    color: color,
                    value: entry.value,
                    title: "${pct.toStringAsFixed(0)}%",
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: List.generate(sortedCategories.length, (idx) {
              final entry = sortedCategories[idx];
              final color = palette[idx % palette.length];
              final pct = totalDebit > 0 ? (entry.value / totalDebit) * 100 : 0.0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2B2B3D) : const Color(0xFFF0F1F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${entry.key}: ",
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${currencyFmt.format(entry.value)} (${pct.toStringAsFixed(0)}%)",
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

