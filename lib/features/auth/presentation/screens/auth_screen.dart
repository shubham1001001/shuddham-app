import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/session/user_session.dart';
import '../../../../main.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/signup_usecase.dart';
import '../../domain/usecases/forgot_password_usecase.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/phone_number_field.dart';
import '../widgets/forgot_password_bottom_sheet.dart';

/// Formatter that limits numeric inputs (phone numbers) to 10 digits, while allowing full email strings
class _PhoneOrEmailInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    // If the input consists purely of digits (phone number), strictly limit to 10 digits
    if (RegExp(r'^\d+$').hasMatch(text) && text.length > 10) {
      return oldValue;
    }
    return newValue;
  }
}

class AuthScreen extends StatefulWidget {
  final bool initialIsSignUp;

  const AuthScreen({super.key, this.initialIsSignUp = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isSignUp;
  bool _obscurePassword = true;
  bool _agreeTerms = true;
  bool _isLoading = false;
  bool _autoValidate = false;

  // Controllers
  final _phoneOrEmailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  // Clean Architecture Usecases
  late final LoginUseCase _loginUseCase;
  late final SignUpUseCase _signUpUseCase;
  late final ForgotPasswordUseCase _forgotPasswordUseCase;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;

    final dataSource = AuthRemoteDataSourceImpl();
    final repository = AuthRepositoryImpl(remoteDataSource: dataSource);
    _loginUseCase = LoginUseCase(repository);
    _signUpUseCase = SignUpUseCase(repository);
    _forgotPasswordUseCase = ForgotPasswordUseCase(repository);
  }

  @override
  void dispose() {
    _phoneOrEmailController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _loginPasswordController.dispose();
    _signUpPasswordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _submitAuth() async {
    setState(() => _autoValidate = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_isSignUp && !_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms & Privacy Policy to continue'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        final phoneInput = _phoneController.text.trim();
        final user = await _signUpUseCase(SignUpParams(
          fullName: _fullNameController.text.trim(),
          phone: phoneInput,
          email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
          password: _signUpPasswordController.text,
        ));
        UserSession().setUser(user, loginInput: phoneInput);
      } else {
        final credential = _phoneOrEmailController.text.trim();
        final password = _loginPasswordController.text.trim();

        final user = await _loginUseCase(LoginParams(
          phoneOrEmail: credential,
          password: password,
        ));
        UserSession().setUser(user, loginInput: credential);
      }

      if (!mounted) return;

      final message = _isSignUp
          ? 'Account created! Welcome to Shuddham Water Solutions.'
          : 'Signed in successfully!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      );
    } catch (e) {
      if (!mounted) return;
      var errorMsg = e.toString().replaceFirst(RegExp(r'^(Exception|ApiException):\s*'), '');
      if (errorMsg.toLowerCase().contains('incorrect password') ||
          errorMsg.toLowerCase().contains('password')) {
        errorMsg = 'Incorrect password. Please enter the correct password.';
      } else if (errorMsg.toLowerCase().contains('administrators registered') || 
          errorMsg.toLowerCase().contains('access this portal') ||
          errorMsg.toLowerCase().contains('account not found')) {
        errorMsg = 'Account not found. Please check your credentials or tap Sign Up to create an account.';
      } else if (_isSignUp && (errorMsg.toLowerCase().contains('already exists') || errorMsg.toLowerCase().contains('already registered'))) {
        errorMsg = 'This mobile number or email is already registered. Please Sign In.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Soft ambient blue glow in header
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            child: Container(
              height: 240,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.9,
                  colors: [
                    const Color(0xFF0077EE).withValues(alpha: 0.08),
                    const Color(0xFF00B4D8).withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _autoValidate
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Shuddham Brand Logo
                      Center(
                        child: Hero(
                          tag: 'shuddham_logo',
                          child: Image.asset(
                            'assets/images/logo-full.png',
                            height: 135,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // 2. Title & Subtitle Header
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Column(
                          key: ValueKey<bool>(_isSignUp),
                          children: [
                            Text(
                              _isSignUp ? 'Create Account' : 'Welcome Back',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isSignUp
                                  ? 'Join Shuddham for pure & certified drinking water'
                                  : 'Sign in to access your purifier services & live health',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // 3. Modern Segmented Tab Switcher (Sign In / Sign Up)
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (_isSignUp) {
                                    _formKey.currentState?.reset();
                                    _loginPasswordController.clear();
                                    setState(() {
                                      _isSignUp = false;
                                      _autoValidate = false;
                                    });
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  decoration: BoxDecoration(
                                    color: !_isSignUp ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: !_isSignUp
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
                                        Icons.login_rounded,
                                        size: 16,
                                        color: !_isSignUp ? AppTheme.royalBlue : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: !_isSignUp ? FontWeight.bold : FontWeight.w600,
                                          color: !_isSignUp ? AppTheme.royalBlue : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (!_isSignUp) {
                                    _formKey.currentState?.reset();
                                    _signUpPasswordController.clear();
                                    setState(() {
                                      _isSignUp = true;
                                      _autoValidate = false;
                                    });
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  decoration: BoxDecoration(
                                    color: _isSignUp ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: _isSignUp
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
                                        Icons.person_add_rounded,
                                        size: 16,
                                        color: _isSignUp ? AppTheme.royalBlue : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Sign Up',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: _isSignUp ? FontWeight.bold : FontWeight.w600,
                                          color: _isSignUp ? AppTheme.royalBlue : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 4. Elevated Form Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(color: const Color(0xFFE8EEF5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_isSignUp) ...[
                              // ───────── SIGN IN FORM ─────────
                              AuthTextField(
                                key: const ValueKey('signin_login_field'),
                                controller: _phoneOrEmailController,
                                label: 'Mobile Number or Email ID',
                                hint: 'Enter 10-digit mobile or email',
                                icon: Icons.alternate_email_rounded,
                                keyboardType: TextInputType.emailAddress,
                                inputFormatters: [_PhoneOrEmailInputFormatter()],
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter your mobile number or email ID';
                                  }
                                  final input = val.trim();
                                  if (input.contains('@')) {
                                    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                    if (!emailRegex.hasMatch(input)) {
                                      return 'Please enter a valid email address';
                                    }
                                  } else {
                                    final digitsOnly = input.replaceAll(RegExp(r'\D'), '');
                                    if (digitsOnly.length != 10) {
                                      return 'Please enter a valid 10-digit mobile number';
                                    }
                                    if (!RegExp(r'^[6-9]').hasMatch(digitsOnly)) {
                                      return 'Mobile number must start with 6, 7, 8, or 9';
                                    }
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              AuthTextField(
                                key: const ValueKey('signin_pass_field'),
                                controller: _loginPasswordController,
                                label: 'Password',
                                hint: 'Enter your password',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscurePassword,
                                autofillHints: const [AutofillHints.password],
                                enableSuggestions: false,
                                autocorrect: false,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    size: 20,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (val.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 8),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    ForgotPasswordBottomSheet.show(
                                      context,
                                      initialValue: _phoneOrEmailController.text.trim(),
                                      forgotPasswordUseCase: _forgotPasswordUseCase,
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.royalBlue,
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Primary Sign In Button
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submitAuth,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.royalBlue,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Sign In',
                                              style: TextStyle(
                                                fontSize: 15.5,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_forward_rounded, size: 18),
                                          ],
                                        ),
                                ),
                              ),
                            ] else ...[
                              // ───────── SIGN UP FORM ─────────
                              AuthTextField(
                                key: const ValueKey('signup_name_field'),
                                controller: _fullNameController,
                                label: 'Full Name',
                                hint: 'e.g. Rajesh Sharma',
                                icon: Icons.person_outline_rounded,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter your full name';
                                  }
                                  final trimmed = val.trim();
                                  if (trimmed.length < 3) {
                                    return 'Full name must be at least 3 characters';
                                  }
                                  if (!RegExp(r"^[a-zA-Z\s.']+$").hasMatch(trimmed)) {
                                    return 'Name can only contain alphabets and spaces';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),

                              PhoneNumberField(
                                key: const ValueKey('signup_phone_field'),
                                controller: _phoneController,
                                label: 'Mobile Number',
                                hint: 'Enter 10-digit number',
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter your mobile number';
                                  }
                                  final digitsOnly = val.replaceAll(RegExp(r'\D'), '');
                                  if (digitsOnly.length != 10) {
                                    return 'Mobile number must be exactly 10 digits';
                                  }
                                  if (!RegExp(r'^[6-9]').hasMatch(digitsOnly)) {
                                    return 'Mobile number must start with 6, 7, 8, or 9';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),

                              AuthTextField(
                                key: const ValueKey('signup_email_field'),
                                controller: _emailController,
                                label: 'Email ID',
                                hint: 'e.g. name@example.com',
                                icon: Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter your email address';
                                  }
                                  final trimmed = val.trim();
                                  final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                  if (!emailRegex.hasMatch(trimmed)) {
                                    return 'Please enter a valid email address';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),

                              AuthTextField(
                                key: const ValueKey('signup_pass_field'),
                                controller: _signUpPasswordController,
                                label: 'Create Password',
                                hint: 'Minimum 6 characters',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscurePassword,
                                autofillHints: null,
                                enableSuggestions: false,
                                autocorrect: false,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    size: 20,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return 'Please create a password';
                                  }
                                  if (val.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              // Terms & Conditions Checkbox
                              InkWell(
                                onTap: () => setState(() => _agreeTerms = !_agreeTerms),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: Checkbox(
                                          value: _agreeTerms,
                                          activeColor: AppTheme.royalBlue,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                                          onChanged: (val) => setState(() => _agreeTerms = val ?? true),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Text(
                                          'I agree to Shuddham Terms & Privacy Policy',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Primary Create Account Button
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submitAuth,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.royalBlue,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Create Account',
                                              style: TextStyle(
                                                fontSize: 15.5,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_forward_rounded, size: 18),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 5. Clean Footer Switcher Card
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _formKey.currentState?.reset();
                                  setState(() {
                                    _isSignUp = !_isSignUp;
                                    _autoValidate = false;
                                  });
                                },
                                child: Text(
                                  _isSignUp ? 'Sign In' : 'Sign Up',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.royalBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
