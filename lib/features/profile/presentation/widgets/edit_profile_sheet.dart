import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/domain/entities/user_entity.dart';
import '../../domain/usecases/update_profile_use_case.dart';
import '../../data/repositories/profile_repository_impl.dart';

/// Modal bottom sheet widget for editing customer profile.
class EditProfileSheet extends StatefulWidget {
  final VoidCallback? onProfileUpdated;
  final UpdateProfileUseCase updateProfileUseCase;

  EditProfileSheet({
    super.key,
    this.onProfileUpdated,
    UpdateProfileUseCase? updateProfileUseCase,
  }) : updateProfileUseCase = updateProfileUseCase ?? UpdateProfileUseCase(ProfileRepositoryImpl());

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onProfileUpdated,
    UpdateProfileUseCase? updateProfileUseCase,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditProfileSheet(
        onProfileUpdated: onProfileUpdated,
        updateProfileUseCase: updateProfileUseCase,
      ),
    );
  }

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _session = UserSession();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  bool _isLoading = false;
  String? _nameError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _session.userName);
    final initialPhone = UserSession.extract10Digits(
      _session.rawPhone.isNotEmpty
          ? _session.rawPhone
          : (_session.currentUser?.phone ?? _session.phoneNumber),
    );
    _phoneController = TextEditingController(text: initialPhone);
    _emailController = TextEditingController(text: _session.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final newName = _nameController.text.trim();
    final newPhone = UserSession.extract10Digits(_phoneController.text.trim());
    final newEmail = _emailController.text.trim();

    setState(() {
      _nameError = null;
      _phoneError = null;
    });

    if (newName.isEmpty) {
      setState(() => _nameError = 'Please enter a valid name');
      return;
    }

    if (newPhone.isNotEmpty && newPhone.length != 10) {
      setState(() => _phoneError = 'Mobile number must be exactly 10 digits');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = _session.currentUser;
      final updatedUser = await widget.updateProfileUseCase(
        UpdateProfileParams(
          fullName: newName,
          phone: newPhone,
          email: newEmail.isNotEmpty ? newEmail : null,
          token: currentUser?.token,
        ),
      );

      // Update local session
      _session.setUser(
        UserEntity(
          id: currentUser?.id ?? updatedUser.id,
          fullName: updatedUser.fullName,
          phone: updatedUser.phone,
          email: updatedUser.email,
          token: currentUser?.token ?? '',
        ),
        loginInput: newPhone.isNotEmpty ? newPhone : newEmail,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onProfileUpdated?.call();

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
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
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
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name *',
                errorText: _nameError,
                prefixIcon: const Icon(Icons.person_outline, color: AppTheme.royalBlue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                labelText: 'Mobile Number (10 digits) *',
                errorText: _phoneError,
                prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.royalBlue),
                prefixText: '+91 ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.royalBlue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.royalBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
