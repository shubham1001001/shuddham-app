import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<UserEntity> signIn({
    required String phoneOrEmail,
    required String password,
  }) {
    return remoteDataSource.signIn(
      phoneOrEmail: phoneOrEmail,
      password: password,
    );
  }

  @override
  Future<UserEntity> signInWithOtp({
    required String phone,
    required String otp,
  }) {
    return remoteDataSource.signInWithOtp(
      phone: phone,
      otp: otp,
    );
  }

  @override
  Future<UserEntity> signUp({
    required String fullName,
    required String phone,
    required String password,
    String? email,
    String? city,
  }) {
    return remoteDataSource.signUp(
      fullName: fullName,
      phone: phone,
      password: password,
      email: email,
      city: city,
    );
  }

  @override
  Future<String> forgotPassword({
    required String phone,
    required String email,
    required String newPassword,
  }) {
    return remoteDataSource.forgotPassword(
      phone: phone,
      email: email,
      newPassword: newPassword,
    );
  }
}
