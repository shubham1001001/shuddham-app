import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Empty state widget shown when no services match the active category filter.
class ServicesEmptyView extends StatelessWidget {
  final String selectedCategory;
  final VoidCallback onShowAll;

  const ServicesEmptyView({
    super.key,
    required this.selectedCategory,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.filter_alt_off_outlined, size: 54, color: AppTheme.textMuted),
            const SizedBox(height: 14),
            Text(
              'No $selectedCategory services found',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try selecting another category or view all services.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onShowAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.royalBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Show All Services'),
            ),
          ],
        ),
      ),
    );
  }
}
