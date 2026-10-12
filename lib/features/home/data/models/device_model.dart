import '../../domain/entities/device_entity.dart';

class DeviceModel extends DeviceEntity {
  const DeviceModel({
    required super.id,
    required super.name,
    required super.model,
    required super.type,
    required super.serialNumber,
    required super.location,
    super.isOnline = true,
    super.tdsPpm = 0,
    super.filterLifePercentage = 100,
    super.lastSync = 'Just now',
    super.totalLitersPurified = 0.0,
    super.temperature,
    super.inletTdsPpm,
    super.mode,
    super.tdsRange,
    super.fan,
    super.lastReadingTime,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Shuddham Purifier',
      model: json['model'] as String? ?? 'Shuddham Smart RO',
      type: json['type'] as String? ?? 'RO Purifier',
      serialNumber: json['serialNumber'] as String? ?? '',
      location: json['location'] as String? ?? '',
      isOnline: json['isOnline'] as bool? ?? false,
      tdsPpm: json['tdsPpm'] as int? ?? 0,
      filterLifePercentage: json['filterLifePercentage'] as int? ?? 100,
      lastSync: json['lastSync'] as String? ?? 'Just now',
      totalLitersPurified: (json['totalLitersPurified'] as num?)?.toDouble() ?? 0.0,
      temperature: (json['temperature'] as num?)?.toDouble(),
      inletTdsPpm: json['inletTdsPpm'] as int?,
      mode: json['mode'] as String?,
      tdsRange: json['tdsRange'] as int?,
      fan: json['fan'] as String?,
      lastReadingTime: json['lastReadingTime'] != null
          ? DateTime.tryParse(json['lastReadingTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'model': model,
      'type': type,
      'serialNumber': serialNumber,
      'location': location,
      'isOnline': isOnline,
      'tdsPpm': tdsPpm,
      'filterLifePercentage': filterLifePercentage,
      'lastSync': lastSync,
      'totalLitersPurified': totalLitersPurified,
      'temperature': temperature,
      'inletTdsPpm': inletTdsPpm,
      'mode': mode,
      'tdsRange': tdsRange,
      'fan': fan,
      'lastReadingTime': lastReadingTime?.toIso8601String(),
    };
  }

  DeviceModel copyWith({
    String? id,
    String? name,
    String? model,
    String? type,
    String? serialNumber,
    String? location,
    bool? isOnline,
    int? tdsPpm,
    int? filterLifePercentage,
    String? lastSync,
    double? totalLitersPurified,
    double? temperature,
    int? inletTdsPpm,
    String? mode,
    int? tdsRange,
    String? fan,
    DateTime? lastReadingTime,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      model: model ?? this.model,
      type: type ?? this.type,
      serialNumber: serialNumber ?? this.serialNumber,
      location: location ?? this.location,
      isOnline: isOnline ?? this.isOnline,
      tdsPpm: tdsPpm ?? this.tdsPpm,
      filterLifePercentage: filterLifePercentage ?? this.filterLifePercentage,
      lastSync: lastSync ?? this.lastSync,
      totalLitersPurified: totalLitersPurified ?? this.totalLitersPurified,
      temperature: temperature ?? this.temperature,
      inletTdsPpm: inletTdsPpm ?? this.inletTdsPpm,
      mode: mode ?? this.mode,
      tdsRange: tdsRange ?? this.tdsRange,
      fan: fan ?? this.fan,
      lastReadingTime: lastReadingTime ?? this.lastReadingTime,
    );
  }
}
