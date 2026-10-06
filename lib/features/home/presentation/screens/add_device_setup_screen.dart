import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/device_model.dart';

enum SetupStep {
  bluetoothPermission,
  radarScanning,
  bleConnecting,
  wifiAndRoom,
  successCelebration,
}

class AddDeviceSetupScreen extends StatefulWidget {
  final Function(DeviceModel) onDeviceAdded;

  const AddDeviceSetupScreen({super.key, required this.onDeviceAdded});

  @override
  State<AddDeviceSetupScreen> createState() => _AddDeviceSetupScreenState();
}

class _AddDeviceSetupScreenState extends State<AddDeviceSetupScreen> with SingleTickerProviderStateMixin {
  SetupStep _currentStep = SetupStep.bluetoothPermission;
  bool _isBluetoothEnabled = false;
  late AnimationController _radarController;

  // Selected device during pairing
  Map<String, dynamic>? _selectedDevice;

  // Wi-Fi & Customization Form State
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _wifiSsidController = TextEditingController(text: 'Home_WiFi_5G');
  final TextEditingController _wifiPassController = TextEditingController();
  bool _showWifiPassword = false;
  String _selectedRoom = 'Kitchen';

  final List<String> _rooms = [
    'Kitchen',
    'Dining Area',
    'Living Room',
    'Rooftop Tank',
    'Utility Area',
    'Office'
  ];

  // Discovered mock BLE devices
  final List<Map<String, dynamic>> _discoveredPurifiers = [
    {
      'id': 'SHD-RO-9482',
      'name': 'Shuddham Smart RO Pro',
      'model': 'RO-7S IoT Edition',
      'type': 'RO Purifier',
      'signal': 98,
      'tds': 78,
      'defaultLocation': 'Kitchen',
      'filterLife': 95,
      'liters': 185.0,
      'icon': Icons.water_drop_rounded,
    },
    {
      'id': 'SHD-RO-8102',
      'name': 'Shuddham Alkaline Mineralizer',
      'model': 'Alka-Mineral v3',
      'type': 'RO Purifier',
      'signal': 92,
      'tds': 65,
      'defaultLocation': 'Dining Area',
      'filterLife': 98,
      'liters': 92.0,
      'icon': Icons.opacity_rounded,
    },
    {
      'id': 'SHD-TS-4109',
      'name': 'Shuddham Tank Level Sensor',
      'model': 'IoT Purity Monitor v2',
      'type': 'Tank Sensor',
      'signal': 85,
      'tds': 118,
      'defaultLocation': 'Rooftop Tank',
      'filterLife': 90,
      'liters': 450.0,
      'icon': Icons.sensors_rounded,
    },
    {
      'id': 'SHD-UV-5520',
      'name': 'Shuddham UV Disinfector Core',
      'model': 'UV-C LED Guard',
      'type': 'UV Disinfector',
      'signal': 79,
      'tds': 85,
      'defaultLocation': 'Utility Area',
      'filterLife': 92,
      'liters': 120.0,
      'icon': Icons.shield_rounded,
    },
  ];

  // Connecting sub-steps
  int _connectionStepIndex = 0;
  final List<String> _connectionSteps = [
    'Establishing Bluetooth LE handshake...',
    'Authenticating Shuddham hardware security chip...',
    'Calibrating TDS & flow telemetry sensors...',
    'Pairing complete! Finalizing device profile...',
  ];

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _deviceNameController.dispose();
    _wifiSsidController.dispose();
    _wifiPassController.dispose();
    super.dispose();
  }

  void _onEnableBluetoothAndContinue() {
    setState(() {
      _isBluetoothEnabled = true;
      _currentStep = SetupStep.radarScanning;
    });
  }

  void _startConnectingDevice(Map<String, dynamic> dev) {
    setState(() {
      _selectedDevice = dev;
      _deviceNameController.text = dev['name'] as String;
      _selectedRoom = dev['defaultLocation'] as String;
      _currentStep = SetupStep.bleConnecting;
      _connectionStepIndex = 0;
    });

    // Simulate realistic BLE connection progression
    Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_connectionStepIndex < _connectionSteps.length - 1) {
        setState(() {
          _connectionStepIndex++;
        });
      } else {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() {
              _currentStep = SetupStep.wifiAndRoom;
            });
          }
        });
      }
    });
  }

  void _finishSetupAndAddDevice() {
    if (_selectedDevice == null) return;

    final dev = _selectedDevice!;
    final customName = _deviceNameController.text.trim().isNotEmpty
        ? _deviceNameController.text.trim()
        : dev['name'] as String;

    final newDevice = DeviceModel(
      id: dev['id'] as String,
      name: customName,
      model: dev['model'] as String,
      type: dev['type'] as String,
      serialNumber: dev['id'] as String,
      location: _selectedRoom,
      isOnline: true,
      tdsPpm: dev['tds'] as int,
      filterLifePercentage: dev['filterLife'] as int,
      lastSync: 'Just now',
      totalLitersPurified: (dev['liters'] as num).toDouble(),
    );

    setState(() {
      _currentStep = SetupStep.successCelebration;
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        widget.onDeviceAdded(newDevice);
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF102A43), size: 24),
          onPressed: () {
            if (_currentStep == SetupStep.bluetoothPermission) {
              Navigator.of(context).pop();
            } else if (_currentStep == SetupStep.radarScanning) {
              setState(() => _currentStep = SetupStep.bluetoothPermission);
            } else if (_currentStep == SetupStep.wifiAndRoom) {
              setState(() => _currentStep = SetupStep.radarScanning);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          _getHeaderTitle(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildCurrentStepView(),
        ),
      ),
    );
  }

  String _getHeaderTitle() {
    switch (_currentStep) {
      case SetupStep.bluetoothPermission:
        return 'Bluetooth Setup';
      case SetupStep.radarScanning:
        return 'Nearby Purifiers';
      case SetupStep.bleConnecting:
        return 'Connecting Device';
      case SetupStep.wifiAndRoom:
        return 'Device Customization';
      case SetupStep.successCelebration:
        return 'Pairing Complete';
    }
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case SetupStep.bluetoothPermission:
        return _buildBluetoothPromptView();
      case SetupStep.radarScanning:
        return _buildRadarScanningView();
      case SetupStep.bleConnecting:
        return _buildConnectingView();
      case SetupStep.wifiAndRoom:
        return _buildWifiAndRoomView();
      case SetupStep.successCelebration:
        return _buildSuccessCelebrationView();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. BLUETOOTH PROMPT & PERMISSION SCREEN
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBluetoothPromptView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bluetooth Animated Header Card
                  Container(
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.bluetooth_audio_rounded,
                            color: AppTheme.royalBlue,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Bluetooth Pairing Mode',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Main Heading
                  const Text(
                    'Let the app find nearby\nShuddham purifiers',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF102A43),
                      height: 1.25,
                      letterSpacing: -0.4,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Subtitle description
                  const Text(
                    'Your smart water purifier exchanges telemetry and receives Wi-Fi network credentials over Bluetooth LE.',
                    style: TextStyle(
                      fontSize: 14.5,
                      color: Color(0xFF56627A),
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bluetooth Switch Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _isBluetoothEnabled ? const Color(0xFFBAE6FD) : const Color(0xFFD5DEEB)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0077EE).withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _isBluetoothEnabled ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.bluetooth_rounded,
                            color: _isBluetoothEnabled ? AppTheme.royalBlue : const Color(0xFF64748B),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Enable Bluetooth',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF102A43),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isBluetoothEnabled ? 'Bluetooth is ON & ready' : 'Required to scan nearby purifiers',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: _isBluetoothEnabled ? AppTheme.accentGreen : const Color(0xFF64748B),
                                  fontWeight: _isBluetoothEnabled ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isBluetoothEnabled,
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppTheme.royalBlue,
                          onChanged: (val) {
                            setState(() {
                              _isBluetoothEnabled = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Requirement 2: Proximity & Power
                  _buildRequirementCard(
                    icon: Icons.power_rounded,
                    title: 'Purifier Power & Proximity',
                    description: 'Keep your RO purifier powered ON and within 2 meters of your smartphone.',
                  ),

                  const Spacer(),
                  const SizedBox(height: 24),

                  // Bottom Button: "Turn on & Scan" or "Continue"
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _onEnableBluetoothAndContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.royalBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.radar_rounded, size: 20, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Scan for Nearby Purifiers',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.2,
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
      },
    );
  }

  Widget _buildRequirementCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0077EE).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0F172A), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF102A43),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. RADAR SCANNING & DISCOVERED PURIFIERS SCREEN
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildRadarScanningView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Radar Scanning Banner with pulsating rings
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _radarController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.royalBlue.withValues(alpha: 0.15 + (0.15 * (1 - _radarController.value))),
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: AppTheme.royalBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.bluetooth_searching_rounded, color: Colors.white, size: 18),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scanning Bluetooth Devices...',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Searching within 2 m range',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_discoveredPurifiers.length} Found',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Discovered Shuddham Purifiers',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF102A43),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.royalBlue, size: 20),
                tooltip: 'Rescan',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Rescanning nearby Bluetooth channels...'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // List of Discovered Devices
          ..._discoveredPurifiers.map((dev) {
            final icon = dev['icon'] as IconData? ?? Icons.water_drop_rounded;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2EEF8)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0077EE).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF5FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: AppTheme.royalBlue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dev['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF102A43)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${dev['model']} • ${dev['id']}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.water_drop_rounded, size: 10, color: AppTheme.accentGreen),
                                  const SizedBox(width: 2),
                                  Text(
                                    'TDS: ${dev['tds']} PPM',
                                    style: const TextStyle(fontSize: 10, color: AppTheme.accentGreen, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                const Icon(Icons.bluetooth_connected_rounded, size: 12, color: Color(0xFF0284C7)),
                                const SizedBox(width: 3),
                                Text(
                                  'Signal: ${dev['signal']}%',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _startConnectingDevice(dev),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.royalBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.link_rounded, size: 15, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Pair', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. BLE CONNECTING PROGRESS SCREEN
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildConnectingView() {
    final dev = _selectedDevice;
    if (dev == null) return const SizedBox();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular Pulse Indicator
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: AppTheme.royalBlue,
                    backgroundColor: const Color(0xFFE2E8F0),
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0F2FE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bluetooth_audio_rounded, color: AppTheme.royalBlue, size: 30),
                ),
              ],
            ),

            const SizedBox(height: 28),

            Text(
              'Connecting to ${dev['name']}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF102A43),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              'Model: ${dev['model']} (SN: ${dev['id']})',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 28),

            // Checklist Steps Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: List.generate(_connectionSteps.length, (idx) {
                  final isDone = idx < _connectionStepIndex;
                  final isCurrent = idx == _connectionStepIndex;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        if (isDone)
                          const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 18)
                        else if (isCurrent)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.royalBlue),
                          )
                        else
                          const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFFCBD5E1), size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _connectionSteps[idx],
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isCurrent || isDone ? FontWeight.w600 : FontWeight.normal,
                              color: isDone
                                  ? const Color(0xFF102A43)
                                  : isCurrent
                                      ? AppTheme.royalBlue
                                      : const Color(0xFF94A3B8),
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
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. WI-FI SETUP & ROOM ALLOCATION SCREEN
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWifiAndRoomView() {
    final dev = _selectedDevice;
    if (dev == null) return const SizedBox();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pairing verified banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bluetooth Paired Successfully! Configure location & Wi-Fi below.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Custom Device Name
          const Text(
            'Purifier Nickname',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF102A43)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _deviceNameController,
            decoration: InputDecoration(
              hintText: 'e.g. Kitchen Smart RO',
              prefixIcon: const Icon(Icons.edit_rounded, color: Color(0xFF0284C7), size: 18),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.royalBlue, width: 1.5)),
            ),
          ),

          const SizedBox(height: 20),

          // Room Assignment Selector
          const Text(
            'Installation Room / Location',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF102A43)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _rooms.map((room) {
              final isSelected = _selectedRoom == room;
              return ChoiceChip(
                label: Text(room),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedRoom = room);
                },
                selectedColor: const Color(0xFFE0F2FE),
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF475569),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0)),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 22),

          // Optional Wi-Fi Setup
          const Text(
            'Home Wi-Fi Setup (Optional)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF102A43)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Connects your purifier to Shuddham cloud for remote telemetry and automatic filter alerts.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _wifiSsidController,
            decoration: InputDecoration(
              labelText: 'Wi-Fi Network (SSID)',
              prefixIcon: const Icon(Icons.wifi_rounded, color: Color(0xFF0284C7), size: 18),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),

          const SizedBox(height: 10),

          TextField(
            controller: _wifiPassController,
            obscureText: !_showWifiPassword,
            decoration: InputDecoration(
              labelText: 'Wi-Fi Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF0284C7), size: 18),
              suffixIcon: IconButton(
                icon: Icon(_showWifiPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                onPressed: () => setState(() => _showWifiPassword = !_showWifiPassword),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _finishSetupAndAddDevice,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.royalBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Complete Setup & Save Device',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. SUCCESS CELEBRATION SCREEN
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSuccessCelebrationView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: AppTheme.accentGreen, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Purifier Added Successfully!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF102A43),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Live water purity telemetry is now streaming to your home dashboard.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.royalBlue),
            ),
          ],
        ),
      ),
    );
  }
}
