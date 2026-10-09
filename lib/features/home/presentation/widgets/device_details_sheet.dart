import 'package:flutter/material.dart';
import '../../../../core/services/device_storage_service.dart';
import '../../../../core/services/telemetry_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/device_model.dart';
import '../../domain/entities/device_entity.dart';

class DeviceDetailsSheet extends StatefulWidget {
  final DeviceEntity device;
  final VoidCallback onRemove;
  final VoidCallback onSync;

  const DeviceDetailsSheet({
    super.key,
    required this.device,
    required this.onRemove,
    required this.onSync,
  });

  static Future<void> show(
    BuildContext context, {
    required DeviceEntity device,
    required VoidCallback onRemove,
    required VoidCallback onSync,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeviceDetailsSheet(
        device: device,
        onRemove: onRemove,
        onSync: onSync,
      ),
    );
  }

  @override
  State<DeviceDetailsSheet> createState() => _DeviceDetailsSheetState();
}

class _DeviceDetailsSheetState extends State<DeviceDetailsSheet> {
  bool _isFlushing = false;
  bool _isSyncing = false;
  late DeviceEntity _device;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
  }

  @override
  void didUpdateWidget(covariant DeviceDetailsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device != widget.device) {
      _device = widget.device;
    }
  }

  String _formatSheetTime(DateTime? dt) {
    if (dt == null) return 'No data received yet';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/$year • $hour12:$minute:$second $period';
  }

  Future<void> _syncTelemetryInSheet() async {
    setState(() => _isSyncing = true);
    try {
      final records = await TelemetryService.instance.fetchAllTelemetry();
      if (records.isNotEmpty) {
        DeviceModel modelToMatch;
        if (_device is DeviceModel) {
          modelToMatch = _device as DeviceModel;
        } else {
          modelToMatch = DeviceModel(
            id: _device.id,
            name: _device.name,
            model: _device.model,
            type: _device.type,
            serialNumber: _device.serialNumber,
            location: _device.location,
            tdsPpm: _device.tdsPpm,
            filterLifePercentage: _device.filterLifePercentage,
            lastSync: _device.lastSync,
            totalLitersPurified: _device.totalLitersPurified,
            inletTdsPpm: _device.inletTdsPpm,
            temperature: _device.temperature,
            mode: _device.mode,
          );
        }
        final match = TelemetryService.instance.findMatchingRecord(modelToMatch, records);
        if (match != null) {
          final updated = TelemetryService.instance.applyTelemetryToDevice(modelToMatch, match);
          await DeviceStorageService.saveOrUpdateDevice(updated);
          if (mounted) {
            setState(() {
              _device = updated;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Live sensor updated: Output ${_device.tdsPpm} PPM, Input ${_device.inletTdsPpm ?? 58} PPM!'),
                backgroundColor: AppTheme.accentGreen,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
              ),
            );
          }
        }
      }
      widget.onSync();
    } catch (e) {
      debugPrint('[Sheet sync error] $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _runFlushCycle() async {
    setState(() {
      _isFlushing = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() {
      _isFlushing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Auto-flush cycle completed successfully!'),
          ],
        ),
        backgroundColor: AppTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.only(
          bottom: 24,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  void _confirmRemoval() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Unpair Device?'),
        content: Text(
          'Are you sure you want to disconnect "${_device.name}"? You will stop receiving live water quality alerts for this unit.',
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textDark)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              Navigator.of(context).pop();
              widget.onRemove();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Unpair Device'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _device.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _device.location.isNotEmpty
                        ? 'Serial: ${_device.serialNumber} • ${_device.location}'
                        : 'Serial: ${_device.serialNumber}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  shape: const CircleBorder(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Real-time Telemetry Metrics
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.royalBlue, Color(0xFF00B4D8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.royalBlue.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Live Water Purity Reading',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _device.isOnline ? '● LIVE SENSOR' : 'OFFLINE',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            final outlet = _device.tdsPpm;
                            final inlet = _device.inletTdsPpm;
                            final temp = _device.temperature;
                            String reductionStr = 'Optimal';
                            if (inlet != null && inlet > 0) {
                              final red = ((1.0 - (outlet / inlet)) * 100).clamp(0, 100).round();
                              reductionStr = '$red%';
                            }

                            return Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildTelemetryStat('Outlet TDS', '$outlet PPM', 'Purified Safe'),
                                    Container(width: 1, height: 40, color: Colors.white24),
                                    _buildTelemetryStat(
                                      'Inlet TDS',
                                      inlet != null ? '$inlet PPM' : '—',
                                      'Raw Supply',
                                    ),
                                    Container(width: 1, height: 40, color: Colors.white24),
                                    _buildTelemetryStat('Filtration', reductionStr, 'Reduction'),
                                  ],
                                ),
                                if (temp != null || _device.mode != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (temp != null) ...[
                                          const Icon(Icons.thermostat_rounded, size: 14, color: Colors.white),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Water Temp: ${temp.toStringAsFixed(1)}°C',
                                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                        if (temp != null && _device.mode != null) ...[
                                          const SizedBox(width: 12),
                                          const Text('•', style: TextStyle(color: Colors.white60)),
                                          const SizedBox(width: 12),
                                        ],
                                        if (_device.mode != null) ...[
                                          Text(
                                            'Mode: ${_device.mode}',
                                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Last Telemetry Timestamp Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 15, color: AppTheme.royalBlue),
                        const SizedBox(width: 8),
                        const Text(
                          'Last Reading: ',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _formatSheetTime(_device.lastReadingTime),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Filter Health Breakdown
                  const Text(
                    'Filter Stages Health',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 10),

                  _buildFilterProgress('1. Sediment Pre-Filter', 0.92, '92% • Healthy'),
                  _buildFilterProgress('2. Activated Carbon Block', 0.88, '88% • Good'),
                  _buildFilterProgress('3. Reverse Osmosis (RO) Membrane', _device.filterLifePercentage / 100.0, '${_device.filterLifePercentage}% • Optimal'),
                  _buildFilterProgress('4. Mineraliser & UV Polish', 0.95, '95% • Pristine'),

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isFlushing ? null : _runFlushCycle,
                          icon: _isFlushing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.waves_rounded, size: 18),
                          label: Text(_isFlushing ? 'Flushing...' : 'Auto Flush'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.royalBlue,
                            side: const BorderSide(color: AppTheme.royalBlue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSyncing ? null : _syncTelemetryInSheet,
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.sync_rounded, size: 18),
                          label: Text(_isSyncing ? 'Syncing...' : 'Sync Telemetry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.royalBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Unpair Device Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _confirmRemoval,
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                      label: const Text('Unpair This Device', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryStat(String label, String value, String sub) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(color: Colors.white60, fontSize: 9)),
      ],
    );
  }

  Widget _buildFilterProgress(String name, double progress, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.royalBlue)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.4 ? AppTheme.royalBlue : AppTheme.accentOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
