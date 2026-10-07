import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
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

/// Concrete implementation that hits the Shuddham backend API via ApiClient.
class ServicesRemoteDataSourceImpl implements ServicesRemoteDataSource {
  final ApiClient apiClient;

  ServicesRemoteDataSourceImpl({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  /// Helper: HTTP GET via ApiClient
  Future<Map<String, dynamic>> _httpGet(String endpoint) async {
    try {
      final res = await apiClient.get(endpoint);
      if (res is Map<String, dynamic>) {
        return res;
      }
      throw ServicesApiException('Unexpected response format received from server.');
    } on ServerException catch (e) {
      throw ServicesApiException(e.message);
    } on NetworkException catch (e) {
      throw ServicesApiException(e.message);
    } catch (e) {
      if (e is ServicesApiException) rethrow;
      throw ServicesApiException(e.toString());
    }
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
