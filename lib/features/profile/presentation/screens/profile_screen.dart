import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/utils/logout_dialog.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../features/auth/domain/entities/user_entity.dart';
import 'dart:io';
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Saved addresses state (dynamically added by user)
  final List<Map<String, String>> _addresses = [];

  void _showEditProfileSheet(BuildContext context) {
    final session = UserSession();
    final nameController = TextEditingController(text: session.userName);
    String rawPhone = session.rawPhone.isNotEmpty ? session.rawPhone : session.phoneNumber;
    String digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 10) {
      digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
    }
    final phoneController = TextEditingController(text: digitsOnly);
    final emailController = TextEditingController(text: session.email);
    String? nameError;
    String? phoneError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Edit Profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Update your personal information below',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                onChanged: (val) {
                  if (nameError != null && val.trim().isNotEmpty) {
                    setSheetState(() => nameError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  errorText: nameError,
                  prefixIcon: const Icon(Icons.person_outline, color: AppTheme.royalBlue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.royalBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: phoneController,
                onChanged: (val) {
                  if (phoneError != null && val.trim().length == 10) {
                    setSheetState(() => phoneError = null);
                  }
                },
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  counterText: '',
                  labelText: 'Phone Number (10 digits)',
                  errorText: phoneError,
                  prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.royalBlue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.royalBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.royalBlue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.royalBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final newName = nameController.text.trim();
                    final newPhone = phoneController.text.trim();
                    final newEmail = emailController.text.trim();

                    if (newName.isEmpty) {
                      setSheetState(() => nameError = 'Please enter a valid name');
                      return;
                    }

                    if (newPhone.isNotEmpty && newPhone.length != 10) {
                      setSheetState(() => phoneError = 'Mobile number must be exactly 10 digits');
                      return;
                    }

                    final currentUser = session.currentUser;
                    
                    try {
                      final url = Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.updateMe}');
                      final client = HttpClient()..connectionTimeout = const Duration(seconds: 45);
                      final request = await client.putUrl(url).timeout(const Duration(seconds: 45));
                      
                      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
                      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${currentUser?.token ?? ''}');
                      
                      final bodyBytes = utf8.encode(json.encode({
                        'fullName': newName,
                        'phone': newPhone,
                        'email': newEmail,
                      }));
                      request.add(bodyBytes);
                      
                      final response = await request.close().timeout(const Duration(seconds: 45));
                      final responseBody = await response.transform(utf8.decoder).join();
                      client.close(force: true);

                      if (response.statusCode != 200) {
                        final data = json.decode(responseBody);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(data['message'] ?? 'Failed to update profile'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        return;
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Network error. Please try again.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    // Update session
                    final updatedUser = UserEntity(
                      id: currentUser?.id ?? 'usr_1',
                      fullName: newName,
                      phone: newPhone,
                      email: newEmail,
                      token: currentUser?.token ?? '',
                    );
                    session.setUser(updatedUser, loginInput: newPhone.isNotEmpty ? newPhone : newEmail);

                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Profile updated successfully!'),
                            ],
                          ),
                          backgroundColor: AppTheme.accentGreen,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.royalBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
          },
        );
      },
    );
  }

  void _showAddressesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Saved Addresses',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                      IconButton(
                        onPressed: () => _showAddAddressDialog(ctx, setSheetState),
                        icon: const Icon(Icons.add_location_alt_outlined, color: AppTheme.royalBlue),
                        tooltip: 'Add New Address',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_addresses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No saved addresses yet.\nTap the + icon above to add an address.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _addresses.length,
                      separatorBuilder: (context, i) => const Divider(height: 20),
                      itemBuilder: (context, index) {
                      final item = _addresses[index];
                      final isDefault = item['isDefault'] == 'true';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: isDefault ? AppTheme.royalBlue.withValues(alpha: 0.1) : Colors.grey.shade100,
                          child: Icon(
                            isDefault ? Icons.home : Icons.location_on_outlined,
                            color: isDefault ? AppTheme.royalBlue : AppTheme.textMuted,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            if (isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.royalBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('DEFAULT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.royalBlue)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(item['address'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        trailing: IconButton(
                          icon: Icon(
                            isDefault ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: isDefault ? AppTheme.royalBlue : AppTheme.textMuted,
                          ),
                          onPressed: () {
                            setState(() {
                              for (var i = 0; i < _addresses.length; i++) {
                                _addresses[i]['isDefault'] = (i == index).toString();
                              }
                            });
                            setSheetState(() {});
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddAddressDialog(BuildContext parentCtx, StateSetter setSheetState) {
    final titleCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: parentCtx,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New Address', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Tag (e.g., Home, Work, Parents)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Full Address'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty && addressCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _addresses.add({
                    'title': titleCtrl.text.trim(),
                    'address': addressCtrl.text.trim(),
                    'isDefault': 'false',
                  });
                });
                setSheetState(() {});
                Navigator.pop(dlgCtx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalBlue, foregroundColor: Colors.white),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showReportsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Water Quality Test Reports',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 4),
            const Text('Certified TDS & Purity Diagnostics', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 16),
            _buildReportTile('Latest Audit Report - Sep 2026', 'TDS: 45 PPM • Purity 99.8%', 'PDF • 1.2 MB', Colors.green),
            const SizedBox(height: 10),
            _buildReportTile('Installation Report - Aug 2026', 'TDS: 52 PPM • 7-Filter Check Passed', 'PDF • 2.4 MB', AppTheme.royalBlue),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTile(String title, String subtitle, String fileInfo, Color badgeColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.picture_as_pdf_rounded, color: badgeColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                const SizedBox(height: 2),
                Text(fileInfo, style: TextStyle(fontSize: 10, color: badgeColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded, color: AppTheme.royalBlue),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading report...')),
              );
            },
          ),
        ],
      ),
    );
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
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFEBF6FF),
                        child: const Icon(Icons.person, size: 30, color: AppTheme.royalBlue),
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
                        onPressed: () => _showEditProfileSheet(context),
                        icon: const Icon(Icons.edit_outlined, color: AppTheme.royalBlue),
                        tooltip: 'Edit Profile',
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // RO Purifier Health Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryBlue, Color(0xFF00B4D8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.royalBlue.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Registered RO Purifier', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Icon(Icons.water_drop, color: Colors.white, size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Shuddham Mineral RO (7-Stage)',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: 0.82,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Filter Life: 82%', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text('Next Service: ~45 Days', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Menu List
            ListenableBuilder(
              listenable: UserSession(),
              builder: (context, _) {
                final email = UserSession().email;
                return Column(
                  children: [
                    if (email.isNotEmpty)
                      _buildMenuItem(
                        Icons.alternate_email_rounded,
                        'Registered Email',
                        email,
                        onTap: () => _showEditProfileSheet(context),
                      ),
                    _buildMenuItem(
                      Icons.location_on_outlined,
                      'Saved Addresses',
                      () {
                        final defaultAddr = _addresses.where((e) => e['isDefault'] == 'true').firstOrNull ?? _addresses.firstOrNull;
                        if (defaultAddr != null) {
                          return '${defaultAddr['title']}: ${defaultAddr['address']}';
                        }
                        return 'Tap to add home or service address';
                      }(),
                      onTap: () => _showAddressesSheet(context),
                    ),
                    _buildMenuItem(
                      Icons.history_outlined,
                      'Water Quality Test Reports',
                      '2 certified reports available',
                      onTap: () => _showReportsSheet(context),
                    ),
                    _buildMenuItem(
                      Icons.headset_mic_outlined,
                      'Customer Support Hotline',
                      '+91 1800-SHUDDHAM',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Calling Support Helpline +91 1800-SHUDDHAM...'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      Icons.info_outline,
                      'About Shuddham Water Solutions',
                      'Version 1.0.0',
                      onTap: () => _showAboutDialog(context),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Prominent Logout Button
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

  Widget _buildMenuItem(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EEF8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0077EE).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.royalBlue, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark)),
                      Text(
                        subtitle,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

