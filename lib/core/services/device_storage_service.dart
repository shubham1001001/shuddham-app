import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/home/data/models/device_model.dart';
import '../session/user_session.dart';
import '../utils/app_logger.dart';

/// Local storage service to persist real paired Shuddham purifiers and their data.
/// Scoped per authenticated customer to guarantee zero cross-account device leakage.
class DeviceStorageService {
  static const String _legacyKey = 'shuddham_paired_devices_v1';
  static const String _globalCacheKey = 'shuddham_paired_devices_cache_global';

  /// Default baseline paired purifier device model with verified last real hardware readings.
  static DeviceModel get defaultPurifier => DeviceModel(
    id: '2805a520c400',
    name: 'Shuddham',
    model: 'Shuddham Smart RO Purifier',
    type: 'RO Purifier',
    serialNumber: 'SH-2805A520C400',
    location: 'Home',
    isOnline: true,
    tdsPpm: 52,
    inletTdsPpm: 58,
    temperature: 25.0,
    mode: 'NF',
    tdsRange: 200,
    fan: 'enable',
    lastReadingTime: DateTime(2026, 10, 12, 20, 37, 55),
  );

  /// Helper to decode SharedPreferences entries whether saved as StringList or raw JSON string
  static List<String>? _getStringListOrJson(SharedPreferences prefs, String key) {
    try {
      final list = prefs.getStringList(key);
      if (list != null && list.isNotEmpty) return list;
    } catch (_) {}

    try {
      final raw = prefs.getString(key);
      if (raw != null && raw.trim().isNotEmpty) {
        final trimmed = raw.trim();
        if (trimmed.startsWith('VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!')) {
          final jsonPart = trimmed.substring('VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!'.length);
          final decoded = jsonDecode(jsonPart);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
        } else if (trimmed.startsWith('[')) {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            return decoded.map((e) => e is String ? e : jsonEncode(e)).toList();
          }
        } else if (trimmed.startsWith('{')) {
          return [trimmed];
        }
      }
    } catch (_) {}
    return null;
  }

  /// Resolves the storage key scoped strictly to the currently authenticated user.
  /// Returns null if no authenticated user session exists.
  static String? _resolveKey([String? userKey]) {
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
    return null;
  }

  /// Purges any legacy global caches to prevent cross-account hardware leaks.
  static Future<void> purgeGlobalCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_globalCacheKey);
      await prefs.remove('shuddham_last_fetched_device_backup');
      await prefs.remove(_legacyKey);
    } catch (_) {}
  }

  /// Clean up caches when an authenticated user logs out.
  static Future<void> onUserLogout() async {
    await purgeGlobalCaches();
  }

  /// Loads all saved devices from device storage strictly for the current (or specified) user.
  /// Guarantees zero cross-account device visibility.
  static Future<List<DeviceModel>> getSavedDevices({String? userKey}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clean up legacy global cache keys so they never leak between users
      await purgeGlobalCaches();

      final key = _resolveKey(userKey);
      if (key == null) {
        // No authenticated user session - return empty
        return [];
      }

      // Check user-scoped storage key
      List<String>? jsonList = _getStringListOrJson(prefs, key);

      // Also check this user's alternative session aliases (phone, id, email)
      final session = UserSession();
      if ((jsonList == null || jsonList.isEmpty) && session.currentUser?.id != null && session.currentUser!.id.isNotEmpty) {
        final idKey = _resolveKey(session.currentUser!.id);
        if (idKey != null && idKey != key) {
          jsonList = _getStringListOrJson(prefs, idKey);
        }
      }
      if ((jsonList == null || jsonList.isEmpty) && session.rawPhone.isNotEmpty) {
        final phoneKey = _resolveKey(session.rawPhone);
        if (phoneKey != null && phoneKey != key) {
          jsonList = _getStringListOrJson(prefs, phoneKey);
        }
      }
      if ((jsonList == null || jsonList.isEmpty) && session.email.isNotEmpty) {
        final emailKey = _resolveKey(session.email);
        if (emailKey != null && emailKey != key) {
          jsonList = _getStringListOrJson(prefs, emailKey);
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

      AppLogger.dataSourceLoaded(
        source: "💾 LOCAL STORAGE (USER-SCOPED)",
        dataType: "Persistent Purifier Hardware Container",
        count: list.length,
        storageKey: key,
        details: list.isNotEmpty
            ? "Loaded user-assigned hardware: Pure TDS ${list.first.tdsPpm} PPM, Raw TDS ${list.first.inletTdsPpm ?? '--'} PPM, Fan ${list.first.fan ?? '--'}."
            : "No devices found in local storage for user $key.",
      );

      return list;
    } catch (e) {
      debugPrint('[Storage] Error loading saved devices: $e');
      return [];
    }
  }

  /// Clears user-scoped saved devices if explicitly requested.
  static Future<void> clearAllDevices({String? userKey}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _resolveKey(userKey);
      if (key != null) {
        await prefs.remove(key);
      }
      final session = UserSession();
      if (session.currentUser?.id != null) {
        final idKey = _resolveKey(session.currentUser!.id);
        if (idKey != null) await prefs.remove(idKey);
      }
      if (session.rawPhone.isNotEmpty) {
        final phoneKey = _resolveKey(session.rawPhone);
        if (phoneKey != null) await prefs.remove(phoneKey);
      }
      if (session.email.isNotEmpty) {
        final emailKey = _resolveKey(session.email);
        if (emailKey != null) await prefs.remove(emailKey);
      }
      await purgeGlobalCaches();
      debugPrint('[Storage] Completed user-scoped clear request for $userKey.');
    } catch (e) {
      debugPrint('[Storage] Error clearing devices: $e');
    }
  }

  /// Saves the complete list of devices to persistent storage strictly for this user.
  /// Prevents accidental empty array overwrites unless allowEmpty is true.
  static Future<void> saveDevices(List<DeviceModel> devices, {String? userKey, bool allowEmpty = false}) async {
    try {
      if (devices.isEmpty && !allowEmpty) {
        debugPrint('[Storage] Ignored empty devices save to prevent wiping local offline storage.');
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final key = _resolveKey(userKey);
      if (key == null) {
        debugPrint('[Storage] Cannot save devices: No active user session or key specified.');
        return;
      }

      final session = UserSession();
      final idKey = session.currentUser?.id != null && session.currentUser!.id.isNotEmpty
          ? _resolveKey(session.currentUser!.id)
          : null;
      final phoneKey = session.rawPhone.isNotEmpty ? _resolveKey(session.rawPhone) : null;
      final emailKey = session.email.isNotEmpty ? _resolveKey(session.email) : null;

      if (devices.isEmpty && allowEmpty) {
        // Explicit clear for this specific user
        await prefs.remove(key);
        if (idKey != null) await prefs.remove(idKey);
        if (phoneKey != null) await prefs.remove(phoneKey);
        if (emailKey != null) await prefs.remove(emailKey);
        await purgeGlobalCaches();
        debugPrint('[Storage] Cleared all devices for user ($key).');
        return;
      }

      final jsonList = devices.map((d) => jsonEncode(d.toJson())).toList();

      // 1. Save strictly to specified user key
      await prefs.setStringList(key, jsonList);

      // 2. Also save to session-based user keys so lookups by ID, phone, or email all succeed for this user
      if (idKey != null && idKey != key) await prefs.setStringList(idKey, jsonList);
      if (phoneKey != null && phoneKey != key) await prefs.setStringList(phoneKey, jsonList);
      if (emailKey != null && emailKey != key) await prefs.setStringList(emailKey, jsonList);
      
      // 3. Purge any global keys so other accounts on this phone NEVER see this user's devices
      await purgeGlobalCaches();

      debugPrint('[Storage] Successfully saved ${devices.length} devices to user-scoped storage ($key).');
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
    list.removeWhere((d) =>
        d.id == deviceId ||
        d.serialNumber == deviceId ||
        d.id.replaceAll(':', '').toLowerCase() == deviceId.replaceAll(':', '').toLowerCase());
    await saveDevices(list, userKey: userKey, allowEmpty: true);
    if (list.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final key = _resolveKey(userKey);
      if (key != null) await prefs.remove(key);
      final session = UserSession();
      if (session.currentUser?.id != null) {
        final idKey = _resolveKey(session.currentUser!.id);
        if (idKey != null) await prefs.remove(idKey);
      }
      if (session.rawPhone.isNotEmpty) {
        final phoneKey = _resolveKey(session.rawPhone);
        if (phoneKey != null) await prefs.remove(phoneKey);
      }
      if (session.email.isNotEmpty) {
        final emailKey = _resolveKey(session.email);
        if (emailKey != null) await prefs.remove(emailKey);
      }
      await purgeGlobalCaches();
      debugPrint('[Storage] Device $deviceId removed. User device list is now empty.');
    }
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
