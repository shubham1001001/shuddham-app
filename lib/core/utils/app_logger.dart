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

  static void telemetryReceived({
    required String deviceId,
    required int? tds1,
    required int? tds2,
    required double? temp,
    required String? mode,
    required String? fan,
    required bool isOnline,
  }) {
    _printBlock('''
╔══════════════════════════════════════════════════════════════════
║ 📊 [LIVE SENSOR TELEMETRY SYNC] • ${_timeNow()}
║ 🆔 Device: $deviceId | Status: ${isOnline ? "🟢 ONLINE" : "🔴 OFFLINE"}
║ 💧 Outlet TDS: ${tds2 ?? tds1 ?? "--"} PPM | Inlet TDS: ${tds1 ?? "--"} PPM
║ 🌡️ Temperature: ${temp != null ? "${temp.toStringAsFixed(1)}°C" : "--"}
║ ⚙️ Mode: ${mode ?? "--"} | Fan: ${fan ?? "--"}
╚══════════════════════════════════════════════════════════════════''');
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
}
