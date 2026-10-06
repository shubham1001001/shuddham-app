import '../entities/water_service_entity.dart';

/// Abstract repository contract for the Services feature.
/// Domain layer depends on this interface, NOT on any data source.
abstract class ServicesRepository {
  /// Fetch all services from the backend.
  /// Optionally filter by [category].
  Future<List<WaterServiceEntity>> getServices({String? category});

  /// Fetch a single service by its [id].
  Future<WaterServiceEntity> getServiceById(String id);
}
