import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../constants/api_endpoints.dart';
import '../error/exceptions.dart';
import '../utils/app_logger.dart';

/// Centralized API HTTP Client handling fallback URLs,
/// logging, request timeout, and standardized exceptions.
class ApiClient {
  final List<String> _baseUrls;
  final Duration timeout;

  ApiClient({
    List<String>? baseUrls,
    this.timeout = const Duration(seconds: 45),
  }) : _baseUrls = baseUrls ?? ApiEndpoints.allBaseUrls;

  /// Helper to send GET request
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? headers,
    String? token,
  }) async {
    return _sendRequest(
      method: 'GET',
      endpoint: endpoint,
      headers: headers,
      token: token,
    );
  }

  /// Helper to send POST request
  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
    String? token,
  }) async {
    return _sendRequest(
      method: 'POST',
      endpoint: endpoint,
      body: body,
      headers: headers,
      token: token,
    );
  }

  /// Helper to send PUT request
  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
    String? token,
  }) async {
    return _sendRequest(
      method: 'PUT',
      endpoint: endpoint,
      body: body,
      headers: headers,
      token: token,
    );
  }

  /// Helper to send DELETE request
  Future<dynamic> delete(
    String endpoint, {
    Map<String, String>? headers,
    String? token,
  }) async {
    return _sendRequest(
      method: 'DELETE',
      endpoint: endpoint,
      headers: headers,
      token: token,
    );
  }

  Future<dynamic> _sendRequest({
    required String method,
    required String endpoint,
    dynamic body,
    Map<String, String>? headers,
    String? token,
  }) async {
    for (final baseUrl in _baseUrls) {
      HttpClient? client;
      final stopwatch = Stopwatch()..start();
      final uri = Uri.parse('$baseUrl$endpoint');

      try {
        final requestHeaders = <String, dynamic>{
          'Accept': 'application/json',
          if (body != null) 'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          ...?headers,
        };

        AppLogger.apiRequest(
          method: method,
          uri: uri,
          headers: requestHeaders,
          body: body,
        );

        client = HttpClient()..connectionTimeout = timeout;
        final HttpClientRequest request;

        switch (method.toUpperCase()) {
          case 'GET':
            request = await client.getUrl(uri).timeout(timeout);
            break;
          case 'POST':
            request = await client.postUrl(uri).timeout(timeout);
            break;
          case 'PUT':
            request = await client.putUrl(uri).timeout(timeout);
            break;
          case 'DELETE':
            request = await client.deleteUrl(uri).timeout(timeout);
            break;
          default:
            request = await client.openUrl(method, uri).timeout(timeout);
        }

        requestHeaders.forEach((key, value) {
          request.headers.set(key, value.toString());
        });

        if (body != null) {
          final encoded = body is String ? body : jsonEncode(body);
          request.add(utf8.encode(encoded));
        }

        final response = await request.close().timeout(timeout);
        final responseBody = await response.transform(utf8.decoder).join();
        stopwatch.stop();

        AppLogger.apiResponse(
          method: method,
          uri: uri,
          statusCode: response.statusCode,
          responseBody: responseBody,
          duration: stopwatch.elapsed,
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          client.close(force: true);
          if (responseBody.isEmpty) return null;
          return jsonDecode(responseBody);
        } else {
          client.close(force: true);
          String message = 'Request failed with status: ${response.statusCode}';
          if (responseBody.isNotEmpty) {
            try {
              final errJson = jsonDecode(responseBody);
              if (errJson is Map && errJson['message'] != null) {
                message = errJson['message'].toString();
              }
            } catch (_) {}
          }
          throw ServerException(message);
        }
      } on ServerException {
        client?.close(force: true);
        rethrow;
      } on SocketException catch (e) {
        AppLogger.apiError(method: method, uri: uri, error: 'SocketException: ${e.message}');
        continue;
      } on HttpException catch (e) {
        AppLogger.apiError(method: method, uri: uri, error: 'HttpException: ${e.message}');
        continue;
      } on TimeoutException {
        AppLogger.apiError(method: method, uri: uri, error: 'TimeoutException: Request timed out');
        continue;
      } catch (e) {
        AppLogger.apiError(method: method, uri: uri, error: e);
        continue;
      } finally {
        client?.close(force: true);
      }
    }

    throw const NetworkException('Unable to reach server. Please check your internet connection.');
  }
}
