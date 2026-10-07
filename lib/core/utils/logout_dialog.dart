import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../session/user_session.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';

/// Shows a standardized confirmation dialog for logging out of the app.
/// Invalidation API call is dispatched to the backend, session cleared, and returns to [AuthScreen].
Future<void> showLogoutDialog(BuildContext context, {LogoutUseCase? logoutUseCase}) async {
  final useCase = logoutUseCase ?? LogoutUseCase(AuthRepositoryImpl());

  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFEF4444),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Log Out',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of Shuddham Water Solutions?',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final currentToken = UserSession().token;

              // Clear local session and navigate to login screen
              UserSession().clear();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );

              // Asynchronously call backend logout API to invalidate session token
              if (currentToken.isNotEmpty) {
                try {
                  await useCase.call(LogoutParams(token: currentToken));
                } catch (_) {
                  // Fallback: local session is safely cleared
                }
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text('Logged out successfully'),
                      ],
                    ),
                    backgroundColor: AppTheme.textDark,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      );
    },
  );
}
