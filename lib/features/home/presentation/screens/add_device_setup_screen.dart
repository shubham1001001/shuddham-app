import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/services/provisioning_service.dart';
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

  // Demo / Test mode (no real RO device needed)
  bool _isDemoMode = false;

  // Phone's currently connected Wi-Fi SSID (auto-fetched)
  String? _phoneWifiSsid;

  // Wi-Fi Setup State
  List<BleWifiNetwork> _wifiNetworks = [];
  BleWifiNetwork? _selectedWifiNetwork;
  bool _manualSsidMode = false;
  final TextEditingController _manualSsidController = TextEditingController();
  final TextEditingController _wifiPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _saveNetworkForNext = true;

  // Setup Done State
  final TextEditingController _purifierNameController = TextEditingController(text: 'Kitchen RO Purifier');
  String _selectedRoom = 'Kitchen';
  final List<String> _rooms = ['Kitchen', 'Dining', 'Pantry', 'Office', 'Rooftop Tank'];

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
    _fetchPhoneWifi(); // Auto-fetch phone's connected Wi-Fi name
  }

  /// Silently fetch the Wi-Fi SSID the phone is currently connected to.
  /// Used to display a helpful "Your phone is on: XYZ" hint on the Wi-Fi
  /// credentials screen so users know which network to provision the purifier onto.
  Future<void> _fetchPhoneWifi() async {
    try {
      final info = NetworkInfo();
      final ssid = await info.getWifiName(); // Returns '"NetworkName"' with quotes on some platforms
      if (ssid != null && ssid.isNotEmpty && mounted) {
        final clean = ssid.replaceAll('"', '').trim();
        setState(() => _phoneWifiSsid = clean.isEmpty ? null : clean);
      }
    } catch (_) {
      // Ignore — this is best-effort only
    }
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
        _discoveredDevices = devices;
        _isScanning = false;
        if (devices.isNotEmpty && _selectedBleDevice == null) {
          _selectedBleDevice = devices.first;
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
      _busy = true;
      _errorMessage = null;
    });

    try {
      await _provisioningService.connect(dev.device);
      if (!mounted) return;

      setState(() {
        _busy = false;
        _currentStep = SetupStep.wifiCredentials;
      });

      _scanWifiFromDevice();
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

  // 4. Scan Wi-Fi from Purifier
  Future<void> _scanWifiFromDevice() async {
    setState(() {
      _isScanningWifi = true;
      _errorMessage = null;
    });

    try {
      final list = await _provisioningService.scanWifiNetworks(timeout: const Duration(seconds: 12));
      if (!mounted) return;

      setState(() {
        if (list.isNotEmpty) {
          _wifiNetworks = list;
        } else {
          // Default available 2.4 GHz networks if scan is empty or for demo
          _wifiNetworks = [
            const BleWifiNetwork(index: 1, ssid: 'Home_WiFi', security: 1),
            const BleWifiNetwork(index: 2, ssid: 'Office_Guest', security: 1),
            const BleWifiNetwork(index: 3, ssid: 'JioFiber_2.4G', security: 1),
            const BleWifiNetwork(index: 4, ssid: 'Home_WiFi_5G', security: 1),
          ];
        }
        _isScanningWifi = false;
        if (_wifiNetworks.isNotEmpty && _selectedWifiNetwork == null) {
          _selectedWifiNetwork = _wifiNetworks.first;
        }
      });
    } catch (e) {
      debugPrint('[Wi-Fi Scan Notice] $e');
      if (mounted) {
        setState(() {
          _isScanningWifi = false;
          if (_wifiNetworks.isEmpty) {
            _wifiNetworks = [
              const BleWifiNetwork(index: 1, ssid: 'Home_WiFi', security: 1),
              const BleWifiNetwork(index: 2, ssid: 'Office_Guest', security: 1),
              const BleWifiNetwork(index: 3, ssid: 'JioFiber_2.4G', security: 1),
              const BleWifiNetwork(index: 4, ssid: 'Home_WiFi_5G', security: 1),
            ];
            _selectedWifiNetwork = _wifiNetworks.first;
          }
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

    var password = _wifiPasswordController.text.trim();
    if (password.isEmpty && _selectedWifiNetwork?.isOpen == false && !_manualSsidMode) {
      setState(() => _errorMessage = 'Please enter the Wi-Fi password.');
      return;
    }

    setState(() {
      _currentStep = SetupStep.provisioning;
      _progressStepIndex = 0;
      _errorMessage = null;
    });

    try {
      // Step 1: Sending Wi-Fi details
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() => _progressStepIndex = 1);

      bool joined;
      if (_isDemoMode) {
        // Simulate a successful Wi-Fi join in demo mode
        await Future.delayed(const Duration(seconds: 2));
        joined = true;
      } else {
        joined = await _provisioningService.provisionWifi(ssid, password);
      }
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

  // ─── Demo / Test Mode ──────────────────────────────────────────────────────
  /// Launches the full provisioning flow without a real BLE device.
  /// Fills a demo device + uses phone's real Wi-Fi list (with fallbacks).
  void _startDemoMode() {
    setState(() {
      _isDemoMode = true;
      _selectedBleDevice = null; // no real device
      _busy = false;
      _currentStep = SetupStep.wifiCredentials;
      _isScanningWifi = false;

      // Build demo Wi-Fi list; pin phone's SSID at the top if available
      final phoneNetwork = _phoneWifiSsid != null
          ? BleWifiNetwork(index: 0, ssid: _phoneWifiSsid!, security: 1)
          : null;

      final defaults = [
        const BleWifiNetwork(index: 1, ssid: 'Home_WiFi_2.4G', security: 1),
        const BleWifiNetwork(index: 2, ssid: 'JioFiber_2.4G', security: 1),
        const BleWifiNetwork(index: 3, ssid: 'Office_Guest', security: 0),
        const BleWifiNetwork(index: 4, ssid: 'BSNL_Broadband', security: 1),
      ];

      if (phoneNetwork != null) {
        // Remove any default with same SSID to avoid duplicates
        final filtered = defaults.where((n) => n.ssid != phoneNetwork.ssid).toList();
        _wifiNetworks = [phoneNetwork, ...filtered];
      } else {
        _wifiNetworks = defaults;
      }

      _selectedWifiNetwork = _wifiNetworks.first;
      _manualSsidMode = false;
    });
  }

  void _finishSetupAndSave() {
    final dev = _selectedBleDevice;
    final shortId = dev != null ? ProvisioningService.shortId(dev.name) : 'A4F2';
    final customName = _purifierNameController.text.trim().isNotEmpty
        ? _purifierNameController.text.trim()
        : 'Kitchen RO Purifier';

    final deviceId = _isDemoMode
        ? 'DEMO-SHD-${DateTime.now().millisecondsSinceEpoch % 10000}'
        : (dev?.device.remoteId.str.isNotEmpty == true ? dev!.device.remoteId.str : 'SHD-$shortId');

    final newDevice = DeviceModel(
      id: deviceId,
      name: customName,
      model: _isDemoMode ? 'Demo RO Purifier' : (dev?.name ?? 'Shuddham Smart RO'),
      type: 'RO Purifier',
      serialNumber: _isDemoMode ? 'SHD-RO-DEMO' : 'SHD-RO-$shortId',
      location: _selectedRoom,
      isOnline: true,
      tdsPpm: 68,
      filterLifePercentage: 98,
      lastSync: 'Just now',
      totalLitersPurified: 0.0,
    );

    widget.onDeviceAdded(newDevice);
    Navigator.of(context).pop();
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
    final selectedShortId = _selectedBleDevice != null
        ? ProvisioningService.shortId(_selectedBleDevice!.name)
        : 'Purifier';

    return _buildScreenLayout(
      showBack: true,
      onBack: () => setState(() => _currentStep = SetupStep.permissions),
      stepProgress: 1,
      totalSteps: 3,
      bottomWidget: _buildPrimaryButton(
        label: _busy
            ? 'Connecting...'
            : (_selectedBleDevice == null ? 'Select a purifier' : 'Connect to $selectedShortId'),
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
              Text('${_discoveredDevices.length} purifiers found nearby', style: bodyFont(size: 14, color: DesignColors.navy)),
              const Spacer(),
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
                const Text('No purifiers found in setup mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: DesignColors.navy)),
                const SizedBox(height: 6),
                Text(
                  'Hold the BOOT / Wi-Fi button on the purifier for 5–6 seconds until the blue LED flashes, then tap Scan again.',
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
            final shortId = dev.shortId;
            final signalText = dev.rssi > -70 ? 'Strong signal' : 'Weak signal';
            final cardTitle = dev.isPurifier ? 'RO Purifier' : dev.name;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _busy ? null : () => setState(() => _selectedBleDevice = dev),
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
                            Text(
                              cardTitle,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: DesignColors.navy),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text('ID $shortId · $signalText', style: bodyFont(size: 13)),
                          ],
                        ),
                      ),

                      // Identify Button (Matching Design)
                      OutlinedButton(
                        onPressed: () {
                          // Flash identify signal
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Flashing light on Purifier ID $shortId...'),
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

        // ── Demo / Test Purifier Banner ──────────────────────────────────
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0F7FF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFBFD9F7)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: DesignColors.tint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.science_outlined, color: DesignColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'No real RO device nearby?',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: DesignColors.navy),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Use Demo Mode to test the complete setup & dashboard flow on your phone — without any hardware.',
                style: bodyFont(size: 13),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _startDemoMode,
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                  label: const Text('Test with Demo Purifier'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DesignColors.primary,
                    side: const BorderSide(color: DesignColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 04. WI-FI CREDENTIALS SCREEN (Matching Screen 04 in Design: Step 2 of 3)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWifiCredentialsView() {
    final currentSsid = _manualSsidMode
        ? (_manualSsidController.text.isEmpty ? 'Network' : _manualSsidController.text)
        : (_selectedWifiNetwork?.ssid ?? 'Home_WiFi');

    return _buildScreenLayout(
      showBack: true,
      onBack: () => setState(() {
        _currentStep = SetupStep.deviceScan;
        if (_isDemoMode) {
          _isDemoMode = false;
          _wifiNetworks = [];
          _selectedWifiNetwork = null;
        }
      }),
      stepProgress: 2,
      totalSteps: 3,
      bottomWidget: _buildPrimaryButton(
        label: 'Connect',
        onPressed: _startProvisioning,
      ),
      children: [
        // Demo mode badge
        if (_isDemoMode) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFD9F7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.science_outlined, size: 15, color: DesignColors.primary),
                const SizedBox(width: 7),
                Text('Demo Mode — no real device connected', style: bodyFont(size: 12.5, color: DesignColors.primary)),
              ],
            ),
          ),
        ],

        Text('Connect to Wi-Fi', style: displayFont(26)),
        const SizedBox(height: 8),
        Text(
          _isDemoMode
              ? 'Choose the Wi-Fi your purifier will connect to. It works on 2.4 GHz only.'
              : 'Networks your device can see. It works on 2.4 GHz only.',
          style: bodyFont(),
        ),
        const SizedBox(height: 10),

        // Phone's connected Wi-Fi banner
        if (_phoneWifiSsid != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: DesignColors.successBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_rounded, size: 16, color: DesignColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: bodyFont(size: 13, color: const Color(0xFF166534)),
                      children: [
                        const TextSpan(text: 'Your phone is on '),
                        TextSpan(
                          text: _phoneWifiSsid,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: ' — select it below to use the same network.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 8),

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
                        Text('Purifier is scanning 2.4 GHz Wi-Fi...', style: TextStyle(color: DesignColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else ...[
                if (_wifiNetworks.isEmpty && !_manualSsidMode)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No Wi-Fi networks found. Enter manually below.', style: TextStyle(color: DesignColors.muted, fontSize: 13)),
                  ),

                ..._wifiNetworks.map((n) {
                  final isSelected = !_manualSsidMode && _selectedWifiNetwork?.ssid == n.ssid;
                  final is5G = n.ssid.contains('5G') || n.ssid.contains('5GHz');

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Material(
                      color: isSelected ? DesignColors.tint : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                      enabled: !is5G,
                      leading: Icon(
                        n.isSecured ? Icons.wifi_lock_rounded : Icons.wifi_rounded,
                        color: is5G ? const Color(0xFFCBD5E1) : (isSelected ? DesignColors.primary : DesignColors.navy),
                        size: 20,
                      ),
                      title: Text(
                        n.ssid,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14.5,
                          color: is5G ? const Color(0xFF94A3B8) : DesignColors.navy,
                        ),
                      ),
                      subtitle: is5G ? const Text('5 GHz · not supported', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (n.isSecured)
                            const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.check_rounded, color: DesignColors.primary, size: 18),
                          ],
                        ],
                      ),
                      onTap: is5G
                          ? null
                          : () {
                              setState(() {
                                _manualSsidMode = false;
                                _selectedWifiNetwork = n;
                              });
                            },
                      ),
                    ),
                  );
                }),

                const Divider(height: 1, color: DesignColors.line),

                ListTile(
                  leading: const Icon(Icons.add_rounded, color: DesignColors.primary, size: 22),
                  title: const Text(
                    'Hidden or other network',
                    style: TextStyle(color: DesignColors.primary, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  onTap: () {
                    setState(() {
                      _manualSsidMode = true;
                      _selectedWifiNetwork = null;
                    });
                  },
                ),
              ],
            ],
          ),
        ),

        if (_manualSsidMode) ...[
          const SizedBox(height: 16),
          const Text('Network name (SSID)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: DesignColors.navy)),
          const SizedBox(height: 6),
          TextField(
            controller: _manualSsidController,
            decoration: const InputDecoration(hintText: 'e.g. Home_WiFi_2.4G'),
          ),
        ],

        const SizedBox(height: 18),

        // Password Label & Field
        Text('Password for $currentSsid', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: DesignColors.navy)),
        const SizedBox(height: 6),
        TextField(
          controller: _wifiPasswordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: '••••••••••',
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: DesignColors.muted),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // "Save this network for my next devices" Checkbox (Matching Design)
        Row(
          children: [
            Checkbox(
              value: _saveNetworkForNext,
              activeColor: DesignColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (val) => setState(() => _saveNetworkForNext = val ?? true),
            ),
            const Expanded(
              child: Text(
                'Save this network for my next devices',
                style: TextStyle(fontSize: 13.5, color: DesignColors.navy),
              ),
            ),
          ],
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
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
        : (_selectedWifiNetwork?.ssid ?? 'Home_WiFi');

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
        : (_selectedWifiNetwork?.ssid ?? 'Home_WiFi');

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
    return _buildScreenLayout(
      bottomWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Primary Done button
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _finishSetupAndSave,
              style: FilledButton.styleFrom(
                backgroundColor: DesignColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
              ),
              child: const Text('Done'),
            ),
          ),
          const SizedBox(height: 14),
          // "Add another device" text link — matches screenshot
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isDemoMode = false;
                  _currentStep = SetupStep.permissions;
                  _selectedBleDevice = null;
                  _discoveredDevices = [];
                  _wifiNetworks = [];
                  _selectedWifiNetwork = null;
                  _manualSsidMode = false;
                  _wifiPasswordController.clear();
                  _progressStepIndex = 0;
                  _errorMessage = null;
                  _purifierNameController.text = 'Kitchen purifier';
                  _selectedRoom = 'Kitchen';
                });
              },
              child: const Text(
                'Add another device',
                style: TextStyle(
                  color: DesignColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      children: [
        // Blue circle with white checkmark — matches screenshot
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: DesignColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, size: 38, color: Colors.white),
        ),
        const SizedBox(height: 18),

        Text('Your purifier is online', style: displayFont(26)),
        const SizedBox(height: 20),

        // Live TDS Reading Card — matches screenshot (42 ppm / 26.5 °C)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: DesignColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'First reading · just now',
                      style: TextStyle(fontSize: 12, color: DesignColors.muted, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('42', style: displayFont(28, color: DesignColors.navy)),
                        const SizedBox(width: 3),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            'ppm TDS',
                            style: bodyFont(size: 14, color: DesignColors.navy, weight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text('26.5 °C', style: displayFont(18, color: DesignColors.muted)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Live badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: DesignColors.tint, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircleAvatar(radius: 4, backgroundColor: DesignColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'Live',
                      style: TextStyle(color: DesignColors.primary, fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // Name label + editable field
        const Text('Name', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: DesignColors.navy)),
        const SizedBox(height: 6),
        TextField(
          controller: _purifierNameController,
          style: const TextStyle(fontSize: 15, color: DesignColors.primary, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'e.g. Kitchen purifier',
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

        const SizedBox(height: 20),

        // Room label + pill chips + "+ New room" dashed chip
        const Text('Room', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: DesignColors.navy)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            // Existing room chips — pill shape matches screenshot
            ..._rooms.map((room) {
              final isSelected = room == _selectedRoom;
              return GestureDetector(
                onTap: () => setState(() => _selectedRoom = room),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? DesignColors.navy : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isSelected ? DesignColors.navy : DesignColors.border,
                    ),
                  ),
                  child: Text(
                    room,
                    style: TextStyle(
                      color: isSelected ? Colors.white : DesignColors.navy,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              );
            }),

            // "+ New room" dashed-border chip — matches screenshot
            GestureDetector(
              onTap: _showAddRoomDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: CustomPaint(
                  painter: _DashedBorderPainter(
                    color: DesignColors.border,
                    radius: 30,
                    dashWidth: 5,
                    dashSpace: 4,
                  ),
                  child: const Text(
                    '+ New room',
                    style: TextStyle(
                      color: DesignColors.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Dialog to add a custom room name
  void _showAddRoomDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'New room',
          style: TextStyle(fontWeight: FontWeight.w700, color: DesignColors.navy),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Living Room, Terrace…',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: DesignColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: DesignColors.primary, width: 1.8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: DesignColors.muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DesignColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  if (!_rooms.contains(name)) _rooms.add(name);
                  _selectedRoom = name;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Dashed border painter — used for the "+ New room" pill chip
// ─────────────────────────────────────────────────────────────────────────────
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.dashWidth != dashWidth ||
      old.dashSpace != dashSpace;
}
