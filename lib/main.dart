import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_config.dart';
import 'providers/transaction_provider.dart';
import 'services/supabase_service.dart';
import 'services/background_sms_handler.dart';
import 'services/background_notification_handler.dart';
import 'services/overlay_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/permission_setup_screen.dart';
import 'widgets/overlay_form_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Cloud Sync Service if configured
  if (AppConfig.supabaseUrl != "YOUR_SUPABASE_URL_HERE") {
    await SupabaseService.instance.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  // Initialize Telephony Background SMS Listening
  final smsListener = BackgroundSmsListenerService();
  await smsListener.initializeSmsListener();

  // Initialize Notification Listener for PhonePe, GPay, Paytm, Navi, CRED, BHIM, etc.
  await BackgroundNotificationHandler.startListening();

  // Load SMS scan preference
  final provider = TransactionProvider();
  await provider.loadSmsPreference();

  // Pre-check permissions & accepted terms to determine initial route
  final prefs = await SharedPreferences.getInstance();
  final hasAcceptedTerms = prefs.getBool('accepted_terms_v1') ?? false;
  final smsStatus = await Permission.sms.status;
  final overlayStatus = await OverlayService.isPermissionGranted();

  final bool isFullySetup = hasAcceptedTerms && smsStatus.isGranted && overlayStatus;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TransactionProvider>.value(value: provider),
      ],
      child: KhataApp(isFullySetup: isFullySetup),
    ),
  );
}

class KhataApp extends StatelessWidget {
  final bool isFullySetup;
  const KhataApp({Key? key, required this.isFullySetup}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, child) {
        return MaterialApp(
          title: 'Cipher',
          debugShowCheckedModeBanner: false,
          themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF5F6FA),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6C5CE7),
              surface: Colors.white,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0F0F1A),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6C5CE7),
              surface: Color(0xFF1E1E2E),
            ),
            useMaterial3: true,
          ),
          home: isFullySetup ? const DashboardScreen() : const PermissionSetupScreen(),
        );
      },
    );
  }
}
