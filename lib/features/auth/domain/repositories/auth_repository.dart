import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> signIn({
    required String phoneOrEmail,
    required String password,
  });

  Future<UserEntity> signInWithOtp({
    required String phone,
    required String otp,
  });

  Future<UserEntity> signUp({
    required String fullName,
    required String phone,
    required String password,
    String? email,
    String? city,
  });

  Future<String> forgotPassword({
    required String phone,
    required String email,
    required String newPassword,
  });

  Future<void> signOut({String? token});
}
