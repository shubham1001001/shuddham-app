import '../entities/address_entity.dart';

abstract class AddressRepository {
  Future<List<AddressEntity>> getAddresses({String? token, String? userId});

  Future<AddressEntity> addAddress({
    required String title,
    required String address,
    String city = '',
    String pincode = '',
    bool isDefault = false,
    String? token,
    String? userId,
  });

  Future<AddressEntity> updateAddress({
    required String id,
    String? title,
    String? address,
    String? city,
    String? pincode,
    bool? isDefault,
    String? token,
    String? userId,
  });

  Future<bool> deleteAddress({
    required String id,
    String? token,
    String? userId,
  });
}
