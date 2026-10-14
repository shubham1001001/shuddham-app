import 'package:flutter/material.dart';

/// Premium, smooth IoT Notification Toasts for Shuddham Water Solutions.
/// Unified design with sleek Obsidian Slate surfaces (#0F172A), border highlights (#334155),
/// glowing route-specific icons (Bluetooth LE / Cloud Wi-Fi), and smooth slide-in/out transitions.
class AppToast {
  /// Base builder for all floating IoT toasts
  static void _showBaseToast({
    BuildContext? context,
    ScaffoldMessengerState? messenger,
    required Widget iconWidget,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeBgColor,
    required Color badgeBorderColor,
    required Color badgeTextColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    final msgr = messenger ?? (context != null && context.mounted ? ScaffoldMessenger.maybeOf(context) : null);
    if (msgr == null) return;

    // Smoothly dismiss any currently visible snackbar instead of abruptly clearing it
    msgr.hideCurrentSnackBar();

    msgr.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
        content: Row(
          children: [
            iconWidget,
            const SizedBox(width: 12),
            // Text Details
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: badgeBgColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeBorderColor, width: 0.8),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: badgeTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF94A3B8),
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Tap to dismiss
            GestureDetector(
              onTap: () {
                msgr.hideCurrentSnackBar();
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF1E293B),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a smooth, modern toast when a command succeeds via Bluetooth or Cloud Wi-Fi.
  static void showSuccess(
    BuildContext? context, {
    ScaffoldMessengerState? messenger,
    required String title,
    required String subtitle,
    String transport = 'mqtt', // 'ble' or 'mqtt'
    String? badgeLabel,
  }) {
    final isBle = transport == 'ble';

    final iconWidget = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isBle ? const Color(0xFFE0F2FE) : const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isBle ? const Color(0xFF0284C7) : const Color(0xFF16A34A)).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        isBle ? Icons.bluetooth_connected_rounded : Icons.check_circle_rounded,
        color: isBle ? const Color(0xFF0284C7) : const Color(0xFF16A34A),
        size: 20,
      ),
    );

    _showBaseToast(
      context: context,
      messenger: messenger,
      iconWidget: iconWidget,
      title: title,
      subtitle: subtitle,
      badgeText: badgeLabel ?? (isBle ? 'Bluetooth' : 'Confirmed'),
      badgeBgColor: isBle ? const Color(0xFF0C4A6E) : const Color(0xFF064E3B),
      badgeBorderColor: isBle ? const Color(0xFF0284C7) : const Color(0xFF16A34A),
      badgeTextColor: isBle ? const Color(0xFF38BDF8) : const Color(0xFF4ADE80),
      duration: const Duration(seconds: 4),
    );
  }

  /// Shows an in-flight progress toast while verifying with purifier via Cloud or connecting via Bluetooth
  static void showProgress(
    BuildContext? context, {
    ScaffoldMessengerState? messenger,
    required String title,
    required String subtitle,
    String transport = 'mqtt',
  }) {
    final isBle = transport == 'ble';

    final iconWidget = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isBle ? const Color(0xFFE0F2FE) : const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: isBle ? const Color(0xFF0284C7) : const Color(0xFF0077EE),
          ),
        ),
      ),
    );

    _showBaseToast(
      context: context,
      messenger: messenger,
      iconWidget: iconWidget,
      title: title,
      subtitle: subtitle,
      badgeText: isBle ? 'Bluetooth' : 'Cloud Wi-Fi',
      badgeBgColor: const Color(0xFF0C4A6E),
      badgeBorderColor: const Color(0xFF0284C7),
      badgeTextColor: const Color(0xFF38BDF8),
      duration: const Duration(seconds: 4),
    );
  }

  /// Shows a smooth, modern toast when command dispatch fails via Bluetooth or Cloud
  static void showFailure(
    BuildContext? context, {
    ScaffoldMessengerState? messenger,
    required String title,
    required String subtitle,
    String transport = 'ble',
  }) {
    final isBle = transport == 'ble';

    final iconWidget = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        isBle ? Icons.bluetooth_disabled_rounded : Icons.error_outline_rounded,
        color: const Color(0xFFDC2626),
        size: 20,
      ),
    );

    _showBaseToast(
      context: context,
      messenger: messenger,
      iconWidget: iconWidget,
      title: title,
      subtitle: subtitle,
      badgeText: isBle ? 'Bluetooth Error' : 'Offline',
      badgeBgColor: const Color(0xFF450A0A),
      badgeBorderColor: const Color(0xFF991B1B),
      badgeTextColor: const Color(0xFFF87171),
      duration: const Duration(seconds: 4),
    );
  }

  /// Shows a smooth, modern toast when hardware fails to respond within the verification window.
  static void showHardwareTimeout(
    BuildContext? context, {
    ScaffoldMessengerState? messenger,
    String title = 'Purifier Did Not Respond',
    String subtitle = 'Setting reverted. Please check if purifier is connected to Wi-Fi.',
  }) {
    final iconWidget = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.wifi_off_rounded,
        color: Color(0xFFD97706),
        size: 20,
      ),
    );

    _showBaseToast(
      context: context,
      messenger: messenger,
      iconWidget: iconWidget,
      title: title,
      subtitle: subtitle,
      badgeText: 'Reverted',
      badgeBgColor: const Color(0xFF451A03),
      badgeBorderColor: const Color(0xFF78350F),
      badgeTextColor: const Color(0xFFFBBF24),
      duration: const Duration(seconds: 4),
    );
  }
}
