import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/services/device_storage_service.dart';
import '../../../../core/services/telemetry_service.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/models/device_model.dart';

/// Centralized state management provider for Paired Purifiers & Live Telemetry
class DeviceProvider extends ChangeNotifier {
  final List<DeviceModel> _devices = [];
  int _selectedDeviceIndex = 0;
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isSendingFanCommand = false;
  String? _syncingFanDeviceId;
  bool _isSendingTdsCommand = false;
  Timer? _telemetryTimer;

  // Getters
  List<DeviceModel> get devices => List.unmodifiable(_devices);
  int get selectedDeviceIndex => _selectedDeviceIndex;
  DeviceModel? get selectedDevice => _devices.isNotEmpty
      ? _devices[_selectedDeviceIndex.clamp(0, _devices.length - 1)]
      : null;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isSendingFanCommand => _isSendingFanCommand;
  String? get syncingFanDeviceId => _syncingFanDeviceId;
  bool get isSendingTdsCommand => _isSendingTdsCommand;

  DeviceProvider() {
    startTelemetryTimer();
  }

  void startTelemetryTimer() {
    _telemetryTimer?.cancel();
    _telemetryTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      syncTelemetry();
    });
  }

  void stopTelemetryTimer() {
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
  }

  void selectDevice(int index) {
    if (index >= 0 && index < _devices.length && index != _selectedDeviceIndex) {
      _selectedDeviceIndex = index;
      notifyListeners();
    }
  }

  /// Loads cached devices from local persistent storage,
  /// then queries cloud REST API for latest assigned hardware.
  Future<void> loadSavedDevices({bool forceLoader = false}) async {
    if (_devices.isEmpty || forceLoader) {
      _isLoading = true;
      notifyListeners();
    }

    // Ensure session is alive
    if (!UserSession().isLoggedIn) {
      await UserSession().loadSession();
    }

    if (!UserSession().isLoggedIn) {
      _devices.clear();
      _isLoading = false;
      notifyListeners();
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

    _devices.clear();
    _devices.addAll(effectiveDevices);
    _selectedDeviceIndex = _devices.isNotEmpty
        ? _selectedDeviceIndex.clamp(0, _devices.length - 1)
        : 0;
    if (_devices.isNotEmpty) {
      _isLoading = false;
    }
    notifyListeners();

    // Check cloud for official assigned purifiers
    try {
      if (userPhone.isNotEmpty || userEmail.isNotEmpty || (userId != null && userId.isNotEmpty)) {
        final cloudDevices = await TelemetryService.instance.fetchCustomerDevices(
          userPhone: userPhone,
          email: userEmail,
          customerId: userId,
          token: UserSession().token,
        );

        if (cloudDevices != null) {
          if (cloudDevices.isNotEmpty) {
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
            _devices.clear();
            _devices.addAll(mergedDevices);
            _selectedDeviceIndex = _devices.isNotEmpty
                ? _selectedDeviceIndex.clamp(0, _devices.length - 1)
                : 0;
            _isLoading = false;
            notifyListeners();
          } else {
            // Explicit 0 devices assigned: clear local cache
            AppLogger.dataSourceLoaded(
              source: "🌐 LIVE CLOUD REST API",
              dataType: "Customer Assigned Purifiers",
              count: 0,
              endpoint: "${ApiEndpoints.liveBaseUrl}/customer/devices",
              details: "Zero purifiers assigned to customer ($userPhone / $userId). Cleared local storage for this user.",
            );

            await DeviceStorageService.saveDevices([], userKey: userKey, allowEmpty: true);
            _devices.clear();
            _selectedDeviceIndex = 0;
            _isLoading = false;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('[DeviceProvider] Cloud assigned devices check notice: $e');
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }

    if (_devices.isNotEmpty) {
      await syncTelemetry();
    }
  }

  /// Syncs real-time telemetry from AWS IoT backend for all active devices
  Future<void> syncTelemetry() async {
    if (_devices.isEmpty || _isSyncing) return;
    _isSyncing = true;
    try {
      final updated = await TelemetryService.instance.syncDevices(_devices);
      if (updated.isNotEmpty) {
        _devices.clear();
        _devices.addAll(updated);
        _selectedDeviceIndex = _devices.isNotEmpty
            ? _selectedDeviceIndex.clamp(0, _devices.length - 1)
            : 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[DeviceProvider] Telemetry sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sends Fan ON / OFF command with optimistic UI update and hardware confirmation
  Future<CommandDispatchResult> sendFanCommand(DeviceModel device, String command) async {
    final isEnable = command.trim() == 'F,1';
    final fanState = isEnable ? 'enable' : 'disable';
    final previousFan = device.fan;

    // 1. Optimistic UI update
    _isSendingFanCommand = true;
    _syncingFanDeviceId = device.id;
    final idx = _devices.indexWhere((d) => d.id == device.id);
    if (idx != -1) {
      _devices[idx] = device.copyWith(fan: fanState);
      notifyListeners();
    }

    try {
      final dispatchResult = await TelemetryService.instance.sendSmartConfig(
        deviceId: device.id,
        serialNumber: device.serialNumber,
        tdsRange: device.tdsRange ?? 200,
        fanState: fanState,
        rawCommand: command,
      );

      if (!dispatchResult.success) {
        // Dispatch failed: revert optimistic update
        final revertIdx = _devices.indexWhere((d) => d.id == device.id);
        if (revertIdx != -1) {
          _devices[revertIdx] = device.copyWith(fan: previousFan);
          notifyListeners();
        }
        return dispatchResult;
      }

      // Check for hardware confirmation
      bool hardwareConfirmed = (dispatchResult.transport == 'ble');
      if (!hardwareConfirmed) {
        hardwareConfirmed = await TelemetryService.instance.waitForHardwareConfirmation(
          deviceId: device.id,
          expectedFan: fanState,
          timeout: const Duration(seconds: 10),
          pollInterval: const Duration(seconds: 3),
        );
      }

      if (hardwareConfirmed) {
        final confirmedDevice = device.copyWith(fan: fanState);
        final confirmIdx = _devices.indexWhere((d) => d.id == device.id);
        if (confirmIdx != -1) {
          _devices[confirmIdx] = confirmedDevice;
        }
        final userPhone = UserSession().rawPhone;
        final userKey = userPhone.isNotEmpty ? userPhone : UserSession().email;
        await DeviceStorageService.saveDevices(_devices, userKey: userKey);
        TelemetryService.instance.clearPendingFan(device.id);
        notifyListeners();
      } else {
        // Hardware did not confirm within timeout: revert
        final revertIdx = _devices.indexWhere((d) => d.id == device.id);
        if (revertIdx != -1) {
          _devices[revertIdx] = device.copyWith(fan: previousFan);
          notifyListeners();
        }
      }

      return dispatchResult;
    } catch (e) {
      final revertIdx = _devices.indexWhere((d) => d.id == device.id);
      if (revertIdx != -1) {
        _devices[revertIdx] = device.copyWith(fan: previousFan);
        notifyListeners();
      }
      return CommandDispatchResult(
        success: false,
        transport: 'mqtt',
        message: e.toString(),
      );
    } finally {
      _isSendingFanCommand = false;
      _syncingFanDeviceId = null;
      notifyListeners();
    }
  }

  /// Sends TDS Range configuration command
  Future<CommandDispatchResult> sendTdsCommand(DeviceModel device, int newTds) async {
    final previousTds = device.tdsRange ?? 200;
    final int clampedTds = newTds >= 991 ? 1000 : newTds;
    final currentFan = device.fan?.toLowerCase().trim() ?? 'enable';

    _isSendingTdsCommand = true;
    final idx = _devices.indexWhere((d) => d.id == device.id);
    if (idx != -1) {
      _devices[idx] = device.copyWith(tdsRange: clampedTds);
      notifyListeners();
    }

    try {
      final dispatchResult = await TelemetryService.instance.sendSmartConfig(
        deviceId: device.id,
        serialNumber: device.serialNumber,
        tdsRange: clampedTds,
        fanState: currentFan,
        rawCommand: 'T,$clampedTds',
      );

      if (!dispatchResult.success) {
        final revertIdx = _devices.indexWhere((d) => d.id == device.id);
        if (revertIdx != -1) {
          _devices[revertIdx] = device.copyWith(tdsRange: previousTds);
          notifyListeners();
        }
        return dispatchResult;
      }

      final confirmedDevice = device.copyWith(tdsRange: clampedTds);
      final confirmIdx = _devices.indexWhere((d) => d.id == device.id);
      if (confirmIdx != -1) {
        _devices[confirmIdx] = confirmedDevice;
      }
      final userPhone = UserSession().rawPhone;
      final userKey = userPhone.isNotEmpty ? userPhone : UserSession().email;
      await DeviceStorageService.saveDevices(_devices, userKey: userKey);
      TelemetryService.instance.clearPendingTds(device.id);
      notifyListeners();

      return dispatchResult;
    } catch (e) {
      final revertIdx = _devices.indexWhere((d) => d.id == device.id);
      if (revertIdx != -1) {
        _devices[revertIdx] = device.copyWith(tdsRange: previousTds);
        notifyListeners();
      }
      return CommandDispatchResult(
        success: false,
        transport: 'mqtt',
        message: e.toString(),
      );
    } finally {
      _isSendingTdsCommand = false;
      notifyListeners();
    }
  }

  /// Adds a newly paired device to the local list and persists it
  Future<void> addDevice(DeviceModel device) async {
    final existingIndex = _devices.indexWhere((d) =>
        d.id == device.id ||
        (d.serialNumber.isNotEmpty && d.serialNumber == device.serialNumber));
    if (existingIndex >= 0) {
      _devices[existingIndex] = device;
    } else {
      _devices.add(device);
      _selectedDeviceIndex = _devices.length - 1;
    }
    final userPhone = UserSession().rawPhone;
    final userKey = userPhone.isNotEmpty ? userPhone : UserSession().email;
    await DeviceStorageService.saveDevices(_devices, userKey: userKey);
    notifyListeners();
  }

  /// Removes a device and updates persistence
  Future<void> removeDevice(String deviceId) async {
    _devices.removeWhere((d) => d.id == deviceId);
    if (_selectedDeviceIndex >= _devices.length) {
      _selectedDeviceIndex = _devices.isNotEmpty ? _devices.length - 1 : 0;
    }
    final userPhone = UserSession().rawPhone;
    final userKey = userPhone.isNotEmpty ? userPhone : UserSession().email;
    await DeviceStorageService.saveDevices(_devices, userKey: userKey);
    notifyListeners();
  }

  @override
  void dispose() {
    stopTelemetryTimer();
    super.dispose();
  }
}
