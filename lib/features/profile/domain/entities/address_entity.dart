class AddressEntity {
  final String id;
  final String userId;
  final String title;
  final String address;
  final String city;
  final String pincode;
  final bool isDefault;

  const AddressEntity({
    required this.id,
    this.userId = '',
    required this.title,
    required this.address,
    this.city = '',
    this.pincode = '',
    this.isDefault = false,
  });

  AddressEntity copyWith({
    String? id,
    String? userId,
    String? title,
    String? address,
    String? city,
    String? pincode,
    bool? isDefault,
  }) {
    return AddressEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      address: address ?? this.address,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
