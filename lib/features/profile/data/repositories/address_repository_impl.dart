import '../../domain/entities/address_entity.dart';
import '../../domain/repositories/address_repository.dart';
import '../datasources/address_remote_data_source.dart';

class AddressRepositoryImpl implements AddressRepository {
  final AddressRemoteDataSource remoteDataSource;

  AddressRepositoryImpl({AddressRemoteDataSource? remoteDataSource})
      : remoteDataSource = remoteDataSource ?? AddressRemoteDataSourceImpl();

  @override
  Future<List<AddressEntity>> getAddresses({String? token, String? userId}) {
    return remoteDataSource.getAddresses(token: token, userId: userId);
  }

  @override
  Future<AddressEntity> addAddress({
    required String title,
    required String address,
    String city = '',
    String pincode = '',
    bool isDefault = false,
    String? token,
    String? userId,
  }) {
    return remoteDataSource.addAddress(
      title: title,
      address: address,
      city: city,
      pincode: pincode,
      isDefault: isDefault,
      token: token,
      userId: userId,
    );
  }

  @override
  Future<AddressEntity> updateAddress({
    required String id,
    String? title,
    String? address,
    String? city,
    String? pincode,
    bool? isDefault,
    String? token,
    String? userId,
  }) {
    return remoteDataSource.updateAddress(
      id: id,
      title: title,
      address: address,
      city: city,
      pincode: pincode,
      isDefault: isDefault,
      token: token,
      userId: userId,
    );
  }

  @override
  Future<bool> deleteAddress({
    required String id,
    String? token,
    String? userId,
  }) {
    return remoteDataSource.deleteAddress(
      id: id,
      token: token,
      userId: userId,
    );
  }
}
