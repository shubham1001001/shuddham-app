import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/device_model.dart';

class AddDeviceSetupScreen extends StatefulWidget {
  final Function(DeviceModel) onDeviceAdded;

  const AddDeviceSetupScreen({super.key, required this.onDeviceAdded});

  @override
  State<AddDeviceSetupScreen> createState() => _AddDeviceSetupScreenState();
}

class _AddDeviceSetupScreenState extends State<AddDeviceSetupScreen> {
  bool _isSearching = false;
  String? _pairingDeviceId;

  final List<Map<String, dynamic>> _discoveredPurifiers = [
    {
      'id': 'SHD-RO-9482',
      'name': 'Shuddham Smart RO Pro',
      'model': 'RO-7S IoT Edition',
      'type': 'RO Purifier',
      'signal': 98,
      'tds': 82,
      'location': 'Kitchen',
    },
    {
      'id': 'SHD-TS-4109',
      'name': 'Shuddham Tank Level Sensor',
      'model': 'IoT Purity Monitor v2',
      'type': 'Tank Sensor',
      'signal': 85,
      'tds': 118,
      'location': 'Rooftop Tank',
    },
  ];

  void _onContinue() {
    setState(() {
      _isSearching = true;
    });
  }

  void _pairPurifier(Map<String, dynamic> dev) async {
    setState(() {
      _pairingDeviceId = dev['id'] as String;
    });

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    final newDevice = DeviceModel(
      id: dev['id'] as String,
      name: dev['name'] as String,
      model: dev['model'] as String,
      type: dev['type'] as String,
      serialNumber: dev['id'] as String,
      location: dev['location'] as String,
      isOnline: true,
      tdsPpm: dev['tds'] as int,
      filterLifePercentage: 88,
      lastSync: 'Just now',
      totalLitersPurified: 146.0,
    );

    widget.onDeviceAdded(newDevice);
    Navigator.of(context).pop();
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
            if (_isSearching) {
              setState(() {
                _isSearching = false;
                _pairingDeviceId = null;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          _isSearching ? 'Nearby Purifiers' : 'Before we start',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ),
      body: SafeArea(
        child: _isSearching ? _buildSearchingView() : _buildPermissionPromptView(),
      ),
    );
  }

  /// 1. Initial Permission Screen matching reference screenshot exactly
  Widget _buildPermissionPromptView() {
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
                  // Bluetooth wide rounded banner badge matching reference screenshot
                  Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3EDFB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.bluetooth_rounded,
                        color: AppTheme.royalBlue,
                        size: 32,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Main Heading
                  const Text(
                    'Let the app find nearby\npurifiers',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF102A43),
                      height: 1.2,
                      letterSpacing: -0.4,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Subtitle description
                  const Text(
                    'Your purifier receives its Wi-Fi details over Bluetooth. Your phone will ask for permission next.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF56627A),
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Card 1: Bluetooth Requirement
                  _buildRequirementCard(
                    icon: Icons.bluetooth_rounded,
                    title: 'Bluetooth',
                    description: 'Required to discover and talk to the purifier during setup.',
                  ),

                  const SizedBox(height: 12),

                  // Card 2: Nearby devices (Android) Requirement
                  _buildRequirementCard(
                    icon: Icons.location_on_outlined,
                    title: 'Nearby devices (Android)',
                    description: "Android labels Bluetooth scanning this way. We don't track your location.",
                  ),

                  const Spacer(),
                  const SizedBox(height: 24),

                  // Bottom "Continue" Button (exact match to Sign In button theme)
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.royalBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
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

  /// Reusable requirement card for Bluetooth & Location
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
        border: Border.all(color: const Color(0xFFD5DEEB)),
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
              color: const Color(0xFFF4F7FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF102A43),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF102A43),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF56627A),
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

  /// 2. Searching/Discovered view shown after clicking "Continue"
  Widget _buildSearchingView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // Radar Scanning Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD6E9FA)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.royalBlue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sensors_rounded, color: AppTheme.royalBlue, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Searching for Shuddham Purifiers',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF102A43)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Keep purifier powered on within 2 m',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.royalBlue),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Discovered Devices',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF102A43),
            ),
          ),
          const SizedBox(height: 10),

          ..._discoveredPurifiers.map((dev) {
            final isPairing = _pairingDeviceId == dev['id'];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF5FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.water_drop_rounded, color: AppTheme.royalBlue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dev['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF102A43)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${dev['model']} • ${dev['location']}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.wifi_rounded, size: 12, color: AppTheme.accentGreen),
                            const SizedBox(width: 4),
                            Text(
                              'Signal: ${dev['signal']}%',
                              style: const TextStyle(fontSize: 10, color: AppTheme.accentGreen, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isPairing ? null : () => _pairPurifier(dev),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.royalBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: const Size(68, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: isPairing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Pair', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
