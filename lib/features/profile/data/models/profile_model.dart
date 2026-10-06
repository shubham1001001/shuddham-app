import '../../domain/entities/profile_entity.dart';

class ProfileModel extends ProfileEntity {
  const ProfileModel({
    required super.fullName,
    required super.phone,
    super.email,
    required super.address,
    required super.purifierFilterLife,
    required super.daysUntilService,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      address: json['address'] as String? ?? '',
      purifierFilterLife: (json['purifierFilterLife'] as num?)?.toDouble() ?? 0.82,
      daysUntilService: json['daysUntilService'] as int? ?? 45,
    );
  }
}
