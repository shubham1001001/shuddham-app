import '../../domain/entities/water_service_entity.dart';
import '../../domain/repositories/services_repository.dart';
import '../datasources/services_remote_data_source.dart';

/// Concrete implementation of [ServicesRepository].
/// Delegates all work to the remote data source.
class ServicesRepositoryImpl implements ServicesRepository {
  final ServicesRemoteDataSource remoteDataSource;

  ServicesRepositoryImpl({ServicesRemoteDataSource? remoteDataSource})
      : remoteDataSource = remoteDataSource ?? ServicesRemoteDataSourceImpl();

  @override
  Future<List<WaterServiceEntity>> getServices({String? category}) {
    return remoteDataSource.getServices(category: category);
  }

  @override
  Future<WaterServiceEntity> getServiceById(String id) {
    return remoteDataSource.getServiceById(id);
  }
}
