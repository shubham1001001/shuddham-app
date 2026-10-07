import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

class LogoutParams {
  final String? token;
  const LogoutParams({this.token});
}

class LogoutUseCase implements UseCase<void, LogoutParams> {
  final AuthRepository repository;

  LogoutUseCase(this.repository);

  @override
  Future<void> call(LogoutParams params) {
    return repository.signOut(token: params.token);
  }
}
