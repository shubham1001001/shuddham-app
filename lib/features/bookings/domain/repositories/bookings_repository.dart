import '../entities/booking_entity.dart';

/// Abstract repository contract for the Bookings feature.
abstract class BookingsRepository {
  /// Fetch all bookings. Optionally filter by [status] and [customerPhone].
  Future<List<BookingEntity>> getBookings({String? status, String? customerPhone});

  /// Fetch bookings for authenticated customer via JWT token.
  Future<List<BookingEntity>> getCustomerBookings({String? token, String? status});

  /// Fetch a single booking by [id].
  Future<BookingEntity> getBookingById(String id);

  /// Create a new booking and return the created booking.
  Future<BookingEntity> createBooking({
    required String customerName,
    required String customerPhone,
    required String serviceTitle,
    required String address,
    required String date,
    required String timeSlot,
    required int amount,
    String? token,
  });
}
