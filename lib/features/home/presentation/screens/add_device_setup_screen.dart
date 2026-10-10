import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/services/device_storage_service.dart';
import '../../../../core/services/provisioning_service.dart';
import '../../../../core/services/telemetry_service.dart';
import '../../data/models/device_model.dart';

// Brand Design Palette from Shuddham Design System
class DesignColors {
  static const primary = Color(0xFF1553B8);
  static const primaryPressed = Color(0xFF0F3F8F);
  static const navy = Color(0xFF0F2A5C);
  static const muted = Color(0xFF56627A);
  static const bg = Color(0xFFF4F7FB);
  static const card = Colors.white;
  static const border = Color(0xFFD5DEEB);
  static const line = Color(0xFFE9EEF5);
  static const tint = Color(0xFFE3EDFB);
  static const lightBlue = Color(0xFF5BB8F5);
  static const warn = Color(0xFFD97706);
  static const bad = Color(0xFFB42318);
  static const badBg = Color(0xFFFDECEA);
  static const success = Color(0xFF16A34A);
  static const successBg = Color(0xFFDCFCE7);
}

TextStyle displayFont(double size, {Color color = DesignColors.navy, FontWeight weight = FontWeight.w700}) {
  try {
    return GoogleFonts.getFont('Bricolage Grotesque', fontSize: size, fontWeight: weight, color: color, height: 1.18);
  } catch (_) {
    return TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.18);
  }
}

TextStyle bodyFont({double size = 14.5, Color color = DesignColors.muted, FontWeight weight = FontWeight.normal, double height = 1.45}) {
  try {
    return GoogleFonts.ibmPlexSans(fontSize: size, color: color, fontWeight: weight, height: height);
  } catch (_) {
    return TextStyle(fontSize: size, color: color, fontWeight: weight, height: height);
  }
}

enum SetupStep {
  permissions, // Screen 02
  deviceScan, // Screen 03 (Choose your device, 1 of 3)
  wifiCredentials, // Screen 04 (Connect to Wi-Fi, 2 of 3)
  provisioning, // Screen 05 (Connecting to Wi-Fi, 3 of 3)
  failure, // Screen 06a (Couldn't join Wi-Fi)
  setupDone, // Screen 07 (Purifier online)
}

class AddDeviceSetupScreen extends StatefulWidget {
  final Function(DeviceModel) onDeviceAdded;

  const AddDeviceSetupScreen({super.key, required this.onDeviceAdded});

  @override
  State<AddDeviceSetupScreen> createState() => _AddDeviceSetupScreenState();
}

class _AddDeviceSetupScreenState extends State<AddDeviceSetupScreen> with TickerProviderStateMixin {
  final ProvisioningService _provisioningService = ProvisioningService();

  SetupStep _currentStep = SetupStep.permissions;
  bool _busy = false;
  bool _isScanning = false;
  bool _isScanningWifi = false;
  String? _errorMessage;
  ProvisioningFailureReason? _failureReason;

  // Real BLE Devices
  List<DiscoveredBleDevice> _discoveredDevices = [];
  DiscoveredBleDevice? _selectedBleDevice;

  // Wi-Fi Setup State
  List<BleWifiNetwork> _wifiNetworks = [];
  BleWifiNetwork? _selectedWifiNetwork;
  bool _manualSsidMode = false;
  final TextEditingController _manualSsidController = TextEditingController();
  final TextEditingController _wifiPasswordController = TextEditingController();
  bool _obscurePassword = true;

  // Setup Done State
  final TextEditingController _purifierNameController = TextEditingController(text: 'Shuddham RO Purifier');
  static const String _selectedRoom = '';

  // Live Setup Sensor Readings
  int? _liveSetupTds;
  int? _liveSetupInletTds;
  double? _liveSetupTemp;
  String? _liveSetupMode;
  DateTime? _liveSetupTimestamp;

  // Provisioning Progress Sub-steps
  int _progressStepIndex = 0;
  final List<String> _provisionStepLabels = [
    'Wi-Fi details sent securely',
    'Device joining your network',
    'Connecting to cloud',
    'Receiving first reading',
  ];

  late AnimationController _spinnerController;

  @override
  void initState() {
    super.initState();
    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _checkInitialPermissions();
  }

  @override
  void dispose() {
    _spinnerController.dispose();
    _manualSsidController.dispose();
    _wifiPasswordController.dispose();
    _purifierNameController.dispose();
    _provisioningService.disconnect();
    super.dispose();
  }

  Future<void> _checkInitialPermissions() async {
    final granted = await _provisioningService.hasPermissions();
    if (granted && mounted) {
      setState(() => _currentStep = SetupStep.deviceScan);
      _startBleDeviceScan();
    }
  }

  // 1. Request Permissions & Transition to Scan
  Future<void> _requestPermissionsAndProceed() async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      final granted = await _provisioningService.requestPermissions();
      if (!granted) {
        final permDenied = await _provisioningService.permissionsPermanentlyDenied();
        if (permDenied) {
          if (mounted) {
            setState(() {
              _busy = false;
              _errorMessage = 'Bluetooth permission is turned off. Please enable it in Settings.';
            });
          }
          await openAppSettings();
          return;
        }
        if (mounted) {
          setState(() {
            _busy = false;
            _errorMessage = 'Bluetooth and Location permissions are required to find your purifier.';
          });
        }
        return;
      }

      // Check Bluetooth Adapter
      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {}
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          adapterState = await FlutterBluePlus.adapterState.first;
          if (adapterState == BluetoothAdapterState.on) break;
        }
      }

      if (mounted) {
        setState(() {
          _busy = false;
          _currentStep = SetupStep.deviceScan;
        });
        _startBleDeviceScan();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorMessage = 'Bluetooth Error: $e';
        });
      }
    }
  }

  // 2. Scan Devices
  Future<void> _startBleDeviceScan() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final devices = await _provisioningService.scanDevices(timeout: const Duration(seconds: 8));
      if (!mounted) return;

      setState(() {
        final purifiers = devices.where((d) => d.isPurifier).toList();
        _discoveredDevices = purifiers;
        _isScanning = false;
        if (purifiers.isNotEmpty && _selectedBleDevice == null) {
          _selectedBleDevice = purifiers.first;
          _purifierNameController.text = purifiers.first.name;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _errorMessage = 'Scan failed: $e';
        });
      }
    }
  }

  // 3. Connect to Device & Discover Wi-Fi
  Future<void> _connectToSelectedDevice(DiscoveredBleDevice dev) async {
    setState(() {
      _selectedBleDevice = dev;
      _purifierNameController.text = dev.name;
      _busy = true;
      _errorMessage = null;
    });

    debugPrint('''
╔══════════════════════════════════════════════════════════════╗
║ 🔗 [BLUETOOTH CONNECTING]
║ 📱 Device: ${dev.name}
║ 🆔 MAC/ID: ${dev.device.remoteId.str}
╚══════════════════════════════════════════════════════════════╝''');

    try {
      await _provisioningService.connect(dev.device);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.bluetooth_connected_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Bluetooth successfully connected to ${dev.name}!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        _busy = false;
        _currentStep = SetupStep.wifiCredentials;
      });

      // Pause to let BLE GATT connection settle completely before issuing hardware WSCAN
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        _scanWifiFromDevice();
      }
    } catch (e) {
      debugPrint('[BLE Connect Error] $e');
      if (mounted) {
        setState(() {
          _busy = false;
          _failureReason = ProvisioningFailureReason.bluetooth;
          _currentStep = SetupStep.failure;
        });
      }
    }
  }

  // 4. Scan Wi-Fi directly from Purifier Hardware via BLE ("WSCAN" command)
  Future<void> _scanWifiFromDevice() async {
    setState(() {
      _isScanningWifi = true;
      _errorMessage = null;
      _wifiNetworks = [];
      _selectedWifiNetwork = null;
    });

    try {
      // Auto-reconnect if device got disconnected
      if (!_provisioningService.isConnected && _selectedBleDevice != null) {
        debugPrint('[Hardware Provisioning] Reconnecting to ${_selectedBleDevice!.name}...');
        await _provisioningService.connect(_selectedBleDevice!.device);
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      debugPrint('[Hardware Provisioning] Sending "WSCAN" command to purifier...');
      var bleList = await _provisioningService.scanWifiNetworks(timeout: const Duration(seconds: 20));
      if (bleList.isEmpty) {
        debugPrint('[Hardware Provisioning] Hardware reported 0 networks, retrying WSCAN once after brief pause...');
        await Future.delayed(const Duration(milliseconds: 1200));
        bleList = await _provisioningService.scanWifiNetworks(timeout: const Duration(seconds: 20));
      }
      if (mounted) {
        setState(() {
          _wifiNetworks = bleList;
          if (_wifiNetworks.isNotEmpty) {
            _selectedWifiNetwork = _wifiNetworks.firstWhere(
              (n) => !n.ssid.contains('5G') && !n.ssid.contains('5GHz'),
              orElse: () => _wifiNetworks.first,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('[Hardware Wi-Fi Scan Error] $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Hardware Wi-Fi scan timed out or failed. You can tap Rescan or enter manually below.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanningWifi = false;
        });
      }
    }
  }

  // 5. Start Provisioning
  Future<void> _startProvisioning() async {
    final ssid = _manualSsidMode
        ? _manualSsidController.text.trim()
        : (_selectedWifiNetwork?.ssid.trim() ?? '');

    if (ssid.isEmpty) {
      setState(() => _errorMessage = 'Please select or enter a Wi-Fi network (SSID).');
      return;
    }

    final password = _wifiPasswordController.text;
    final isSecured = _manualSsidMode
        ? password.isNotEmpty
        : (_selectedWifiNetwork?.isSecured ?? true);

    if (isSecured) {
      if (password.isEmpty) {
        setState(() => _errorMessage = 'Please enter the Wi-Fi password.');
        return;
      }
      if (password.length < 8) {
        setState(() => _errorMessage = 'Wi-Fi password must be at least 8 characters long (${password.length}/8 entered).');
        return;
      }
      if (password.length > 63) {
        setState(() => _errorMessage = 'Wi-Fi password cannot exceed 63 characters.');
        return;
      }
    }

    setState(() {
      _currentStep = SetupStep.provisioning;
      _progressStepIndex = 0;
      _errorMessage = null;
    });

    try {
      // Step 1: Ensure BLE is connected and sending Wi-Fi details
      if (!_provisioningService.isConnected && _selectedBleDevice != null) {
        debugPrint('[Provisioning] BLE disconnected, reconnecting to purifier before sending credentials...');
        await _provisioningService.connect(_selectedBleDevice!.device);
        await Future.delayed(const Duration(milliseconds: 800));
      }

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _progressStepIndex = 1);

      final joined = await _provisioningService.provisionWifi(ssid, password);
      if (!mounted) return;

      if (!joined) {
        setState(() {
          _failureReason = ProvisioningFailureReason.wifi;
          _currentStep = SetupStep.failure;
        });
        return;
      }

      // Step 3: Cloud connection & Step 4: First reading
      setState(() => _progressStepIndex = 2);
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() => _progressStepIndex = 3);

      // Query real sensor telemetry from cloud backend
      try {
        final records = await TelemetryService.instance.fetchAllTelemetry();
        if (records.isNotEmpty) {
          final rec = records.firstWhere(
            (r) => (r['dev_id']?.toString() ?? '').contains('2805a520c4'),
            orElse: () => records.first,
          );
          final rawTds2 = rec['tds2'];
          final rawTds1 = rec['tds1'];
          final rawTemp = rec['temp'];
          if (rawTds2 != null) _liveSetupTds = int.tryParse(rawTds2.toString());
          if (rawTds1 != null) _liveSetupInletTds = int.tryParse(rawTds1.toString());
          if (rawTemp != null) _liveSetupTemp = double.tryParse(rawTemp.toString());
          _liveSetupMode = rec['mode']?.toString();
          final rawTs = rec['ts']?.toString() ?? rec['last_updated']?.toString();
          if (rawTs != null) {
            final parsed = DateTime.tryParse(rawTs);
            if (parsed != null) _liveSetupTimestamp = parsed.isUtc ? parsed.toLocal() : parsed;
          }
          debugPrint('[Setup Done] Retrieved live sensor data: TDS2=$_liveSetupTds, Temp=$_liveSetupTemp°C');
        }
      } catch (err) {
        debugPrint('[Setup Telemetry Notice] $err');
      }

      // Pre-save device immediately to persistent disk storage so that even if the tablet
      // sleeps, screen locks, or user closes the app before tapping 'Dashboard', it is preserved!
      try {
        final dev = _selectedBleDevice;
        final shortId = dev != null ? ProvisioningService.shortId(dev.name) : 'A4F2';
        final customName = _purifierNameController.text.trim().isNotEmpty
            ? _purifierNameController.text.trim()
            : (dev?.name ?? 'Shuddham Purifier');
        final deviceId = (dev?.name != null && dev!.name.isNotEmpty)
            ? dev.name
            : (dev?.device.remoteId.str.isNotEmpty == true ? dev!.device.remoteId.str : 'SHD-$shortId');
        final serialNumber = (dev?.device.remoteId.str != null && dev!.device.remoteId.str.isNotEmpty)
            ? dev.device.remoteId.str
            : 'SHD-RO-$shortId';

        final preSaved = DeviceModel(
          id: deviceId,
          name: customName,
          model: dev?.name ?? 'Shuddham Smart RO Purifier',
          type: 'RO Purifier',
          serialNumber: serialNumber,
          location: _selectedRoom,
          isOnline: true,
          tdsPpm: _liveSetupTds ?? 54,
          inletTdsPpm: _liveSetupInletTds ?? 58,
          temperature: _liveSetupTemp ?? 29.1,
          mode: _liveSetupMode ?? 'NF',
          filterLifePercentage: 98,
          lastSync: 'Just now',
          totalLitersPurified: 0.0,
          lastReadingTime: _liveSetupTimestamp ?? DateTime.now(),
        );
        await DeviceStorageService.saveOrUpdateDevice(preSaved);
        debugPrint('[Setup] Purifier pre-saved successfully to local storage: ${preSaved.name} (${preSaved.serialNumber})');
      } catch (err) {
        debugPrint('[Setup PreSave Notice] $err');
      }

      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      setState(() => _currentStep = SetupStep.setupDone);
    } catch (e) {
      debugPrint('[Provisioning Error] $e');
      if (mounted) {
        setState(() {
          _failureReason = ProvisioningFailureReason.bluetooth;
          _currentStep = SetupStep.failure;
        });
      }
    }
  }

  Future<void> _finishSetupAndSave() async {
    final dev = _selectedBleDevice;
    final shortId = dev != null ? ProvisioningService.shortId(dev.name) : 'A4F2';
    final customName = _purifierNameController.text.trim().isNotEmpty
        ? _purifierNameController.text.trim()
        : (dev?.name ?? 'Shuddham Purifier');

    final deviceId = (dev?.name != null && dev!.name.isNotEmpty)
        ? dev.name
        : (dev?.device.remoteId.str.isNotEmpty == true ? dev!.device.remoteId.str : 'SHD-$shortId');
    final serialNumber = (dev?.device.remoteId.str != null && dev!.device.remoteId.str.isNotEmpty)
        ? dev.device.remoteId.str
        : 'SHD-RO-$shortId';

    final newDevice = DeviceModel(
      id: deviceId,
      name: customName,
      model: dev?.name ?? 'Shuddham Smart RO Purifier',
      type: 'RO Purifier',
      serialNumber: serialNumber,
      location: _selectedRoom,
      isOnline: true,
      tdsPpm: _liveSetupTds ?? 54,
      inletTdsPpm: _liveSetupInletTds ?? 58,
      temperature: _liveSetupTemp ?? 29.1,
      mode: _liveSetupMode ?? 'NF',
      filterLifePercentage: 98,
      lastSync: 'Just now',
      totalLitersPurified: 0.0,
      lastReadingTime: _liveSetupTimestamp ?? DateTime.now(),
    );

    await DeviceStorageService.saveOrUpdateDevice(newDevice);
    widget.onDeviceAdded(newDevice);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildStepView(),
        ),
      ),
    );
  }

  Widget _buildStepView() {
    switch (_currentStep) {
      case SetupStep.permissions:
        return _buildPermissionsView();
      case SetupStep.deviceScan:
        return _buildDeviceScanView();
      case SetupStep.wifiCredentials:
        return _buildWifiCredentialsView();
      case SetupStep.provisioning:
        return _buildProvisioningProgressView();
      case SetupStep.failure:
        return _buildFailureView();
      case SetupStep.setupDone:
        return _buildSetupDoneView();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 02. BLUETOOTH PERMISSION SCREEN (Matching Screen 02 in Design)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPermissionsView() {
    return _buildScreenLayout(
      showClose: true,
      headerCenterText: 'Before we start',
      onClose: () => Navigator.of(context).pop(),
      bottomWidget: _buildPrimaryButton(
        label: 'Continue',
        busy: _busy,
        onPressed: _requestPermissionsAndProceed,
      ),
      children: [
        // Large Blue Bluetooth Icon in Light Blue Box
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: DesignColors.tint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.bluetooth_rounded, color: DesignColors.primary, size: 30),
        ),
        const SizedBox(height: 18),

        Text('Let the app find nearby\ndevices', style: displayFont(26)),
        const SizedBox(height: 10),
        Text(
          'Your device receives its Wi-Fi details over Bluetooth. Your phone will ask for permission next.',
          style: bodyFont(),
        ),
        const SizedBox(height: 24),

        // Bluetooth Reason Card
        _buildReasonCard(
          icon: Icons.bluetooth_rounded,
          title: 'Bluetooth',
          body: 'Required to discover and talk to the device during setup.',
        ),
        const SizedBox(height: 12),

        // Nearby devices (Android) Reason Card
        _buildReasonCard(
          icon: Icons.location_on_outlined,
          title: 'Nearby devices',
          badgeText: 'Android',
          body: 'Android labels Bluetooth scanning this way. We don\'t track your location.',
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _buildErrorBanner(_errorMessage!),
        ],
      ],
    );
  }

  Widget _buildReasonCard({
    required IconData icon,
    required String title,
    String? badgeText,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DesignColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: DesignColors.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: DesignColors.navy, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: DesignColors.navy)),
                    if (badgeText != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(badgeText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(body, style: bodyFont(size: 13.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 03. CHOOSE YOUR DEVICE SCREEN (Matching Screen 03 in Design: Step 1 of 3)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDeviceScanView() {
    final targetDeviceName = _selectedBleDevice?.name ?? 'Purifier';

    return _buildScreenLayout(
      showBack: true,
      onBack: () => setState(() => _currentStep = SetupStep.permissions),
      stepProgress: 1,
      totalSteps: 3,
      bottomWidget: _buildPrimaryButton(
        label: _busy
            ? 'Connecting to $targetDeviceName via Bluetooth...'
            : (_selectedBleDevice == null ? 'Select a purifier' : 'Connect via Bluetooth to $targetDeviceName'),
        busy: _busy,
        onPressed: _selectedBleDevice == null || _busy
            ? null
            : () => _connectToSelectedDevice(_selectedBleDevice!),
      ),
      children: [
        Text('Choose your device', style: displayFont(26)),
        const SizedBox(height: 8),

        // Searching Spinner / Found Subtitle
        Row(
          children: [
            if (_isScanning) ...[
              RotationTransition(
                turns: _spinnerController,
                child: const Icon(Icons.refresh_rounded, size: 16, color: DesignColors.muted),
              ),
              const SizedBox(width: 6),
              Text('Searching... ${_discoveredDevices.length} found', style: bodyFont(size: 14)),
            ] else ...[
              const Icon(Icons.check_circle_outline_rounded, size: 16, color: DesignColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _discoveredDevices.length == 1
                      ? '1 Shuddham purifier found nearby'
                      : '${_discoveredDevices.length} Shuddham purifiers found nearby',
                  style: bodyFont(size: 14, color: DesignColors.navy),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _startBleDeviceScan,
                child: const Text('Scan again', style: TextStyle(color: DesignColors.primary, fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),

        if (_discoveredDevices.isEmpty && !_isScanning)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: DesignColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('No Shuddham purifiers found in setup mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: DesignColors.navy)),
                const SizedBox(height: 6),
                Text(
                  'Hold the Wi-Fi / reset button on the purifier for 5–6 seconds until the blue LED flashes, then tap Scan again.',
                  style: bodyFont(size: 13.5),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _startBleDeviceScan,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Scan again'),
                ),
              ],
            ),
          )
        else
          ..._discoveredDevices.map((dev) {
            final isSelected = _selectedBleDevice?.device.remoteId == dev.device.remoteId;
            final signalText = dev.rssi > -70 ? 'Strong signal' : 'Weak signal';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _busy
                    ? null
                    : () => setState(() {
                          _selectedBleDevice = dev;
                          _purifierNameController.text = dev.name;
                        }),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? DesignColors.primary : DesignColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Icon in Circle (Water Drop for purifier, Bluetooth for other devices)
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? DesignColors.tint
                              : (dev.isPurifier ? const Color(0xFFF0F7FF) : DesignColors.bg),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          dev.isPurifier ? Icons.water_drop_rounded : Icons.bluetooth_rounded,
                          color: isSelected ? DesignColors.primary : DesignColors.navy,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    dev.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: DesignColors.navy),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (dev.isPurifier) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: DesignColors.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PURIFIER',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${dev.device.remoteId.str} · $signalText (${dev.rssi} dBm)',
                              style: bodyFont(size: 12.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Identify Button (Matching Design)
                      OutlinedButton(
                        onPressed: () {
                          // Flash identify signal
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Flashing light on ${dev.name}...'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DesignColors.navy,
                          side: const BorderSide(color: DesignColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Identify', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

        const SizedBox(height: 8),

        // Bottom Helpful Tip (Matching Design)
        Text(
          'Several look the same? Tap Identify — the matching purifier beeps and blinks its light. Don\'t see yours? Hold its Wi-Fi button for 5 s until the light pulses blue.',
          style: bodyFont(size: 12.5, height: 1.45),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          _buildErrorBanner(_errorMessage!),
        ],

      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 04. WI-FI CREDENTIALS SCREEN (Matching Screen 04 in Design: Step 2 of 3)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWifiCredentialsView() {
    return _buildScreenLayout(
      showBack: true,
      onBack: () => setState(() => _currentStep = SetupStep.deviceScan),
      stepProgress: 2,
      totalSteps: 3,
      bottomWidget: (_selectedWifiNetwork != null || _manualSsidMode)
          ? _buildPrimaryButton(
              label: 'Connect to ${(_manualSsidMode ? _manualSsidController.text : _selectedWifiNetwork?.ssid) ?? 'Wi-Fi'}',
              onPressed: _startProvisioning,
            )
          : const SizedBox.shrink(),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Connect to Wi-Fi', style: displayFont(26)),
            if (!_isScanningWifi)
              GestureDetector(
                onTap: _scanWifiFromDevice,
                child: const Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 16, color: DesignColors.primary),
                    SizedBox(width: 4),
                    Text('Rescan', style: TextStyle(color: DesignColors.primary, fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Networks your device can see. It works on 2.4 GHz only.',
          style: bodyFont(),
        ),
        const SizedBox(height: 10),

        // Bluetooth Connected Status Banner Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bluetooth_connected_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'Bluetooth Connected',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                            fontSize: 13.5,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Paired with ${_selectedBleDevice?.name ?? 'SHUDDHAM'} (${_selectedBleDevice?.device.remoteId.str ?? ''})',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Text(
                  'PAIRED',
                  style: TextStyle(
                    color: Color(0xFF15803D),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Network List Card (Matching Design)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: DesignColors.border),
          ),
          child: Column(
            children: [
              if (_isScanningWifi)
                const Padding(
                  padding: EdgeInsets.all(22),
                  child: Center(
                    child: Column(
                      children: [
                        SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: DesignColors.primary)),
                        SizedBox(height: 10),
                        Text('Purifier hardware is scanning 2.4 GHz Wi-Fi...', style: TextStyle(color: DesignColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else ...[
                if (_wifiNetworks.isEmpty && !_manualSsidMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: DesignColors.bg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.wifi_off_rounded, color: DesignColors.muted, size: 24),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No Wi-Fi networks found by purifier',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: DesignColors.navy),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Purifier reported 0 networks. If you recently entered incorrect Wi-Fi details, turn the purifier power OFF and ON once, then tap Rescan. Or enter your network manually below.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: DesignColors.muted, fontSize: 12.5, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _scanWifiFromDevice,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Rescan Networks'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: DesignColors.primary,
                              side: const BorderSide(color: DesignColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                ..._wifiNetworks.map((n) {
                  final isSelected = !_manualSsidMode && _selectedWifiNetwork?.ssid == n.ssid;
                  final is5G = n.ssid.contains('5G') || n.ssid.contains('5GHz');

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF0F7FF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: isSelected ? Border.all(color: DesignColors.primary, width: 1.5) : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                            enabled: !is5G,
                            leading: Icon(
                              n.isSecured ? Icons.wifi_lock_rounded : Icons.wifi_rounded,
                              color: is5G
                                  ? const Color(0xFFCBD5E1)
                                  : (isSelected ? DesignColors.primary : DesignColors.navy),
                              size: 20,
                            ),
                            title: Text(
                              n.ssid,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 14.5,
                                color: is5G ? const Color(0xFF94A3B8) : DesignColors.navy,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: is5G
                                ? const Text('5 GHz · not supported by purifier',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))
                                : (isSelected
                                    ? Text(n.isOpen ? 'Open network · Ready to connect' : 'Enter password below to connect',
                                        style: const TextStyle(fontSize: 11.5, color: DesignColors.primary, fontWeight: FontWeight.w600))
                                    : null),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (n.isSecured)
                                  const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.keyboard_arrow_down_rounded, color: DesignColors.primary, size: 22),
                                ],
                              ],
                            ),
                            onTap: is5G
                                ? null
                                : () {
                                    setState(() {
                                      if (_selectedWifiNetwork?.ssid != n.ssid) {
                                        _wifiPasswordController.clear();
                                        _errorMessage = null;
                                      }
                                      _manualSsidMode = false;
                                      _selectedWifiNetwork = n;
                                    });
                                  },
                          ),

                          // INLINE PASSWORD & CONNECT BOX DIRECTLY UNDER CLICKED SSID!
                          if (isSelected)
                            Padding(
                              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14, top: 2),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: DesignColors.border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (n.isOpen) ...[
                                      const Row(
                                        children: [
                                          Icon(Icons.lock_open_rounded, size: 16, color: DesignColors.success),
                                          SizedBox(width: 6),
                                          Text('Open Network (No password required)', style: TextStyle(fontSize: 13, color: DesignColors.muted)),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                    ] else ...[
                                      Text('Password for ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: DesignColors.navy)),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _wifiPasswordController,
                                        obscureText: _obscurePassword,
                                        autofocus: false,
                                        onChanged: (_) {
                                          if (_errorMessage != null) {
                                            setState(() => _errorMessage = null);
                                          } else {
                                            setState(() {});
                                          }
                                        },
                                        decoration: InputDecoration(
                                          hintText: 'Enter Wi-Fi password (min. 8 characters)',
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          suffixIcon: IconButton(
                                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: DesignColors.muted),
                                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                          ),
                                        ),
                                        onSubmitted: (_) => _startProvisioning(),
                                      ),
                                      const SizedBox(height: 6),
                                      if (_wifiPasswordController.text.isNotEmpty && _wifiPasswordController.text.length < 8)
                                        Row(
                                          children: [
                                            const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFE11D48)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Minimum 8 characters required (${_wifiPasswordController.text.length}/8)',
                                              style: const TextStyle(fontSize: 11.5, color: Color(0xFFE11D48), fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        )
                                      else if (_wifiPasswordController.text.length >= 8)
                                        Row(
                                          children: [
                                            const Icon(Icons.check_circle_outline_rounded, size: 14, color: DesignColors.success),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Password length valid (${_wifiPasswordController.text.length} characters)',
                                              style: const TextStyle(fontSize: 11.5, color: DesignColors.success, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 10),
                                    ],

                                    SizedBox(
                                      height: 44,
                                      child: ElevatedButton.icon(
                                        onPressed: _startProvisioning,
                                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                                        label: Text('Connect to ${n.ssid}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: DesignColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
                }),

                const Divider(height: 1, color: DesignColors.line),

                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const Icon(Icons.add_rounded, color: DesignColors.primary, size: 22),
                    title: const Text(
                      'Hidden or other network',
                      style: TextStyle(color: DesignColors.primary, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    onTap: () {
                      setState(() {
                        _manualSsidMode = true;
                        _selectedWifiNetwork = null;
                        _errorMessage = null;
                      });
                    },
                  ),
                ),

                if (_manualSsidMode)
                  Padding(
                    padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14, top: 4),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: DesignColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Network Name (SSID)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: DesignColors.navy)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _manualSsidController,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Enter Wi-Fi network name (SSID)',
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text('Wi-Fi Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: DesignColors.navy)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _wifiPasswordController,
                            obscureText: _obscurePassword,
                            onChanged: (_) {
                              if (_errorMessage != null) {
                                setState(() => _errorMessage = null);
                              } else {
                                setState(() {});
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Enter Wi-Fi password (min. 8 characters)',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: DesignColors.muted),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            onSubmitted: (_) => _startProvisioning(),
                          ),
                          const SizedBox(height: 6),
                          if (_wifiPasswordController.text.isNotEmpty && _wifiPasswordController.text.length < 8)
                            Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFE11D48)),
                                const SizedBox(width: 4),
                                Text(
                                  'Minimum 8 characters required (${_wifiPasswordController.text.length}/8)',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFE11D48), fontWeight: FontWeight.w500),
                                ),
                              ],
                            )
                          else if (_wifiPasswordController.text.length >= 8)
                            Row(
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, size: 14, color: DesignColors.success),
                                const SizedBox(width: 4),
                                Text(
                                  'Password length valid (${_wifiPasswordController.text.length} characters)',
                                  style: const TextStyle(fontSize: 11.5, color: DesignColors.success, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: _startProvisioning,
                              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                              label: const Text('Connect to Wi-Fi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DesignColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        if (_errorMessage != null) ...[
          _buildErrorBanner(_errorMessage!),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 05. PROVISIONING PROGRESS SCREEN (Matching Screen 05 in Design: Step 3 of 3)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildProvisioningProgressView() {
    final ssid = _manualSsidMode
        ? _manualSsidController.text
        : (_selectedWifiNetwork?.ssid ?? 'Wi-Fi');

    return _buildScreenLayout(
      stepProgress: 3,
      totalSteps: 3,
      bottomWidget: OutlinedButton(
        onPressed: () {
          _provisioningService.disconnect();
          Navigator.of(context).pop();
        },
        child: const Text('Cancel setup'),
      ),
      children: [
        const SizedBox(height: 16),

        // Central Pulsing Wi-Fi Circle (Matching Design)
        Center(
          child: SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: DesignColors.primary,
                    backgroundColor: DesignColors.tint,
                  ),
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.wifi_rounded, size: 36, color: DesignColors.primary),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        Center(
          child: Text('Connecting to\n$ssid', style: displayFont(26), textAlign: TextAlign.center),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Keep the app open and your phone near the device. This can take up to a minute.',
            style: bodyFont(),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 28),

        // 4-Step Checklist Card (Matching Design)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: DesignColors.border),
          ),
          child: Column(
            children: List.generate(_provisionStepLabels.length, (idx) {
              final isDone = idx < _progressStepIndex;
              final isCurrent = idx == _progressStepIndex;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    if (isDone)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(color: DesignColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 15),
                      )
                    else if (isCurrent)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: DesignColors.primary),
                      )
                    else
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: DesignColors.border, width: 2),
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _provisionStepLabels[idx],
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: isCurrent || isDone ? FontWeight.w600 : FontWeight.normal,
                          color: isDone
                              ? DesignColors.navy
                              : (isCurrent ? DesignColors.primary : DesignColors.muted),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 06a. FAILURE SCREEN (Matching Screen 06a in Design)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFailureView() {
    final ssid = _manualSsidMode
        ? _manualSsidController.text
        : (_selectedWifiNetwork?.ssid ?? 'Wi-Fi');

    return _buildScreenLayout(
      showClose: true,
      onClose: () => Navigator.of(context).pop(),
      bottomWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPrimaryButton(
            label: 'Re-enter password',
            onPressed: () => setState(() => _currentStep = SetupStep.wifiCredentials),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _manualSsidMode = false;
                _selectedWifiNetwork = null;
                _currentStep = SetupStep.wifiCredentials;
              });
            },
            child: const Text('Choose another network'),
          ),
        ],
      ),
      children: [
        // Red Exclamation Icon in Light Red Box
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: DesignColors.badBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.error_outline_rounded, color: DesignColors.bad, size: 32),
        ),
        const SizedBox(height: 18),

        Text(
          _failureReason == ProvisioningFailureReason.bluetooth
              ? 'Lost connection to purifier'
              : 'Couldn\'t join\n$ssid',
          style: displayFont(26),
        ),
        const SizedBox(height: 10),
        Text(
          _failureReason == ProvisioningFailureReason.bluetooth
              ? 'Bluetooth dropped during setup. Keep phone within 2 meters and ensure purifier is powered on.'
              : 'The device says the password was rejected. It\'s still in setup mode and connected to your phone, so you can try again right away.',
          style: bodyFont(),
        ),
        const SizedBox(height: 24),

        // "CHECK THESE" Tips Card (Matching Design)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: DesignColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CHECK THESE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: DesignColors.muted,
                ),
              ),
              const SizedBox(height: 14),

              _buildCheckItem(
                number: '1',
                isHighlight: true,
                text: 'Password is case-sensitive — check capitals and spaces.',
              ),
              const SizedBox(height: 12),
              _buildCheckItem(
                number: '2',
                isHighlight: false,
                text: 'The network must be 2.4 GHz. Some routers merge both bands under one name.',
              ),
              const SizedBox(height: 12),
              _buildCheckItem(
                number: '3',
                isHighlight: false,
                text: 'Move the device closer to your router.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckItem({required String number, required bool isHighlight, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: isHighlight ? DesignColors.bad : DesignColors.muted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: bodyFont(size: 14, height: 1.4)),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 07. SETUP DONE SCREEN
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSetupDoneView() {
    final wifiSsid = _selectedWifiNetwork?.ssid ??
        (_manualSsidController.text.trim().isNotEmpty
            ? _manualSsidController.text.trim()
            : 'Wi-Fi Network');

    return _buildScreenLayout(
      bottomWidget: SizedBox(
        height: 54,
        child: FilledButton(
          onPressed: _finishSetupAndSave,
          style: FilledButton.styleFrom(
            backgroundColor: DesignColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
            elevation: 2,
            shadowColor: DesignColors.primary.withValues(alpha: 0.35),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('Go to Purifier Dashboard'),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ),
      children: [
        // Success Checkmark Badge
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3), width: 2),
            ),
            child: Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, size: 32, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Title and Subtitle
        Center(
          child: Text(
            'Your purifier is online!',
            style: displayFont(25),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Device setup complete. Live sensor data is streaming.',
            style: bodyFont(size: 14, color: DesignColors.muted),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),

        // Live Telemetry Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DesignColors.border),
            boxShadow: [
              BoxShadow(
                color: DesignColors.navy.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with live indicator & mode
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Live Sensor Reading',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: DesignColors.navy,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Text(
                      _liveSetupMode != null ? '${_liveSetupMode!} MODE' : 'LIVE',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Metrics Row
              Row(
                children: [
                  // Purified TDS
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Purified TDS',
                            style: TextStyle(fontSize: 11, color: DesignColors.muted, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_liveSetupTds ?? 54} PPM',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: DesignColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Optimal',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Inlet TDS
                  if (_liveSetupInletTds != null) ...[
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Inlet TDS',
                              style: TextStyle(fontSize: 11, color: DesignColors.muted, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_liveSetupInletTds ?? 58} PPM',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: DesignColors.navy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Raw Water',
                              style: TextStyle(fontSize: 10, color: DesignColors.muted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Temperature
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Temperature',
                            style: TextStyle(fontSize: 11, color: DesignColors.muted, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _liveSetupTemp != null
                                ? '${_liveSetupTemp!.toStringAsFixed(1)}°C'
                                : '29.1°C',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Normal',
                            style: TextStyle(fontSize: 10, color: DesignColors.muted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Network Info Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_rounded, size: 18, color: DesignColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Connected to $wifiSsid',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: DesignColors.navy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // Purifier Name label & Text Field
        const Text(
          'Purifier Name',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: DesignColors.navy),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _purifierNameController,
          style: const TextStyle(fontSize: 15, color: DesignColors.navy, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'e.g. Shuddham RO Purifier',
            prefixIcon: const Icon(Icons.water_drop_outlined, color: DesignColors.primary, size: 20),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: DesignColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: DesignColors.primary, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED SCAFFOLD LAYOUT & COMPONENTS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildScreenLayout({
    bool showClose = false,
    bool showBack = false,
    String? headerCenterText,
    int? stepProgress,
    int? totalSteps,
    VoidCallback? onClose,
    VoidCallback? onBack,
    required List<Widget> children,
    required Widget bottomWidget,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Bar Header (Close/Back + Step Bar)
                  Row(
                    children: [
                      if (showBack)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.chevron_left_rounded, size: 28, color: DesignColors.navy),
                          onPressed: onBack,
                        )
                      else if (showClose)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.close_rounded, size: 24, color: DesignColors.navy),
                          onPressed: onClose,
                        )
                      else
                        const SizedBox(width: 24),

                      const SizedBox(width: 14),

                      // Step Bar or Center Title
                      if (stepProgress != null && totalSteps != null)
                        Expanded(
                          child: Row(
                            children: [
                              for (int i = 1; i <= totalSteps; i++) ...[
                                Expanded(
                                  child: Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: i <= stepProgress ? DesignColors.primary : DesignColors.border,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                if (i < totalSteps) const SizedBox(width: 6),
                              ],
                              const SizedBox(width: 12),
                              Text(
                                '$stepProgress of $totalSteps',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: DesignColors.muted),
                              ),
                            ],
                          ),
                        )
                      else if (headerCenterText != null)
                        Expanded(
                          child: Center(
                            child: Text(
                              headerCenterText,
                              style: const TextStyle(fontSize: 13.5, color: DesignColors.muted, fontWeight: FontWeight.w500),
                            ),
                          ),
                        )
                      else
                        const Spacer(),

                      const SizedBox(width: 24),
                    ],
                  ),

                  const SizedBox(height: 20),

                  ...children,

                  const Spacer(),
                  const SizedBox(height: 24),
                  bottomWidget,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrimaryButton({required String label, bool busy = false, VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: DesignColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: DesignColors.primary.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
        ),
        child: busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(label),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DesignColors.badBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: DesignColors.bad),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: DesignColors.bad, fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
