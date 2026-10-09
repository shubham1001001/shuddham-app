import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Placeholder screen — Bookings feature is not yet available.
class BookingsScreen extends StatelessWidget {
  /// Kept for compatibility with main.dart's BookingsScreen.refresh() call.
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);
  static void refresh() {
    refreshNotifier.value++;
  }

  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Bookings',
          style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      size: 34,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Title
              const Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF102A43),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              const Text(
                'Book service appointments, track technician visits & manage your purifier maintenance — all from one place.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  color: Color(0xFF627D98),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.construction_rounded, size: 18, color: Color(0xFFD97706)),
                    SizedBox(width: 8),
                    Text(
                      'Under development',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

