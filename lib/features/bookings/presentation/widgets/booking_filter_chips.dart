import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'booking_card.dart';

/// Horizontal status filter chip bar for service bookings.
class BookingFilterChips extends StatelessWidget {
  final String? selectedStatus;
  final ValueChanged<String?> onStatusChanged;

  const BookingFilterChips({
    super.key,
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  static const List<String> statusFilters = [
    'All',
    'Pending',
    'Confirmed',
    'Assigned',
    'Completed',
    'Cancelled'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: statusFilters.length,
          separatorBuilder: (context, i) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final s = statusFilters[index];
            final isSelected = (s == 'All' && selectedStatus == null) || (s == selectedStatus);
            final color = BookingCard.statusColor(s);
            final bgColor = BookingCard.statusBgColor(s);

            return FilterChip(
              label: Text(s),
              selected: isSelected,
              onSelected: (_) {
                if (s == 'All' || s == selectedStatus) {
                  onStatusChanged(null);
                } else {
                  onStatusChanged(s);
                }
              },
              selectedColor: bgColor,
              checkmarkColor: color,
              labelStyle: TextStyle(
                color: isSelected ? color : AppTheme.textDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? color : const Color(0xFFE2EEF8),
              ),
            );
          },
        ),
      ),
    );
  }
}
