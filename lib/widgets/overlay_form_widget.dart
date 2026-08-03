import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../services/database_helper.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayFormWidget(),
    ),
  );
}

class OverlayFormWidget extends StatefulWidget {
  const OverlayFormWidget({Key? key}) : super(key: key);

  @override
  State<OverlayFormWidget> createState() => _OverlayFormWidgetState();
}

class _OverlayFormWidgetState extends State<OverlayFormWidget> {
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();

  int? _transactionId;
  double _amount = 0.0;
  String _merchant = 'Unknown Merchant';
  String _category = 'General';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Listen for data sent from main app isolate
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map) {
        setState(() {
          _transactionId = data['transaction_id'] as int?;
          _amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          _merchant = data['merchant']?.toString() ?? 'Unknown Merchant';
          _category = data['category']?.toString() ?? 'General';
          _purposeController.text = _category;
        });
      }
    });
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final purpose = _purposeController.text.trim();
    final recipient = _recipientController.text.trim();

    if (purpose.isEmpty && recipient.isEmpty) {
      await FlutterOverlayWindow.closeOverlay();
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_transactionId != null) {
        // Direct write to SQLite database from overlay isolate
        await DatabaseHelper.instance.updateTransactionDetails(
          id: _transactionId!,
          purpose: purpose.isNotEmpty ? purpose : _category,
          recipient: recipient.isNotEmpty ? recipient : _merchant,
          category: purpose.isNotEmpty ? purpose : null,
        );
      }

      // Also share message back to main app isolate if needed
      await FlutterOverlayWindow.shareData({
        'action': 'transaction_updated',
        'transaction_id': _transactionId,
        'purpose': purpose,
        'recipient': recipient,
      });
    } catch (e) {
      print('Error saving from overlay: $e');
    } finally {
      await FlutterOverlayWindow.closeOverlay();
    }
  }

  Future<void> _handleDismiss() async {
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext mehtaContext) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E), // Dark Glassmorphic container
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 4,
                offset: const Offset(0, 10),
              )
            ],
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          color: Color(0xFFA29BFE),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "New Expense Detected",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: _handleDismiss,
                  )
                ],
              ),
              const SizedBox(height: 12),

              // Amount & Merchant Badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3D),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _merchant,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "₹${_amount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Color(0xFFFF7675),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _category,
                        style: const TextStyle(color: Color(0xFFA29BFE), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Input 1: Purpose / Category
              const Text(
                "Purpose / Category",
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _purposeController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "e.g. Dinner, Groceries, Cab",
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF252538),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Input 2: Recipient Name
              const Text(
                "Recipient Name",
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _recipientController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "e.g. Swiggy, Ramesh, Landlord",
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF252538),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleDismiss,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Dismiss", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )

            ],
          ),
        ),
      ),
    );
  }
}
