import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
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
    _checkContactsPermissionOnLaunch();
  }

  Future<void> _checkContactsPermissionOnLaunch() async {
    final status = await Permission.contacts.status;
    if (!status.isGranted) {
      await Permission.contacts.request();
    }
  }

  Future<void> _loadDebts() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllDebts();
    setState(() {
      _debts = data;
      _isLoading = false;
    });
  }

  String _formatDateTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Future<Contact?> _pickContact(BuildContext context) async {
    var status = await Permission.contacts.status;
    if (!status.isGranted) {
      status = await Permission.contacts.request();
      if (!status.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Contacts permission is required to choose a contact."),
              backgroundColor: Color(0xFFFF7675),
            ),
          );
        }
        return null;
      }
    }

    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        final fullContact = await FlutterContacts.getContact(contact.id);
        return fullContact ?? contact;
      }
      return null;
    } catch (e) {
      try {
        if (await FlutterContacts.requestPermission(readonly: true)) {
          final contacts = await FlutterContacts.getContacts(withProperties: true);
          if (contacts.isEmpty) return null;
          if (!context.mounted) return null;

          return await showDialog<Contact>(
            context: context,
            builder: (ctx) {
              String search = '';
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  final filtered = contacts
                      .where((c) => c.displayName.toLowerCase().contains(search.toLowerCase()))
                      .toList();
                  return AlertDialog(
                    title: const Text("Select Contact"),
                    content: SizedBox(
                      width: double.maxFinite,
                      height: 350,
                      child: Column(
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              labelText: "Search Contact",
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (val) => setDialogState(() => search = val),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final c = filtered[index];
                                final phone = c.phones.isNotEmpty ? c.phones.first.number : 'No number';
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '?'),
                                  ),
                                  title: Text(c.displayName),
                                  subtitle: Text(phone),
                                  onTap: () => Navigator.pop(ctx, c),
                                );
                              },
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
      } catch (_) {}
    }
    return null;
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime initialDateTime) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return null;

    if (!context.mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
    );
    if (pickedTime == null) {
      return DateTime(pickedDate.year, pickedDate.month, pickedDate.day, initialDateTime.hour, initialDateTime.minute);
    }

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  void _showAddDebtDialog({required String initialType}) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final phoneController = TextEditingController();
    final upiController = TextEditingController();
    String type = initialType; // 'lent' (you gave) or 'borrowed' (you owe)
    DateTime selectedDateTime = DateTime.now();

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

                // Button to choose contact directly
                OutlinedButton.icon(
                  onPressed: () async {
                    final contact = await _pickContact(context);
                    if (contact != null) {
                      setSheetState(() {
                        if (nameController.text.trim().isEmpty) {
                          nameController.text = contact.displayName;
                        }
                        if (contact.phones.isNotEmpty) {
                          phoneController.text = contact.phones.first.number.replaceAll(RegExp(r'\s+|-'), '');
                        }
                      });
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFF6C5CE7)),
                  ),
                  icon: const Icon(Icons.contacts_rounded, color: Color(0xFF6C5CE7), size: 20),
                  label: const Text(
                    "Choose Person from Contacts",
                    style: TextStyle(color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: nameController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Person Name",
                    prefixIcon: const Icon(Icons.person_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.contacts_rounded, color: Color(0xFF6C5CE7)),
                      tooltip: "Pick Contact",
                      onPressed: () async {
                        final contact = await _pickContact(context);
                        if (contact != null) {
                          setSheetState(() {
                            nameController.text = contact.displayName;
                            if (contact.phones.isNotEmpty) {
                              phoneController.text = contact.phones.first.number.replaceAll(RegExp(r'\s+|-'), '');
                            }
                          });
                        }
                      },
                    ),
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

                // Manual Date & Time Picker Selector
                InkWell(
                  onTap: () async {
                    final dt = await _pickDateTime(context, selectedDateTime);
                    if (dt != null) {
                      setSheetState(() => selectedDateTime = dt);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2B2B3D) : const Color(0xFFF0F1F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 20, color: Color(0xFF6C5CE7)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Transaction Date & Time", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('dd MMM yyyy, hh:mm a').format(selectedDateTime),
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.edit_calendar_rounded, size: 18, color: isDark ? Colors.white60 : Colors.black54),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Phone Number (For SMS Reminder)",
                    prefixIcon: const Icon(Icons.phone_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.contacts_rounded, color: Color(0xFF6C5CE7)),
                      tooltip: "Pick Contact Phone",
                      onPressed: () async {
                        final contact = await _pickContact(context);
                        if (contact != null && contact.phones.isNotEmpty) {
                          setSheetState(() {
                            phoneController.text = contact.phones.first.number.replaceAll(RegExp(r'\s+|-'), '');
                            if (nameController.text.trim().isEmpty) {
                              nameController.text = contact.displayName;
                            }
                          });
                        }
                      },
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2B2B3D) : const Color(0xFFF0F1F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: upiController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: "UPI ID / VPA (Optional, e.g. name@upi)",
                    prefixIcon: const Icon(Icons.qr_code_rounded),
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
                        phoneNumber: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                        upiId: upiController.text.trim().isEmpty ? null : upiController.text.trim(),
                        date: selectedDateTime.toIso8601String(),
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

  Future<void> _editDebtDateTime(DebtModel debt) async {
    DateTime initialDt = DateTime.now();
    try {
      initialDt = DateTime.parse(debt.date);
    } catch (_) {}

    final newDt = await _pickDateTime(context, initialDt);
    if (newDt != null && debt.id != null) {
      await DatabaseHelper.instance.updateDebtDate(debt.id!, newDt.toIso8601String());
      _loadDebts();
    }
  }

  Future<void> _sendSmsReminder(DebtModel debt) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String phoneNumber = debt.phoneNumber ?? '';

    if (phoneNumber.isEmpty) {
      final phoneController = TextEditingController();
      final selectedPhone = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          title: const Text("Recipient Phone Number"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Select from your Contacts or enter a mobile number to send the SMS reminder:",
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final contact = await _pickContact(context);
                  if (contact != null) {
                    if (contact.phones.isNotEmpty) {
                      final num = contact.phones.first.number.replaceAll(RegExp(r'[^\d+]'), '');
                      if (ctx.mounted) Navigator.pop(ctx, num);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("No phone number found for ${contact.displayName}."),
                            backgroundColor: const Color(0xFFFF7675),
                          ),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.contacts_rounded, color: Colors.white),
                label: const Text("Choose from Contacts", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text("OR", style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: const InputDecoration(
                  labelText: "Enter Mobile Number",
                  hintText: "e.g. 9876543210",
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, phoneController.text.trim()),
              child: const Text("Send SMS"),
            ),
          ],
        ),
      );

      if (selectedPhone == null || selectedPhone.isEmpty) return;
      phoneNumber = selectedPhone;

      if (debt.id != null) {
        await DatabaseHelper.instance.updateDebtPhoneNumber(debt.id!, phoneNumber);
        _loadDebts();
      }
    }

    final formattedAmount = debt.amount.toStringAsFixed(0);
    final notePart = debt.note.isNotEmpty ? " (${debt.note})" : "";
    final dateStr = _formatDateTime(debt.date);
    
    final message = debt.type == 'lent'
        ? "Hi ${debt.personName}, a friendly reminder regarding pending amount of ₹$formattedAmount$notePart given on $dateStr. Kindly clear when possible. Thanks!"
        : "Hi ${debt.personName}, regarding the amount of ₹$formattedAmount$notePart taken on $dateStr. Let's settle it soon. Thanks!";

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: <String, String>{
        'body': message,
      },
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      } else {
        final fallbackUrl = Uri.parse("sms:$phoneNumber?body=${Uri.encodeComponent(message)}");
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open SMS app: $e")),
        );
      }
    }
  }

  Future<void> _settleDebtOptions(DebtModel debt) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF6C5CE7), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Settle Debt with ${debt.personName}",
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Amount: ₹${debt.amount.toStringAsFixed(0)}${debt.note.isNotEmpty ? ' (${debt.note})' : ''}",
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _launchUpiPay(debt);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.send_to_mobile_rounded, color: Colors.white),
              label: const Text("Pay / Settle via UPI App (GPay / PhonePe / Paytm)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await DatabaseHelper.instance.toggleDebtSettled(debt.id!, !debt.isSettled);
                _loadDebts();
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: BorderSide(color: isDark ? Colors.white38 : Colors.black26),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: Icon(debt.isSettled ? Icons.refresh_rounded : Icons.check_circle_outline_rounded,
                  color: isDark ? Colors.white : Colors.black87),
              label: Text(
                debt.isSettled ? "Reopen Entry" : "Mark as Settled directly",
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUpiPay(DebtModel debt) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String upiId = debt.upiId ?? '';

    if (upiId.isEmpty) {
      final upiController = TextEditingController();
      final enteredUpi = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          title: const Text("UPI Payment Details"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Enter receiver's UPI ID (VPA) or Google Pay / PhonePe number to open UPI app:",
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: upiController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: const InputDecoration(
                  labelText: "UPI ID / VPA / Mobile",
                  hintText: "e.g. 9876543210@paytm or name@upi",
                  prefixIcon: Icon(Icons.qr_code_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text("Skip UPI ID"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, upiController.text.trim()),
              child: const Text("Open UPI Apps"),
            ),
          ],
        ),
      );

      if (enteredUpi != null) {
        upiId = enteredUpi;
      }
    }

    final note = debt.note.isNotEmpty ? debt.note : 'Khata Settlement';
    final name = debt.personName;
    final amount = debt.amount.toStringAsFixed(2);

    String upiUrl = "upi://pay?pa=$upiId&pn=${Uri.encodeComponent(name)}&am=$amount&cu=INR&tn=${Uri.encodeComponent(note)}";

    try {
      final uri = Uri.parse(upiUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to launch UPI app: $e")),
        );
      }
    }
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
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Top Row: Avatar + Details + Amount
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: color.withOpacity(0.12),
                                          child: Icon(
                                            isLent ? Icons.call_made_rounded : Icons.call_received_rounded,
                                            color: color,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                debt.personName,
                                                style: TextStyle(
                                                  color: isDark ? Colors.white : Colors.black87,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  decoration: debt.isSettled ? TextDecoration.lineThrough : null,
                                                ),
                                              ),
                                              if (debt.note.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  debt.note,
                                                  style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                                                ),
                                              ],
                                              const SizedBox(height: 6),
                                              InkWell(
                                                onTap: () => _editDebtDateTime(debt),
                                                borderRadius: BorderRadius.circular(6),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.access_time_rounded, size: 13, color: isDark ? Colors.white38 : Colors.black38),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        _formatDateTime(debt.date),
                                                        style: TextStyle(
                                                          color: isDark ? Colors.white38 : Colors.black45,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Icon(Icons.edit_rounded, size: 10, color: isDark ? Colors.white38 : Colors.black38),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              "${isLent ? '+' : '-'}${currency.format(debt.amount)}",
                                              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
                                            ),
                                            if (debt.isSettled)
                                              Container(
                                                margin: const EdgeInsets.only(top: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text("Settled", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),
                                    Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
                                    const SizedBox(height: 8),

                                    // Bottom Action Row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // SMS Reminder button
                                        TextButton.icon(
                                          onPressed: () => _sendSmsReminder(debt),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          icon: const Icon(Icons.sms_rounded, size: 16, color: Color(0xFF0984E3)),
                                          label: const Text(
                                            "SMS Reminder",
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0984E3)),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            // Settle Button
                                            ElevatedButton.icon(
                                              onPressed: () => _settleDebtOptions(debt),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: debt.isSettled ? Colors.grey.withOpacity(0.3) : const Color(0xFF6C5CE7),
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: Icon(
                                                debt.isSettled ? Icons.refresh_rounded : Icons.account_balance_wallet_rounded,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                              label: Text(
                                                debt.isSettled ? "Reopen" : "Settle",
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Delete Button
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                                              tooltip: "Delete Entry",
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
