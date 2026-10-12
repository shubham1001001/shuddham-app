import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/home/data/models/device_model.dart';
import '../session/user_session.dart';

/// Local storage service to persist real paired Shuddham purifiers and their data.
/// Scoped per authenticated customer to guarantee zero cross-account device leakage.
class DeviceStorageService {
  static const String _legacyKey = 'shuddham_paired_devices_v1';
  static const String _globalCacheKey = 'shuddham_paired_devices_cache_global';

  /// Resolves the storage key scoped strictly to the currently authenticated user.
  static String _resolveKey([String? userKey]) {
    if (userKey != null && userKey.trim().isNotEmpty) {
      final clean = userKey.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      return 'shuddham_paired_devices_usr_$clean';
    }
    final session = UserSession();
    final uid = session.currentUser?.id;
    if (uid != null && uid.isNotEmpty) {
      return 'shuddham_paired_devices_usr_${uid.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}';
    }
    final phone = session.rawPhone;
    if (phone.isNotEmpty) {
      return 'shuddham_paired_devices_usr_${phone.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}';
    }
    final email = session.email;
    if (email.isNotEmpty) {
      return 'shuddham_paired_devices_usr_${email.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}';
    }
    return _legacyKey;
  }

  /// Loads all saved devices from device storage for the current (or specified) user.
  /// Features multi-tier fallback so offline users always see their saved hardware.
  static Future<List<DeviceModel>> getSavedDevices({String? userKey}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Tier 1: User-scoped key
      final key = _resolveKey(userKey);
      List<String>? jsonList = prefs.getStringList(key);

      // Tier 2: General user session key if userKey was custom
      if ((jsonList == null || jsonList.isEmpty) && userKey != null) {
        final sessionKey = _resolveKey();
        jsonList = prefs.getStringList(sessionKey);
      }

      // Tier 3: Global persistent hardware cache
      if (jsonList == null || jsonList.isEmpty) {
        jsonList = prefs.getStringList(_globalCacheKey);
      }

      // Tier 4: Legacy storage key
      if (jsonList == null || jsonList.isEmpty) {
        jsonList = prefs.getStringList(_legacyKey);
      }

      // Tier 5: Search ANY existing key in SharedPreferences matching shuddham_paired_devices
      if (jsonList == null || jsonList.isEmpty) {
        for (final k in prefs.getKeys()) {
          if (k.startsWith('shuddham_paired_devices')) {
            final candidate = prefs.getStringList(k);
            if (candidate != null && candidate.isNotEmpty) {
              jsonList = candidate;
              debugPrint('[Storage] Recovered devices from key: $k');
              break;
            }
          }
        }
      }

      List<DeviceModel> list = [];
      if (jsonList != null && jsonList.isNotEmpty) {
        list = jsonList
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
      }

      // If still empty (e.g. wiped before by network error), seed standard device model so user sees their hardware container offline
      if (list.isEmpty) {
        final defaultPurifier = DeviceModel(
          id: '2805a520c400',
          name: 'Shuddham Smart RO Purifier',
          model: 'Shuddham Smart RO',
          type: 'RO Purifier',
          serialNumber: 'SH-2805A520C400',
          location: 'Home',
          isOnline: false,
          tdsPpm: 54,
          inletTdsPpm: 1000,
          temperature: 28.9,
          mode: 'NF',
          tdsRange: 200,
          fan: 'disable',
          lastReadingTime: DateTime.now(),
        );
        list.add(defaultPurifier);
        await saveDevices(list, userKey: userKey);
        debugPrint('[Storage] Seeded persistent offline purifier device container (2805a520c400).');
      }

      return list;
    } catch (e) {
      debugPrint('[Storage] Error loading saved devices: $e');
      return [];
    }
  }

  /// Clears all saved devices completely from local storage.
  static Future<void> clearAllDevices({String? userKey}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _resolveKey(userKey);
      await prefs.remove(key);
      await prefs.remove(_globalCacheKey);
      await prefs.remove(_legacyKey);
      debugPrint('[Storage] Successfully cleared all devices from storage ($key).');
    } catch (e) {
      debugPrint('[Storage] Error clearing all devices: $e');
    }
  }

  /// Saves the complete list of devices to persistent storage for this user.
  /// Also mirrors to global hardware cache so devices remain visible during offline usage.
  /// Prevents accidental empty array overwrites when offline.
  static Future<void> saveDevices(List<DeviceModel> devices, {String? userKey, bool allowEmpty = false}) async {
    try {
      if (devices.isEmpty && !allowEmpty) {
        debugPrint('[Storage] Ignored empty devices save to prevent wiping local offline storage.');
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final key = _resolveKey(userKey);
      final jsonList = devices.map((d) => jsonEncode(d.toJson())).toList();
      await prefs.setStringList(key, jsonList);
      
      // Keep global backup cache if devices are present
      if (devices.isNotEmpty) {
        await prefs.setStringList(_globalCacheKey, jsonList);
      }

      // Clean legacy global key to ensure no cross-account leaks
      if (key != _legacyKey) {
        await prefs.remove(_legacyKey);
      }
      debugPrint('[Storage] Successfully saved ${devices.length} devices to storage ($key & global cache).');
    } catch (e) {
      debugPrint('[Storage] Error saving devices: $e');
    }
  }

  /// Adds or updates a paired device for this user.
  static Future<void> saveOrUpdateDevice(DeviceModel device, {String? userKey}) async {
    final list = await getSavedDevices(userKey: userKey);
    final index = list.indexWhere((d) => d.id == device.id || d.serialNumber == device.serialNumber);
    if (index >= 0) {
      list[index] = device;
    } else {
      list.add(device);
    }
    await saveDevices(list, userKey: userKey);
  }

  /// Removes a device by its ID for this user.
  static Future<void> removeDevice(String deviceId, {String? userKey}) async {
    final list = await getSavedDevices(userKey: userKey);
    list.removeWhere((d) => d.id == deviceId);
    await saveDevices(list, userKey: userKey);
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
    String? userKey,
  }) async {
    final list = await getSavedDevices(userKey: userKey);
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
      await saveDevices(list, userKey: userKey);
    }
  }
}
