import '../../../../core/usecase/usecase.dart';
import '../../../../features/auth/domain/entities/user_entity.dart';
import '../repositories/profile_repository.dart';

class UpdateProfileParams {
  final String fullName;
  final String phone;
  final String? email;
  final String? token;

  const UpdateProfileParams({
    required this.fullName,
    required this.phone,
    this.email,
    this.token,
  });
}

class UpdateProfileUseCase implements UseCase<UserEntity, UpdateProfileParams> {
  final ProfileRepository repository;

  const UpdateProfileUseCase(this.repository);

  @override
  Future<UserEntity> call(UpdateProfileParams params) async {
    return repository.updateProfile(
      fullName: params.fullName,
      phone: params.phone,
      email: params.email,
      token: params.token,
    );
  }
}
