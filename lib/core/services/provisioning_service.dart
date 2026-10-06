import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/ble_constants.dart';

/// Scanned Wi-Fi network reported by the ESP32 TDS Monitor over BLE.
class BleWifiNetwork {
  const BleWifiNetwork({
    required this.index,
    required this.ssid,
    required this.security,
  });

  final int index;
  final String ssid;
  final int security; // 0 = Open, 1 = WEP/WPA/WPA2/WPA3, 2 = Other

  bool get isOpen => security == 0;
  bool get isSecured => security != 0;
}

/// BLE device discovered in setup mode.
class DiscoveredBleDevice {
  const DiscoveredBleDevice({
    required this.device,
    required this.name,
    required this.rssi,
    this.isPurifier = false,
  });

  final BluetoothDevice device;
  final String name;
  final int rssi;
  final bool isPurifier;

  int get signalPercent => ((rssi + 100) * 1.66).clamp(5, 100).toInt();

  String get shortId {
    if (name.contains('-')) {
      final parts = name.split('-');
      if (parts.last.trim().isNotEmpty) {
        return parts.last.trim().toUpperCase();
      }
    }
    final macClean = device.remoteId.str.replaceAll(':', '').replaceAll('-', '').toUpperCase();
    if (macClean.length >= 4) {
      return macClean.substring(macClean.length - 4);
    }
    return macClean.isNotEmpty ? macClean : 'A4F2';
  }
}

/// Reason for provisioning failures.
enum ProvisioningFailureReason {
  bluetooth,
  wifi,
  timeout,
  deviceNotFound,
}

/// Bluetooth Wi-Fi provisioning service for Shuddham ESP32 Smart Purifiers.
/// Implements the custom BLE GATT protocol:
/// - Advertised Name: SHUDDHAM... or SHD-...
/// - Advertised Service UUID: 0xABF0
/// - Real GATT Service UUID: 0x00FF
/// - Characteristic UUID: 0xFF01 (Write with response, Notify)
/// - MTU: 64
/// - Commands: `WSCAN`, `S,<ssid>`, `P,<password>`
class ProvisioningService {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _commChar;
  StreamSubscription<List<int>>? _notifySub;
  final StreamController<String> _notifications = StreamController<String>.broadcast();

  BluetoothDevice? get connectedDevice => _connectedDevice;
  Stream<String> get notifications => _notifications.stream;

  /// Checks if required Bluetooth & Location permissions are granted.
  Future<bool> hasPermissions() async {
    if (Platform.isAndroid) {
      final sScan = await Permission.bluetoothScan.status;
      final sConnect = await Permission.bluetoothConnect.status;
      final sLoc = await Permission.locationWhenInUse.status;
      return (sScan.isGranted || sScan.isLimited) &&
          (sConnect.isGranted || sConnect.isLimited) &&
          (sLoc.isGranted || sLoc.isLimited);
    }
    if (Platform.isIOS) {
      final s = await Permission.bluetooth.status;
      return s.isGranted || s.isLimited;
    }
    return true;
  }

  /// Asks for Bluetooth and Location permissions needed for BLE scanning.
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final perms = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ];
      final results = await perms.request();
      return results.values.every((s) => s.isGranted || s.isLimited);
    }
    if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      return status.isGranted || status.isLimited;
    }
    return true;
  }

  /// Checks if Bluetooth permissions are permanently denied.
  Future<bool> permissionsPermanentlyDenied() async {
    if (Platform.isAndroid) {
      final perms = [Permission.bluetoothScan, Permission.bluetoothConnect];
      for (final p in perms) {
        if (await p.isPermanentlyDenied) return true;
      }
    } else if (Platform.isIOS) {
      return await Permission.bluetooth.isPermanentlyDenied;
    }
    return false;
  }

  /// Scans for nearby Shuddham purifiers advertising in setup mode.
  Future<List<DiscoveredBleDevice>> scanDevices({Duration timeout = const Duration(seconds: 8)}) async {
    // Ensure Bluetooth is available and powered on
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      if (Platform.isAndroid) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {}
      }
    }

    final discoveredMap = <String, DiscoveredBleDevice>{};

    final scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final advName = r.advertisementData.advName.trim().replaceAll('\x00', '');
        final devName = r.device.platformName.trim().replaceAll('\x00', '');
        final name = advName.isNotEmpty ? advName : devName;

        debugPrint('[BLE Found] Name: "$name", AdvName: "$advName", DevName: "$devName", ID: "${r.device.remoteId}", UUIDs: ${r.advertisementData.serviceUuids.map((u) => u.str).toList()}, RSSI: ${r.rssi}');

        final upper = name.toUpperCase();
        final hasMatchingName = upper.startsWith(BleConstants.bleNamePrefix) ||
            upper.startsWith(BleConstants.bleAltPrefix) ||
            upper.contains('SHUDDHAM') ||
            upper.contains('SHD') ||
            upper.contains('ESP32') ||
            upper.contains('TDS') ||
            upper.contains('WATER') ||
            upper.contains('PURIFIER');

        final hasMatchingService = r.advertisementData.serviceUuids.any((u) {
          final s = u.str.toLowerCase();
          return s.contains('abf0') ||
              s.contains('00ff') ||
              s == BleConstants.bleAdvertisedServiceUuid.toLowerCase() ||
              s == BleConstants.bleGattServiceUuid.toLowerCase();
        });

        final isPurifierDevice = hasMatchingName || hasMatchingService;

        if (isPurifierDevice || (name.isNotEmpty && !name.contains('TV') && !name.contains('Band'))) {
          final displayName = name.isNotEmpty
              ? name
              : 'SHUDDHAM-${r.device.remoteId.str.replaceAll(':', '').toUpperCase().substring(0, 4)}';
          discoveredMap[r.device.remoteId.str] = DiscoveredBleDevice(
            device: r.device,
            name: displayName,
            rssi: r.rssi,
            isPurifier: isPurifierDevice,
          );
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );
      await Future<void>.delayed(timeout);
    } finally {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      await scanSub.cancel();
    }

    final list = discoveredMap.values.toList();
    list.sort((a, b) {
      if (a.isPurifier && !b.isPurifier) return -1;
      if (!a.isPurifier && b.isPurifier) return 1;
      return b.rssi.compareTo(a.rssi);
    });
    return list;
  }

  /// Connects to the ESP32, requests MTU 64, discovers Service 0x00FF and Char 0xFF01,
  /// and enables notification subscription sequentially.
  Future<void> connect(BluetoothDevice device) async {
    await disconnect();

    // Try connecting with up to 3 attempts with settling delays
    Object? connectError;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        debugPrint('[BLE] 1. Connecting to ${device.remoteId} (attempt $attempt)...');
        await device.connect(autoConnect: false, mtu: null).timeout(const Duration(seconds: 8));
        _connectedDevice = device;
        connectError = null;
        break;
      } catch (e) {
        connectError = e;
        debugPrint('[BLE] Connect attempt $attempt failed: $e');
        try {
          await device.disconnect();
        } catch (_) {}
        if (attempt < 3) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
    }
    if (connectError != null) {
      throw connectError;
    }

    // Settle connection before requesting MTU
    await Future.delayed(const Duration(milliseconds: 500));

    // Request MTU 64 as specified in the firmware spec
    if (Platform.isAndroid) {
      try {
        debugPrint('[BLE] 2. Requesting MTU 64...');
        await device.requestMtu(64).timeout(const Duration(seconds: 3));
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('[BLE] MTU request notice (continuing): $e');
      }
    }

    debugPrint('[BLE] 3. Discovering services...');
    final services = await device.discoverServices();
    await Future.delayed(const Duration(milliseconds: 500));

    BluetoothCharacteristic? writeChar;
    BluetoothCharacteristic? notifyChar;

    for (final s in services) {
      final sUuid = s.uuid.str.toLowerCase();
      debugPrint('[BLE Discovery] Found Service: $sUuid');
      for (final c in s.characteristics) {
        final cUuid = c.uuid.str.toLowerCase();
        debugPrint('[BLE Discovery]   -> Char: $cUuid (write: ${c.properties.write}, writeWithoutResponse: ${c.properties.writeWithoutResponse}, notify: ${c.properties.notify}, indicate: ${c.properties.indicate})');
        if (sUuid.contains('00ff') || sUuid == BleConstants.bleGattServiceUuid.toLowerCase()) {
          if (cUuid.contains('ff01') || cUuid == BleConstants.bleCharUuid.toLowerCase()) {
            writeChar = c;
            notifyChar = c;
          }
        }
      }
    }

    if (writeChar == null || notifyChar == null) {
      // Fallback 1: Match FF01 on any service
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.uuid.str.toLowerCase().contains('ff01')) {
            writeChar ??= c;
            notifyChar ??= c;
            break;
          }
        }
      }
    }

    if (writeChar == null || notifyChar == null) {
      // Fallback 2: Look for dual or single write & notify
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.properties.write || c.properties.writeWithoutResponse) {
            writeChar ??= c;
          }
          if (c.properties.notify || c.properties.indicate) {
            notifyChar ??= c;
          }
        }
      }
    }

    if (writeChar == null && notifyChar == null) {
      throw Exception('Shuddham BLE characteristic not found on device.');
    }

    _commChar = writeChar ?? notifyChar;
    final activeNotifyChar = notifyChar ?? writeChar;

    if (activeNotifyChar != null) {
      _notifySub = activeNotifyChar.onValueReceived.listen((bytes) {
        final text = utf8.decode(bytes, allowMalformed: true).trim();
        debugPrint('[BLE Notify] <<< $text');
        if (text.isNotEmpty) {
          _notifications.add(text);
        }
      });

      if (activeNotifyChar.properties.notify || activeNotifyChar.properties.indicate) {
        debugPrint('[BLE] 4. Enabling notifications on characteristic: ${activeNotifyChar.uuid.str}...');
        try {
          await activeNotifyChar.setNotifyValue(true, timeout: 3);
          debugPrint('[BLE] Notifications listener registered.');
        } catch (e) {
          debugPrint('[BLE] setNotifyValue notice: $e');
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 300));
    debugPrint('[BLE] 5. Connected and ready for commands.');
  }

  /// Writes ASCII command to BLE Characteristic.
  Future<void> _writeAscii(String command) async {
    if (_commChar == null) throw Exception('Device not connected over BLE.');
    debugPrint('[BLE Write] >>> $command');
    final bytes = utf8.encode(command);
    final withoutResponse = !_commChar!.properties.write && _commChar!.properties.writeWithoutResponse;

    Object? lastError;
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        await Future.delayed(Duration(milliseconds: attempt * 200));
        await _commChar!.write(bytes, withoutResponse: withoutResponse, timeout: BleConstants.writeTimeout.inSeconds);
        debugPrint('[BLE Write Success] >>> $command');
        return;
      } catch (e) {
        lastError = e;
        debugPrint('[BLE Write] Attempt $attempt failed: $e');
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
    if (lastError != null) throw lastError;
  }

  /// Scans for Wi-Fi networks visible to the purifier by sending "WSCAN".
  /// Handles both formats:
  ///   "Found WiFi: 5"
  ///   "[1]:Airtel_MESB[1]"
  ///   "[4]:DYNAMIQUE ELECTR"
  Future<List<BleWifiNetwork>> scanWifiNetworks({Duration timeout = BleConstants.wifiScanTimeout}) async {
    if (_commChar == null) throw Exception('Device not connected over BLE');

    final networks = <BleWifiNetwork>[];
    final seenSsids = <String>{};
    final completer = Completer<List<BleWifiNetwork>>();
    int expectedCount = -1;

    final sub = _notifications.stream.listen((msg) {
      debugPrint('[BLE Scan Msg] $msg');
      if (msg.startsWith('Found WiFi:')) {
        final countStr = msg.replaceFirst('Found WiFi:', '').trim();
        expectedCount = int.tryParse(countStr) ?? -1;
        debugPrint('[BLE] Expected Wi-Fi networks: $expectedCount');
        if (expectedCount == 0 && !completer.isCompleted) {
          completer.complete([]);
        }
      } else if (msg.startsWith('[') && msg.contains(']:')) {
        final closeBracketIdx = msg.indexOf(']:');
        final idxStr = msg.substring(1, closeBracketIdx);
        final idx = int.tryParse(idxStr) ?? networks.length + 1;
        String rest = msg.substring(closeBracketIdx + 2).trim();

        int sec = 1; // Default secured
        final secMatch = RegExp(r'\[(\d+)\]$').firstMatch(rest);
        if (secMatch != null) {
          sec = int.tryParse(secMatch.group(1) ?? '1') ?? 1;
          rest = rest.substring(0, secMatch.start).trim();
        }

        final ssid = rest;
        if (ssid.isNotEmpty && !seenSsids.contains(ssid)) {
          seenSsids.add(ssid);
          networks.add(BleWifiNetwork(index: idx, ssid: ssid, security: sec));
          debugPrint('[BLE] Parsed Network #$idx: "$ssid" (security: $sec)');
        }

        if (expectedCount > 0 && networks.length >= expectedCount && !completer.isCompleted) {
          completer.complete(networks);
        }
      }
    });

    try {
      await _writeAscii('WSCAN');
      return await completer.future.timeout(
        timeout,
        onTimeout: () => networks, // return whatever was collected
      );
    } finally {
      await sub.cancel();
    }
  }

  /// Sends Wi-Fi SSID and Password to ESP32:
  /// 1. Write `S,<ssid>` -> Wait for "Get SSID."
  /// 2. Write `P,<password>` -> Wait for "Get Password."
  /// 3. Wait for "Wifi Conected." (success) or "Wifi Not Conected." (failure)
  Future<bool> provisionWifi(String ssid, String password, {Duration timeout = BleConstants.provisionTimeout}) async {
    final cleanSsid = ssid.trim();
    final cleanPass = password;

    if (cleanSsid.isEmpty) {
      throw ArgumentError('SSID must not be empty.');
    }

    final completer = Completer<bool>();

    final sub = _notifications.stream.listen((msg) {
      debugPrint('[BLE Provision Msg] $msg');
      final lower = msg.toLowerCase();
      if ((lower.contains('conected') || lower.contains('connected') || lower.contains('wifi ok') || lower.contains('ip:')) &&
          !lower.contains('not')) {
        debugPrint('[BLE] Wi-Fi connection successful on ESP32!');
        if (!completer.isCompleted) completer.complete(true);
      } else if (lower.contains('not conected') || lower.contains('not connected') || lower.contains('fail') || lower.contains('error')) {
        debugPrint('[BLE] Wi-Fi connection failed on ESP32!');
        if (!completer.isCompleted) completer.complete(false);
      }
    });

    StreamSubscription? connSub;
    if (_connectedDevice != null) {
      connSub = _connectedDevice!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint('[BLE] Device disconnected (expected behavior when ESP32 joins Wi-Fi)');
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (!completer.isCompleted) {
              debugPrint('[BLE] Successfully connected: Firmware disabled BLE as per spec.');
              completer.complete(true);
            }
          });
        }
      });
    }

    try {
      // 1. Send SSID
      await _writeAndExpect('S,$cleanSsid', (m) => m.toLowerCase().contains('ssid'));
      await Future.delayed(const Duration(milliseconds: 300));

      // 2. Send Password (or 'none' if empty)
      final passToSend = cleanPass.isEmpty ? 'none' : cleanPass;
      await _writeAndExpect('P,$passToSend', (m) => m.toLowerCase().contains('pass'));

      // 3. Wait for connection result
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          debugPrint('[BLE] Timeout waiting for WiFi connection result from ESP32');
          return false;
        },
      );
    } finally {
      await sub.cancel();
      await connSub?.cancel();
    }
  }

  Future<void> _writeAndExpect(String command, bool Function(String) predicate, {Duration timeout = const Duration(seconds: 6)}) async {
    final c = Completer<void>();
    final sub = _notifications.stream.listen((msg) {
      if (predicate(msg) && !c.isCompleted) {
        c.complete();
      }
    });
    try {
      await _writeAscii(command);
      await c.future.timeout(timeout);
    } catch (e) {
      debugPrint('[BLE] Notice waiting for response to $command: $e');
    } finally {
      await sub.cancel();
    }
  }

  /// Disconnects from current BLE peripheral.
  Future<void> disconnect() async {
    try {
      await _notifySub?.cancel();
      _notifySub = null;
      _commChar = null;
      if (_connectedDevice != null) {
        try {
          await _connectedDevice!.disconnect();
        } catch (_) {}
        _connectedDevice = null;
      }
    } catch (e) {
      debugPrint('[BLE] Disconnect cleanup notice: $e');
    }
  }

  static String deviceIdFromBleName(String name) => name.trim().toUpperCase();

  static String shortId(String name) {
    final clean = name.trim().toUpperCase();
    return clean.length > 4 ? clean.substring(clean.length - 4) : clean;
  }
}
