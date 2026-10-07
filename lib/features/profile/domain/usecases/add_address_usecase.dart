import '../../../../core/usecase/usecase.dart';
import '../entities/address_entity.dart';
import '../repositories/address_repository.dart';

class AddAddressParams {
  final String title;
  final String address;
  final String city;
  final String pincode;
  final bool isDefault;
  final String? token;
  final String? userId;

  const AddAddressParams({
    required this.title,
    required this.address,
    this.city = '',
    this.pincode = '',
    this.isDefault = false,
    this.token,
    this.userId,
  });
}

class AddAddressUseCase implements UseCase<AddressEntity, AddAddressParams> {
  final AddressRepository repository;

  const AddAddressUseCase(this.repository);

  @override
  Future<AddressEntity> call(AddAddressParams params) {
    return repository.addAddress(
      title: params.title,
      address: params.address,
      city: params.city,
      pincode: params.pincode,
      isDefault: params.isDefault,
      token: params.token,
      userId: params.userId,
    );
  }
}
