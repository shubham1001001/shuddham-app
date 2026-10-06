import 'package:flutter/foundation.dart';
import '../../features/auth/domain/entities/user_entity.dart';

/// Centralized session manager holding the currently authenticated user's details.
class UserSession extends ChangeNotifier {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  UserEntity? _currentUser;
  String _phoneNumber = '';
  String _userName = '';
  String _email = '';
  String _token = '';

  UserEntity? get currentUser => _currentUser;
  String get phoneNumber => _phoneNumber;
  String get rawPhone => _extractDigits(_phoneNumber);
  String get userName => _userName;
  String get email => _email;
  String get token => _currentUser?.token ?? _token;
  bool get isLoggedIn => _currentUser != null;

  /// Update the current session with the authenticated user and login input.
  void setUser(UserEntity user, {String? loginInput}) {
    _currentUser = user;

    // 1. Determine Phone Number
    if (loginInput != null && !loginInput.contains('@') && _extractDigits(loginInput).isNotEmpty) {
      _phoneNumber = formatPhoneNumber(loginInput);
    } else if (user.phone.trim().isNotEmpty) {
      _phoneNumber = formatPhoneNumber(user.phone);
    } else {
      _phoneNumber = '';
    }

    // 2. Determine Name
    if (user.fullName.trim().isNotEmpty && user.fullName.trim().toLowerCase() != 'customer') {
      _userName = user.fullName.trim();
    } else if (loginInput != null && loginInput.contains('@')) {
      final namePart = loginInput.split('@')[0];
      _userName = namePart.isNotEmpty
          ? '${namePart[0].toUpperCase()}${namePart.substring(1)}'
          : 'Shuddham Member';
    } else if (user.phone.trim().isNotEmpty) {
      _userName = 'User ${user.phone.trim()}';
    } else {
      _userName = 'Shuddham Member';
    }

    // 3. Determine Email
    if (user.email != null && user.email!.trim().isNotEmpty) {
      _email = user.email!.trim();
    } else if (loginInput != null && loginInput.contains('@')) {
      _email = loginInput.trim();
    } else {
      _email = '';
    }

    // 4. Determine Token
    _token = user.token;

    notifyListeners();
  }

  /// Helper to extract only numeric digits
  static String _extractDigits(String text) {
    return text.replaceAll(RegExp(r'\D'), '');
  }

  /// Format phone numbers into standard Indian format (+91 XXXXX XXXXX)
  static String formatPhoneNumber(String raw) {
    final digits = _extractDigits(raw);
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    } else if (digits.length == 12 && digits.startsWith('91')) {
      final sub = digits.substring(2);
      return '+91 ${sub.substring(0, 5)} ${sub.substring(5)}';
    } else if (raw.trim().startsWith('+')) {
      return raw.trim();
    } else if (digits.length >= 7) {
      return '+91 $digits';
    }
    return raw.trim();
  }

  /// Clear user session on logout
  void clear() {
    _currentUser = null;
    _phoneNumber = '';
    _userName = '';
    _email = '';
    _token = '';
    notifyListeners();
  }
}
