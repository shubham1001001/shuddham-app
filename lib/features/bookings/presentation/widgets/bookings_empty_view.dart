import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Empty state widget shown when no bookings are found.
class BookingsEmptyView extends StatelessWidget {
  final String? selectedStatus;
  final Future<void> Function() onRefresh;
  final VoidCallback onClearFilter;

  const BookingsEmptyView({
    super.key,
    required this.selectedStatus,
    required this.onRefresh,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilter = selectedStatus != null;

    return RefreshIndicator(
      color: AppTheme.royalBlue,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD6EBFF), width: 2),
                    ),
                    child: Icon(
                      hasFilter ? Icons.filter_alt_off_outlined : Icons.calendar_today_outlined,
                      size: 48,
                      color: AppTheme.royalBlue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    hasFilter ? 'No "$selectedStatus" Bookings' : 'No Booked Services Yet',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasFilter
                        ? 'There are currently no bookings with "$selectedStatus" status. Select another filter or view all bookings.'
                        : 'You haven\'t booked any water purifier services yet. Go to the Services tab to book an installation, repair, or maintenance.',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13.5, height: 1.45),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (hasFilter)
                    ElevatedButton.icon(
                      onPressed: onClearFilter,
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      label: const Text('Show All Bookings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.royalBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Refresh Bookings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.royalBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
