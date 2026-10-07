import '../../../../core/usecase/usecase.dart';
import '../entities/address_entity.dart';
import '../repositories/address_repository.dart';

class UpdateAddressParams {
  final String id;
  final String? title;
  final String? address;
  final String? city;
  final String? pincode;
  final bool? isDefault;
  final String? token;
  final String? userId;

  const UpdateAddressParams({
    required this.id,
    this.title,
    this.address,
    this.city,
    this.pincode,
    this.isDefault,
    this.token,
    this.userId,
  });
}

class UpdateAddressUseCase implements UseCase<AddressEntity, UpdateAddressParams> {
  final AddressRepository repository;

  const UpdateAddressUseCase(this.repository);

  @override
  Future<AddressEntity> call(UpdateAddressParams params) {
    return repository.updateAddress(
      id: params.id,
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
