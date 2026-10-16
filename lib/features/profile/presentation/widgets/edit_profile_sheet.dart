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
  String? _emailError;
  String? _generalError;

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

  void _clearErrors() {
    if (_generalError != null || _nameError != null || _phoneError != null || _emailError != null) {
      setState(() {
        _generalError = null;
        _nameError = null;
        _phoneError = null;
        _emailError = null;
      });
    }
  }

  Future<void> _handleSave() async {
    final newName = _nameController.text.trim();
    final newPhone = UserSession.extract10Digits(_phoneController.text.trim());
    final newEmail = _emailController.text.trim();

    setState(() {
      _nameError = null;
      _phoneError = null;
      _emailError = null;
      _generalError = null;
    });

    bool hasValidationError = false;

    if (newName.isEmpty) {
      _nameError = 'Please enter a valid name';
      hasValidationError = true;
    }

    if (newPhone.isNotEmpty && newPhone.length != 10) {
      _phoneError = 'Mobile number must be exactly 10 digits';
      hasValidationError = true;
    }

    if (newEmail.isNotEmpty && (!newEmail.contains('@') || !newEmail.contains('.'))) {
      _emailError = 'Please enter a valid email address';
      hasValidationError = true;
    }

    if (hasValidationError) {
      setState(() {});
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
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
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
        String msg = e
            .toString()
            .replaceFirst(RegExp(r'^(Exception|ApiException):\s*'), '')
            .trim();
        if (msg.isEmpty) {
          msg = 'Unable to update profile. Please check your connection and try again.';
        }
        setState(() {
          _isLoading = false;
          _generalError = msg;
        });
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

            // In-Sheet Error Alert Banner (Never hidden behind modal)
            if (_generalError != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _generalError!,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => _generalError = null),
                      child: const Icon(Icons.close_rounded, color: Color(0xFFDC2626), size: 18),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              onChanged: (_) => _clearErrors(),
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
              onChanged: (_) => _clearErrors(),
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
              onChanged: (_) => _clearErrors(),
              decoration: InputDecoration(
                labelText: 'Email Address',
                errorText: _emailError,
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
