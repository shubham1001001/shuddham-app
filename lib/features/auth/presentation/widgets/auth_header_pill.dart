import 'package:flutter/material.dart';

class AuthHeaderPill extends StatelessWidget {
  const AuthHeaderPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0077EE).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2EEF8)),
      ),
      child: Center(
        child: Hero(
          tag: 'shuddham_logo',
          child: Image.asset(
            'assets/images/logo.png',
            height: 44,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
