import '../../domain/entities/water_service_entity.dart';

/// Data model that maps the backend JSON response to [WaterServiceEntity].
/// Handles field name differences (backend uses `description`, entity uses `desc`).
class WaterServiceModel extends WaterServiceEntity {
  const WaterServiceModel({
    required super.id,
    required super.title,
    required super.category,
    required super.price,
    required super.duration,
    required super.desc,
    super.featured,
    required super.rating,
    super.reviewCount,
  });

  /// Factory to parse a single service JSON object from the backend API.
  /// Backend response shape:
  /// ```json
  /// { "id": "srv-1", "title": "...", "category": "...", "price": 999,
  ///   "duration": "2 Hours", "description": "...", "featured": true,
  ///   "rating": 4.9, "reviewCount": 320 }
  /// ```
  factory WaterServiceModel.fromJson(Map<String, dynamic> json) {
    return WaterServiceModel(
      id: (json['id'] ?? 'srv-0') as String,
      title: (json['title'] ?? '') as String,
      category: (json['category'] ?? '') as String,
      price: (json['price'] is int)
          ? json['price'] as int
          : (json['price'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] ?? '1 Hour') as String,
      desc: (json['description'] ?? json['desc'] ?? '') as String,
      featured: (json['featured'] as bool?) ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: (json['reviewCount'] as int?) ?? 0,
    );
  }

  /// Convert model back to JSON (useful for caching or sending to API).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'price': price,
      'duration': duration,
      'description': desc,
      'featured': featured,
      'rating': rating,
      'reviewCount': reviewCount,
    };
  }
}
