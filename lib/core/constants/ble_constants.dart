/// Bluetooth & Hardware Provisioning Constants for Shuddham Smart Purifiers.
class BleConstants {
  /// Advertised name prefix from firmware (e.g. "SHUDDHAM" or "SHD-")
  static const bleNamePrefix = 'SHUDDHAM';
  static const bleAltPrefix = 'SHD-';

  /// Advertised Service UUID: 0xABF0
  static const bleAdvertisedServiceUuid = '0000abf0-0000-1000-8000-00805f9b34fb';

  /// Real GATT Service UUID: 0x00FF
  static const bleGattServiceUuid = '000000ff-0000-1000-8000-00805f9b34fb';

  /// GATT Characteristic UUID: 0xFF01 (Write & Notify)
  static const bleCharUuid = '0000ff01-0000-1000-8000-00805f9b34fb';

  /// Command write timeout
  static const Duration writeTimeout = Duration(seconds: 15);

  /// Default Wi-Fi network scan timeout over BLE
  static const Duration wifiScanTimeout = Duration(seconds: 20);

  /// Provisioning handshake timeout
  static const Duration provisionTimeout = Duration(seconds: 45);
}
