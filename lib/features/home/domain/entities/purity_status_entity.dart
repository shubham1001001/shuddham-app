class PurityStatusEntity {
  final int currentTdsPpm;
  final String status;
  final String message;

  const PurityStatusEntity({
    required this.currentTdsPpm,
    required this.status,
    required this.message,
  });
}
