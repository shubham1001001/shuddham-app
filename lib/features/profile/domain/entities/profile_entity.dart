class ProfileEntity {
  final String fullName;
  final String phone;
  final String? email;
  final String address;
  final double purifierFilterLife;
  final int daysUntilService;

  const ProfileEntity({
    required this.fullName,
    required this.phone,
    this.email,
    required this.address,
    required this.purifierFilterLife,
    required this.daysUntilService,
  });
}
