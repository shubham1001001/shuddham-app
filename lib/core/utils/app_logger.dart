import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Centralized Full-System Logger for Shuddham Mobile App.
/// Provides high-visibility, formatted console and logcat output for:
/// - Bluetooth Adapter State (ON / OFF / Turning ON / OFF)
/// - BLE Scanning & Discovered Devices (Names, MACs, RSSI)
/// - BLE Connection & Disconnection (Exact timestamps and device names)
/// - Wi-Fi Hardware Scan Results (Visible networks to Purifier)
/// - Wi-Fi Provisioning (SSID, Success / Failure status)
/// - Commands Sent to Server & MQTT Downlink
/// - API HTTP Requests, Headers, Payloads, Response Status & Data
class AppLogger {
  AppLogger._();

  static String _timeNow() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  /// Formats a DateTime object into readable DD/MM/YYYY HH:mm:ss format
  static String formatTimestamp(DateTime? dt) {
    if (dt == null) return '--';
    final local = dt.isUtc ? dt.toLocal() : dt;
    final d = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$d/$mo/$y $h:$m:$s';
  }

  /// Calculates human-readable time difference between two dates (e.g. "12s ago", "4m 10s ago")
  static String timeDifferenceString(DateTime? from, [DateTime? to]) {
    if (from == null) return 'Unknown';
    final target = to ?? DateTime.now();
    final diff = target.difference(from.isUtc ? from.toLocal() : from);
    if (diff.isNegative || diff.inSeconds < 5) return 'Just now (< 5s)';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ${diff.inSeconds % 60}s ago';
    if (diff.inHours < 24) return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
    return '${diff.inDays}d ago';
  }

  static void _printBlock(String content) {
    for (final line in content.split('\n')) {
      if (line.isNotEmpty) {
        debugPrint(line);
      }
    }
  }

  // ==========================================
  // 1. BLUETOOTH ADAPTER (PHONE STATE)
  // ==========================================
  static void bleAdapterState(BluetoothAdapterState state) {
    final isOn = state == BluetoothAdapterState.on;
    final icon = isOn ? '🔵' : '🔴';
    final statusText = state.name.toUpperCase();
    
    _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ $icon [PHONE BLUETOOTH STATE CHANGE] • ${_timeNow()}
║ 📱 Phone Bluetooth: $statusText
║ ℹ️ Status: ${isOn ? "READY TO SCAN & CONNECT" : "BLUETOOTH IS OFF - PLEASE TURN ON"}
╚══════════════════════════════════════════════════════════════════''');
  }

  // ==========================================
  // 2. BLE SCAN & DISCOVERED DEVICES
  // ==========================================
  static void bleScanStarted() {
    _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ 🔍 [BLE SCAN STARTED] • ${_timeNow()}
║ 📡 Scanning for nearby Shuddham Purifier hardware...
╚══════════════════════════════════════════════════════════════════''');
  }

  static void bleDeviceDiscovered({
    required String name,
    required String remoteId,
    required int rssi,
    required bool isPurifier,
    List<String>? serviceUuids,
  }) {
    // Only log Shuddham purifiers, ignore non-Shuddham devices
    if (!isPurifier) return;

    _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ ⭐ [SHUDDHAM PURIFIER FOUND IN SCAN] • ${_timeNow()}
║ 🏷️ Device Name: "${name.isEmpty ? "SHUDDHAM" : name}"
║ 🆔 Bluetooth MAC / Remote ID: $remoteId
║ 📶 Signal Strength (RSSI): ${rssi}dBm
${serviceUuids != null && serviceUuids.isNotEmpty ? "║ 📡 Services: ${serviceUuids.join(', ')}" : ""}
╚══════════════════════════════════════════════════════════════════''');
  }

  static void bleScanCompleted(int totalFound, int totalPurifiers) {
    _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ 📋 [BLE SCAN FINISHED] • ${_timeNow()}
║ ⭐ Shuddham Purifiers Found: $totalPurifiers
╚══════════════════════════════════════════════════════════════════''');
  }

  // ==========================================
  // 3. BLE CONNECT / DISCONNECT
  // ==========================================
  static void bleConnecting(String name, String remoteId, int attempt) {
    _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ 🔄 [CONNECTING TO HARDWARE BLE] • ${_timeNow()}
║ 🏷️ Device Name: "${name.isEmpty ? "Shuddham Device" : name}"
║ 🆔 Bluetooth MAC/ID: $remoteId
║ 🔁 Attempt: #$attempt
╚══════════════════════════════════════════════════════════════════''');
  }

  static void bleConnected({
    required String name,
    required String remoteId,
    List<String>? services,
  }) {
    _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ 🟢 [BLUETOOTH CONNECTED TO HARDWARE] • ${_timeNow()}
║ 🏷️ Connected Name: "${name.isEmpty ? "Shuddham Device" : name}"
║ 🆔 Connected MAC/ID: $remoteId
${services != null && services.isNotEmpty ? "║ 📡 Discovered Services: ${services.join(', ')}" : ""}
║ ✅ Connection Established: Ready to send Provisioning & Commands
╚══════════════════════════════════════════════════════════════════''');
  }

  static void bleDisconnected({
    required String name,
    required String remoteId,
    String? reason,
  }) {
    _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ 🔴 [BLUETOOTH DISCONNECTED FROM HARDWARE] • ${_timeNow()}
║ 🏷️ Disconnected Device: "${name.isEmpty ? "Shuddham Device" : name}"
║ 🆔 Device ID: $remoteId
║ ⏰ Disconnected At: ${_timeNow()}
║ ℹ️ Reason: ${reason ?? "Normal disconnect / Connection closed"}
╚══════════════════════════════════════════════════════════════════''');
  }

  // ==========================================
  // 4. BLE COMMANDS & RESPONSES
  // ==========================================
  static void bleCommandSent(String command, {String? targetDev}) {
    _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ 📤 [BLE COMMAND TRANSMITTED] • ${_timeNow()}
║ 💬 Command: "$command"
${targetDev != null ? "║ 🎯 Target Device: $targetDev" : ""}
╚══════════════════════════════════════════════════════════════════''');
  }

  static void bleResponseReceived(String response) {
    _printBlock('║ 📥 [BLE RESPONSE FROM HARDWARE] <<< "$response"');
  }

  // ==========================================
  // 5. WI-FI HARDWARE SCAN & PROVISIONING
  // ==========================================
  static void wifiScanStarted() {
    _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ 📶 [HARDWARE WI-FI SCAN STARTED] • ${_timeNow()}
║ 📡 Sending "WSCAN" command to ESP32 Purifier...
╚══════════════════════════════════════════════════════════════════''');
  }

  static void wifiScanCompleted(List<dynamic> networks) {
    final buffer = StringBuffer();
    buffer.writeln('╔══════════════════════════════════════════════════════════════════');
    buffer.writeln('║ 📶 [HARDWARE WI-FI NETWORKS FOUND] • ${_timeNow()}');
    buffer.writeln('║ 🔢 Total SSIDs Visible to Purifier: ${networks.length}');
    for (int i = 0; i < networks.length; i++) {
      final net = networks[i];
      final ssid = net is Map ? net['ssid'] : (net.ssid ?? '');
      buffer.writeln('║   • [${i + 1}] "$ssid"');
    }
    buffer.writeln('╚══════════════════════════════════════════════════════════════════');
    _printBlock(buffer.toString());
  }

  static void wifiProvisioningStarted({
    required String ssid,
    required String deviceName,
  }) {
    _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ 🚀 [WI-FI PROVISIONING INITIATED] • ${_timeNow()}
║ 🏷️ Device: "$deviceName"
║ 📶 Target Wi-Fi SSID: "$ssid"
║ 🔑 Transmitting Wi-Fi SSID (S,...) & Password (P,...) to ESP32...
╚══════════════════════════════════════════════════════════════════''');
  }

  static void wifiProvisioningResult({
    required bool success,
    required String ssid,
    String? message,
  }) {
    if (success) {
      _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ 🎉 [PURIFIER WI-FI CONNECTED SUCCESSFULLY] • ${_timeNow()}
║ 📶 Connected to Wi-Fi SSID: "$ssid"
║ ✅ Hardware state: Wi-Fi Connected -> Switching to Cloud MQTT!
╚══════════════════════════════════════════════════════════════════''');
    } else {
      _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ ❌ [PURIFIER WI-FI CONNECTION FAILED] • ${_timeNow()}
║ 📶 Target SSID: "$ssid"
║ ⚠️ Failure Reason: ${message ?? "ESP32 could not authenticate or join Wi-Fi"}
╚══════════════════════════════════════════════════════════════════''');
    }
  }

  // ==========================================
  // 6. SERVER / MQTT COMMANDS & TELEMETRY
  // ==========================================
  static void mqttCommandSent({
    required String command,
    required String deviceId,
    required String topic,
    Map<String, dynamic>? payload,
  }) {
    _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ ☁️ [SERVER / MQTT COMMAND SENT] • ${_timeNow()}
║ 🎯 Device ID: $deviceId
║ 📮 MQTT Topic: $topic
║ 💬 Command: "$command"
${payload != null ? "║ 📦 Payload: ${jsonEncode(payload)}" : ""}
╚══════════════════════════════════════════════════════════════════''');
  }

  static void tdsCommandSent({
    required String deviceId,
    required double rawTds,
    required int finalTds,
    required String command,
    required String topic,
  }) {
    final isSnapped = rawTds.round() >= 991;
    _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ 📤 [TDS COMMAND DISPATCHED] • ${_timeNow()}
║ 🎯 Device ID        : $deviceId
║ 🎚️ Selected Slider   : ${rawTds.round()} PPM
║ 💧 Passed To Device : $finalTds PPM ${isSnapped ? '(Rule applied: 991 or above -> 1000 PPM)' : ''}
║ 📮 Target Topic     : $topic
║ 📡 Transport        : Dispatched via AWS IoT Core MQTT
║ ⏳ Note             : Awaiting hardware confirmation to update DB
╚══════════════════════════════════════════════════════════════════''');
  }

  static void tdsCommandResult({
    required String deviceId,
    required int targetTds,
    required bool success,
    required String transport,
    required String message,
  }) {
    if (success) {
      _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ ✅ [COMMAND DELIVERY CONFIRMED] • ${_timeNow()}
║ 🎯 Device ID   : $deviceId
║ 🎚️ Target TDS  : $targetTds PPM
║ 📡 Route       : ${transport == 'ble' ? 'Bluetooth LE (Local)' : 'Cloud MQTT (AWS)'}
║ ℹ️ Result      : $message
╚══════════════════════════════════════════════════════════════════''');
    } else {
      _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ ❌ [COMMAND DELIVERY FAILED] • ${_timeNow()}
║ 🎯 Device ID   : $deviceId
║ 🎚️ Target TDS  : $targetTds PPM
║ 📡 Route       : ${transport == 'ble' ? 'Bluetooth LE (Local)' : 'Cloud MQTT (AWS)'}
║ 🔒 Setting     : KEPT UNCHANGED (Command not delivered)
║ ⚠️ Reason      : $message
╚══════════════════════════════════════════════════════════════════''');
    }
  }

  static void internetPriorityMqttDispatched({
    required String deviceId,
    required String topic,
    required Map<String, dynamic> payload,
    required String command,
    DateTime? mobileDispatchTime,
    DateTime? backendLastReadingTime,
  }) {
    final dispatchTime = mobileDispatchTime ?? DateTime.now();

    _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ 🌐 [CONFIG DISPATCHED TO AWS IOT] • ${_timeNow()}
║ 🎯 Device ID    : $deviceId
║ 📮 MQTT Topic   : $topic
║ 📦 Payload JSON : ${jsonEncode(payload)}
║ ⏱️ Sent At      : ${formatTimestamp(dispatchTime)}
║ ℹ️ Local State  : Stored optimistically (waiting for hardware DB update)
╚══════════════════════════════════════════════════════════════════''');
  }

  static void bleFallbackTriggered({
    required String reason,
    required String deviceId,
  }) {
    _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ 🔵 [OFFLINE BLE FALLBACK TRIGGERED] • ${_timeNow()}
║ ⚠️ Reason    : $reason
║ 🎯 Target Dev: $deviceId
║ 📶 Action    : Activating Bluetooth & Connecting directly to ESP32 Purifier
╚══════════════════════════════════════════════════════════════════''');
  }

  static void telemetryReceived({
    required String deviceId,
    required int? tds1,
    required int? tds2,
    required double? temp,
    required String? mode,
    required String? fan,
    String? rawHardwareFan,
    String? pendingExpectedFan,
    int? tdsRange,
    int? rawHardwareTdsRange,
    int? pendingExpectedTdsRange,
    required bool isOnline,
    String source = "🌐 LIVE CLOUD API",
    DateTime? mobileCheckTime,
    DateTime? backendReadingTime,
    String? rawBackendTs,
    bool isChanged = false,
  }) {
    final checkTime = mobileCheckTime ?? DateTime.now();
    final diffStr = backendReadingTime != null 
        ? timeDifferenceString(backendReadingTime, checkTime)
        : (rawBackendTs ?? 'Live');
    final backendFormatted = backendReadingTime != null
        ? formatTimestamp(backendReadingTime)
        : (rawBackendTs ?? '--');

    final title = isChanged ? '⚡ [NEW HARDWARE TELEMETRY RECEIVED]' : '📊 [TELEMETRY STATE SYNC]';

    final String fanLogLine;
    if (pendingExpectedFan != null &&
        pendingExpectedFan.toLowerCase().trim() != (rawHardwareFan ?? fan)?.toLowerCase().trim()) {
      fanLogLine =
          '║ 🌀 Real Last Fan Status: ${(rawHardwareFan ?? fan)?.toUpperCase() ?? "--"} (from Cloud DB)\n'
          '║ ⏳ Expected Status     : ${pendingExpectedFan.toUpperCase()} (Awaiting Hardware Confirmation)';
    } else {
      fanLogLine = '║ 🌀 Cooling Fan Relay   : ${fan?.toUpperCase() ?? "--"}';
    }

    final String tdsRangeLogLine;
    if (pendingExpectedTdsRange != null &&
        pendingExpectedTdsRange != (rawHardwareTdsRange ?? tdsRange)) {
      tdsRangeLogLine =
          '║ 🎯 Real Target TDS     : ${rawHardwareTdsRange != null ? "$rawHardwareTdsRange PPM" : (tdsRange != null ? "$tdsRange PPM" : "--")} (from Cloud DB)\n'
          '║ ⏳ Expected Target TDS : $pendingExpectedTdsRange PPM (Awaiting Hardware Confirmation)';
    } else {
      tdsRangeLogLine = '║ 🎯 Target TDS Limit    : ${tdsRange != null ? "$tdsRange PPM" : "--"}';
    }

    _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ $title • ${_timeNow()}
║ 📍 Source             : $source
║ 🆔 Device ID           : $deviceId (${isOnline ? "🟢 ONLINE" : "🔴 OFFLINE"})
║ ⏱️ Hardware Reading Ts : $backendFormatted ($diffStr)
║ 💧 Pure TDS (Outlet)   : ${tds2 ?? "--"} PPM
║ 💧 Raw TDS (Inlet)     : ${tds1 ?? "--"} PPM
$tdsRangeLogLine
$fanLogLine
║ 🌡️ Water Temperature   : ${temp != null ? "${temp.toStringAsFixed(1)}°C" : "--"} | Mode: ${mode ?? "--"}
╚══════════════════════════════════════════════════════════════════''');
  }

  // ==========================================
  // 7. DATA SOURCE TRACKING (API vs LOCAL STORAGE)
  // ==========================================
  static void dataSourceLoaded({
    required String source,
    required String dataType,
    required int count,
    String? storageKey,
    String? endpoint,
    String? details,
  }) {
    final icon = source.contains('API') || source.contains('CLOUD') ? '🌐' : '💾';
    final buffer = StringBuffer();
    buffer.writeln('╔══════════════════════════════════════════════════════════════════');
    buffer.writeln('║ $icon [DATA SOURCE: $source] • ${_timeNow()}');
    buffer.writeln('║ 📦 Data Type    : $dataType');
    buffer.writeln('║ 🔢 Device Count : $count');
    if (endpoint != null && endpoint.isNotEmpty) {
      buffer.writeln('║ 🔗 API Endpoint : $endpoint');
    }
    if (storageKey != null && storageKey.isNotEmpty) {
      buffer.writeln('║ 🔑 Storage Key  : $storageKey');
    }
    if (details != null && details.isNotEmpty) {
      buffer.writeln('║ ℹ️ Source Info  : $details');
    }
    buffer.writeln('╚══════════════════════════════════════════════════════════════════');
    _printBlock(buffer.toString());
  }

  // ==========================================
  // 7. REST API REQUEST & RESPONSE
  // ==========================================
  static void apiRequest({
    required String method,
    required Uri uri,
    Map<String, dynamic>? headers,
    dynamic body,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('╔══════════════════════════════════════════════════════════════════');
    buffer.writeln('║ 📡 [API REQUEST] $method $uri • ${_timeNow()}');
    if (headers != null && headers.isNotEmpty) {
      buffer.writeln('║ 📋 Headers: ${jsonEncode(headers)}');
    }
    if (body != null) {
      buffer.writeln('║ 📦 Request Body: ${body is String ? body : jsonEncode(body)}');
    }
    buffer.writeln('╚══════════════════════════════════════════════════════════════════');
    _printBlock(buffer.toString());
  }

  static void apiResponse({
    required String method,
    required Uri uri,
    required int statusCode,
    String? responseBody,
    Duration? duration,
  }) {
    final isSuccess = statusCode >= 200 && statusCode < 300;
    final icon = isSuccess ? '✅' : '❌';
    final buffer = StringBuffer();
    buffer.writeln('╔══════════════════════════════════════════════════════════════════');
    buffer.writeln('║ $icon [API RESPONSE] $statusCode | $method $uri (${duration?.inMilliseconds ?? 0}ms) • ${_timeNow()}');
    if (responseBody != null && responseBody.isNotEmpty) {
      buffer.writeln('║ 📄 Response Body: $responseBody');
    }
    buffer.writeln('╚══════════════════════════════════════════════════════════════════');
    _printBlock(buffer.toString());
  }

  static void apiError({
    required String method,
    required Uri uri,
    required dynamic error,
  }) {
    _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ ⚠️ [API NETWORK/REQUEST ERROR] $method $uri • ${_timeNow()}
║ 💥 Error Details: $error
╚══════════════════════════════════════════════════════════════════''');
  }

  static void fanCommandResult({
    required String deviceId,
    required String command,
    required String action,
    required bool success,
    required String transport,
    required String message,
    required String currentFanStatus,
    String? newFanStatus,
  }) {
    if (success) {
      _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ ✅ [FAN COMMAND SUCCESS] • ${_timeNow()}
║ 🎯 Device ID   : $deviceId
║ 🌀 Action      : $action
║ 📡 Transport   : ${transport.toUpperCase()} (${transport == 'ble' ? 'Bluetooth LE' : 'Cloud MQTT'})
║ ⚙️ Fan Status  : Updated to ${newFanStatus?.toUpperCase() ?? 'UPDATED'}
║ ℹ️ Message     : $message
╚══════════════════════════════════════════════════════════════════''');
    } else {
      _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ ❌ [FAN COMMAND FAILED - STATUS NOT CHANGED] • ${_timeNow()}
║ 🎯 Device ID   : $deviceId
║ 🌀 Action      : $action
║ 📡 Transport   : ${transport.toUpperCase()} (${transport == 'ble' ? 'Bluetooth LE' : 'Cloud MQTT'})
║ 🔒 Fan Status  : KEPT UNCHANGED as "$currentFanStatus" (No state change applied)
║ ⚠️ Failure     : $message
╚══════════════════════════════════════════════════════════════════''');
    }
  }
}

