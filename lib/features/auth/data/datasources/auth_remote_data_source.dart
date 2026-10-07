import 'dart:async';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
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

  Future<void> signOut({String? token});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSourceImpl({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  /// Helper to send HTTP POST request to backend via ApiClient
  Future<Map<String, dynamic>> _httpPost(String endpoint, Map<String, dynamic> body) async {
    try {
      final res = await apiClient.post(endpoint, body: body);
      if (res is Map<String, dynamic>) {
        return res;
      }
      throw ApiException('Unexpected response format received from server.');
    } on ServerException catch (e) {
      throw ApiException(e.message);
    } on NetworkException catch (e) {
      throw ApiException(e.message);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(e.toString());
    }
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

  @override
  Future<void> signOut({String? token}) async {
    try {
      await apiClient.post(ApiEndpoints.logout, token: token);
    } catch (_) {
      // Graceful fallback: local logout proceeds even if network error occurs
    }
  }
}

