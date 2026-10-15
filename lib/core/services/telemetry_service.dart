import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants/api_endpoints.dart';
import '../services/device_storage_service.dart';
import '../utils/app_logger.dart';
import '../session/user_session.dart';
import '../../features/home/data/models/device_model.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'provisioning_service.dart';

class CommandDispatchResult {
  final bool success;
  final String transport; // 'mqtt' or 'ble'
  final String message;

  CommandDispatchResult({
    required this.success,
    required this.transport,
    required this.message,
  });
}

/// Service responsible for fetching live sensor readings (TDS, temperature, mode)
/// from the AWS IoT telemetry backend (http://3.88.13.76:4000/api/telemetry).
class TelemetryService {
  TelemetryService._();
  static final TelemetryService instance = TelemetryService._();

  static const String _telemetryUrl = '${ApiEndpoints.liveBaseUrl}/telemetry/latest';

  // In-flight command tracking to preserve local state until DB updates with hardware response
  static final Map<String, DateTime> _pendingFanCommandTimes = {};
  static final Map<String, String> _pendingFanStates = {};
  static final Map<String, DateTime> _pendingTdsCommandTimes = {};
  static final Map<String, int> _pendingTdsRanges = {};

  void clearPendingTds(String deviceId) {
    final clean = _cleanMac(deviceId);
    _pendingTdsCommandTimes.remove(clean);
    _pendingTdsRanges.remove(clean);
  }

  void clearPendingFan(String deviceId) {
    final clean = _cleanMac(deviceId);
    _pendingFanCommandTimes.remove(clean);
    _pendingFanStates.remove(clean);
  }

  /// Fetches latest telemetry records for all purifiers from the cloud.
  Future<List<Map<String, dynamic>>> fetchAllTelemetry() async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(_telemetryUrl));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final rawBody = await response.transform(utf8.decoder).join();
        final body = jsonDecode(rawBody);
        if (body is Map && body['success'] == true && body['data'] is List) {
          final list = (body['data'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
          return list;
        }
      }
    } catch (e) {
      debugPrint('[Telemetry] Failed to fetch live telemetry: $e');
    } finally {
      client?.close(force: true);
    }
    return [];
  }

  /// Fetches purifiers officially assigned & installed for this customer from the cloud.
  /// Matches strictly against customer phone, email, customerId, or authenticated Bearer token.
  /// Returns `List<DeviceModel>` (which may be empty [] if user has no assigned devices) on success,
  /// or null if the network is offline or request fails.
  Future<List<DeviceModel>?> fetchCustomerDevices({
    String? userPhone,
    String? email,
    String? customerId,
    String? token,
  }) async {
    final phone = (userPhone ?? '').replaceAll(RegExp(r'\D'), '');
    final mail = (email ?? '').trim();
    final cid = (customerId ?? '').trim();
    final jwt = (token != null && token.isNotEmpty) ? token : UserSession().token;

    if (phone.isEmpty && mail.isEmpty && cid.isEmpty && jwt.isEmpty) {
      return null;
    }

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);

      final queryParams = <String, String>{};
      if (phone.isNotEmpty) queryParams['phone'] = phone;
      if (mail.isNotEmpty) queryParams['email'] = mail;
      if (cid.isNotEmpty) queryParams['customerId'] = cid;

      final uri = Uri.parse('${ApiEndpoints.liveBaseUrl}/customer/devices').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (jwt.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $jwt');
      }
      final response = await request.close().timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final rawBody = await response.transform(utf8.decoder).join();
        final body = jsonDecode(rawBody);
        if (body is Map && body['success'] == true && body['data'] is List) {
          final list = (body['data'] as List)
              .whereType<Map<String, dynamic>>()
              .map((d) {
                try {
                  return DeviceModel.fromJson(d);
                } catch (e) {
                  debugPrint('[Telemetry] Failed to parse customer device: $e');
                  return null;
                }
              })
              .whereType<DeviceModel>()
              .toList();
          return list;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[Telemetry] Failed to fetch customer assigned devices: $e');
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  static String? _lastLoggedSource;
  static final Map<String, String> _lastLoggedSignatures = {};
  static DateTime? _lastFullLogTime;

  /// Syncs an active list of [DeviceModel] instances with real-time sensor data from the backend.
  /// Updates local persistent storage with the new sensor readings.
  Future<List<DeviceModel>> syncDevices(List<DeviceModel> devices) async {
    if (devices.isEmpty) return [];

    final telemetryRecords = await fetchAllTelemetry();
    final mobileCheckNow = DateTime.now();
    final isCloud = telemetryRecords.isNotEmpty;
    final currentSource = isCloud ? "🌐 LIVE CLOUD API" : "💾 LOCAL STORAGE (OFFLINE CACHE)";

    // Only log data source change when the source switches (e.g. cloud -> offline cache)
    if (_lastLoggedSource != currentSource) {
      _lastLoggedSource = currentSource;
      AppLogger.dataSourceLoaded(
        source: currentSource,
        dataType: "Sensor Telemetry (TDS / Temp / Relay)",
        count: isCloud ? telemetryRecords.length : devices.length,
        endpoint: isCloud ? _telemetryUrl : null,
        details: isCloud
            ? "Connected to live IoT cloud backend."
            : "Live cloud unreachable. Displaying persistent storage cache.",
      );
    }

    if (telemetryRecords.isEmpty) {
      return List<DeviceModel>.from(devices);
    }

    final bool shouldHeartbeat = _lastFullLogTime == null ||
        mobileCheckNow.difference(_lastFullLogTime!).inSeconds >= 60;

    final List<DeviceModel> updatedList = [];
    bool hasChanges = false;

    for (final dev in devices) {
      final match = findMatchingRecord(dev, telemetryRecords);
      if (match != null) {
        final updated = applyTelemetryToDevice(dev, match);
        updatedList.add(updated);
        final signature = '${updated.id}_${updated.tdsPpm}_${updated.inletTdsPpm}_${updated.temperature}_${updated.fan}_${updated.tdsRange}_${updated.isOnline}_${updated.lastReadingTime}';
        final isStateChanged = _lastLoggedSignatures[updated.id] != signature;
        if (isStateChanged) {
          hasChanges = true;
        }

        if (isStateChanged || shouldHeartbeat) {
          _lastLoggedSignatures[updated.id] = signature;
          _lastFullLogTime = mobileCheckNow;

          final devIdClean = _cleanMac(dev.id);
          final rawDbFan = match['fan']?.toString();
          final rawDbTdsRange = match['tds_range'] != null ? int.tryParse(match['tds_range'].toString()) : null;
          final pendingFan = _pendingFanStates[devIdClean];
          final pendingTds = _pendingTdsRanges[devIdClean];

          AppLogger.telemetryReceived(
            deviceId: updated.id,
            tds1: updated.inletTdsPpm,
            tds2: updated.tdsPpm,
            temp: updated.temperature,
            mode: updated.mode,
            fan: updated.fan,
            rawHardwareFan: rawDbFan,
            pendingExpectedFan: pendingFan,
            tdsRange: updated.tdsRange,
            rawHardwareTdsRange: rawDbTdsRange,
            pendingExpectedTdsRange: pendingTds,
            isOnline: updated.isOnline,
            source: "🌐 LIVE CLOUD API",
            mobileCheckTime: mobileCheckNow,
            backendReadingTime: updated.lastReadingTime,
            rawBackendTs: match['ts']?.toString() ?? match['last_updated']?.toString(),
            isChanged: isStateChanged,
          );
        }
      } else {
        updatedList.add(dev);
      }
    }

    if (hasChanges) {
      await DeviceStorageService.saveDevices(updatedList);
    }

    return List<DeviceModel>.from(updatedList);
  }

  /// Actively polls the IoT backend to check if the purifier hardware has reported
  /// the expected state (e.g. fanState or tdsRange) following a command.
  /// Returns `true` if hardware confirms within [timeout] (default 150s for ESP32's ~2min cycle), or `false` on timeout.
  Future<bool> waitForHardwareConfirmation({
    required String deviceId,
    String? expectedFan,
    int? expectedTdsRange,
    Duration timeout = const Duration(seconds: 30), // Snappy timeout for responsive UI
    Duration pollInterval = const Duration(seconds: 6),
  }) async {
    final cleanDevId = _cleanMac(deviceId);
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < timeout) {
      await Future.delayed(pollInterval);
      try {
        final records = await fetchAllTelemetry();
        for (final r in records) {
          final rId = _cleanMac(r['dev_Id'] ?? r['dev_id'] ?? r['devId'] ?? '');
          final matches = rId == cleanDevId ||
              (rId.length >= 10 && cleanDevId.length >= 10 && rId.substring(0, 10) == cleanDevId.substring(0, 10));

          if (matches) {
            bool fanMatches = true;
            if (expectedFan != null) {
              final actualFan = (r['fan']?.toString() ?? '').toLowerCase().trim();
              fanMatches = (actualFan == expectedFan.toLowerCase().trim());
            }

            bool tdsMatches = true;
            if (expectedTdsRange != null) {
              final actualTds = int.tryParse(r['tds_range']?.toString() ?? '');
              tdsMatches = (actualTds == expectedTdsRange);
            }

            if (fanMatches && tdsMatches) {
              _pendingFanCommandTimes.remove(cleanDevId);
              _pendingFanStates.remove(cleanDevId);
              _pendingTdsCommandTimes.remove(cleanDevId);
              _pendingTdsRanges.remove(cleanDevId);
              debugPrint('✅ [Hardware Verified] $cleanDevId confirmed state: fan=$expectedFan, tds=$expectedTdsRange');
              return true;
            }
          }
        }
      } catch (e) {
        debugPrint('[Telemetry] Hardware polling check error: $e');
      }
    }

    // Timed out: hardware did not confirm in time
    _pendingFanCommandTimes.remove(cleanDevId);
    _pendingFanStates.remove(cleanDevId);
    _pendingTdsCommandTimes.remove(cleanDevId);
    _pendingTdsRanges.remove(cleanDevId);
    debugPrint('⏱️ [Hardware Timeout] $cleanDevId did not confirm within ${timeout.inSeconds}s');
    return false;
  }

  /// Matches a DeviceModel against telemetry payloads using MAC address heuristics.
  Map<String, dynamic>? findMatchingRecord(
    DeviceModel device,
    List<Map<String, dynamic>> records,
  ) {
    final devIdClean = _cleanMac(device.id);
    final serialClean = _cleanMac(device.serialNumber);
    final modelClean = _cleanMac(device.model);

    // 1. Direct or partial ID match
    for (final r in records) {
      final rDevId = _cleanMac(r['dev_id']?.toString() ?? '');
      if (rDevId.isEmpty) continue;

      if (rDevId == devIdClean || rDevId == serialClean || rDevId == modelClean) {
        return r;
      }

      // Check substring containment
      if (devIdClean.contains(rDevId) || rDevId.contains(devIdClean)) {
        return r;
      }

      // Prefix match for ESP32: Wi-Fi STA MAC (e.g. 2805a520c400) vs BLE MAC (2805a520c402)
      // The first 10 hex characters represent the same physical board!
      if (rDevId.length >= 10 && devIdClean.length >= 10) {
        if (rDevId.substring(0, 10) == devIdClean.substring(0, 10)) {
          return r;
        }
      }
      if (rDevId.length >= 10 && serialClean.length >= 10) {
        if (rDevId.substring(0, 10) == serialClean.substring(0, 10)) {
          return r;
        }
      }
    }

    return null;
  }

  /// Updates a DeviceModel with real sensor readings from a telemetry record.
  DeviceModel applyTelemetryToDevice(DeviceModel dev, Map<String, dynamic> r) {
    final rawDevId = r['dev_id']?.toString() ?? r['dev_Id']?.toString();
    if (rawDevId != null && rawDevId.isNotEmpty) {
      _lastHardwareDevId = rawDevId;
    }

    // Outlet TDS (purified water) -> tds2 or tds1
    final rawTds2 = r['tds2'];
    final rawTds1 = r['tds1'];
    int? outletTds;
    int? inletTds;

    if (rawTds2 != null) outletTds = int.tryParse(rawTds2.toString());
    if (rawTds1 != null) inletTds = int.tryParse(rawTds1.toString());

    // If only one TDS value is given, use it
    outletTds ??= inletTds ?? dev.tdsPpm;
    inletTds ??= dev.inletTdsPpm;

    // Water temperature in Celsius
    final rawTemp = r['temp'];
    double? temp;
    if (rawTemp != null) {
      temp = double.tryParse(rawTemp.toString());
    }

    // Mode ('NF' or 'RO')
    final mode = r['mode']?.toString() ?? dev.mode;

    // Timestamp
    final tsStr = r['ts']?.toString() ?? r['last_updated']?.toString();
    DateTime? readingTime;
    if (tsStr != null) {
      DateTime? parsed = DateTime.tryParse(tsStr);
      if (parsed == null && tsStr.contains('/')) {
        try {
          final parts = tsStr.trim().split(' ');
          final dateParts = parts[0].split('/');
          if (dateParts.length == 3) {
            final day = int.parse(dateParts[0]);
            final month = int.parse(dateParts[1]);
            final year = int.parse(dateParts[2]);
            int hour = 0, minute = 0, second = 0;
            if (parts.length > 1) {
              final timeParts = parts[1].split(':');
              if (timeParts.isNotEmpty) hour = int.parse(timeParts[0]);
              if (timeParts.length > 1) minute = int.parse(timeParts[1]);
              if (timeParts.length > 2) second = int.parse(timeParts[2].split('.')[0]);
            }
            parsed = DateTime(year, month, day, hour, minute, second);
          }
        } catch (_) {}
      }
      if (parsed != null) {
        readingTime = parsed.isUtc ? parsed.toLocal() : parsed;
      }
    }

    // Online status:
    // 1. Explicit status string from backend/LWT ('offline' -> false)
    // 2. Staleness check: ESP32 sends telemetry every ~2 minutes.
    //    If last packet is older than 5 minutes, mark offline.
    final statusStr = (r['status']?.toString() ?? 'online').toLowerCase();
    bool isOnline = statusStr == 'online';
    if (isOnline && readingTime != null) {
      final stalenessMinutes = DateTime.now().difference(readingTime).inMinutes;
      if (stalenessMinutes >= 5) {
        isOnline = false;
      }
    }

    final devIdClean = _cleanMac(dev.id);

    // TDS range: DB verified response or local pending state
    final pendingTdsTime = _pendingTdsCommandTimes[devIdClean];
    final pendingTds = _pendingTdsRanges[devIdClean];
    int? tdsRange;
    if (pendingTdsTime != null && pendingTds != null) {
      if (readingTime != null && readingTime.isAfter(pendingTdsTime)) {
        // Hardware has responded and DB is updated!
        final rawRange = r['tds_range'];
        tdsRange = rawRange != null ? int.tryParse(rawRange.toString()) : pendingTds;
        _pendingTdsCommandTimes.remove(devIdClean);
        _pendingTdsRanges.remove(devIdClean);
      } else if (DateTime.now().difference(pendingTdsTime).inSeconds < 180) {
        // Awaiting hardware verification — hold for up to 3 minutes for ESP32's ~2 min cycle
        tdsRange = dev.tdsRange ?? pendingTds;
      } else {
        final rawRange = r['tds_range'];
        tdsRange = rawRange != null ? int.tryParse(rawRange.toString()) : dev.tdsRange;
        _pendingTdsCommandTimes.remove(devIdClean);
        _pendingTdsRanges.remove(devIdClean);
      }
    } else {
      final rawRange = r['tds_range'];
      tdsRange = rawRange != null ? int.tryParse(rawRange.toString()) : dev.tdsRange;
    }

    // Fan status: DB verified response or local pending state
    final pendingFanTime = _pendingFanCommandTimes[devIdClean];
    final pendingFan = _pendingFanStates[devIdClean];
    String? fan;
    if (pendingFanTime != null && pendingFan != null) {
      if (readingTime != null && readingTime.isAfter(pendingFanTime)) {
        // Hardware has responded and DB is updated!
        fan = r['fan']?.toString() ?? pendingFan;
        _pendingFanCommandTimes.remove(devIdClean);
        _pendingFanStates.remove(devIdClean);
      } else if (DateTime.now().difference(pendingFanTime).inSeconds < 180) {
        // Awaiting hardware verification — hold for up to 3 minutes for ESP32's ~2 min cycle
        fan = dev.fan ?? pendingFan;
      } else {
        fan = r['fan']?.toString() ?? dev.fan;
        _pendingFanCommandTimes.remove(devIdClean);
        _pendingFanStates.remove(devIdClean);
      }
    } else {
      fan = r['fan']?.toString() ?? dev.fan;
    }

    return dev.copyWith(
      tdsPpm: outletTds,
      inletTdsPpm: inletTds,
      temperature: temp,
      isOnline: isOnline,
      mode: mode,
      tdsRange: tdsRange,
      fan: fan,
      lastSync: 'Just now',
      lastReadingTime: readingTime ?? dev.lastReadingTime ?? DateTime.now(),
    );
  }

  String? _lastHardwareDevId;
  String? get lastHardwareDevId => _lastHardwareDevId;

  /// Smart Hybrid Dispatcher:
  /// 1. Checks if Internet is connected.
  /// 2. If connected: sends JSON {"dev_Id":"...","tds_range":...,"fan":"..."}
  ///    to topic 'Shudhham/tds/v1/SubConfig' via Cloud MQTT Backend.
  /// 3. If NOT connected (or offline): turns on Bluetooth on Android and sends
  ///    command directly to the ESP32 purifier via Bluetooth LE (BLE).
  Future<CommandDispatchResult> sendSmartConfig({
    required String deviceId,
    String? serialNumber,
    required int tdsRange,
    required String fanState,
    String? rawCommand,
  }) async {
    final cleanDevId = _cleanMac(deviceId);
    final cleanSerial = serialNumber != null ? _cleanMac(serialNumber) : '';
    String targetHwId;
    if (cleanDevId.length == 12) {
      targetHwId = cleanDevId.endsWith('02') ? '${cleanDevId.substring(0, 10)}00' : cleanDevId;
    } else if (cleanSerial.length == 12) {
      targetHwId = cleanSerial.endsWith('02') ? '${cleanSerial.substring(0, 10)}00' : cleanSerial;
    } else if (_lastHardwareDevId != null && _lastHardwareDevId!.isNotEmpty) {
      targetHwId = _cleanMac(_lastHardwareDevId!);
    } else {
      targetHwId = cleanDevId.isNotEmpty ? cleanDevId : cleanSerial;
    }

    final int effectiveTds = tdsRange >= 991 ? 1000 : tdsRange;
    final String effectiveFan = fanState.toLowerCase().trim() == 'disable' ? 'disable' : 'enable';
    final String command = rawCommand ?? (effectiveFan == 'disable' ? 'F,0' : (effectiveFan == 'enable' && rawCommand != null ? rawCommand : 'T,$effectiveTds'));

    final subConfigMap = {
      'dev_Id': targetHwId,
      'tds_range': effectiveTds,
      'fan': effectiveFan,
    };
    final subConfigJson = jsonEncode(subConfigMap);

    // Record pending commanded states so local UI preserves them until DB updates with hardware response
    final now = DateTime.now();
    _pendingFanCommandTimes[cleanDevId] = now;
    _pendingFanStates[cleanDevId] = effectiveFan;
    _pendingTdsCommandTimes[cleanDevId] = now;
    _pendingTdsRanges[cleanDevId] = effectiveTds;
    if (targetHwId.isNotEmpty && targetHwId != cleanDevId) {
      _pendingFanCommandTimes[targetHwId] = now;
      _pendingFanStates[targetHwId] = effectiveFan;
      _pendingTdsCommandTimes[targetHwId] = now;
      _pendingTdsRanges[targetHwId] = effectiveTds;
    }

    // ============================================================
    // PRIORITY 1: CLOUD MQTT DISPATCH (INTERNET HIGHEST PRIORITY)
    // ============================================================
    bool isOfflineSocketException = false;
    String lastCloudError = '';

    // Direct Cloud MQTT Attempt (Up to 2 attempts before falling back to Bluetooth)
    final candidateEndpoints = [
      '${ApiEndpoints.liveBaseUrl}/telemetry/publish',
      '${ApiEndpoints.liveBaseUrl}/telemetry/tds',
    ];

    for (int attempt = 1; attempt <= 2; attempt++) {
      HttpClient? client;
      try {
        client = HttpClient()..connectionTimeout = const Duration(seconds: 8);

        bool dispatched = false;
        for (final endpoint in candidateEndpoints) {
          try {
            final req = await client.postUrl(Uri.parse(endpoint));
            req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
            req.headers.set(HttpHeaders.acceptHeader, 'application/json');
            req.add(utf8.encode(jsonEncode({
              'topic': 'Shudhham/tds/v1/SubConfig',
              'message': subConfigMap,
              'deviceId': targetHwId,
              'dev_Id': targetHwId,
              'tds': effectiveTds,
              'tds_range': effectiveTds,
              'fan': effectiveFan,
              'command': command,
            })));

            final resp = await req.close().timeout(const Duration(seconds: 8));
            final respBody = await resp.transform(utf8.decoder).join();

            if (resp.statusCode >= 200 && resp.statusCode < 300) {
              dispatched = true;
              break;
            } else {
              lastCloudError = '$endpoint returned HTTP ${resp.statusCode}: $respBody';
            }
          } catch (endpointErr) {
            lastCloudError = '$endpoint error: $endpointErr';
          }
        }

        if (dispatched) {
          AppLogger.internetPriorityMqttDispatched(
            deviceId: targetHwId,
            topic: 'Shudhham/tds/v1/SubConfig',
            payload: subConfigMap,
            command: command,
            mobileDispatchTime: DateTime.now(),
          );

          String successMessage;
          if (command == 'F,0' || (command.startsWith('F') && effectiveFan == 'disable')) {
            successMessage = 'Disable command sent via Cloud';
          } else if (command == 'F,1' || (command.startsWith('F') && effectiveFan == 'enable')) {
            successMessage = 'Enable command sent via Cloud';
          } else if (command.startsWith('T,')) {
            successMessage = 'TDS command sent via Cloud';
          } else {
            successMessage = 'Command sent via Cloud';
          }

          return CommandDispatchResult(
            success: true,
            transport: 'mqtt',
            message: successMessage,
          );
        }
      } on SocketException catch (se) {
        isOfflineSocketException = true;
        lastCloudError = 'SocketException: ${se.message}';
        debugPrint('[Telemetry] Device offline (SocketException): $lastCloudError');
        break; // Network socket is unreachable -> phone is offline, break to BLE
      } catch (e) {
        lastCloudError = e.toString();
        debugPrint('[Telemetry] Cloud MQTT dispatch attempt $attempt error: $e');
        if (attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } finally {
        client?.close(force: true);
      }
    }

    // ============================================================
    // PRIORITY 2: BLUETOOTH LE (FALLBACK ONLY WHEN OFFLINE)
    // ============================================================
    AppLogger.bleFallbackTriggered(
      reason: isOfflineSocketException 
          ? 'No Internet connection (Phone Offline)' 
          : 'Cloud MQTT unreachable ($lastCloudError)',
      deviceId: targetHwId,
    );

    // Turn on Bluetooth if off on Android
    try {
      if (Platform.isAndroid) {
        final state = await FlutterBluePlus.adapterState.first;
        if (state != BluetoothAdapterState.on) {
          await FlutterBluePlus.turnOn();
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    } catch (e) {
      debugPrint('[BLE] TurnOn Notice: $e');
    }

    final bleOk = await ProvisioningService.instance.sendBleCommandAuto(
      targetDeviceId: targetHwId,
      command: command,
    );

    // Also send JSON config over BLE characteristic if connection succeeded
    try {
      if (bleOk) {
        await ProvisioningService.instance.sendRawCommand(subConfigJson);
      }
    } catch (_) {}

    if (!bleOk) {
      _pendingFanCommandTimes.remove(cleanDevId);
      _pendingFanStates.remove(cleanDevId);
      _pendingTdsCommandTimes.remove(cleanDevId);
      _pendingTdsRanges.remove(cleanDevId);
      if (targetHwId.isNotEmpty) {
        _pendingFanCommandTimes.remove(targetHwId);
        _pendingFanStates.remove(targetHwId);
        _pendingTdsCommandTimes.remove(targetHwId);
        _pendingTdsRanges.remove(targetHwId);
      }
    }

    String bleMessage;
    if (bleOk) {
      if (command == 'F,0' || (command.startsWith('F') && effectiveFan == 'disable')) {
        bleMessage = 'Disable command sent via Bluetooth';
      } else if (command == 'F,1' || (command.startsWith('F') && effectiveFan == 'enable')) {
        bleMessage = 'Enable command sent via Bluetooth';
      } else if (command.startsWith('T,')) {
        bleMessage = 'TDS command sent via Bluetooth';
      } else {
        bleMessage = 'Command sent via Bluetooth';
      }
    } else {
      bleMessage = 'Failed to deliver command via Bluetooth';
    }

    return CommandDispatchResult(
      success: bleOk,
      transport: 'ble',
      message: bleMessage,
    );
  }

  /// Sends an MQTT downlink command (e.g. "F,0", "F,1") to the purifier via the AWS IoT backend.
  Future<bool> sendCommand({
    required String deviceId,
    String? serialNumber,
    required String command,
    int? tds1,
    int? tds2,
    double? temp,
    String? mode,
    int? tdsRange,
    String? fan,
  }) async {
    HttpClient? client;
    try {
      // 1. Resolve true Wi-Fi hardware MAC (STA MAC 2805a520c400)
      final cleanDevId = _cleanMac(deviceId);
      final cleanSerial = serialNumber != null ? _cleanMac(serialNumber) : '';
      
      String targetHwId;
      if (cleanDevId.length == 12) {
        targetHwId = cleanDevId.endsWith('02') ? '${cleanDevId.substring(0, 10)}00' : cleanDevId;
      } else if (cleanSerial.length == 12) {
        targetHwId = cleanSerial.endsWith('02') ? '${cleanSerial.substring(0, 10)}00' : cleanSerial;
      } else if (_lastHardwareDevId != null && _lastHardwareDevId!.isNotEmpty) {
        targetHwId = _cleanMac(_lastHardwareDevId!);
      } else {
        targetHwId = cleanDevId.isNotEmpty ? cleanDevId : cleanSerial;
      }

      final publishUrl = '${ApiEndpoints.liveBaseUrl}/telemetry/publish';
      client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      
      // Target direct single downlink topic for purifier
      final targetTopic = 'Shudhham/$targetHwId/v1/command';

      // Send single direct command string ("F,1", "F,0", or "T,xxx")
      await _publishSingleMqtt(client, publishUrl, targetTopic, command);

      // Also publish configuration JSON to Shudhham/tds/v1/SubConfig
      int? finalTds = tdsRange;
      if (finalTds == null && command.startsWith('T,')) {
        finalTds = int.tryParse(command.substring(2).trim());
      }
      if (finalTds != null && finalTds >= 991) {
        finalTds = 1000;
      }

      String effectiveFan;
      if (command == 'F,0') {
        effectiveFan = 'disable';
      } else if (command == 'F,1') {
        effectiveFan = 'enable';
      } else if (fan != null && fan.isNotEmpty) {
        effectiveFan = fan.toLowerCase().trim() == 'disable' ? 'disable' : 'enable';
      } else {
        effectiveFan = 'enable';
      }

      final subConfigPayload = jsonEncode({
        'dev_Id': targetHwId,
        'tds_range': finalTds ?? 200,
        'fan': effectiveFan,
      });
      await _publishSingleMqtt(client, publishUrl, 'Shudhham/tds/v1/SubConfig', subConfigPayload);

      return true;
    } catch (e) {
      debugPrint('[Telemetry] Failed to send MQTT command: $e');
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  Future<void> _publishSingleMqtt(HttpClient client, String publishUrl, String topic, String message) async {
    try {
      final payload = {
        'topic': topic,
        'message': message,
      };
      final devId = topic.replaceAll('Shudhham/', '').replaceAll('/v1/command', '');
      AppLogger.mqttCommandSent(
        command: message,
        deviceId: devId,
        topic: topic,
        payload: payload,
      );

      final req = await client.postUrl(Uri.parse(publishUrl));
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.add(utf8.encode(jsonEncode(payload)));
      final resp = await req.close().timeout(const Duration(seconds: 3));
      debugPrint('✅ [MQTT DELIVERED] $topic => "$message" (HTTP ${resp.statusCode})');
    } catch (e) {
      debugPrint('❌ [MQTT FAILED] $topic => "$message" ($e)');
    }
  }

  /// Directly updates the device fan state in the live backend database (/api/telemetry/ingest)
  /// so that both the backend database and all UI views immediately reflect the real updated state.
  Future<bool> updateFanStateInBackend({
    required String deviceId,
    String? serialNumber,
    required String fanState,
    int? tds1,
    int? tds2,
    double? temp,
    String? mode,
    int? tdsRange,
  }) async {
    HttpClient? client;
    try {
      final cleanDev = _cleanMac(deviceId);
      final cleanSerial = serialNumber != null ? _cleanMac(serialNumber) : '';

      String targetDevId;
      if (cleanDev.length == 12) {
        targetDevId = cleanDev.endsWith('02') ? '${cleanDev.substring(0, 10)}00' : cleanDev;
      } else if (cleanSerial.length == 12) {
        targetDevId = cleanSerial.endsWith('02') ? '${cleanSerial.substring(0, 10)}00' : cleanSerial;
      } else if (_lastHardwareDevId != null && _lastHardwareDevId!.isNotEmpty) {
        targetDevId = _cleanMac(_lastHardwareDevId!);
      } else {
        targetDevId = cleanDev.isNotEmpty ? cleanDev : cleanSerial;
      }

      final ingestUrl = '${ApiEndpoints.liveBaseUrl}/telemetry/ingest';
      client = HttpClient()..connectionTimeout = const Duration(seconds: 5);

      final request = await client.postUrl(Uri.parse(ingestUrl));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final payload = <String, dynamic>{
        'dev_Id': targetDevId,
        'fan': fanState,
      };
      if (tds1 != null) payload['tds1'] = tds1;
      if (tds2 != null) payload['tds2'] = tds2;
      if (temp != null) payload['temp'] = temp;
      if (mode != null) payload['mode'] = mode;
      if (tdsRange != null) payload['tds_range'] = tdsRange;

      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close().timeout(const Duration(seconds: 5));
      final isOk = response.statusCode == 200 || response.statusCode == 201;
      debugPrint('[Telemetry] Updated fan state ($fanState) in backend for $targetDevId: HTTP ${response.statusCode}');
      return isOk;
    } catch (e) {
      debugPrint('[Telemetry] Failed to update fan state in backend: $e');
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  String _cleanMac(String text) {
    return text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
  }
}
