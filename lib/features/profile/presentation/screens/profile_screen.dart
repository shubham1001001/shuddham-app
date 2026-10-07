import 'package:flutter/material.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/logout_dialog.dart';
import '../../data/repositories/address_repository_impl.dart';
import '../../domain/usecases/get_addresses_usecase.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/profile_menu_item.dart';
import '../widgets/saved_addresses_sheet.dart';
import '../widgets/water_reports_sheet.dart';

class ProfileScreen extends StatefulWidget {
  final GetAddressesUseCase? _injectedUseCase;
  GetAddressesUseCase get getAddressesUseCase =>
      _injectedUseCase ?? GetAddressesUseCase(AddressRepositoryImpl());

  const ProfileScreen({
    super.key,
    GetAddressesUseCase? getAddressesUseCase,
  }) : _injectedUseCase = getAddressesUseCase;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final List<Map<String, String>> _addresses = [];

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    try {
      final token = UserSession().token.isNotEmpty ? UserSession().token : null;
      final userId = UserSession().currentUser?.id;
      final list = await widget.getAddressesUseCase(
        GetAddressesParams(token: token, userId: userId),
      );
      if (!mounted) return;
      setState(() {
        _addresses.clear();
        for (final item in list) {
          _addresses.add({
            'id': item.id,
            'title': item.title,
            'address': item.address,
            'city': item.city,
            'pincode': item.pincode,
            'isDefault': item.isDefault.toString(),
          });
        }
      });
    } catch (_) {}
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryBlue, Color(0xFF00B4D8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.royalBlue.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.water_drop_rounded, size: 38, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Shuddham Water Solutions',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.royalBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'v1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.royalBlue,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Providing pure, healthy, and mineralized water solutions for domestic and industrial purifiers.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.royalBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Profile & Support', style: TextStyle(color: AppTheme.textDark)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            tooltip: 'Log Out',
            onPressed: () => showLogoutDialog(context),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // User Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2EEF8)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0077EE).withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListenableBuilder(
                listenable: UserSession(),
                builder: (context, _) {
                  final session = UserSession();
                  return Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Color(0xFFEBF6FF),
                        child: Icon(Icons.person, size: 30, color: AppTheme.royalBlue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.userName.isNotEmpty ? session.userName : 'Shuddham Member',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            if (session.phoneNumber.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                session.phoneNumber,
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            if (session.email.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                session.email,
                                style: const TextStyle(
                                  color: AppTheme.royalBlue,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => EditProfileSheet.show(
                          context,
                          onProfileUpdated: () => setState(() {}),
                        ),
                        icon: const Icon(Icons.edit_outlined, color: AppTheme.royalBlue),
                        tooltip: 'Edit Profile',
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Menu Items
            ListenableBuilder(
              listenable: UserSession(),
              builder: (context, _) {
                final email = UserSession().email;
                return Column(
                  children: [
                    if (email.isNotEmpty)
                      ProfileMenuItem(
                        icon: Icons.alternate_email_rounded,
                        title: 'Registered Email',
                        subtitle: email,
                        onTap: () => EditProfileSheet.show(
                          context,
                          onProfileUpdated: () => setState(() {}),
                        ),
                      ),
                    ProfileMenuItem(
                      icon: Icons.location_on_outlined,
                      title: 'Saved Addresses',
                      subtitle: () {
                        final defaultAddr = _addresses.where((e) => e['isDefault'] == 'true').firstOrNull ?? _addresses.firstOrNull;
                        if (defaultAddr != null) {
                          return '${defaultAddr['title']}: ${defaultAddr['address']}';
                        }
                        return 'Tap to add home or service address';
                      }(),
                      onTap: () => SavedAddressesSheet.show(
                        context,
                        addresses: _addresses,
                        onAddressesChanged: () => setState(() {}),
                      ),
                    ),
                    ProfileMenuItem(
                      icon: Icons.history_outlined,
                      title: 'Water Quality Test Reports',
                      subtitle: '2 certified reports available',
                      onTap: () => WaterReportsSheet.show(context),
                    ),
                    ProfileMenuItem(
                      icon: Icons.headset_mic_outlined,
                      title: 'Customer Support Hotline',
                      subtitle: '+91 1800-SHUDDHAM',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Calling Support Helpline +91 1800-SHUDDHAM...'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    ProfileMenuItem(
                      icon: Icons.info_outline,
                      title: 'About Shuddham Water Solutions',
                      subtitle: 'Version 1.0.0',
                      onTap: () => _showAboutDialog(context),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Logout Action Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => showLogoutDialog(context),
                  borderRadius: BorderRadius.circular(16),
                  splashColor: const Color(0xFFFCA5A5).withValues(alpha: 0.2),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
