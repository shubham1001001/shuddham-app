import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/device_entity.dart';

class DeviceCard extends StatelessWidget {
  final DeviceEntity device;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback? onDetails;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;

  const DeviceCard({
    super.key,
    required this.device,
    required this.isSelected,
    required this.onSelect,
    this.onDetails,
    this.width,
    this.height,
    this.margin,
  });

  IconData _getDeviceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'tds meter':
      case 'tds sensor':
        return Icons.speed_rounded;
      case 'tank sensor':
      case 'tank level sensor':
        return Icons.sensors_rounded;
      case 'uv filter':
      case 'uv disinfector':
        return Icons.wb_iridescent_rounded;
      case 'ro purifier':
      default:
        return Icons.water_drop_rounded;
    }
  }

  Color _getTdsColor(int tds) {
    if (tds <= 100) return AppTheme.accentGreen;
    if (tds <= 250) return const Color(0xFF0284C7);
    if (tds <= 400) return AppTheme.accentOrange;
    return const Color(0xFFEF4444);
  }

  String _getTdsStatus(int tds) {
    if (tds <= 100) return 'Optimal';
    if (tds <= 250) return 'Good';
    if (tds <= 400) return 'Fair';
    return 'High';
  }

  String _formatDeviceTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/$year, $hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final tdsColor = _getTdsColor(device.tdsPpm);
    final tdsStatus = _getTdsStatus(device.tdsPpm);

    return Container(
      width: width ?? 260,
      height: height,
      margin: margin ?? const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppTheme.royalBlue : const Color(0xFFE2EEF8),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppTheme.royalBlue.withValues(alpha: 0.12)
                : const Color(0xFF0077EE).withValues(alpha: 0.04),
            blurRadius: isSelected ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Icon + Name / Status + 3 dots
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSelected
                              ? [AppTheme.royalBlue, const Color(0xFF00B4D8)]
                              : [const Color(0xFFEBF5FF), const Color(0xFFD8ECFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getDeviceIcon(device.type),
                        color: isSelected ? Colors.white : AppTheme.royalBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: device.isOnline ? AppTheme.accentGreen : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                device.isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: device.isOnline ? AppTheme.accentGreen : AppTheme.textMuted,
                                ),
                              ),
                              if (device.lastReadingTime != null) ...[
                                const SizedBox(width: 5),
                                const Text('•', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    _formatDeviceTime(device.lastReadingTime!),
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Bottom Row: TDS Metric Chip + Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            device.inletTdsPpm != null ? 'Pure: ' : 'TDS: ',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${device.tdsPpm}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: tdsColor,
                            ),
                          ),
                          if (device.inletTdsPpm != null) ...[
                            Text(
                              ' | Raw: ${device.inletTdsPpm}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                          const Text(
                            ' PPM',
                            style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: tdsColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tdsStatus,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: tdsColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
