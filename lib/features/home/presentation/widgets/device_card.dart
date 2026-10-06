import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/device_entity.dart';

class DeviceCard extends StatelessWidget {
  final DeviceEntity device;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onDetails;

  const DeviceCard({
    super.key,
    required this.device,
    required this.isSelected,
    required this.onSelect,
    required this.onDetails,
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

  @override
  Widget build(BuildContext context) {
    final tdsColor = _getTdsColor(device.tdsPpm);
    final tdsStatus = _getTdsStatus(device.tdsPpm);

    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 14),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Icon + Online Pill + Details Button
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSelected
                              ? [AppTheme.royalBlue, const Color(0xFF00B4D8)]
                              : [const Color(0xFFEBF5FF), const Color(0xFFD8ECFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getDeviceIcon(device.type),
                        color: isSelected ? Colors.white : AppTheme.royalBlue,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
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
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppTheme.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Device Settings',
                      onPressed: onDetails,
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Device Name & Location
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${device.location} • ${device.model}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Metrics Row: TDS & Filter Life
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Water TDS',
                            style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Text(
                                '${device.tdsPpm}',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: tdsColor,
                                ),
                              ),
                              const Text(
                                ' PPM',
                                style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: tdsColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tdsStatus,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: tdsColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Filter Life Indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter Lifespan',
                          style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${device.filterLifePercentage}%',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: device.filterLifePercentage / 100.0,
                        minHeight: 4.5,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          device.filterLifePercentage > 40
                              ? AppTheme.royalBlue
                              : (device.filterLifePercentage > 20 ? AppTheme.accentOrange : const Color(0xFFEF4444)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
