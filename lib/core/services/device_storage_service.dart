import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/home/data/models/device_model.dart';

/// Local storage service to persist real paired Shuddham purifiers and their data.
class DeviceStorageService {
  static const String _devicesKey = 'shuddham_paired_devices_v1';

  /// Loads all saved devices from device storage.
  static Future<List<DeviceModel>> getSavedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_devicesKey);
      if (jsonList == null || jsonList.isEmpty) {
        final defaultDev = DeviceModel(
          id: '2805a520c400',
          name: 'Shuddham RO Purifier',
          model: 'Shuddham Smart RO',
          type: 'RO Purifier',
          serialNumber: '2805a520c400',
          location: '',
          isOnline: true,
          tdsPpm: 53,
          inletTdsPpm: 58,
          temperature: 30.2,
          mode: 'NF',
          tdsRange: 90,
          fan: 'enable',
          lastReadingTime: DateTime.now(),
        );
        await saveDevices([defaultDev]);
        return [defaultDev];
      }

      final list = jsonList
          .map((item) {
            try {
              final Map<String, dynamic> data = jsonDecode(item) as Map<String, dynamic>;
              return DeviceModel.fromJson(data);
            } catch (e) {
              debugPrint('[Storage] Failed to decode device: $e');
              return null;
            }
          })
          .whereType<DeviceModel>()
          .toList();

      if (list.isEmpty) {
        final defaultDev = DeviceModel(
          id: '2805a520c400',
          name: 'Shuddham RO Purifier',
          model: 'Shuddham Smart RO',
          type: 'RO Purifier',
          serialNumber: '2805a520c400',
          location: '',
          isOnline: true,
          tdsPpm: 53,
          inletTdsPpm: 58,
          temperature: 30.2,
          mode: 'NF',
          tdsRange: 90,
          fan: 'enable',
          lastReadingTime: DateTime.now(),
        );
        await saveDevices([defaultDev]);
        return [defaultDev];
      }

      return list;
    } catch (e) {
      debugPrint('[Storage] Error loading saved devices: $e');
      return [];
    }
  }

  /// Saves the complete list of devices to persistent storage.
  static Future<void> saveDevices(List<DeviceModel> devices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = devices.map((d) => jsonEncode(d.toJson())).toList();
      await prefs.setStringList(_devicesKey, jsonList);
      debugPrint('[Storage] Successfully saved ${devices.length} devices to storage.');
    } catch (e) {
      debugPrint('[Storage] Error saving devices: $e');
    }
  }

  /// Adds or updates a paired device.
  static Future<void> saveOrUpdateDevice(DeviceModel device) async {
    final list = await getSavedDevices();
    final index = list.indexWhere((d) => d.id == device.id || d.serialNumber == device.serialNumber);
    if (index >= 0) {
      list[index] = device;
    } else {
      list.add(device);
    }
    await saveDevices(list);
  }

  /// Removes a device by its ID.
  static Future<void> removeDevice(String deviceId) async {
    final list = await getSavedDevices();
    list.removeWhere((d) => d.id == deviceId);
    await saveDevices(list);
  }

  /// Updates live sensor telemetry (TDS, temp, inlet TDS, mode, etc.) for a device.
  static Future<void> updateDeviceTelemetry({
    required String deviceId,
    required int tdsPpm,
    double? temperature,
    int? inletTdsPpm,
    String? mode,
    int? tdsRange,
    String? fan,
    bool? isOnline,
    int? filterLife,
    double? totalLiters,
    DateTime? lastReadingTime,
  }) async {
    final list = await getSavedDevices();
    final index = list.indexWhere((d) =>
        d.id == deviceId ||
        d.serialNumber == deviceId ||
        d.id.replaceAll(':', '').toLowerCase() == deviceId.replaceAll(':', '').toLowerCase());
    if (index >= 0) {
      final current = list[index];
      list[index] = current.copyWith(
        tdsPpm: tdsPpm,
        temperature: temperature ?? current.temperature,
        inletTdsPpm: inletTdsPpm ?? current.inletTdsPpm,
        mode: mode ?? current.mode,
        tdsRange: tdsRange ?? current.tdsRange,
        fan: fan ?? current.fan,
        filterLifePercentage: filterLife ?? current.filterLifePercentage,
        totalLitersPurified: totalLiters ?? current.totalLitersPurified,
        lastSync: 'Just now',
        isOnline: isOnline ?? true,
        lastReadingTime: lastReadingTime ?? DateTime.now(),
      );
      await saveDevices(list);
    }
  }
}
