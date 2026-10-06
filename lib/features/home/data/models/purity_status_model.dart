import '../../domain/entities/purity_status_entity.dart';

class PurityStatusModel extends PurityStatusEntity {
  const PurityStatusModel({
    required super.currentTdsPpm,
    required super.status,
    required super.message,
  });

  factory PurityStatusModel.fromJson(Map<String, dynamic> json) {
    return PurityStatusModel(
      currentTdsPpm: json['currentTdsPpm'] as int? ?? 85,
      status: json['status'] as String? ?? 'Optimal Purity',
      message: json['message'] as String? ?? '100% Certified Safe Drinking Water',
    );
  }
}
