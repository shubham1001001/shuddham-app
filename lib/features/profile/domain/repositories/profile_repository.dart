import '../../../../features/auth/domain/entities/user_entity.dart';

abstract class ProfileRepository {
  Future<UserEntity> updateProfile({
    required String fullName,
    required String phone,
    String? email,
    String? token,
  });
}
