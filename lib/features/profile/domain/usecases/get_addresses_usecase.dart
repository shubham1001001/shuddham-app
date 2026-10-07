import '../../../../core/usecase/usecase.dart';
import '../entities/address_entity.dart';
import '../repositories/address_repository.dart';

class GetAddressesParams {
  final String? token;
  final String? userId;

  const GetAddressesParams({this.token, this.userId});
}

class GetAddressesUseCase implements UseCase<List<AddressEntity>, GetAddressesParams> {
  final AddressRepository repository;

  const GetAddressesUseCase(this.repository);

  @override
  Future<List<AddressEntity>> call(GetAddressesParams params) {
    return repository.getAddresses(
      token: params.token,
      userId: params.userId,
    );
  }
}
