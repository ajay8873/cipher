import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/overlay_service.dart';
import 'dashboard_screen.dart';

import 'package:flutter_notification_listener/flutter_notification_listener.dart';

class PermissionSetupScreen extends StatefulWidget {
  const PermissionSetupScreen({Key? key}) : super(key: key);

  @override
  State<PermissionSetupScreen> createState() => _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends State<PermissionSetupScreen> with WidgetsBindingObserver {
  bool _isSmsGranted = false;
  bool _isOverlayGranted = false;
  bool _isNotificationGranted = false;
  bool _isChecking = true;

  bool _isContactsGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstTimeTermsAndPermissions());
  }

  Future<void> _checkFirstTimeTermsAndPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAcceptedTerms = prefs.getBool('accepted_terms_v1') ?? false;

    if (!hasAcceptedTerms && mounted) {
      setState(() => _isChecking = false);
      _showTermsAndPrivacyDialog();
    } else {
      _checkPermissions();
    }
  }

  void _showTermsAndPrivacyDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.privacy_tip_rounded, color: Color(0xFF6C5CE7), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Terms of Use & Privacy",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Welcome to Cipher! Please read and accept our privacy practices & terms of service before using the app:",
                  style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(height: 14),
                _buildPolicyPoint(
                  icon: Icons.phonelink_lock_rounded,
                  title: "1. 100% On-Device Processing & Privacy",
                  description:
                      "Cipher is designed privacy-first. Your financial SMS messages, notifications, and transaction history are processed locally on your phone. We do NOT collect, sell, lease, or share your personal financial data with any third-party advertisers, data brokers, or external entities.",
                ),
                const SizedBox(height: 10),
                _buildPolicyPoint(
                  icon: Icons.security_rounded,
                  title: "2. Exclusive Data Usage for App Services",
                  description:
                      "SMS & Notification access is used solely to parse debit/credit financial alerts (e.g. Bank SMS, PhonePe, GPay, Paytm) to automatically build your personal expense ledger. Non-financial messages, OTPs, promotional SMS, and personal chats are completely filtered out and ignored.",
                ),
                const SizedBox(height: 10),
                _buildPolicyPoint(
                  icon: Icons.cloud_done_rounded,
                  title: "3. Future Cloud Service & Automatic Consent",
                  description:
                      "By agreeing to these terms, you grant explicit consent that if Cipher integrates cloud sync or backup services (such as Supabase, Encrypted Cloud Storage, or accredited infrastructure providers) in future app updates, your encrypted transaction data may be synced securely to provide multi-device access and cloud backup functionality.",
                ),
                const SizedBox(height: 10),
                _buildPolicyPoint(
                  icon: Icons.admin_panel_settings_rounded,
                  title: "4. Right to Optimize & Manage Platform",
                  description:
                      "We reserve full rights to maintain, improve, update, and optimize parsing rules, application features, algorithms, security standards, and user interfaces to provide seamless service reliability.",
                ),
                const SizedBox(height: 10),
                _buildPolicyPoint(
                  icon: Icons.gavel_rounded,
                  title: "5. Limitation of Liability",
                  description:
                      "Cipher is an automated expense ledger provided 'as-is' for informational purposes. Users remain solely responsible for verifying financial calculations, budgeting decisions, and tax reporting.",
                ),
              ],
            ),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('accepted_terms_v1', true);
                if (mounted) {
                  Navigator.pop(ctx);
                  _checkPermissions();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                "I Understand & Agree",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyPoint({required IconData icon, required String title, required String description}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B2B3D) : const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6C5CE7)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _isChecking = true);

    final smsStatus = await Permission.sms.status;
    final overlayStatus = await OverlayService.isPermissionGranted();
    final notificationStatus = await NotificationsListener.hasPermission ?? false;
    final contactsStatus = await Permission.contacts.status;

    if (mounted) {
      setState(() {
        _isSmsGranted = smsStatus.isGranted;
        _isOverlayGranted = overlayStatus;
        _isNotificationGranted = notificationStatus;
        _isContactsGranted = contactsStatus.isGranted;
        _isChecking = false;
      });
    }

    if (_isSmsGranted && _isOverlayGranted) {
      _navigateToDashboard();
    }
  }

  Future<void> _requestSmsPermission() async {
    final status = await Permission.sms.request();
    if (mounted) {
      setState(() {
        _isSmsGranted = status.isGranted;
      });
    }
    _checkIfAllGranted();
  }

  Future<void> _requestContactsPermission() async {
    final status = await Permission.contacts.request();
    if (mounted) {
      setState(() {
        _isContactsGranted = status.isGranted;
      });
    }
  }

  Future<void> _requestOverlayPermission() async {
    await OverlayService.requestPermission();
    await _checkPermissions();
  }

  Future<void> _requestNotificationPermission() async {
    await NotificationsListener.openPermissionSettings();
    await _checkPermissions();
  }

  void _checkIfAllGranted() {
    if (_isSmsGranted && _isOverlayGranted) {
      _navigateToDashboard();
    }
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white60 : Colors.black54;

    if (_isChecking) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              // Header Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 48,
                  color: Color(0xFF6C5CE7),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "App Permissions Setup",
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "To automatically track expenses, incoming credits, and show the background popup overlay, Cipher uses SMS and Push Notification tracking:",
                style: TextStyle(color: subtextColor, fontSize: 14, height: 1.5),
              ),

              const SizedBox(height: 30),

              // Card 1: SMS Permission
              _buildPermissionTile(
                title: "1. Read & Receive SMS",
                subtitle: "Required to detect incoming bank & UPI debit SMS alerts in real-time.",
                icon: Icons.sms_rounded,
                isGranted: _isSmsGranted,
                onRequest: _requestSmsPermission,
                isDark: isDark,
              ),

              const SizedBox(height: 16),

              // Card 2: System Alert Window Permission
              _buildPermissionTile(
                title: "2. Display Over Other Apps",
                subtitle: "Required to open the background overlay window asking for transaction purpose & recipient.",
                icon: Icons.layers_rounded,
                isGranted: _isOverlayGranted,
                onRequest: _requestOverlayPermission,
                isDark: isDark,
              ),

              const SizedBox(height: 16),

              // Card 3: UPI Notification Access
              _buildPermissionTile(
                title: "3. PhonePe / UPI Notification Access",
                subtitle: "Required to detect incoming credits & payments from PhonePe, GPay, Paytm, Navi, CRED & BHIM.",
                icon: Icons.notifications_active_rounded,
                isGranted: _isNotificationGranted,
                onRequest: _requestNotificationPermission,
                isDark: isDark,
              ),

              const SizedBox(height: 16),

              // Card 4: Contacts Access
              _buildPermissionTile(
                title: "4. Contacts Access",
                subtitle: "Required to pick contacts for Khatabook debt SMS reminders & entry details.",
                icon: Icons.contacts_rounded,
                isGranted: _isContactsGranted,
                onRequest: _requestContactsPermission,
                isDark: isDark,
              ),

              const Spacer(),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_isSmsGranted && _isOverlayGranted)
                      ? _navigateToDashboard
                      : () async {
                          await _checkPermissions();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_isSmsGranted && _isOverlayGranted)
                        ? const Color(0xFF6C5CE7)
                        : (isDark ? Colors.white12 : Colors.black12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    (_isSmsGranted && _isOverlayGranted)
                        ? "Continue to Dashboard"
                        : "Check & Proceed",
                    style: TextStyle(
                      color: (_isSmsGranted && _isOverlayGranted)
                          ? Colors.white
                          : (isDark ? Colors.white54 : Colors.black45),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isGranted,
    required VoidCallback onRequest,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final cardBorder = isGranted
        ? const Color(0xFF00B894)
        : (isDark ? Colors.white10 : Colors.black.withOpacity(0.08));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cardBorder,
          width: 1.5,
        ),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isGranted
                  ? const Color(0xFF00B894).withOpacity(0.15)
                  : const Color(0xFF6C5CE7).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: isGranted ? const Color(0xFF00B894) : const Color(0xFF6C5CE7),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          isGranted
              ? const Icon(Icons.check_circle, color: Color(0xFF00B894), size: 28)
              : ElevatedButton(
                  onPressed: onRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Grant", style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
        ],
      ),
    );
  }
}
