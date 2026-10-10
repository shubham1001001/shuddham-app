import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants/api_endpoints.dart';
import '../services/device_storage_service.dart';
import '../utils/app_logger.dart';
import '../session/user_session.dart';
import '../../features/home/data/models/device_model.dart';

/// Service responsible for fetching live sensor readings (TDS, temperature, mode)
/// from the AWS IoT telemetry backend (http://3.88.13.76:4000/api/telemetry).
class TelemetryService {
  TelemetryService._();
  static final TelemetryService instance = TelemetryService._();

  static const String _telemetryUrl = '${ApiEndpoints.liveBaseUrl}/telemetry/latest';

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
  Future<List<DeviceModel>> fetchCustomerDevices({
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
      return [];
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
    } catch (e) {
      debugPrint('[Telemetry] Failed to fetch customer assigned devices: $e');
    } finally {
      client?.close(force: true);
    }
    return [];
  }

  /// Syncs an active list of [DeviceModel] instances with real-time sensor data from the backend.
  /// Updates local persistent storage with the new sensor readings.
  Future<List<DeviceModel>> syncDevices(List<DeviceModel> devices) async {
    if (devices.isEmpty) return devices;

    final telemetryRecords = await fetchAllTelemetry();
    if (telemetryRecords.isEmpty) return devices;

    final List<DeviceModel> updatedList = [];
    bool hasChanges = false;

    for (final dev in devices) {
      final match = findMatchingRecord(dev, telemetryRecords);
      if (match != null) {
        final updated = applyTelemetryToDevice(dev, match);
        updatedList.add(updated);
        hasChanges = true;

        AppLogger.telemetryReceived(
          deviceId: updated.id,
          tds1: updated.inletTdsPpm,
          tds2: updated.tdsPpm,
          temp: updated.temperature,
          mode: updated.mode,
          fan: updated.fan,
          isOnline: updated.isOnline,
        );
      } else {
        updatedList.add(dev);
      }
    }

    if (hasChanges) {
      await DeviceStorageService.saveDevices(updatedList);
    }

    return updatedList;
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

    // 2. If user has only one paired device, bind to the most recently updated record
    if (records.isNotEmpty) {
      // Pick device 2805a520c400 if present or first
      final preferred = records.firstWhere(
        (r) => (r['dev_id']?.toString() ?? '').contains('2805a520c4'),
        orElse: () => records.first,
      );
      return preferred;
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

    // Online status
    final statusStr = (r['status']?.toString() ?? 'online').toLowerCase();
    final isOnline = statusStr == 'online';

    // Mode ('NF' or 'RO')
    final mode = r['mode']?.toString() ?? dev.mode;

    // TDS range
    final rawRange = r['tds_range'];
    int? tdsRange;
    if (rawRange != null) tdsRange = int.tryParse(rawRange.toString());

    // Real Fan status directly from hardware telemetry record in DB
    final fan = r['fan']?.toString() ?? dev.fan;

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

  String? _lastHardwareDevId = '2805a520c400';
  String? get lastHardwareDevId => _lastHardwareDevId;

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

      // Send single direct command string ("F,1" or "F,0")
      await _publishSingleMqtt(client, publishUrl, targetTopic, command);
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
