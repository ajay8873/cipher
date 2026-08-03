import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  /// Check if System Alert Window (Display over other apps) permission is granted
  static Future<bool> isPermissionGranted() async {
    return await FlutterOverlayWindow.isPermissionGranted();
  }

  /// Request System Alert Window permission
  static Future<bool?> requestPermission() async {
    return await FlutterOverlayWindow.requestPermission();
  }

  /// Show overlay window with transaction details
  static Future<void> showTransactionOverlay({
    required int transactionId,
    required double amount,
    required String merchant,
    required String category,
  }) async {
    final bool isGranted = await isPermissionGranted();
    if (!isGranted) {
      print('Overlay permission not granted.');
      return;
    }

    final bool isActive = await FlutterOverlayWindow.isActive();
    if (isActive) {
      await FlutterOverlayWindow.closeOverlay();
    }

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: "Transaction Detected",
      overlayContent: "Tap to record Purpose & Recipient",
      flag: OverlayFlag.defaultFlag,
      alignment: OverlayAlignment.center,
      visibility: NotificationVisibility.visibilitySecret,
      positionGravity: PositionGravity.auto,
      height: 750,
      width: WindowSize.matchParent,
    );

    // Send payload data to overlay window isolate
    await FlutterOverlayWindow.shareData({
      'transaction_id': transactionId,
      'amount': amount,
      'merchant': merchant,
      'category': category,
    });
  }

  /// Close overlay window
  static Future<void> closeOverlay() async {
    await FlutterOverlayWindow.closeOverlay();
  }
}
