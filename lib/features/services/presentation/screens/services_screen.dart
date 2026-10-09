import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Placeholder screen — Services catalog is not yet available.
class ServicesScreen extends StatelessWidget {
  final void Function(int index)? onNavigate;

  const ServicesScreen({
    super.key,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFE),
      appBar: AppBar(
        title: const Text(
          'Services',
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
              // Animated-style icon container
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.royalBlue.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.royalBlue.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppTheme.royalBlue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cleaning_services_rounded,
                      size: 36,
                      color: AppTheme.royalBlue,
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
                'We\'re building a catalog of premium water purifier services for you — filter replacement, AMC, deep cleaning & more.',
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
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_active_outlined, size: 18, color: Color(0xFF10B981)),
                    SizedBox(width: 8),
                    Text(
                      'You\'ll be notified when ready',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF10B981),
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

