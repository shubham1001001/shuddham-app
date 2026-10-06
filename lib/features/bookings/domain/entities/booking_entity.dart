/// Domain entity representing a service booking.
/// Matches the backend booking response shape.
class BookingEntity {
  final String id;
  final String customerName;
  final String customerPhone;
  final String serviceTitle;
  final String address;
  final String date;
  final String timeSlot;
  final String status;
  final String? technicianId;
  final String technicianName;
  final int amount;
  final String paymentStatus;
  final int? tdsBefore;
  final int? tdsAfter;

  const BookingEntity({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.serviceTitle,
    required this.address,
    required this.date,
    required this.timeSlot,
    required this.status,
    this.technicianId,
    required this.technicianName,
    required this.amount,
    required this.paymentStatus,
    this.tdsBefore,
    this.tdsAfter,
  });

  /// Convenience getters matching requested API contract
  String get serviceName => serviceTitle;
  String get bookingDate => date;
  int get price => amount;
  String get bookingStatus => status;

  /// Helper: generates TDS report string if both readings are available
  String? get tdsReport {
    if (tdsBefore != null && tdsAfter != null) {
      return 'Reduced from $tdsBefore to $tdsAfter PPM (Clean & Safe)';
    }
    return null;
  }
}
