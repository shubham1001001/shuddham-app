import '../../domain/entities/address_entity.dart';

class AddressModel extends AddressEntity {
  const AddressModel({
    required super.id,
    super.userId = '',
    required super.title,
    required super.address,
    super.city = '',
    super.pincode = '',
    super.isDefault = false,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    final rawIsDefault = json['is_default'] ?? json['isDefault'];
    final bool defaultVal = rawIsDefault == true ||
        rawIsDefault == 1 ||
        rawIsDefault == '1' ||
        rawIsDefault == 'true';

    return AddressModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Home',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      isDefault: defaultVal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'address': address,
      'city': city,
      'pincode': pincode,
      'isDefault': isDefault,
    };
  }
}
