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
  static final ProvisioningService instance = ProvisioningService();

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _commChar;
  StreamSubscription<List<int>>? _notifySub;
  final StreamController<String> _notifications = StreamController<String>.broadcast();

  BluetoothDevice? get connectedDevice => _connectedDevice;
  Stream<String> get notifications => _notifications.stream;
  bool get isConnected => _connectedDevice != null && _connectedDevice!.isConnected;

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

        final id = r.device.remoteId.str;
        final existing = discoveredMap[id];

        final upper = name.toUpperCase();
        final hasMatchingName = upper.startsWith(BleConstants.bleNamePrefix) ||
            upper.startsWith(BleConstants.bleAltPrefix) ||
            upper.contains('SHUDDHAM') ||
            upper.contains('SHD');

        final hasMatchingService = r.advertisementData.serviceUuids.any((u) {
          final s = u.str.toLowerCase();
          return s.contains('abf0') ||
              s.contains('00ff') ||
              s == BleConstants.bleAdvertisedServiceUuid.toLowerCase() ||
              s == BleConstants.bleGattServiceUuid.toLowerCase();
        });

        // Strict filter: ONLY accept genuine Shuddham purifier devices
        final isPurifierDevice = hasMatchingName || hasMatchingService;

        if (isPurifierDevice) {
          // Retain real discovered name if subsequent packets have empty name
          String displayName = name;
          if (displayName.isEmpty && existing != null && existing.name.isNotEmpty) {
            displayName = existing.name;
          }
          if (displayName.isEmpty) {
            final macClean = id.replaceAll(':', '').replaceAll('-', '').toUpperCase();
            final tail = macClean.length >= 4 ? macClean.substring(macClean.length - 4) : macClean;
            displayName = 'SHUDDHAM-$tail';
          }

          discoveredMap[id] = DiscoveredBleDevice(
            device: r.device,
            name: displayName,
            rssi: r.rssi,
            isPurifier: true,
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

  /// Connects to the ESP32, discovers Service 0x00FF and Char 0xFF01,
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

    // Settle connection completely before discovering services
    await Future.delayed(const Duration(milliseconds: 1000));

    debugPrint('[BLE] 2. Discovering services...');
    final services = await device.discoverServices();
    await Future.delayed(const Duration(milliseconds: 1200));

    BluetoothCharacteristic? writeChar;
    BluetoothCharacteristic? notifyChar;

    for (final s in services) {
      final sUuid = s.uuid.str.toLowerCase();
      debugPrint('[BLE Discovery] Found Service: $sUuid');
      for (final c in s.characteristics) {
        final cUuid = c.uuid.str.toLowerCase();
        final descUuids = c.descriptors.map((d) => d.uuid.str.toLowerCase()).toList();
        debugPrint('[BLE Discovery]   -> Char: $cUuid (write: ${c.properties.write}, writeWithoutResp: ${c.properties.writeWithoutResponse}, notify: ${c.properties.notify}) Descriptors: $descUuids');
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
        debugPrint('[BLE] 3. Enabling notifications on characteristic: ${activeNotifyChar.uuid.str}...');
        try {
          await Future.delayed(const Duration(milliseconds: 1000));
          await activeNotifyChar.setNotifyValue(true, timeout: 15);
          debugPrint('[BLE] Notifications listener registered.');
          await Future.delayed(const Duration(milliseconds: 1000));
        } catch (e) {
          debugPrint('[BLE] setNotifyValue notice (settling GATT queue): $e');
          // If setNotifyValue timed out or had an error, wait for Android GATT queue to clear
          await Future.delayed(const Duration(milliseconds: 2500));
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 800));
    debugPrint('''
╔══════════════════════════════════════════════════════════════╗
║ 🔵 [BLUETOOTH CONNECTED] Purifier: ${_connectedDevice?.remoteId.str}
║ 📡 BLE Service: 0x00FF | Characteristic: 0xFF01
║ ✅ Status: Ready to receive commands (WSCAN / Provisioning)
╚══════════════════════════════════════════════════════════════╝''');
  }

  /// Writes ASCII command to BLE Characteristic with robust queue-busy retry logic.
  Future<void> _writeAscii(String command, {int? timeoutSeconds}) async {
    if (_commChar == null) throw Exception('Device not connected over BLE.');
    final canWrite = _commChar!.properties.write;
    final canWriteWithoutResp = _commChar!.properties.writeWithoutResponse;
    final bool useWithoutResponse = !canWrite && canWriteWithoutResp;
    final int timeout = timeoutSeconds ?? BleConstants.writeTimeout.inSeconds;

    debugPrint('''
╔══════════════════════════════════════════════════════════════╗
║ 📤 [BLE COMMAND TRANSMITTED] >>> "$command" (withoutResponse: $useWithoutResponse, timeout: ${timeout}s)
╚══════════════════════════════════════════════════════════════╝''');
    final bytes = utf8.encode(command);

    Object? lastError;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        if (attempt > 1) {
          await Future.delayed(Duration(milliseconds: attempt * 300));
        }
        await _commChar!.write(
          bytes,
          withoutResponse: useWithoutResponse,
          timeout: timeout,
        );
        debugPrint('✅ [BLE COMMAND ACKNOWLEDGED] >>> "$command"');
        return;
      } catch (e) {
        lastError = e;
        final errStr = e.toString();
        debugPrint('[BLE Write] Attempt $attempt failed: $e');
        if (errStr.contains('201') || errStr.contains('BUSY') || errStr.contains('busy')) {
          await Future.delayed(Duration(milliseconds: 600 * attempt));
        } else {
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }
    }
    if (lastError != null) throw lastError;
  }

  /// Sends a raw command (e.g. "F,0", "F,1") to the connected purifier over BLE.
  Future<bool> sendRawCommand(String command) async {
    if (_commChar == null) return false;
    try {
      await _writeAscii(command);
      return true;
    } catch (e) {
      debugPrint('[BLE Command Error] $e');
      return false;
    }
  }

  /// Attempts to send command over BLE. If not already connected,
  /// tries to connect to the target device or scans for the purifier in range.
  Future<bool> sendBleCommandAuto({String? targetDeviceId, required String command}) async {
    // 1. If already connected, send directly
    if (_commChar != null && _connectedDevice != null && _connectedDevice!.isConnected) {
      return await sendRawCommand(command);
    }

    // 2. If Bluetooth is turned off, skip gracefully
    try {
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        debugPrint('[BLE] Bluetooth is off, skipping BLE command');
        return false;
      }
    } catch (_) {
      return false;
    }

    // 3. Try connecting directly by ID if provided
    if (targetDeviceId != null && targetDeviceId.isNotEmpty) {
      try {
        debugPrint('[BLE Auto-Connect] Trying direct connect to: $targetDeviceId');
        final bleDevice = BluetoothDevice.fromId(targetDeviceId);
        await connect(bleDevice).timeout(const Duration(seconds: 4));
        if (_commChar != null) {
          return await sendRawCommand(command);
        }
      } catch (e) {
        debugPrint('[BLE Direct Connect Error] $e');
      }
    }

    // 4. Quick scan (3 seconds) for any nearby Shuddham purifier
    try {
      debugPrint('[BLE Quick Scan] Scanning for nearby purifier...');
      final discovered = await scanDevices(timeout: const Duration(seconds: 3));
      for (final d in discovered) {
        if (d.isPurifier || d.name.toUpperCase().contains('SHUDDHAM') || d.name.toUpperCase().startsWith('SHD-')) {
          debugPrint('[BLE Quick Scan] Found purifier: ${d.name} (${d.device.remoteId}). Connecting...');
          await connect(d.device).timeout(const Duration(seconds: 4));
          if (_commChar != null) {
            return await sendRawCommand(command);
          }
        }
      }
    } catch (e) {
      debugPrint('[BLE Quick Scan Error] $e');
    }

    return false;
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
    Timer? settleTimer;

    String currentRawBuffer = '';
    int currentIndex = 0;

    void finalizeCurrentEntry() {
      if (currentRawBuffer.trim().isEmpty) return;
      String text = currentRawBuffer.trim();
      int sec = 1;

      // Extract trailing security flag like [1], [0], [2]
      final secMatch = RegExp(r'\[(\d+)\]\s*$').firstMatch(text);
      if (secMatch != null) {
        sec = int.tryParse(secMatch.group(1) ?? '1') ?? 1;
        text = text.substring(0, secMatch.start).trim();
      }
      // Remove any leftover bracket fragments
      text = text.replaceAll(RegExp(r'\[\d*\]?$'), '').trim();

      // Reject non-SSID noise tokens
      if (text.isNotEmpty &&
          text != '[1]' &&
          text != '[0]' &&
          text != ']' &&
          !text.toLowerCase().contains('found wifi') &&
          !seenSsids.contains(text.toLowerCase())) {
        seenSsids.add(text.toLowerCase());
        final realIdx = currentIndex > 0 ? currentIndex : networks.length + 1;
        networks.add(BleWifiNetwork(index: realIdx, ssid: text, security: sec));
        debugPrint('📶 [PURIFIER WI-FI READY] #$realIdx: "$text" (${sec == 0 ? "Open" : "Secured"})');
      }
      currentRawBuffer = '';
    }

    final sub = _notifications.stream.listen((msg) {
      debugPrint('[BLE Scan Msg] $msg');
      final trimmed = msg.trim();
      if (trimmed.isEmpty) return;

      if (trimmed.startsWith('Found WiFi:')) {
        finalizeCurrentEntry();
        final countStr = trimmed.replaceFirst('Found WiFi:', '').trim();
        expectedCount = int.tryParse(countStr) ?? -1;
        debugPrint('📊 [PURIFIER WI-FI SCAN] Hardware reported total networks: $expectedCount');
        if (expectedCount == 0 && !completer.isCompleted) {
          settleTimer?.cancel();
          completer.complete([]);
        }
        return;
      }

      // Check if this line starts a NEW numbered network entry e.g. "[1]:", "[12]:"
      if (trimmed.startsWith('[') && trimmed.contains(']:')) {
        finalizeCurrentEntry();
        final closeIdx = trimmed.indexOf(']:');
        currentIndex = int.tryParse(trimmed.substring(1, closeIdx)) ?? (networks.length + 1);
        currentRawBuffer = trimmed.substring(closeIdx + 2).trim();

        // If the entry was short and completed in this single packet (e.g. "tulsi[2]")
        if (RegExp(r'\[\d+\]\s*$').hasMatch(currentRawBuffer)) {
          finalizeCurrentEntry();
        }
      } else if (currentRawBuffer.isNotEmpty) {
        // Continuation chunk of the current network (e.g. "IES_4G[1]" or "]" or "[1]")
        currentRawBuffer += trimmed;
        if (RegExp(r'\[\d+\]\s*$').hasMatch(currentRawBuffer) || currentRawBuffer.endsWith(']')) {
          finalizeCurrentEntry();
        }
      } else if (RegExp(r'^\d+[\:\.\-]\s*').hasMatch(trimmed)) {
        finalizeCurrentEntry();
        final match = RegExp(r'^\d+[\:\.\-]\s*').firstMatch(trimmed)!;
        currentIndex = int.tryParse(trimmed.substring(0, match.end - 1).replaceAll(RegExp(r'[^\d]'), '')) ?? (networks.length + 1);
        currentRawBuffer = trimmed.substring(match.end).trim();
        if (RegExp(r'\[\d+\]\s*$').hasMatch(currentRawBuffer)) {
          finalizeCurrentEntry();
        }
      }

      settleTimer?.cancel();
      settleTimer = Timer(const Duration(milliseconds: 2500), () {
        finalizeCurrentEntry();
        if (!completer.isCompleted && networks.isNotEmpty) {
          completer.complete(networks);
        }
      });

      if (expectedCount > 0 && networks.length >= expectedCount && !completer.isCompleted) {
        finalizeCurrentEntry();
        settleTimer?.cancel();
        completer.complete(networks);
      }
    });

    try {
      debugPrint('''
╔══════════════════════════════════════════════════════════════╗
║ 🔍 [HARDWARE WI-FI SCAN STARTED] Sending "WSCAN" to Purifier...
╚══════════════════════════════════════════════════════════════╝''');
      try {
        await _writeAscii('WSCAN', timeoutSeconds: 25);
      } catch (writeErr) {
        debugPrint('[BLE WSCAN Write Notice] $writeErr');
      }

      final result = await completer.future.timeout(
        timeout,
        onTimeout: () {
          finalizeCurrentEntry();
          return networks;
        },
      );

      final listSummary = result.map((n) => '║   • [${n.index}] ${n.ssid} (${n.isOpen ? "Open" : "Secured"})').join('\n');
      debugPrint('''
╔══════════════════════════════════════════════════════════════╗
║ 📋 [PURIFIER WI-FI SCAN COMPLETE]
║ 🔢 Total Networks Visible to Hardware: ${result.length}
$listSummary
╚══════════════════════════════════════════════════════════════╝''');
      return result;
    } finally {
      settleTimer?.cancel();
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

    debugPrint('''
╔══════════════════════════════════════════════════════════════╗
║ 🚀 [WI-FI PROVISIONING STARTED]
║ 📶 Target SSID: "$cleanSsid"
║ 🔑 Password: ${cleanPass.isEmpty ? "(None / Open)" : "********"}
╚══════════════════════════════════════════════════════════════╝''');

    final completer = Completer<bool>();

    if (!isConnected) {
      throw StateError('Purifier Bluetooth is not connected.');
    }

    bool credentialsDelivered = false;

    final sub = _notifications.stream.listen((msg) {
      debugPrint('[BLE Provision Msg] $msg');
      final lower = msg.toLowerCase();
      if ((lower.contains('conected') || lower.contains('connected') || lower.contains('wifi ok') || lower.contains('ip:')) &&
          !lower.contains('not')) {
        debugPrint('''
╔══════════════════════════════════════════════════════════════╗
║ 🎉 [PURIFIER WI-FI CONNECTED SUCCESSFULLY]
║ 📶 Network: "$cleanSsid"
║ ✅ ESP32 Purifier has connected to Wi-Fi!
╚══════════════════════════════════════════════════════════════╝''');
        if (!completer.isCompleted) completer.complete(true);
      } else if (lower.contains('not conected') || lower.contains('not connected') || lower.contains('fail') || lower.contains('error')) {
        debugPrint('''
╔══════════════════════════════════════════════════════════════╗
║ ❌ [PURIFIER WI-FI CONNECTION FAILED]
║ ⚠️ ESP32 returned: Not Connected / Failed
╚══════════════════════════════════════════════════════════════╝''');
        if (!completer.isCompleted) completer.complete(false);
      }
    });

    StreamSubscription? connSub;
    if (_connectedDevice != null) {
      connSub = _connectedDevice!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          if (credentialsDelivered) {
            debugPrint('''
╔══════════════════════════════════════════════════════════════╗
║ 📡 [BLE DISCONNECTED - EXPECTED ON WI-FI JOIN]
║ Firmware turned off BLE to enter Wi-Fi MQTT mode.
╚══════════════════════════════════════════════════════════════╝''');
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (!completer.isCompleted) {
                completer.complete(true);
              }
            });
          } else {
            debugPrint('⚠️ [BLE] Disconnected BEFORE credentials were fully transmitted.');
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          }
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
      
      // Both credentials successfully transmitted
      credentialsDelivered = true;

      // 3. Wait for connection result
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          debugPrint('⚠️ [BLE] Timeout waiting for WiFi connection result from ESP32');
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
    } on TimeoutException {
      debugPrint('[BLE] Timed out waiting for ack to $command (command was transmitted)');
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
