import '../../../../core/usecase/usecase.dart';
import '../entities/booking_entity.dart';
import '../repositories/bookings_repository.dart';

/// Use case to create a new service booking via backend API.
class CreateBookingUseCase implements UseCase<BookingEntity, CreateBookingParams> {
  final BookingsRepository repository;
  CreateBookingUseCase(this.repository);

  @override
  Future<BookingEntity> call(CreateBookingParams params) {
    return repository.createBooking(
      customerName: params.customerName,
      customerPhone: params.customerPhone,
      serviceTitle: params.serviceTitle,
      address: params.address,
      date: params.date,
      timeSlot: params.timeSlot,
      amount: params.amount,
      token: params.token,
    );
  }
}

class CreateBookingParams {
  final String customerName;
  final String customerPhone;
  final String serviceTitle;
  final String address;
  final String date;
  final String timeSlot;
  final int amount;
  final String? token;

  const CreateBookingParams({
    required this.customerName,
    required this.customerPhone,
    required this.serviceTitle,
    required this.address,
    required this.date,
    required this.timeSlot,
    required this.amount,
    this.token,
  });
}
