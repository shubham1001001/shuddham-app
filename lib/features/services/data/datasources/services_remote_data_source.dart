import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../models/water_service_model.dart';

/// Exception class for Services API errors.
class ServicesApiException implements Exception {
  final String message;
  ServicesApiException(this.message);

  @override
  String toString() => message;
}

/// Abstract contract for the services remote data source.
abstract class ServicesRemoteDataSource {
  /// Fetch all services, optionally filtered by [category].
  Future<List<WaterServiceModel>> getServices({String? category});

  /// Fetch a single service by [id].
  Future<WaterServiceModel> getServiceById(String id);
}

/// Concrete implementation that hits the Shuddham backend API.
/// Uses the same multi-endpoint fallback strategy as [AuthRemoteDataSourceImpl].
class ServicesRemoteDataSourceImpl implements ServicesRemoteDataSource {
  final List<String> _baseUrls = ApiEndpoints.allBaseUrls;

  /// Helper: HTTP GET with automatic fallback across all backend URLs.
  Future<Map<String, dynamic>> _httpGet(String endpoint) async {
    for (final baseUrl in _baseUrls) {
      HttpClient? client;
      try {
        final uri = Uri.parse('$baseUrl$endpoint');
        debugPrint('📡 [Services API] GET $uri');

        client = HttpClient()..connectionTimeout = const Duration(seconds: 45);
        final request = await client.getUrl(uri).timeout(const Duration(seconds: 45));
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');

        final response = await request.close().timeout(const Duration(seconds: 45));
        final responseBody = await response.transform(utf8.decoder).join();

        debugPrint('📥 [Services API] Status ${response.statusCode} from $uri');

        if (responseBody.isNotEmpty) {
          final json = jsonDecode(responseBody) as Map<String, dynamic>;
          if (response.statusCode >= 200 && response.statusCode < 300) {
            debugPrint('✅ [Services API] Success via $baseUrl');
            client.close(force: true);
            return json;
          } else {
            final msg = json['message'] as String? ?? 'Error: ${response.statusCode}';
            debugPrint('❌ [Services API] Error ${response.statusCode}: $msg');
            client.close(force: true);
            throw ServicesApiException(msg);
          }
        }
      } on ServicesApiException {
        client?.close(force: true);
        rethrow;
      } on SocketException catch (e) {
        debugPrint('⚠️ [Services API] $baseUrl unreachable: ${e.message}. Trying next...');
        continue;
      } on HttpException catch (e) {
        debugPrint('⚠️ [Services API] $baseUrl HTTP error: ${e.message}. Trying next...');
        continue;
      } on TimeoutException {
        debugPrint('⚠️ [Services API] $baseUrl timed out. Trying next...');
        continue;
      } on HandshakeException catch (e) {
        debugPrint('⚠️ [Services API] $baseUrl SSL error: ${e.message}. Trying next...');
        continue;
      } catch (e) {
        if (e is ServicesApiException) rethrow;
        debugPrint('⚠️ [Services API] $baseUrl exception: $e');
        continue;
      } finally {
        client?.close(force: true);
      }
    }

    debugPrint('❌ [Services API] All backend endpoints failed.');
    throw ServicesApiException(
      'Unable to load services. Please check your internet connection and try again.',
    );
  }

  @override
  Future<List<WaterServiceModel>> getServices({String? category}) async {
    final endpoint = category != null && category.isNotEmpty
        ? '${ApiEndpoints.services}?category=${Uri.encodeComponent(category)}'
        : ApiEndpoints.services;

    final json = await _httpGet(endpoint);

    final dataList = json['data'] as List<dynamic>? ?? [];
    return dataList
        .map((item) => WaterServiceModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<WaterServiceModel> getServiceById(String id) async {
    final json = await _httpGet(ApiEndpoints.serviceById(id));

    final data = json['data'] as Map<String, dynamic>;
    return WaterServiceModel.fromJson(data);
  }
}
