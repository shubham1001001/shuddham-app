import '../../domain/entities/booking_entity.dart';
import '../../domain/repositories/bookings_repository.dart';
import '../datasources/bookings_remote_data_source.dart';
import '../models/booking_model.dart';

/// Concrete implementation of [BookingsRepository].
/// Delegates to the remote data source.
class BookingsRepositoryImpl implements BookingsRepository {
  final BookingsRemoteDataSource remoteDataSource;

  BookingsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<BookingEntity>> getBookings({String? status, String? customerPhone}) {
    return remoteDataSource.getBookings(status: status, customerPhone: customerPhone);
  }

  @override
  Future<List<BookingEntity>> getCustomerBookings({String? token, String? status}) {
    return remoteDataSource.getCustomerBookings(token: token, status: status);
  }

  @override
  Future<BookingEntity> getBookingById(String id) {
    return remoteDataSource.getBookingById(id);
  }

  @override
  Future<BookingEntity> createBooking({
    required String customerName,
    required String customerPhone,
    required String serviceTitle,
    required String address,
    required String date,
    required String timeSlot,
    required int amount,
    String? token,
  }) {
    final model = BookingModel(
      id: '',
      customerName: customerName,
      customerPhone: customerPhone,
      serviceTitle: serviceTitle,
      address: address,
      date: date,
      timeSlot: timeSlot,
      status: 'Pending',
      technicianName: 'Unassigned',
      amount: amount,
      paymentStatus: 'Pending',
    );
    return remoteDataSource.createBooking(model.toJson(), token: token);
  }
}
