import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/device_model.dart';

class AddDeviceSheet extends StatefulWidget {
  final Function(DeviceModel) onDeviceAdded;

  const AddDeviceSheet({super.key, required this.onDeviceAdded});

  static Future<void> show(BuildContext context, Function(DeviceModel) onDeviceAdded) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddDeviceSheet(onDeviceAdded: onDeviceAdded),
    );
  }

  @override
  State<AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<AddDeviceSheet> with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 0; // 0: QR Scan, 1: Nearby, 2: Manual

  // Scan state
  bool _isTorchOn = false;
  late AnimationController _laserAnimController;
  late Animation<double> _laserAnim;

  // Radar state
  bool _isScanningRadar = true;
  String? _pairingDeviceId;

  // Manual Form State
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Kitchen RO Purifier');
  final _serialController = TextEditingController(text: 'SHD-RO-8492');
  String _selectedType = 'RO Purifier';
  String _selectedLocation = 'Kitchen';

  final List<String> _deviceTypes = [
    'RO Purifier',
    'TDS Meter',
    'Tank Sensor',
    'UV Filter',
  ];

  final List<String> _locations = [
    'Kitchen',
    'Rooftop Tank',
    'Utility Room',
    'Dining Room',
    'Office',
  ];

  final List<Map<String, dynamic>> _radarDevices = [];

  @override
  void initState() {
    super.initState();
    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _laserAnim = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _laserAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserAnimController.dispose();
    _nameController.dispose();
    _serialController.dispose();
    super.dispose();
  }

  void _rescanRadar() async {
    setState(() {
      _isScanningRadar = true;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _isScanningRadar = false;
    });
  }

  void _finishAddingDevice(DeviceModel device) {
    widget.onDeviceAdded(device);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Add Shuddham Device',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Pair RO purifier, TDS meter or smart sensor',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tab Selector: QR Scan / Bluetooth Radar / Manual Entry (Matching App Theme)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  _buildTabItem(0, Icons.qr_code_scanner_rounded, 'Scan QR'),
                  _buildTabItem(1, Icons.bluetooth_searching_rounded, 'Nearby'),
                  _buildTabItem(2, Icons.edit_note_rounded, 'Manual'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Tab Content
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildCurrentTabContent(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppTheme.royalBlue : AppTheme.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? AppTheme.royalBlue : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildQrScanView();
      case 1:
        return _buildRadarView();
      case 2:
      default:
        return _buildManualView();
    }
  }

  // --- TAB 1: QR SCAN VIEW (Theme Aligned) ---
  Widget _buildQrScanView() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 230,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF072146), Color(0xFF0D3B66)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.royalBlue.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle background water ripple glow
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.aquaCyan.withValues(alpha: 0.06),
                ),
              ),

              // Viewfinder frame
              Container(
                width: 165,
                height: 165,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Stack(
                  children: [
                    // Corner brackets in Aqua Cyan
                    _buildCornerBracket(Alignment.topLeft),
                    _buildCornerBracket(Alignment.topRight),
                    _buildCornerBracket(Alignment.bottomLeft),
                    _buildCornerBracket(Alignment.bottomRight),

                    // Animated Scanning Laser Bar
                    AnimatedBuilder(
                      animation: _laserAnim,
                      builder: (context, child) {
                        return Positioned(
                          top: _laserAnim.value * 155,
                          left: 8,
                          right: 8,
                          child: Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0x000084FF), Color(0xFF00E5FF), Color(0x000084FF)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Torch Toggle
              Positioned(
                bottom: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isTorchOn = !_isTorchOn;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isTorchOn ? AppTheme.royalBlue : Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Icon(
                      _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        const Text(
          'Point camera at the QR code on the back or bottom panel of your Shuddham purifier.',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.35),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Quick Simulated Scan Action (Theme Aligned Button)
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              final newDevice = DeviceModel(
                id: 'dev-${DateTime.now().millisecondsSinceEpoch}',
                name: 'Kitchen Mineral RO',
                model: 'Shuddham RO-7S Pro',
                type: 'RO Purifier',
                serialNumber: 'SHD-QR-${DateTime.now().millisecondsSinceEpoch % 10000}',
                location: 'Kitchen',
                isOnline: true,
                tdsPpm: 82,
                filterLifePercentage: 88,
                lastSync: 'Just now',
                totalLitersPurified: 146.0,
              );
              _finishAddingDevice(newDevice);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.royalBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.qr_code_2_rounded, size: 20, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Simulate Scan & Pair Device',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCornerBracket(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          border: Border(
            top: alignment == Alignment.topLeft || alignment == Alignment.topRight
                ? const BorderSide(color: Color(0xFF00B4D8), width: 3.5)
                : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight
                ? const BorderSide(color: Color(0xFF00B4D8), width: 3.5)
                : BorderSide.none,
            left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft
                ? const BorderSide(color: Color(0xFF00B4D8), width: 3.5)
                : BorderSide.none,
            right: alignment == Alignment.topRight || alignment == Alignment.bottomRight
                ? const BorderSide(color: Color(0xFF00B4D8), width: 3.5)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  // --- TAB 2: BLUETOOTH / RADAR VIEW (Theme Aligned) ---
  Widget _buildRadarView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Radar status card
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Discovered Nearby Devices',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                    ),
                    Text(
                      _isScanningRadar ? 'Scanning for Shuddham BLE beacons...' : 'Scan complete',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _isScanningRadar ? Icons.sync_rounded : Icons.refresh_rounded,
                  color: AppTheme.royalBlue,
                  size: 20,
                ),
                tooltip: 'Rescan nearby devices',
                onPressed: _isScanningRadar ? null : _rescanRadar,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // List of discovered devices
        ..._radarDevices.map((dev) {
          final isPairing = _pairingDeviceId == dev['id'];

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
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
                  child: const Icon(Icons.router_rounded, color: AppTheme.royalBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dev['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${dev['model']} • ${dev['location']}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
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
                  onPressed: isPairing
                      ? null
                      : () async {
                          setState(() {
                            _pairingDeviceId = dev['id'] as String;
                          });
                          await Future.delayed(const Duration(milliseconds: 700));
                          if (!mounted) return;
                          final newDevice = DeviceModel(
                            id: dev['id'] as String,
                            name: dev['name'] as String,
                            model: dev['model'] as String,
                            type: dev['type'] as String,
                            serialNumber: 'SHD-BLE-${DateTime.now().millisecondsSinceEpoch % 10000}',
                            location: dev['location'] as String,
                            isOnline: true,
                            tdsPpm: dev['tds'] as int,
                            filterLifePercentage: 92,
                            lastSync: 'Just now',
                            totalLitersPurified: 95.0,
                          );
                          _finishAddingDevice(newDevice);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.royalBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: const Size(64, 36),
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
    );
  }

  // --- TAB 3: MANUAL ENTRY VIEW (Theme Aligned) ---
  Widget _buildManualView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device Type Selector
          const Text(
            'Device Type',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _deviceTypes.map((type) {
              final isSelected = _selectedType == type;
              return GestureDetector(
                onTap: () => setState(() => _selectedType = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.royalBlue : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppTheme.royalBlue : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.royalBlue.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Device Nickname
          const Text(
            'Device Nickname',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 7),
          TextFormField(
            controller: _nameController,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'e.g., Kitchen Purifier or Master Tank',
              hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.label_outline_rounded, size: 20, color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.royalBlue, width: 1.8),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter a device nickname';
              }
              return null;
            },
          ),

          const SizedBox(height: 14),

          // Serial Number
          const Text(
            'Serial Number / Device ID',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 7),
          TextFormField(
            controller: _serialController,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), letterSpacing: 0.5),
            decoration: InputDecoration(
              hintText: 'e.g. SHD-RO-9021',
              hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8), letterSpacing: 0),
              prefixIcon: const Icon(Icons.qr_code_rounded, size: 20, color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.royalBlue, width: 1.8),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter the device serial number';
              }
              return null;
            },
          ),

          const SizedBox(height: 14),

          // Location
          const Text(
            'Installation Location',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _locations.map((loc) {
              final isSelected = _selectedLocation == loc;
              return GestureDetector(
                onTap: () => setState(() => _selectedLocation = loc),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.royalBlue : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppTheme.royalBlue : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.royalBlue.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    loc,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 22),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  final newDevice = DeviceModel(
                    id: 'dev-${DateTime.now().millisecondsSinceEpoch}',
                    name: _nameController.text.trim(),
                    model: 'Shuddham $_selectedType',
                    type: _selectedType,
                    serialNumber: _serialController.text.trim().toUpperCase(),
                    location: _selectedLocation,
                    isOnline: true,
                    tdsPpm: _selectedType == 'Tank Sensor' ? 120 : 85,
                    filterLifePercentage: 90,
                    lastSync: 'Just now',
                    totalLitersPurified: 80.0,
                  );
                  _finishAddingDevice(newDevice);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.royalBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle_outline_rounded, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Register & Connect Device',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
