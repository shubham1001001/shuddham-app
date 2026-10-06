import '../../../../core/usecase/usecase.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignUpParams {
  final String fullName;
  final String phone;
  final String password;
  final String? email;
  final String? city;

  const SignUpParams({
    required this.fullName,
    required this.phone,
    required this.password,
    this.email,
    this.city,
  });
}

class SignUpUseCase implements UseCase<UserEntity, SignUpParams> {
  final AuthRepository repository;
  SignUpUseCase(this.repository);

  @override
  Future<UserEntity> call(SignUpParams params) {
    return repository.signUp(
      fullName: params.fullName,
      phone: params.phone,
      password: params.password,
      email: params.email,
      city: params.city,
    );
  }
}
