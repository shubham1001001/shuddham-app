class DeviceEntity {
  final String id;
  final String name;
  final String model;
  final String type; // 'RO Purifier', 'UV Disinfector', 'TDS Meter', 'Tank Sensor'
  final String serialNumber;
  final String location;
  final bool isOnline;
  final int tdsPpm;
  final int filterLifePercentage;
  final String lastSync;
  final double totalLitersPurified;
  final double? temperature;
  final int? inletTdsPpm;
  final String? mode;
  final int? tdsRange;
  final String? fan;
  final DateTime? lastReadingTime;

  const DeviceEntity({
    required this.id,
    required this.name,
    required this.model,
    required this.type,
    required this.serialNumber,
    required this.location,
    this.isOnline = true,
    this.tdsPpm = 85,
    this.filterLifePercentage = 85,
    this.lastSync = 'Just now',
    this.totalLitersPurified = 142.5,
    this.temperature,
    this.inletTdsPpm,
    this.mode,
    this.tdsRange,
    this.fan,
    this.lastReadingTime,
  });
}
