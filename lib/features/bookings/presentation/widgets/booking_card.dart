import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/booking_entity.dart';

/// Reusable card displaying booking details, status, technician, and TDS reports.
class BookingCard extends StatelessWidget {
  final BookingEntity booking;

  const BookingCard({
    super.key,
    required this.booking,
  });

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'all':
        return AppTheme.royalBlue;
      case 'completed':
        return AppTheme.accentGreen;
      case 'confirmed':
      case 'assigned':
        return const Color(0xFF0284C7);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'pending':
      default:
        return const Color(0xFFD97706);
    }
  }

  static Color statusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'all':
        return const Color(0xFFE0F2FE);
      case 'completed':
        return const Color(0xFFECFDF5);
      case 'confirmed':
      case 'assigned':
        return const Color(0xFFE0F2FE);
      case 'cancelled':
        return const Color(0xFFFEE2E2);
      case 'pending':
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final color = statusColor(b.status);
    final bgColor = statusBgColor(b.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EEF8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0077EE).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Booking ID & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                b.id,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.royalBlue, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  b.status,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Service title
          Text(
            b.serviceTitle,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
          const SizedBox(height: 6),

          // Date & Time
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text('${b.date} • ${b.timeSlot}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 4),

          // Address
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  b.address,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Technician & Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Assigned Technician', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  Text(
                    b.technicianName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                  ),
                ],
              ),
              Text(
                '₹${b.amount}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.royalBlue),
              ),
            ],
          ),

          // Payment status pill
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: b.paymentStatus == 'Paid' ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Payment: ${b.paymentStatus}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: b.paymentStatus == 'Paid' ? AppTheme.accentGreen : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),

          // TDS Report (if available)
          if (b.tdsReport != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 14, color: AppTheme.accentGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      b.tdsReport!,
                      style: const TextStyle(fontSize: 11, color: AppTheme.accentGreen, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
