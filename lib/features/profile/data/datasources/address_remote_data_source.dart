import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../models/address_model.dart';

abstract class AddressRemoteDataSource {
  Future<List<AddressModel>> getAddresses({String? token, String? userId});

  Future<AddressModel> addAddress({
    required String title,
    required String address,
    String city = '',
    String pincode = '',
    bool isDefault = false,
    String? token,
    String? userId,
  });

  Future<AddressModel> updateAddress({
    required String id,
    String? title,
    String? address,
    String? city,
    String? pincode,
    bool? isDefault,
    String? token,
    String? userId,
  });

  Future<bool> deleteAddress({
    required String id,
    String? token,
    String? userId,
  });
}

class AddressRemoteDataSourceImpl implements AddressRemoteDataSource {
  final ApiClient apiClient;

  AddressRemoteDataSourceImpl({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  Map<String, String>? _buildHeaders(String? userId) {
    if (userId != null && userId.isNotEmpty) {
      return {'x-user-id': userId};
    }
    return null;
  }

  @override
  Future<List<AddressModel>> getAddresses({String? token, String? userId}) async {
    final response = await apiClient.get(
      ApiEndpoints.customerAddresses,
      token: token,
      headers: _buildHeaders(userId),
    );

    if (response is Map<String, dynamic> && response['data'] is List) {
      final list = response['data'] as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map((json) => AddressModel.fromJson(json))
          .toList();
    }
    return [];
  }

  @override
  Future<AddressModel> addAddress({
    required String title,
    required String address,
    String city = '',
    String pincode = '',
    bool isDefault = false,
    String? token,
    String? userId,
  }) async {
    final payload = {
      'title': title,
      'address': address,
      'city': city,
      'pincode': pincode,
      'isDefault': isDefault,
    };

    final response = await apiClient.post(
      ApiEndpoints.customerAddresses,
      body: payload,
      token: token,
      headers: _buildHeaders(userId),
    );

    if (response is Map<String, dynamic> && response['data'] is Map<String, dynamic>) {
      return AddressModel.fromJson(response['data'] as Map<String, dynamic>);
    }

    return AddressModel(
      id: 'addr-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      address: address,
      city: city,
      pincode: pincode,
      isDefault: isDefault,
    );
  }

  @override
  Future<AddressModel> updateAddress({
    required String id,
    String? title,
    String? address,
    String? city,
    String? pincode,
    bool? isDefault,
    String? token,
    String? userId,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (address != null) payload['address'] = address;
    if (city != null) payload['city'] = city;
    if (pincode != null) payload['pincode'] = pincode;
    if (isDefault != null) payload['isDefault'] = isDefault;

    final response = await apiClient.put(
      '${ApiEndpoints.customerAddresses}/$id',
      body: payload,
      token: token,
      headers: _buildHeaders(userId),
    );

    if (response is Map<String, dynamic> && response['data'] is Map<String, dynamic>) {
      return AddressModel.fromJson(response['data'] as Map<String, dynamic>);
    }

    return AddressModel(
      id: id,
      title: title ?? 'Home',
      address: address ?? '',
      city: city ?? '',
      pincode: pincode ?? '',
      isDefault: isDefault ?? false,
    );
  }

  @override
  Future<bool> deleteAddress({
    required String id,
    String? token,
    String? userId,
  }) async {
    final response = await apiClient.delete(
      '${ApiEndpoints.customerAddresses}/$id',
      token: token,
      headers: _buildHeaders(userId),
    );

    if (response is Map<String, dynamic>) {
      return response['success'] == true;
    }
    return true;
  }
}
