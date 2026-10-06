import '../../../../core/usecase/usecase.dart';
import '../entities/booking_entity.dart';
import '../repositories/bookings_repository.dart';

/// Use case to fetch authenticated customer's bookings via JWT token.
class GetCustomerBookingsUseCase implements UseCase<List<BookingEntity>, GetCustomerBookingsParams> {
  final BookingsRepository repository;
  GetCustomerBookingsUseCase(this.repository);

  @override
  Future<List<BookingEntity>> call(GetCustomerBookingsParams params) {
    return repository.getCustomerBookings(
      token: params.token,
      status: params.status,
    );
  }
}

class GetCustomerBookingsParams {
  final String? token;
  final String? status;
  const GetCustomerBookingsParams({this.token, this.status});
}
