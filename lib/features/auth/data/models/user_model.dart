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
    final resolvedId = (json['id'] ?? json['_id'] ?? json['customerId'] ?? json['userId'] ?? '').toString();
    return UserModel(
      id: resolvedId.isNotEmpty ? resolvedId : 'usr-shuddham-customer',
      fullName: json['fullName'] as String? ?? json['name'] as String? ?? 'Customer',
      phone: (json['phone'] ?? json['phoneNumber'] ?? json['mobile'] ?? '').toString(),
      email: json['email'] as String?,
      city: json['city'] as String?,
      token: (json['token'] ?? 'mock-jwt-token').toString(),
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
