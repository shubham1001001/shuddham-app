import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../models/user_model.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

abstract class AuthRemoteDataSource {
  Future<UserModel> signIn({
    required String phoneOrEmail,
    required String password,
  });

  Future<UserModel> signInWithOtp({
    required String phone,
    required String otp,
  });

  Future<UserModel> signUp({
    required String fullName,
    required String phone,
    required String password,
    String? email,
    String? city,
  });

  Future<String> forgotPassword({
    required String phone,
    required String email,
    required String newPassword,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final List<String> _baseUrls = ApiEndpoints.allBaseUrls;

  /// Helper to send HTTP POST request to backend with automatic fallback endpoints
  Future<Map<String, dynamic>> _httpPost(String endpoint, Map<String, dynamic> body) async {
    for (final baseUrl in _baseUrls) {
      HttpClient? client;
      try {
        final uri = Uri.parse('$baseUrl$endpoint');
        debugPrint('📡 [API Request] POST $uri');
        debugPrint('   Payload: ${jsonEncode(body)}');

        client = HttpClient()..connectionTimeout = const Duration(seconds: 45);
        final request = await client.postUrl(uri).timeout(const Duration(seconds: 45));
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        request.add(utf8.encode(jsonEncode(body)));

        final response = await request.close().timeout(const Duration(seconds: 45));
        final responseBody = await response.transform(utf8.decoder).join();

        debugPrint('📥 [API Response] Status ${response.statusCode} from $uri');
        debugPrint('   Body: $responseBody');

        if (responseBody.isNotEmpty) {
          final json = jsonDecode(responseBody) as Map<String, dynamic>;
          if (response.statusCode >= 200 && response.statusCode < 300) {
            debugPrint('✅ [API Success] Request succeeded via $baseUrl');
            client.close(force: true);
            return json;
          } else {
            final msg = json['message'] as String? ?? 'Error: ${response.statusCode}';
            debugPrint('❌ [API Error] Status ${response.statusCode}: $msg');
            client.close(force: true);
            throw ApiException(msg);
          }
        }
      } on ApiException {
        client?.close(force: true);
        rethrow;
      } on SocketException catch (e) {
        debugPrint('⚠️ [API Network] $baseUrl unreachable: ${e.message}. Trying next candidate...');
        continue;
      } on HttpException catch (e) {
        debugPrint('⚠️ [API HTTP] $baseUrl error: ${e.message}. Trying next candidate...');
        continue;
      } on TimeoutException {
        debugPrint('⚠️ [API Timeout] $baseUrl timed out. Render may be waking up...');
        continue;
      } on HandshakeException catch (e) {
        debugPrint('⚠️ [API SSL] $baseUrl SSL handshake failed: ${e.message}. Trying next candidate...');
        continue;
      } catch (e) {
        if (e is ApiException) rethrow;
        debugPrint('⚠️ [API Error] $baseUrl exception: $e');
        continue;
      } finally {
        client?.close(force: true);
      }
    }

    debugPrint('❌ [API Network Error] All backend endpoints failed to respond.');
    throw ApiException('Unable to connect to Shuddham server. Please check your internet connection and try again.');
  }

  @override
  Future<UserModel> signIn({
    required String phoneOrEmail,
    required String password,
  }) async {
    Map<String, dynamic> json;
    try {
      json = await _httpPost(ApiEndpoints.customerLogin, {
        'phoneOrEmail': phoneOrEmail,
        'password': password,
      });
    } on ApiException catch (e) {
      if (e.message.contains('404')) {
        json = await _httpPost(ApiEndpoints.login, {
          'phoneOrEmail': phoneOrEmail,
          'password': password,
        });
      } else {
        rethrow;
      }
    }

    final data = json['data'] as Map<String, dynamic>;
    final userMap = Map<String, dynamic>.from(data['user'] as Map);
    userMap['token'] = data['token'];
    if (!phoneOrEmail.contains('@') && (userMap['phone'] == null || userMap['phone'].toString().isEmpty)) {
      userMap['phone'] = phoneOrEmail;
    }
    return UserModel.fromJson(userMap);
  }

  @override
  Future<UserModel> signInWithOtp({
    required String phone,
    required String otp,
  }) async {
    final json = await _httpPost(ApiEndpoints.verifyOtp, {
      'phone': phone,
      'otp': otp,
    });

    final data = json['data'] as Map<String, dynamic>;
    final userMap = Map<String, dynamic>.from(data['user'] as Map);
    userMap['token'] = data['token'];
    return UserModel.fromJson(userMap);
  }

  @override
  Future<UserModel> signUp({
    required String fullName,
    required String phone,
    required String password,
    String? email,
    String? city,
  }) async {
    Map<String, dynamic> json;
    try {
      json = await _httpPost(ApiEndpoints.customerSignup, {
        'fullName': fullName,
        'phone': phone,
        'password': password,
        'role': 'Customer',
        if (email != null && email.isNotEmpty) 'email': email,
        if (city != null && city.isNotEmpty) 'city': city,
      });
    } on ApiException catch (e) {
      if (e.message.contains('404')) {
        json = await _httpPost(ApiEndpoints.signup, {
          'fullName': fullName,
          'phone': phone,
          'password': password,
          'role': 'Customer',
          if (email != null && email.isNotEmpty) 'email': email,
          if (city != null && city.isNotEmpty) 'city': city,
        });
      } else {
        rethrow;
      }
    }

    final data = json['data'] as Map<String, dynamic>;
    final userMap = Map<String, dynamic>.from(data['user'] as Map);
    userMap['token'] = data['token'];
    return UserModel.fromJson(userMap);
  }

  @override
  Future<String> forgotPassword({
    required String phone,
    required String email,
    required String newPassword,
  }) async {
    final json = await _httpPost(ApiEndpoints.forgotPassword, {
      'phone': phone,
      'email': email,
      'newPassword': newPassword,
    });
    return json['message'] as String? ?? 'Password reset successfully.';
  }
}

