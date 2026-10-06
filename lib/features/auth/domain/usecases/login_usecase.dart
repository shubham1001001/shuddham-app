import '../../../../core/usecase/usecase.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class LoginParams {
  final String phoneOrEmail;
  final String password;
  const LoginParams({required this.phoneOrEmail, required this.password});
}

class LoginUseCase implements UseCase<UserEntity, LoginParams> {
  final AuthRepository repository;
  LoginUseCase(this.repository);

  @override
  Future<UserEntity> call(LoginParams params) {
    return repository.signIn(
      phoneOrEmail: params.phoneOrEmail,
      password: params.password,
    );
  }
}
