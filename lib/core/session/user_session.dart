import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/domain/entities/user_entity.dart';

/// Centralized session manager holding the currently authenticated user's details.
class UserSession extends ChangeNotifier {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  static const String _userSessionKey = 'shuddham_user_session_v1';

  UserEntity? _currentUser;
  String _phoneNumber = '';
  String _userName = '';
  String _email = '';
  String _token = '';

  UserEntity? get currentUser => _currentUser;
  String get phoneNumber => _phoneNumber;
  String get rawPhone => extract10Digits(_phoneNumber.isNotEmpty ? _phoneNumber : (_currentUser?.phone ?? ''));
  String get userName => _userName;
  String get email => _email;
  String get token => _currentUser?.token ?? _token;
  bool get isLoggedIn => _currentUser != null && (_currentUser!.id.isNotEmpty || _token.isNotEmpty);

  /// Load session from persistent storage
  Future<void> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_userSessionKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final token = data['token'] as String? ?? '';
        final id = data['id'] as String? ?? '';
        if (token.isNotEmpty || id.isNotEmpty) {
          _currentUser = UserEntity(
            id: id.isNotEmpty ? id : 'usr-saved',
            fullName: data['fullName'] as String? ?? '',
            phone: data['phone'] as String? ?? '',
            email: data['email'] as String?,
            city: data['city'] as String?,
            token: token,
          );
          _phoneNumber = data['phoneNumber'] as String? ?? _currentUser!.phone;
          _userName = data['userName'] as String? ?? _currentUser!.fullName;
          _email = data['email'] as String? ?? '';
          _token = token;
          notifyListeners();
        }
      } else {
        _currentUser = null;
        _phoneNumber = '';
        _userName = '';
        _email = '';
        _token = '';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[UserSession] Error loading session: $e');
    }
  }

  /// Update the current session with the authenticated user and login input.
  Future<void> setUser(UserEntity user, {String? loginInput}) async {
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

    await _persistSession();
    notifyListeners();
  }

  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUser != null) {
        final data = {
          'id': _currentUser!.id,
          'fullName': _currentUser!.fullName,
          'phone': _currentUser!.phone,
          'email': _currentUser!.email,
          'city': _currentUser!.city,
          'token': _currentUser!.token,
          'phoneNumber': _phoneNumber,
          'userName': _userName,
        };
        await prefs.setString(_userSessionKey, jsonEncode(data));
      } else {
        await prefs.remove(_userSessionKey);
      }
    } catch (e) {
      debugPrint('[UserSession] Error persisting session: $e');
    }
  }

  /// Helper to extract only numeric digits
  static String _extractDigits(String text) {
    return text.replaceAll(RegExp(r'\D'), '');
  }

  /// Helper to extract clean 10-digit Indian phone number (strips +91, 91, or leading 0)
  static String extract10Digits(String? text) {
    if (text == null || text.isEmpty) return '';
    final digits = _extractDigits(text);
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      return digits.substring(1);
    }
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
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
  Future<void> clear() async {
    _currentUser = null;
    _phoneNumber = '';
    _userName = '';
    _email = '';
    _token = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userSessionKey);
    } catch (e) {
      debugPrint('[UserSession] Error clearing session: $e');
    }
    notifyListeners();
  }
}
