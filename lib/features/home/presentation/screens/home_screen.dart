import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/logout_dialog.dart';
import '../../data/models/device_model.dart';
import '../widgets/water_drop_illustration.dart';
import '../widgets/device_card.dart';
import '../widgets/add_device_card.dart';
import '../widgets/device_details_sheet.dart';
import 'add_device_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Start with empty devices list to show the "No purifier added yet" screen
  final List<DeviceModel> _devices = [];
  int _selectedDeviceIndex = 0;

  void _openAddDeviceModal() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddDeviceSetupScreen(
          onDeviceAdded: (newDevice) {
            setState(() {
              _devices.add(newDevice);
              _selectedDeviceIndex = _devices.length - 1;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${newDevice.name} paired successfully! Telemetry is live.',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppTheme.accentGreen,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 4),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openDeviceDetails(DeviceModel device, int index) {
    DeviceDetailsSheet.show(
      context,
      device: device,
      onRemove: () {
        setState(() {
          _devices.removeAt(index);
          if (_selectedDeviceIndex >= _devices.length) {
            _selectedDeviceIndex = _devices.isNotEmpty ? _devices.length - 1 : 0;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${device.name} has been unpaired.'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      },
      onSync: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced telemetry for ${device.name}. All readings updated!'),
            backgroundColor: AppTheme.royalBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _devices.isEmpty
            ? _buildNoPurifierScreen()
            : _buildConnectedPurifierScreen(),
      ),
    );
  }

  /// 1. Screen matching the user's reference image
  /// (with "Home" [Guest], centered water drop, "No purifier added yet",
  /// and "+ Add device" button - WITHOUT the bottom "Try with sample purifier" button)
  Widget _buildNoPurifierScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header: Shuddham Brand Logo + Title + Status + Logout
        _buildTopHeader(isConnected: false),

        // Centered Main Content
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Circular water droplet illustration
                  const WaterDropIllustration(size: 155),
                  const SizedBox(height: 28),

                  // Heading
                  const Text(
                    'No purifier added yet',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF102A43),
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Subtitle description
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 36),
                    child: Text(
                      'Add your RO purifier to see water TDS and temperature live. Keep it powered on and within 2 m of your phone.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF627D98),
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Primary Button: "+ Add device"
                  // Note: Bottom button ("Try with sample purifier") is omitted as per "niche vali btn nhi"
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _openAddDeviceModal,
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
                            Icon(Icons.add_rounded, size: 20, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Add device',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 2. Screen shown once user connects their purifier(s)
  Widget _buildConnectedPurifierScreen() {
    final activeDevice = _devices.isNotEmpty && _selectedDeviceIndex < _devices.length
        ? _devices[_selectedDeviceIndex]
        : null;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header: Shuddham Brand Logo + Title + Status + Actions
          _buildTopHeader(isConnected: true),

          const SizedBox(height: 16),

          // Devices Carousel
          SizedBox(
            height: 215,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _devices.length + 1,
              itemBuilder: (context, index) {
                if (index == _devices.length) {
                  return AddDeviceCard(onTap: _openAddDeviceModal);
                }
                final dev = _devices[index];
                return DeviceCard(
                  device: dev,
                  isSelected: index == _selectedDeviceIndex,
                  onSelect: () {
                    setState(() {
                      _selectedDeviceIndex = index;
                    });
                  },
                  onDetails: () => _openDeviceDetails(dev, index),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Live Water Purity & Temperature Telemetry Card
          if (activeDevice != null)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2EEF8)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0077EE).withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.accentGreen,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Live Sensor • ${activeDevice.name}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'CERTIFIED SAFE',
                          style: TextStyle(
                            color: AppTheme.accentGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
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
                              const Text('Water TDS', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              const SizedBox(height: 4),
                              Text(
                                '${activeDevice.tdsPpm} PPM',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                              ),
                              const Text('Optimal Purity', style: TextStyle(fontSize: 10, color: AppTheme.accentGreen, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Temperature', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              SizedBox(height: 4),
                              Text(
                                '24°C',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                              ),
                              Text('Normal & Safe', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => _openDeviceDetails(activeDevice, _selectedDeviceIndex),
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: const Text('Manage Device'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _devices.removeAt(_selectedDeviceIndex);
                            if (_selectedDeviceIndex >= _devices.length) {
                              _selectedDeviceIndex = _devices.isNotEmpty ? _devices.length - 1 : 0;
                            }
                          });
                        },
                        icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                        label: const Text('Unpair', style: TextStyle(color: Color(0xFFEF4444))),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Popular Water Services Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Popular Water Services',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              TextButton(
                onPressed: () => widget.onNavigate(1),
                child: const Text('View All', style: TextStyle(color: AppTheme.royalBlue, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: AppConstants.quickServices.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              final srv = AppConstants.quickServices[index];
              return InkWell(
                onTap: () => widget.onNavigate(1),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2EEF8)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0077EE).withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F7FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.water_drop_outlined, color: AppTheme.royalBlue, size: 20),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            srv['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            srv['subtitle'] as String,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Text(
                        srv['price'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.royalBlue, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Top Brand Header with Shuddham Logo, Name, Status Pill and Actions
  Widget _buildTopHeader({required bool isConnected}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isConnected ? 0 : 24,
        vertical: isConnected ? 0 : 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                // Shuddham Logo Mark
                Image.asset(
                  'assets/images/logo-mark.png',
                  height: 38,
                  width: 38,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Flexible(
                            child: Text(
                              'Shuddham',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF102A43),
                                letterSpacing: -0.4,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_devices.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_devices.length} Paired',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Smart Water Solutions',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isConnected) ...[
                InkWell(
                  onTap: _openAddDeviceModal,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.royalBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.royalBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add_rounded, size: 15, color: AppTheme.royalBlue),
                        SizedBox(width: 3),
                        Text(
                          'Add Device',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.royalBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
                tooltip: 'Log Out',
                onPressed: () => showLogoutDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
