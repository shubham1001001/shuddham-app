import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.fullName,
    required super.phone,
    super.email,
    super.city,
    required super.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? 'usr-${DateTime.now().millisecondsSinceEpoch}',
      fullName: json['fullName'] as String? ?? 'Customer',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      city: json['city'] as String?,
      token: json['token'] as String? ?? 'mock-jwt-token',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'city': city,
      'token': token,
    };
  }
}
