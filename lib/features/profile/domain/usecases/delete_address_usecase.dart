import '../../../../core/usecase/usecase.dart';
import '../repositories/address_repository.dart';

class DeleteAddressParams {
  final String id;
  final String? token;
  final String? userId;

  const DeleteAddressParams({
    required this.id,
    this.token,
    this.userId,
  });
}

class DeleteAddressUseCase implements UseCase<bool, DeleteAddressParams> {
  final AddressRepository repository;

  const DeleteAddressUseCase(this.repository);

  @override
  Future<bool> call(DeleteAddressParams params) {
    return repository.deleteAddress(
      id: params.id,
      token: params.token,
      userId: params.userId,
    );
  }
}
