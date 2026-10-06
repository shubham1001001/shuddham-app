/// Domain entity representing a water service offered by Shuddham.
/// This is the core business object — independent of any data source.
class WaterServiceEntity {
  final String id;
  final String title;
  final String category;
  final int price;
  final String duration;
  final String desc;
  final bool featured;
  final double rating;
  final int reviewCount;

  const WaterServiceEntity({
    required this.id,
    required this.title,
    required this.category,
    required this.price,
    required this.duration,
    required this.desc,
    this.featured = false,
    required this.rating,
    this.reviewCount = 0,
  });
}
