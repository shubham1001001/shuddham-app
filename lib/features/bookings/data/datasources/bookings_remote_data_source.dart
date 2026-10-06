import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../models/booking_model.dart';

/// Exception class for Bookings API errors.
class BookingsApiException implements Exception {
  final String message;
  BookingsApiException(this.message);

  @override
  String toString() => message;
}

/// Abstract contract for the bookings remote data source.
abstract class BookingsRemoteDataSource {
  /// Fetch all bookings, optionally filtered by [status] and [customerPhone].
  Future<List<BookingModel>> getBookings({String? status, String? customerPhone});

  /// Fetch bookings for authenticated customer via JWT token.
  Future<List<BookingModel>> getCustomerBookings({String? token, String? status});

  /// Fetch a single booking by [id].
  Future<BookingModel> getBookingById(String id);

  /// Create a new booking via POST.
  Future<BookingModel> createBooking(Map<String, dynamic> body, {String? token});
}

/// Concrete implementation hitting the Shuddham backend API.
/// Uses multi-endpoint fallback strategy.
class BookingsRemoteDataSourceImpl implements BookingsRemoteDataSource {
  final List<String> _baseUrls = ApiEndpoints.allBaseUrls;

  // ─────────────────────────────────────────────────────────────────────────
  // HTTP Helpers (GET & POST with multi-URL fallback)
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _httpRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    for (final baseUrl in _baseUrls) {
      HttpClient? client;
      try {
        final uri = Uri.parse('$baseUrl$endpoint');
        debugPrint('📡 [Bookings API] $method $uri');
        if (body != null) debugPrint('   Payload: ${jsonEncode(body)}');

        client = HttpClient()..connectionTimeout = const Duration(seconds: 45);

        late HttpClientRequest request;
        if (method == 'GET') {
          request = await client.getUrl(uri).timeout(const Duration(seconds: 45));
          request.headers.set(HttpHeaders.acceptHeader, 'application/json');
          if (token != null && token.isNotEmpty) {
            request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
          }
        } else {
          request = await client.postUrl(uri).timeout(const Duration(seconds: 45));
          request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
          request.headers.set(HttpHeaders.acceptHeader, 'application/json');
          if (token != null && token.isNotEmpty) {
            request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
          }
          request.add(utf8.encode(jsonEncode(body ?? {})));
        }

        final response = await request.close().timeout(const Duration(seconds: 45));
        final responseBody = await response.transform(utf8.decoder).join();

        debugPrint('📥 [Bookings API] Status ${response.statusCode} from $uri');

        if (responseBody.isNotEmpty) {
          final json = jsonDecode(responseBody) as Map<String, dynamic>;
          if (response.statusCode >= 200 && response.statusCode < 300) {
            debugPrint('✅ [Bookings API] Success via $baseUrl');
            client.close(force: true);
            return json;
          } else {
            final msg = json['message'] as String? ?? 'Error: ${response.statusCode}';
            debugPrint('❌ [Bookings API] Error ${response.statusCode}: $msg');
            client.close(force: true);
            throw BookingsApiException(msg);
          }
        }
      } on BookingsApiException {
        client?.close(force: true);
        rethrow;
      } on SocketException catch (e) {
        debugPrint('⚠️ [Bookings API] $baseUrl unreachable: ${e.message}. Trying next...');
        continue;
      } on HttpException catch (e) {
        debugPrint('⚠️ [Bookings API] $baseUrl HTTP error: ${e.message}. Trying next...');
        continue;
      } on TimeoutException {
        debugPrint('⚠️ [Bookings API] $baseUrl timed out. Trying next...');
        continue;
      } on HandshakeException catch (e) {
        debugPrint('⚠️ [Bookings API] $baseUrl SSL error: ${e.message}. Trying next...');
        continue;
      } catch (e) {
        if (e is BookingsApiException) rethrow;
        debugPrint('⚠️ [Bookings API] $baseUrl exception: $e');
        continue;
      } finally {
        client?.close(force: true);
      }
    }

    debugPrint('❌ [Bookings API] All backend endpoints failed.');
    throw BookingsApiException(
      'Unable to reach booking service. Please check your internet connection.',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data Source Methods
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<List<BookingModel>> getBookings({String? status, String? customerPhone}) async {
    final params = <String>[];
    if (status != null && status.isNotEmpty) {
      params.add('status=${Uri.encodeComponent(status)}');
    }
    if (customerPhone != null && customerPhone.isNotEmpty) {
      params.add('customerPhone=${Uri.encodeComponent(customerPhone)}');
    }

    final queryStr = params.isNotEmpty ? '?${params.join('&')}' : '';
    final endpoint = '${ApiEndpoints.bookings}$queryStr';

    final json = await _httpRequest('GET', endpoint);

    final dataList = json['data'] as List<dynamic>? ?? [];
    return dataList
        .map((item) => BookingModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<BookingModel>> getCustomerBookings({String? token, String? status}) async {
    final params = <String>[];
    if (status != null && status.isNotEmpty) {
      params.add('status=${Uri.encodeComponent(status)}');
    }

    final queryStr = params.isNotEmpty ? '?${params.join('&')}' : '';
    final endpoint = '${ApiEndpoints.customerBookings}$queryStr';

    final json = await _httpRequest('GET', endpoint, token: token);

    final dataList = json['data'] as List<dynamic>? ?? [];
    return dataList
        .map((item) => BookingModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<BookingModel> getBookingById(String id) async {
    final json = await _httpRequest('GET', ApiEndpoints.bookingById(id));
    final data = json['data'] as Map<String, dynamic>;
    return BookingModel.fromJson(data);
  }

  @override
  Future<BookingModel> createBooking(Map<String, dynamic> body, {String? token}) async {
    final json = await _httpRequest('POST', ApiEndpoints.createBooking, body: body, token: token);
    final data = json['data'] as Map<String, dynamic>;
    return BookingModel.fromJson(data);
  }
}
