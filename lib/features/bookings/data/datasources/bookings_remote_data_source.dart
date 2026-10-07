import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
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
class BookingsRemoteDataSourceImpl implements BookingsRemoteDataSource {
  final ApiClient apiClient;

  BookingsRemoteDataSourceImpl({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> _send(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      dynamic res;
      if (method == 'POST') {
        res = await apiClient.post(endpoint, body: body, token: token);
      } else {
        res = await apiClient.get(endpoint, token: token);
      }

      if (res is Map<String, dynamic>) {
        return res;
      }
      throw BookingsApiException('Unexpected response format received from server.');
    } on ServerException catch (e) {
      throw BookingsApiException(e.message);
    } on NetworkException catch (e) {
      throw BookingsApiException(e.message);
    } catch (e) {
      if (e is BookingsApiException) rethrow;
      throw BookingsApiException(e.toString());
    }
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

    final json = await _send('GET', endpoint);

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

    final json = await _send('GET', endpoint, token: token);

    final dataList = json['data'] as List<dynamic>? ?? [];
    return dataList
        .map((item) => BookingModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<BookingModel> getBookingById(String id) async {
    final json = await _send('GET', ApiEndpoints.bookingById(id));
    final data = json['data'] as Map<String, dynamic>;
    return BookingModel.fromJson(data);
  }

  @override
  Future<BookingModel> createBooking(Map<String, dynamic> body, {String? token}) async {
    final json = await _send('POST', ApiEndpoints.createBooking, body: body, token: token);
    final data = json['data'] as Map<String, dynamic>;
    return BookingModel.fromJson(data);
  }
}
