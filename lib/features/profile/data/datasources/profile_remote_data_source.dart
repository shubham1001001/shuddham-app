import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/data/models/user_model.dart';

abstract class ProfileRemoteDataSource {
  Future<UserModel> updateProfile({
    required String fullName,
    required String phone,
    String? email,
    String? token,
  });
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final ApiClient apiClient;

  ProfileRemoteDataSourceImpl({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  @override
  Future<UserModel> updateProfile({
    required String fullName,
    required String phone,
    String? email,
    String? token,
  }) async {
    final payload = {
      'fullName': fullName,
      'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
    };

    final response = await apiClient.put(
      ApiEndpoints.updateMe,
      body: payload,
      token: token,
    );

    if (response is Map<String, dynamic>) {
      final userData = response['data']?['user'] ?? response['data'];
      if (userData is Map<String, dynamic>) {
        final dataWithToken = Map<String, dynamic>.from(userData);
        dataWithToken['token'] = dataWithToken['token'] ?? token ?? '';
        return UserModel.fromJson(dataWithToken);
      }
    }

    return UserModel(
      id: 'usr_me',
      fullName: fullName,
      phone: phone,
      email: email,
      token: token ?? '',
    );
  }
}
