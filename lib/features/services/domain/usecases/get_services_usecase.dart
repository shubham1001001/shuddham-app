import '../../../../core/usecase/usecase.dart';
import '../entities/water_service_entity.dart';
import '../repositories/services_repository.dart';

/// Use case to fetch all available water services from the backend.
/// Accepts an optional [category] filter via [GetServicesParams].
class GetServicesUseCase implements UseCase<List<WaterServiceEntity>, GetServicesParams> {
  final ServicesRepository repository;
  GetServicesUseCase(this.repository);

  @override
  Future<List<WaterServiceEntity>> call(GetServicesParams params) {
    return repository.getServices(category: params.category);
  }
}

class GetServicesParams {
  final String? category;
  const GetServicesParams({this.category});
}
