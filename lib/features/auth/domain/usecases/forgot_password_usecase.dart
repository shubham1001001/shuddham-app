import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

class ForgotPasswordParams {
  final String phone;
  final String email;
  final String newPassword;
  const ForgotPasswordParams({
    required this.phone,
    required this.email,
    required this.newPassword,
  });
}

class ForgotPasswordUseCase implements UseCase<String, ForgotPasswordParams> {
  final AuthRepository repository;
  ForgotPasswordUseCase(this.repository);

  @override
  Future<String> call(ForgotPasswordParams params) {
    return repository.forgotPassword(
      phone: params.phone,
      email: params.email,
      newPassword: params.newPassword,
    );
  }
}
