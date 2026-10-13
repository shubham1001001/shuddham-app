import 'package:flutter/material.dart';
import '../../../../core/services/device_storage_service.dart';
import '../../../../core/services/telemetry_service.dart';
import '../../../../core/utils/app_logger.dart';
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
      enableDrag: false,
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
  late DeviceEntity _device;
  late double _tdsValue;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    final int? lastTdsRange = _device.tdsRange;
    final double initial = (lastTdsRange != null && lastTdsRange > 0)
        ? lastTdsRange.toDouble()
        : (_device.inletTdsPpm ?? _device.tdsPpm).toDouble();
    _tdsValue = initial.clamp(50.0, 1000.0);
    _loadLatestTdsRange();
  }

  Future<void> _loadLatestTdsRange() async {
    try {
      final savedDevices = await DeviceStorageService.getSavedDevices();
      final match = savedDevices.where((d) => d.id == _device.id).firstOrNull;
      if (match != null && match.tdsRange != null && match.tdsRange! > 0 && mounted && !_isSaving) {
        setState(() {
          _device = match;
          _tdsValue = match.tdsRange!.toDouble().clamp(50.0, 1000.0);
        });
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant DeviceDetailsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device != widget.device) {
      _device = widget.device;
      if (!_isSaving) {
        final int? lastTdsRange = _device.tdsRange;
        final double initial = (lastTdsRange != null && lastTdsRange > 0)
            ? lastTdsRange.toDouble()
            : (_device.inletTdsPpm ?? _device.tdsPpm).toDouble();
        _tdsValue = initial.clamp(50.0, 1000.0);
      }
    }
  }

  Color _getTdsColor(double tds) {
    if (tds <= 150) return AppTheme.accentGreen;
    if (tds <= 300) return const Color(0xFF0284C7);
    if (tds <= 500) return AppTheme.accentOrange;
    return const Color(0xFFEF4444);
  }

  Future<void> _saveTdsValue() async {
    setState(() => _isSaving = true);
    final int selectedTds = _tdsValue.round();
    final targetRange = selectedTds >= 991 ? 1000 : selectedTds;

    final fanState = _device.fan ?? 'enable';

    try {
      // 1. Dispatch via Smart Hybrid Config (checks Internet -> MQTT JSON, falls back to BLE)
      final dispatchResult = await TelemetryService.instance.sendSmartConfig(
        deviceId: _device.id,
        serialNumber: _device.serialNumber,
        tdsRange: targetRange,
        fanState: fanState,
        rawCommand: 'T,$targetRange',
      );

      // Print structured log for developer & QA visibility
      AppLogger.tdsCommandSent(
        deviceId: _device.id,
        rawTds: _tdsValue,
        finalTds: targetRange,
        command: 'T,$targetRange',
        topic: 'Shudhham/tds/v1/SubConfig',
      );

      if (dispatchResult.success) {
        AppLogger.tdsCommandResult(
          deviceId: _device.id,
          targetTds: targetRange,
          success: true,
          transport: dispatchResult.transport,
          message: dispatchResult.message,
        );

        // 3. Update local storage device model ONLY when command succeeded
        DeviceModel modelToSave;
        if (_device is DeviceModel) {
          modelToSave = (_device as DeviceModel).copyWith(
            tdsRange: targetRange,
          );
        } else {
          modelToSave = DeviceModel(
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
            fan: _device.fan,
            tdsRange: targetRange,
          );
        }
        await DeviceStorageService.saveOrUpdateDevice(modelToSave);

        widget.onSync();

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dispatchResult.message,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: dispatchResult.transport == 'mqtt'
                  ? AppTheme.accentGreen
                  : Colors.blue.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } else {
        // Command NOT successful (e.g. Bluetooth failed to connect or deliver)
        // DO NOT UPDATE TDS IN LOCAL STORAGE!
        AppLogger.tdsCommandResult(
          deviceId: _device.id,
          targetTds: targetRange,
          success: false,
          transport: dispatchResult.transport,
          message: dispatchResult.message,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        dispatchResult.transport == 'ble'
                            ? 'Bluetooth delivery failed! TDS value not changed.'
                            : (dispatchResult.message.isNotEmpty
                                ? dispatchResult.message
                                : 'Failed to deliver TDS command. Setting unchanged.'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 4),
              ),
            );
        }
      }
    } catch (e) {
      debugPrint('[DeviceDetailsSheet] Error saving TDS value: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Failed to update TDS value: $e',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 4),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tdsColor = _getTdsColor(_tdsValue);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
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
                    const Text(
                      'Device Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _device.name,
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

            const SizedBox(height: 20),

            // TDS Value Card with Slider
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2EEF8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Target TDS Limit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      if (_device.tdsRange != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Last Saved: ${_device.tdsRange} PPM',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Big Value Counter
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${_tdsValue.round()}',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: tdsColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'PPM',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Interactive Slider (50 to 1000)
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: tdsColor,
                      inactiveTrackColor: const Color(0xFFE2E8F0),
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 12,
                        elevation: 4,
                      ),
                      overlayColor: tdsColor.withValues(alpha: 0.16),
                      trackHeight: 6,
                    ),
                    child: Slider(
                      min: 50.0,
                      max: 1000.0,
                      divisions: 950,
                      value: _tdsValue,
                      onChanged: (val) {
                        setState(() => _tdsValue = val);
                      },
                    ),
                  ),

                  // Min & Max Labels
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          '50 PPM (Min)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        Text(
                          '1000 PPM (Max)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Set TDS Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveTdsValue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.royalBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Set Input TDS Value',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
