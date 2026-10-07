import '../../../../features/auth/domain/entities/user_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;

  ProfileRepositoryImpl({ProfileRemoteDataSource? remoteDataSource})
      : remoteDataSource = remoteDataSource ?? ProfileRemoteDataSourceImpl();

  @override
  Future<UserEntity> updateProfile({
    required String fullName,
    required String phone,
    String? email,
    String? token,
  }) async {
    return remoteDataSource.updateProfile(
      fullName: fullName,
      phone: phone,
      email: email,
      token: token,
    );
  }
}
