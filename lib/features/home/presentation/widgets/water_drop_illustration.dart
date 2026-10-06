import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class WaterDropIllustration extends StatelessWidget {
  final double size;
  final Color dropColor;
  final Color backgroundColor;

  const WaterDropIllustration({
    super.key,
    this.size = 155,
    this.dropColor = AppTheme.royalBlue,
    this.backgroundColor = const Color(0xFFEBF5FF),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD6EBFF), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0072EC).withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.68,
          height: size * 0.68,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.water_drop_rounded,
              size: size * 0.44,
              color: const Color(0xFF0072EC),
            ),
          ),
        ),
      ),
    );
  }
}
