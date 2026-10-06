import '../../domain/entities/booking_entity.dart';

/// Data model that maps backend JSON to [BookingEntity].
/// Handles the exact field names from the bookings API.
class BookingModel extends BookingEntity {
  const BookingModel({
    required super.id,
    required super.customerName,
    required super.customerPhone,
    required super.serviceTitle,
    required super.address,
    required super.date,
    required super.timeSlot,
    required super.status,
    super.technicianId,
    required super.technicianName,
    required super.amount,
    required super.paymentStatus,
    super.tdsBefore,
    super.tdsAfter,
  });

  /// Parse from backend JSON response.
  /// Backend shape:
  /// ```json
  /// { "id": "BK-1234", "customerName": "...", "customerPhone": "...",
  ///   "serviceTitle": "...", "address": "...", "date": "2026-09-24",
  ///   "timeSlot": "10:00 AM - 12:00 PM", "status": "Pending",
  ///   "technicianId": null, "technicianName": "Unassigned",
  ///   "amount": 499, "paymentStatus": "Pending",
  ///   "tdsBefore": null, "tdsAfter": null }
  /// ```
  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: (json['id'] ?? '') as String,
      customerName: (json['customerName'] ?? '') as String,
      customerPhone: (json['customerPhone'] ?? '') as String,
      serviceTitle: (json['serviceName'] ?? json['serviceTitle'] ?? json['service'] ?? '') as String,
      address: (json['address'] ?? '') as String,
      date: (json['bookingDate'] ?? json['date'] ?? '') as String,
      timeSlot: (json['timeSlot'] ?? json['time'] ?? '10:00 AM - 12:00 PM') as String,
      status: (json['bookingStatus'] ?? json['status'] ?? 'Pending') as String,
      technicianId: json['technicianId'] as String?,
      technicianName: (json['technicianName'] ?? json['technician'] ?? 'Unassigned') as String,
      amount: (json['price'] is int)
          ? json['price'] as int
          : (json['amount'] is int)
              ? json['amount'] as int
              : (json['price'] ?? json['amount'] as num?)?.toInt() ?? 0,
      paymentStatus: (json['paymentStatus'] ?? 'Pending') as String,
      tdsBefore: (json['tdsBefore'] as num?)?.toInt(),
      tdsAfter: (json['tdsAfter'] as num?)?.toInt(),
    );
  }

  /// Convert to JSON for creating a new booking (POST /bookings).
  Map<String, dynamic> toJson() {
    return {
      'customerName': customerName,
      'customerPhone': customerPhone,
      'serviceTitle': serviceTitle,
      'address': address,
      'date': date,
      'timeSlot': timeSlot,
      'amount': amount,
    };
  }
}
