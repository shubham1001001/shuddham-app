import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/device_storage_service.dart';
import '../../../../core/services/telemetry_service.dart';
import '../../../../core/services/provisioning_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/logout_dialog.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/session/user_session.dart';
import '../../data/models/device_model.dart';
import '../widgets/water_drop_illustration.dart';
import '../widgets/device_card.dart';
import '../widgets/add_device_card.dart';
import '../widgets/device_details_sheet.dart';
import '../widgets/home_shimmer_card.dart';
import '../../../../core/utils/app_toast.dart';
import 'add_device_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Paired devices list loaded from persistent storage
  final List<DeviceModel> _devices = [];
  int _selectedDeviceIndex = 0;
  Timer? _telemetryTimer;
  bool _isSyncing = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedDevices();
    // Periodically fetch live sensor telemetry from purifier every 8 seconds
    _telemetryTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _syncTelemetry();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _telemetryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[HomeScreen] Tablet resumed / screen turned on. Refreshing saved & cloud devices...');
      _loadSavedDevices();
    }
  }

  Future<void> _loadSavedDevices({bool forceLoader = false}) async {
    if (mounted && (_devices.isEmpty || forceLoader)) {
      setState(() => _isLoading = true);
    }

    // 1. Ensure user session is alive in memory (e.g. after sleep/resume)
    if (!UserSession().isLoggedIn) {
      await UserSession().loadSession();
    }

    if (!UserSession().isLoggedIn) {
      if (mounted) {
        setState(() {
          _devices.clear();
          _isLoading = false;
        });
      }
      return;
    }

    final userPhone = UserSession().rawPhone;
    final userEmail = UserSession().email;
    final userId = UserSession().currentUser?.id;
    final userKey = (userId != null && userId.isNotEmpty)
        ? userId
        : (userPhone.isNotEmpty ? userPhone : userEmail);

    final localList = await DeviceStorageService.getSavedDevices(userKey: userKey);
    final effectiveDevices = localList;
    AppLogger.dataSourceLoaded(
      source: "💾 LOCAL STORAGE (DEVICE PERSISTENCE)",
      dataType: "Paired Purifiers List",
      count: effectiveDevices.length,
      storageKey: userKey,
      details: effectiveDevices.isNotEmpty
          ? "Loaded user-assigned hardware: Pure TDS ${effectiveDevices.first.tdsPpm} PPM, Raw TDS ${effectiveDevices.first.inletTdsPpm ?? '--'} PPM, Fan ${effectiveDevices.first.fan ?? '--'}."
          : "No devices saved for user $userKey in local storage.",
    );

    // Display saved devices immediately so user sees their purifier container without any lag
    if (mounted) {
      final safeInitial = List<DeviceModel>.from(effectiveDevices);
      setState(() {
        _devices.clear();
        _devices.addAll(safeInitial);
        _selectedDeviceIndex = _devices.isNotEmpty
            ? _selectedDeviceIndex.clamp(0, _devices.length - 1)
            : 0;
        // If we have saved devices from cache, turn off loading immediately for zero-lag display.
        // If empty (e.g. fresh login), keep _isLoading = true so the Shimmer card stays visible while cloud is checked!
        if (_devices.isNotEmpty) {
          _isLoading = false;
        }
      });
    }

    // Automatically check for purifiers assigned to this specific customer in the cloud
    try {
      if (userPhone.isNotEmpty || userEmail.isNotEmpty || (userId != null && userId.isNotEmpty)) {
        final cloudDevices = await TelemetryService.instance.fetchCustomerDevices(
          userPhone: userPhone,
          email: userEmail,
          customerId: userId,
          token: UserSession().token,
        );

        if (cloudDevices != null) {
          // Backend responded successfully!
          if (cloudDevices.isNotEmpty) {
            // Hardware IS assigned to this customer in cloud inventory
            AppLogger.dataSourceLoaded(
              source: "🌐 LIVE CLOUD REST API",
              dataType: "Customer Assigned Purifiers",
              count: cloudDevices.length,
              endpoint: "${ApiEndpoints.liveBaseUrl}/customer/devices",
              details: "Fetched assigned hardware live from cloud for customer ($userPhone / $userId).",
            );

            final mergedDevices = cloudDevices.map((cloudDev) {
              final existingIndex = _devices.indexWhere((l) =>
                  l.id == cloudDev.id ||
                  l.serialNumber == cloudDev.serialNumber ||
                  l.id.replaceAll(':', '').toLowerCase() == cloudDev.id.replaceAll(':', '').toLowerCase());
              if (existingIndex >= 0) {
                final existing = _devices[existingIndex];
                return cloudDev.copyWith(
                  tdsPpm: cloudDev.tdsPpm > 0 ? cloudDev.tdsPpm : existing.tdsPpm,
                  inletTdsPpm: cloudDev.inletTdsPpm ?? existing.inletTdsPpm,
                  temperature: cloudDev.temperature ?? existing.temperature,
                  mode: cloudDev.mode ?? existing.mode,
                  fan: cloudDev.fan ?? existing.fan,
                  tdsRange: cloudDev.tdsRange ?? existing.tdsRange,
                  lastReadingTime: cloudDev.lastReadingTime ?? existing.lastReadingTime,
                  isOnline: cloudDev.isOnline,
                );
              }
              return cloudDev;
            }).toList();

            await DeviceStorageService.saveDevices(mergedDevices, userKey: userKey);
            if (mounted) {
              final safeMerged = List<DeviceModel>.from(mergedDevices);
              setState(() {
                _devices.clear();
                _devices.addAll(safeMerged);
                _selectedDeviceIndex = _devices.isNotEmpty
                    ? _selectedDeviceIndex.clamp(0, _devices.length - 1)
                    : 0;
                _isLoading = false;
              });
            }
          } else {
            // Backend returned 0 assigned devices from cloud.
            // If user has locally paired devices, PRESERVE them and sync/claim to cloud!
            if (_devices.isNotEmpty) {
              AppLogger.dataSourceLoaded(
                source: "💾 LOCAL STORAGE (PRESERVED & CLAIMING)",
                dataType: "Customer Paired Purifiers",
                count: _devices.length,
                endpoint: "${ApiEndpoints.liveBaseUrl}/customer/devices",
                details: "Cloud returned 0 assigned devices, but user has ${_devices.length} locally paired purifier(s). Auto-syncing to cloud.",
              );
              // Auto-claim locally paired purifiers on backend cloud
              for (final dev in _devices) {
                TelemetryService.instance.claimDevice(
                  serialNumber: dev.serialNumber,
                  deviceName: dev.name,
                  location: dev.location,
                  phone: userPhone,
                  email: userEmail,
                  customerId: userId,
                  customerName: UserSession().userName,
                ).catchError((_) => false);
              }
              if (mounted) {
                setState(() => _isLoading = false);
              }
            } else {
              // Clean local storage when user has no devices locally either
              await DeviceStorageService.saveDevices([], userKey: userKey, allowEmpty: true);
              if (mounted) {
                setState(() {
                  _devices.clear();
                  _selectedDeviceIndex = 0;
                  _isLoading = false;
                });
              }
            }
          }
        } else {
          AppLogger.dataSourceLoaded(
            source: "💾 LOCAL STORAGE (OFFLINE / CACHE)",
            dataType: "Paired Purifiers List",
            count: _devices.length,
            details: "Cloud unreachable (offline). Displaying local storage for user $userKey.",
          );
        }
      }
    } catch (e) {
      debugPrint('[HomeScreen] Cloud assigned devices check notice: $e');
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }

    // Immediately pull real sensor telemetry for loaded devices
    if (_devices.isNotEmpty) {
      await _syncTelemetry();
    }
  }

  Future<void> _syncTelemetry() async {
    if (!mounted || _devices.isEmpty || _isSyncing) return;
    _isSyncing = true;
    try {
      final updated = await TelemetryService.instance.syncDevices(_devices);
      // ONLY update if updated returned real devices - NEVER wipe _devices on network error!
      if (mounted && updated.isNotEmpty) {
        final safeCopy = List<DeviceModel>.from(updated);
        setState(() {
          _devices.clear();
          _devices.addAll(safeCopy);
          _selectedDeviceIndex = _devices.isNotEmpty
              ? _selectedDeviceIndex.clamp(0, _devices.length - 1)
              : 0;
        });
      }
    } catch (e) {
      debugPrint('[HomeScreen] Telemetry sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  String _formatTelemetryDateTime(DateTime? dt) {
    if (dt == null) return 'No readings yet';
    final effectiveDt = dt;
    final day = effectiveDt.day.toString().padLeft(2, '0');
    final month = effectiveDt.month.toString().padLeft(2, '0');
    final year = effectiveDt.year;

    final hour12 = effectiveDt.hour % 12 == 0 ? 12 : effectiveDt.hour % 12;
    final minute = effectiveDt.minute.toString().padLeft(2, '0');
    final second = effectiveDt.second.toString().padLeft(2, '0');
    final period = effectiveDt.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/$year • $hour12:$minute:$second $period';
  }

  bool _isSendingFanCommand = false;
  String? _syncingFanDeviceId;

  Future<void> _sendFanCommand(DeviceModel device, String command) async {
    final isEnable = command.trim() == 'F,1';
    final isDisable = command.trim() == 'F,0';
    final currentFan = device.fan?.trim().toLowerCase();

    final isAlreadyDisabled = currentFan == 'disable' || currentFan == 'disabled' || currentFan == 'off' || currentFan == '0';
    final isAlreadyEnabled = currentFan == 'enable' || currentFan == 'enabled' || currentFan == 'on' || currentFan == '1';

    if (isDisable && isAlreadyDisabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Fan is already disabled!',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (isEnable && isAlreadyEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Fan is already enabled!',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final actionName = isEnable ? 'Enable Fan' : 'Disable Fan';
    final fanState = isEnable ? 'enable' : 'disable';
    final previousFan = device.fan;

    // 1. Optimistic UI update: show target state immediately with a 'Syncing' indicator
    setState(() {
      _isSendingFanCommand = true;
      _syncingFanDeviceId = device.id;
      final idx = _devices.indexWhere((d) => d.id == device.id);
      if (idx != -1) {
        _devices[idx] = device.copyWith(fan: fanState);
      }
    });

    try {
      final dispatchResult = await TelemetryService.instance.sendSmartConfig(
        deviceId: device.id,
        serialNumber: device.serialNumber,
        tdsRange: device.tdsRange ?? 200,
        fanState: fanState,
        rawCommand: command,
      );

      if (!dispatchResult.success) {
        // Dispatch failed (e.g. offline and bluetooth failed): REVERT UI!
        if (mounted) {
          setState(() {
            final idx = _devices.indexWhere((d) => d.id == device.id);
            if (idx != -1) {
              _devices[idx] = device.copyWith(fan: previousFan);
            }
          });
          AppToast.showFailure(
            context,
            title: dispatchResult.transport == 'ble'
                ? 'Bluetooth Delivery Failed'
                : 'Command Failed',
            subtitle: dispatchResult.message.isNotEmpty
                ? dispatchResult.message
                : 'Failed to send fan command. Status unchanged.',
            transport: dispatchResult.transport,
          );
        }
        return;
      }

      // If sent via BLE, hardware executes immediately
      bool hardwareConfirmed = (dispatchResult.transport == 'ble');

      if (!hardwareConfirmed) {
        // Wait briefly (up to 10s) for immediate hardware confirmation
        hardwareConfirmed = await TelemetryService.instance.waitForHardwareConfirmation(
          deviceId: device.id,
          expectedFan: fanState,
          timeout: const Duration(seconds: 10),
          pollInterval: const Duration(seconds: 3),
        );
      }

      if (hardwareConfirmed) {
        // HARDWARE CONFIRMED IMMEDIATELY!
        final confirmedDevice = device.copyWith(fan: fanState);
        await DeviceStorageService.saveOrUpdateDevice(confirmedDevice);

        if (mounted) {
          setState(() {
            final idx = _devices.indexWhere((d) => d.id == device.id);
            if (idx != -1) {
              _devices[idx] = confirmedDevice;
            }
          });

          AppToast.showSuccess(
            context,
            title: dispatchResult.transport == 'ble'
                ? 'Purifier Updated'
                : 'Hardware Confirmed',
            subtitle: dispatchResult.transport == 'ble'
                ? 'Cooling fan is now ${fanState.toUpperCase()}! Delivered via Bluetooth.'
                : 'Cooling fan is now ${fanState.toUpperCase()}! Confirmed via Wi-Fi.',
            transport: dispatchResult.transport,
          );
        }

        AppLogger.fanCommandResult(
          deviceId: device.id,
          command: command,
          action: actionName,
          success: true,
          transport: dispatchResult.transport,
          message: 'Hardware confirmed fan state $fanState',
          currentFanStatus: previousFan ?? 'unknown',
          newFanStatus: fanState,
        );
      } else {
        // Hardware did NOT confirm: REVERT TO PREVIOUS STATE!
        TelemetryService.instance.clearPendingFan(device.id);

        if (mounted) {
          setState(() {
            final idx = _devices.indexWhere((d) => d.id == device.id);
            if (idx != -1) {
              _devices[idx] = device.copyWith(fan: previousFan);
            }
          });

          AppToast.showHardwareTimeout(
            context,
            title: 'Purifier Did Not Respond',
            subtitle: 'Fan setting reverted. Purifier is offline.',
          );
        }

        AppLogger.fanCommandResult(
          deviceId: device.id,
          command: command,
          action: actionName,
          success: false,
          transport: dispatchResult.transport,
          message: 'Hardware did not confirm within timeout. Reverted to $previousFan.',
          currentFanStatus: previousFan ?? 'unknown',
        );
      }
    } catch (e) {
      // Exception: Revert UI
      if (mounted) {
        setState(() {
          final idx = _devices.indexWhere((d) => d.id == device.id);
          if (idx != -1) {
            _devices[idx] = device.copyWith(fan: previousFan);
          }
        });
        AppToast.showFailure(
          context,
          title: 'Command Failed',
          subtitle: 'Failed to execute $actionName: $e',
          transport: 'ble',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingFanCommand = false;
          _syncingFanDeviceId = null;
        });
      }
    }
  }

  void _openAddDeviceModal() {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddDeviceSetupScreen(
          onDeviceAdded: (newDevice) async {
            await DeviceStorageService.saveOrUpdateDevice(newDevice);
            if (mounted) {
              setState(() {
                _devices.removeWhere((d) => d.id == newDevice.id);
                _devices.add(newDevice);
                _selectedDeviceIndex = _devices.length - 1;
              });

              messenger.showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${newDevice.name} paired successfully! Telemetry is live.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppTheme.accentGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _unpairDeviceWithHardwareReset(DeviceModel device) async {
    // 1. Immediately update UI state so screen switches instantly without lag
    if (mounted) {
      setState(() {
        _devices.removeWhere((d) => d.id == device.id);
        _selectedDeviceIndex = _devices.isNotEmpty
            ? _selectedDeviceIndex.clamp(0, _devices.length - 1)
            : 0;
      });

      // 2. Show friendly guidance dialog immediately
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          title: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Device Unpaired',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"${device.name}" has been removed from your app.',
                style: const TextStyle(fontSize: 14, color: AppTheme.textDark, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.tips_and_updates_outlined, color: Color(0xFF059669), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'To pair again or connect to a new Wi-Fi, press & hold the physical button on your purifier for 5 seconds to enter Pairing Mode.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF065F46), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.royalBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got It', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      );
    }

    // 3. Remove from persistent local storage
    await DeviceStorageService.removeDevice(device.id);

    // 4. Send hardware reset / Wi-Fi clear commands to purifier via Cloud MQTT and BLE in background
    try {
      await TelemetryService.instance.sendCommand(
        deviceId: device.id,
        command: 'WIFI_CLEAR',
      );
    } catch (e) {
      debugPrint('[HomeScreen] Cloud unpair command error: $e');
    }

    try {
      await ProvisioningService.instance.sendRawCommand('WIFI_CLEAR');
      await ProvisioningService.instance.disconnect();
    } catch (e) {
      debugPrint('[HomeScreen] BLE unpair command error: $e');
    }
  }

  void _openDeviceDetails(DeviceModel device, int index) {
    DeviceDetailsSheet.show(
      context,
      device: device,
      onRemove: () => _unpairDeviceWithHardwareReset(device),
      onSync: () async {
        // Re-read local storage first so offline changes (TDS, fan) are immediately updated in UI
        final localDevices = await DeviceStorageService.getSavedDevices();
        if (mounted && localDevices.isNotEmpty) {
          setState(() {
            _devices.clear();
            _devices.addAll(localDevices);
          });
        }
        await _syncTelemetry();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _isLoading && _devices.isEmpty
            ? const HomeShimmerCard()
            : (_devices.isEmpty
                ? _buildNoPurifierScreen()
                : _buildConnectedPurifierScreen()),
      ),
    );
  }

  /// 1. Screen matching the user's reference image
  /// (with "Home" [Guest], centered water drop, "No purifier added yet",
  /// and "+ Add device" button - WITHOUT the bottom "Try with sample purifier" button)
  Widget _buildNoPurifierScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header: Shuddham Brand Logo + Title + Status + Logout
        _buildTopHeader(isConnected: false),

        // Centered Main Content with Pull-To-Refresh
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadSavedDevices(forceLoader: true),
            color: AppTheme.royalBlue,
            child: Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  // Circular water droplet illustration
                  const WaterDropIllustration(size: 155),
                  const SizedBox(height: 28),

                  // Heading
                  const Text(
                    'No purifier added yet',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF102A43),
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Subtitle description
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 36),
                    child: Text(
                      'Add your RO purifier to see water TDS and temperature live. Keep it powered on and within 2 m of your phone.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF627D98),
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Primary Button: "+ Add device"
                  // Note: Bottom button ("Try with sample purifier") is omitted as per "niche vali btn nhi"
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _openAddDeviceModal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.royalBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_rounded, size: 20, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Add device',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
  }

  Widget _buildConnectedPurifierScreen() {
    if (_devices.isEmpty) {
      return _buildNoPurifierScreen();
    }
    final safeIndex = _selectedDeviceIndex.clamp(0, _devices.length - 1);
    final activeDevice = _devices[safeIndex];

    return RefreshIndicator(
      onRefresh: _syncTelemetry,
      color: AppTheme.royalBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Shuddham Brand Logo + Title + Status + Actions
            _buildTopHeader(isConnected: true),

            const SizedBox(height: 16),



            // Devices: Full width when single device paired, carousel when multiple
            if (_devices.length == 1)
              DeviceCard(
                device: _devices.first,
                isSelected: true,
                width: double.infinity,
                margin: EdgeInsets.zero,
                onSelect: () => _openDeviceDetails(_devices.first, 0),
                onDetails: () => _openDeviceDetails(_devices.first, 0),
              )
            else
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _devices.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _devices.length) {
                      return AddDeviceCard(onTap: _openAddDeviceModal);
                    }
                    final dev = _devices[index];
                    return DeviceCard(
                      device: dev,
                      isSelected: index == _selectedDeviceIndex,
                      width: 280,
                      margin: const EdgeInsets.only(right: 14),
                      onSelect: () {
                        setState(() {
                          _selectedDeviceIndex = index;
                        });
                        _openDeviceDetails(dev, index);
                      },
                      onDetails: () => _openDeviceDetails(dev, index),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            // Live Water Purity & Temperature Telemetry Card
            Container(
              padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2EEF8)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0077EE).withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: activeDevice.isOnline ? AppTheme.accentGreen : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${activeDevice.isOnline ? 'Live Sensor' : 'Offline'} • ${activeDevice.name}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: activeDevice.isOnline ? const Color(0xFFF0FDF4) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                activeDevice.mode != null
                                    ? '${activeDevice.mode} MODE'
                                    : (activeDevice.isOnline ? 'LIVE' : 'OFFLINE'),
                                style: TextStyle(
                                  color: activeDevice.isOnline ? AppTheme.accentGreen : AppTheme.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Theme(
                              data: Theme.of(context).copyWith(
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                              ),
                              child: PopupMenuButton<String>(
                                color: Colors.white,
                                icon: const Icon(
                                  Icons.more_vert_rounded,
                                  size: 19,
                                  color: AppTheme.textDark,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 124, maxWidth: 142),
                                menuPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                tooltip: 'Device Options',
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(color: Color(0xFFE2EEF8)),
                                ),
                                onSelected: (value) {
                                  if (value == 'details') {
                                    _openDeviceDetails(activeDevice, _selectedDeviceIndex);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem<String>(
                                    value: 'details',
                                    height: 34,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Row(
                                      children: const [
                                        Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.royalBlue),
                                        SizedBox(width: 8),
                                        Text(
                                          'Device Details',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Inlet TDS', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                const SizedBox(height: 4),
                                Text(
                                  activeDevice.inletTdsPpm != null ? '${activeDevice.inletTdsPpm} PPM' : '—',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                ),
                                const Text('Raw Water', style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Purified TDS', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                const SizedBox(height: 4),
                                Text(
                                  '${activeDevice.tdsPpm} PPM',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                ),
                                Text(
                                  activeDevice.tdsPpm <= 100
                                      ? 'Optimal'
                                      : (activeDevice.tdsPpm <= 250 ? 'Safe' : 'High'),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: activeDevice.tdsPpm <= 100
                                        ? AppTheme.accentGreen
                                        : (activeDevice.tdsPpm <= 250 ? const Color(0xFF0284C7) : const Color(0xFFEF4444)),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Temperature', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                const SizedBox(height: 4),
                                Text(
                                  activeDevice.temperature != null
                                      ? '${activeDevice.temperature!.toStringAsFixed(1)}°C'
                                      : '—',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                ),
                                Text(
                                  activeDevice.temperature != null ? 'Real Sensor' : 'Awaiting reading',
                                  style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Last Data Received Date & Time Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 16, color: AppTheme.royalBlue),
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
                              _formatTelemetryDateTime(activeDevice.lastReadingTime),
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

                    const SizedBox(height: 12),

                    // Fan Control Buttons Container: F,0 (Disable) and F,1 (Enable)
                    // Fan Control Buttons Container: F,0 (Disable) and F,1 (Enable)
                    Builder(
                      builder: (context) {
                        final isFanDisabled = activeDevice.fan?.toLowerCase() == 'disable';
                        final isFanEnabled = activeDevice.fan?.toLowerCase() == 'enable';

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: isFanDisabled ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isFanDisabled ? const Color(0xFFFECACA) : const Color(0xFFE2EEF8),
                              width: isFanDisabled ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: isFanDisabled
                                              ? const Color(0xFFFEE2E2)
                                              : (isFanEnabled ? const Color(0xFFDCFCE7) : const Color(0xFFE0F2FE)),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          isFanDisabled ? Icons.power_settings_new_rounded : Icons.mode_fan_off_rounded,
                                          color: isFanDisabled
                                              ? const Color(0xFFDC2626)
                                              : (isFanEnabled ? AppTheme.accentGreen : const Color(0xFF0284C7)),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Cooling Fan Relay',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textDark,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Container(
                                                width: 7,
                                                height: 7,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isFanDisabled
                                                      ? const Color(0xFFEF4444)
                                                      : (isFanEnabled ? const Color(0xFF22C55E) : const Color(0xFF94A3B8)),
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                isFanDisabled
                                                    ? 'Status: DISABLED (Off)'
                                                    : (isFanEnabled ? 'Status: ENABLED (Active)' : 'Status: Standby'),
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: isFanDisabled
                                                      ? const Color(0xFFDC2626)
                                                      : (isFanEnabled ? const Color(0xFF15803D) : AppTheme.textMuted),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (_syncingFanDeviceId == activeDevice.id)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: const Color(0xFFFDE68A)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          SizedBox(
                                            width: 10,
                                            height: 10,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              color: Color(0xFFD97706),
                                            ),
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            'SYNCING',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                              color: Color(0xFFB45309),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (_isSendingFanCommand)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isFanDisabled
                                            ? const Color(0xFFFEE2E2)
                                            : (isFanEnabled ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isFanDisabled
                                              ? const Color(0xFFFCA5A5)
                                              : (isFanEnabled ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
                                        ),
                                      ),
                                      child: Text(
                                        isFanDisabled ? 'DISABLED' : (isFanEnabled ? 'ACTIVE' : 'IDLE'),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          color: isFanDisabled
                                              ? const Color(0xFFB91C1C)
                                              : (isFanEnabled ? const Color(0xFF15803D) : const Color(0xFF64748B)),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // Button 1: Disable Fan (F,0)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isSendingFanCommand
                                          ? null
                                          : () {
                                              if (isFanDisabled) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Row(
                                                      children: const [
                                                        Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                                                        SizedBox(width: 10),
                                                        Expanded(
                                                          child: Text(
                                                            'Fan is already disabled!',
                                                            style: TextStyle(fontWeight: FontWeight.w600),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    backgroundColor: const Color(0xFFEF4444),
                                                    behavior: SnackBarBehavior.floating,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    margin: const EdgeInsets.all(16),
                                                    duration: const Duration(seconds: 2),
                                                  ),
                                                );
                                                return;
                                              }
                                              _sendFanCommand(activeDevice, 'F,0');
                                            },
                                      icon: Icon(
                                        isFanDisabled ? Icons.check_circle_rounded : Icons.power_settings_new_rounded,
                                        size: 16,
                                      ),
                                      label: Text(
                                        isFanDisabled ? 'Disabled' : 'Disable',
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isFanDisabled ? const Color(0xFFEF4444) : Colors.white,
                                        foregroundColor: isFanDisabled ? Colors.white : const Color(0xFFEF4444),
                                        elevation: isFanDisabled ? 1 : 0,
                                        side: BorderSide(
                                          color: const Color(0xFFEF4444),
                                          width: isFanDisabled ? 1.5 : 1.2,
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Button 2: Enable Fan (F,1)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isSendingFanCommand
                                          ? null
                                          : () {
                                              if (isFanEnabled) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Row(
                                                      children: const [
                                                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                                        SizedBox(width: 10),
                                                        Expanded(
                                                          child: Text(
                                                            'Fan is already enabled!',
                                                            style: TextStyle(fontWeight: FontWeight.w600),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    backgroundColor: const Color(0xFF16A34A),
                                                    behavior: SnackBarBehavior.floating,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    margin: const EdgeInsets.all(16),
                                                    duration: const Duration(seconds: 2),
                                                  ),
                                                );
                                                return;
                                              }
                                              _sendFanCommand(activeDevice, 'F,1');
                                            },
                                      icon: Icon(
                                        isFanEnabled ? Icons.check_circle_rounded : Icons.mode_fan_off_rounded,
                                        size: 16,
                                      ),
                                      label: Text(
                                        isFanEnabled ? 'Enabled' : 'Enable',
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isFanEnabled ? const Color(0xFF16A34A) : Colors.white,
                                        foregroundColor: isFanEnabled ? Colors.white : const Color(0xFF16A34A),
                                        elevation: isFanEnabled ? 1 : 0,
                                        side: BorderSide(
                                          color: const Color(0xFF16A34A),
                                          width: isFanEnabled ? 1.5 : 1.2,
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              title: const Text('Unpair Device?'),
                              content: Text(
                                'Are you sure you want to disconnect "${activeDevice.name}"? You will stop receiving live water quality alerts for this unit.',
                                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textDark)),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _unpairDeviceWithHardwareReset(activeDevice);
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
                        },
                        icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                        label: const Text('Unpair', style: TextStyle(color: Color(0xFFEF4444))),
                      ),
                    ),
                  ],
                ),
              ),

          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

  /// Top Brand Header with Shuddham Logo, Name, Status Pill and Actions
  Widget _buildTopHeader({required bool isConnected}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isConnected ? 0 : 24,
        vertical: isConnected ? 0 : 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                // Shuddham Logo Mark
                Image.asset(
                  'assets/images/logo-mark.png',
                  height: 38,
                  width: 38,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Flexible(
                            child: Text(
                              'Shuddham',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF102A43),
                                letterSpacing: -0.4,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_devices.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_devices.length} Paired',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Smart Water Solutions',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isConnected) ...[
                InkWell(
                  onTap: _openAddDeviceModal,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.royalBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.royalBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add_rounded, size: 15, color: AppTheme.royalBlue),
                        SizedBox(width: 3),
                        Text(
                          'Add Device',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.royalBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
                tooltip: 'Log Out',
                onPressed: () => showLogoutDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
