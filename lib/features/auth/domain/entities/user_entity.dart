class UserEntity {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String? city;
  final String token;

  const UserEntity({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.city,
    required this.token,
  });
}
