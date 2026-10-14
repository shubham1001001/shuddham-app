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
    DateTime? parseDateTime(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      final str = val.toString().trim();
      if (str.isEmpty) return null;
      final dt = DateTime.tryParse(str);
      if (dt != null) return dt.isUtc ? dt.toLocal() : dt;
      if (str.contains('/')) {
        try {
          final parts = str.split(' ');
          final dParts = parts[0].split('/');
          if (dParts.length == 3) {
            final day = int.parse(dParts[0]);
            final month = int.parse(dParts[1]);
            final year = int.parse(dParts[2]);
            int h = 0, m = 0, s = 0;
            if (parts.length > 1) {
              final tParts = parts[1].split(':');
              if (tParts.isNotEmpty) h = int.parse(tParts[0]);
              if (tParts.length > 1) m = int.parse(tParts[1]);
              if (tParts.length > 2) s = int.parse(tParts[2].split('.')[0]);
            }
            return DateTime(year, month, day, h, m, s);
          }
        } catch (_) {}
      }
      return null;
    }

    int? parseNullableInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString());
    }

    double? parseNullableDouble(dynamic val) {
      if (val == null) return null;
      if (val is double) return val;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    final rawId = (json['id'] ?? json['dev_id'] ?? json['devId'] ?? json['deviceId'] ?? json['serialNumber'] ?? '2805a520c400').toString();
    final rawName = (json['name'] ?? json['deviceName'] ?? 'Shuddham').toString();
    final rawSerial = (json['serialNumber'] ?? json['serial_number'] ?? rawId).toString();

    return DeviceModel(
      id: rawId.isNotEmpty ? rawId : '2805a520c400',
      name: rawName.isNotEmpty ? rawName : 'Shuddham',
      model: json['model'] as String? ?? 'Shuddham Smart RO Purifier',
      type: json['type'] as String? ?? 'RO Purifier',
      serialNumber: rawSerial.isNotEmpty ? rawSerial : 'SH-2805A520C400',
      location: json['location'] as String? ?? 'Home',
      isOnline: json['isOnline'] == true || (json['status']?.toString().toLowerCase() == 'online'),
      tdsPpm: parseNullableInt(json['tdsPpm'] ?? json['tds2'] ?? json['outletTds']) ?? 0,
      filterLifePercentage: parseNullableInt(json['filterLifePercentage']) ?? 100,
      lastSync: json['lastSync'] as String? ?? 'Just now',
      totalLitersPurified: parseNullableDouble(json['totalLitersPurified']) ?? 0.0,
      temperature: parseNullableDouble(json['temperature'] ?? json['temp']),
      inletTdsPpm: parseNullableInt(json['inletTdsPpm'] ?? json['tds1'] ?? json['inletTds']),
      mode: json['mode'] as String? ?? 'NF',
      tdsRange: parseNullableInt(json['tdsRange'] ?? json['tds_range']),
      fan: json['fan'] as String?,
      lastReadingTime: parseDateTime(json['lastReadingTime'] ?? json['ts'] ?? json['last_updated']),
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
