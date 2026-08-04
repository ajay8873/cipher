import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({Key? key}) : super(key: key);

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  static const String adminName = "AJAY";
  static const String adminEmail = "cont.cipher@gmail.com";
  static const String githubUrl = "https://github.com/ajay8873";
  static const String instagramUrl = "https://www.instagram.com/_ajay__mehta__?igsh=MWNocHF1eW1xN3o2aw==";
  static const String upiId = "ronit88@ybl";
  static const String upiName = "AJAY";

  int _selectedAmount = 20;
  bool _isCustomAmount = false;
  final TextEditingController _customAmountController = TextEditingController();
  final List<int> _presetAmounts = [10, 20, 50, 100];

  @override
  void initState() {
    super.initState();
    _customAmountController.text = "20";
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(BuildContext context, String urlStr, String errorMessage) async {
    final Uri url = Uri.parse(urlStr);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

  Future<void> _sendEmail(BuildContext context) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: adminEmail,
      queryParameters: {
        'subject': 'Support Request - Cipher App',
      },
    );
    if (!await launchUrl(emailLaunchUri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open email app")),
        );
      }
    }
  }

  Future<void> _payViaPhonePe(BuildContext context) async {
    final String note = Uri.encodeComponent("Buy Me a Coffee - Cipher App");
    final String name = Uri.encodeComponent(upiName);

    // Try PhonePe deep link first
    final phonePeUri = Uri.parse(
      "phonepe://pay?pa=$upiId&pn=$name&am=$_selectedAmount&cu=INR&tn=$note",
    );

    // Generic UPI fallback (shows all UPI apps)
    final upiUri = Uri.parse(
      "upi://pay?pa=$upiId&pn=$name&am=$_selectedAmount&cu=INR&tn=$note",
    );

    bool launched = false;
    try {
      launched = await launchUrl(phonePeUri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    if (!launched) {
      try {
        launched = await launchUrl(upiUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Could not open PhonePe. Please install PhonePe and try again."),
          backgroundColor: Color(0xFFFF7675),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Admin Profile",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          children: [
            // ── Profile Header Card ──────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF2D2B55), const Color(0xFF1E1E2E)]
                      : [const Color(0xFF6C5CE7), const Color(0xFF8E44AD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 12,
                        )
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 46,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person_rounded,
                        size: 56,
                        color: Color(0xFF6C5CE7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    adminName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Lead Developer & Creator",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Connect & Contact Links ───────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "CONNECT WITH ADMIN",
                style: TextStyle(
                  color: const Color(0xFF6C5CE7),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // GitHub Tile
            _buildLinkTile(
              context: context,
              icon: Icons.code_rounded,
              iconBg: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
              iconColor: textColor,
              label: "GitHub Profile",
              value: "github.com/ajay8873",
              isDark: isDark,
              cardColor: cardColor,
              onTap: () => _launchUrl(context, githubUrl, "Could not open GitHub profile"),
            ),

            const SizedBox(height: 12),

            // Instagram Tile
            _buildLinkTile(
              context: context,
              icon: Icons.camera_alt_rounded,
              iconBg: null, // gradient handled inside
              iconColor: Colors.white,
              iconGradient: const LinearGradient(
                colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFF77737)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              label: "Instagram",
              value: "@_ajay__mehta__",
              isDark: isDark,
              cardColor: cardColor,
              onTap: () => _launchUrl(context, instagramUrl, "Could not open Instagram profile"),
            ),

            const SizedBox(height: 12),

            // Email Tile
            _buildLinkTile(
              context: context,
              icon: Icons.email_rounded,
              iconBg: const Color(0xFF6C5CE7).withOpacity(0.15),
              iconColor: const Color(0xFF6C5CE7),
              label: "Support Email",
              value: adminEmail,
              isDark: isDark,
              cardColor: cardColor,
              onTap: () => _sendEmail(context),
              trailingIcon: Icons.send_rounded,
            ),

            const SizedBox(height: 24),

            // ── Buy Me a Coffee Section ───────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "BUY ME A COFFEE",
                style: TextStyle(
                  color: const Color(0xFFFF9800),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFFF9800).withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFFFF9800).withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        )
                      ],
              ),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.local_cafe_rounded, color: Color(0xFFFF9800), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Support the Developer",
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "If you love Cipher, consider supporting the developer.",
                              style: TextStyle(color: subtitleColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Amount selector presets + Custom option
                  Row(
                    children: [
                      ..._presetAmounts.map((amount) {
                        final isSelected = !_isCustomAmount && _selectedAmount == amount;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isCustomAmount = false;
                                _selectedAmount = amount;
                                _customAmountController.text = amount.toString();
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFF9800)
                                    : (isDark ? const Color(0xFF2B2B3D) : const Color(0xFFF5F5F5)),
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: isDark ? Colors.white12 : Colors.black12,
                                      ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFFF9800).withOpacity(0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        )
                                      ]
                                    : [],
                              ),
                              child: Text(
                                "₹$amount",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      // Custom Amount Chip
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isCustomAmount = true;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isCustomAmount
                                  ? const Color(0xFFFF9800)
                                  : (isDark ? const Color(0xFF2B2B3D) : const Color(0xFFF5F5F5)),
                              borderRadius: BorderRadius.circular(12),
                              border: _isCustomAmount
                                  ? null
                                  : Border.all(
                                      color: isDark ? Colors.white12 : Colors.black12,
                                    ),
                              boxShadow: _isCustomAmount
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFFF9800).withOpacity(0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Text(
                              "Custom",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _isCustomAmount ? Colors.white : textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Custom Amount Input Field (Visible when Custom is selected)
                  if (_isCustomAmount) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _customAmountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                      onChanged: (val) {
                        final parsed = int.tryParse(val) ?? 0;
                        setState(() {
                          _selectedAmount = parsed;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: "Enter Custom Amount (₹)",
                        labelStyle: const TextStyle(color: Color(0xFFFF9800), fontSize: 13),
                        prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Color(0xFFFF9800), size: 18),
                        hintText: "e.g. 150",
                        hintStyle: TextStyle(color: subtitleColor.withOpacity(0.5), fontSize: 13),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF0F1F5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: const Color(0xFFFF9800).withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFFF9800), width: 2),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // UPI ID display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF0F1F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_balance_wallet_rounded,
                            color: subtitleColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          "UPI: $upiId",
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // PhonePe Pay Button
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () => _payViaPhonePe(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5F259F), Color(0xFF7B3FBD)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5F259F).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              "Pay ₹$_selectedAmount via PhonePe",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── About Cipher ─────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "ABOUT CIPHER",
                style: TextStyle(
                  color: const Color(0xFF6C5CE7),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
                ),
              ),
              child: Column(
                children: [
                  _buildFeatureRow(
                    icon: Icons.security_rounded,
                    color: const Color(0xFF00B894),
                    title: "100% Offline & Private",
                    subtitle: "Your financial data stays securely on your phone database.",
                    isDark: isDark,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),
                  _buildFeatureRow(
                    icon: Icons.sms_rounded,
                    color: const Color(0xFF6C5CE7),
                    title: "Smart SMS & Push Parser",
                    subtitle: "Auto tracks debit/credit transactions directly from bank alerts.",
                    isDark: isDark,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),
                  _buildFeatureRow(
                    icon: Icons.pie_chart_rounded,
                    color: const Color(0xFFFF7675),
                    title: "Monthly Budget & Debt Tracker",
                    subtitle: "Manage category limits, track borrowings & lendings effortlessly.",
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── App Version Footer ──────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF0F1F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_rounded, color: subtitleColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    "Cipher App • Version 1.0.0",
                    style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkTile({
    required BuildContext context,
    required IconData icon,
    required Color? iconBg,
    required Color iconColor,
    Gradient? iconGradient,
    required String label,
    required String value,
    required bool isDark,
    required Color cardColor,
    required VoidCallback onTap,
    IconData trailingIcon = Icons.open_in_new_rounded,
  }) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
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
                color: iconGradient == null ? iconBg : null,
                gradient: iconGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: subtitleColor, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Icon(trailingIcon, color: const Color(0xFF6C5CE7), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
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
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
