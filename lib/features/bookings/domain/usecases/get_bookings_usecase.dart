import '../../../../core/usecase/usecase.dart';
import '../entities/booking_entity.dart';
import '../repositories/bookings_repository.dart';

/// Use case to fetch all bookings from backend.
class GetBookingsUseCase implements UseCase<List<BookingEntity>, GetBookingsParams> {
  final BookingsRepository repository;
  GetBookingsUseCase(this.repository);

  @override
  Future<List<BookingEntity>> call(GetBookingsParams params) {
    return repository.getBookings(
      status: params.status,
      customerPhone: params.customerPhone,
    );
  }
}

class GetBookingsParams {
  final String? status;
  final String? customerPhone;
  const GetBookingsParams({this.status, this.customerPhone});
}
