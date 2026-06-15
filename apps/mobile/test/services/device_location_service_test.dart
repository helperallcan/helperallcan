import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:helper/services/device_location_service.dart';

void main() {
  test('DeviceLocationReading.fromPosition maps GPS telemetry safely', () {
    final reading = DeviceLocationReading.fromPosition(
      Position(
        latitude: 3.139,
        longitude: 101.6869,
        timestamp: DateTime.utc(2026, 6, 15, 8),
        accuracy: 9.4,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 45,
        headingAccuracy: 0,
        speed: 1.2,
        speedAccuracy: 0,
      ),
    );

    expect(reading.latitude, 3.139);
    expect(reading.longitude, 101.6869);
    expect(reading.accuracyMeters, 9.4);
    expect(reading.headingDegrees, 45);
    expect(reading.speedMps, 1.2);
  });

  test('DeviceLocationReading.fromPosition drops invalid telemetry', () {
    final reading = DeviceLocationReading.fromPosition(
      Position(
        latitude: 3.139,
        longitude: 101.6869,
        timestamp: DateTime.utc(2026, 6, 15, 8),
        accuracy: -1,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 500,
        headingAccuracy: 0,
        speed: -2,
        speedAccuracy: 0,
      ),
    );

    expect(reading.accuracyMeters, isNull);
    expect(reading.headingDegrees, isNull);
    expect(reading.speedMps, isNull);
  });

  test('DeviceLocationException exposes user friendly messages', () {
    expect(
      const DeviceLocationException(DeviceLocationFailure.serviceDisabled)
          .userMessage,
      contains('定位服务'),
    );
    expect(
      const DeviceLocationException(DeviceLocationFailure.permissionDenied)
          .userMessage,
      contains('允许 Helper 使用定位'),
    );
    expect(
      const DeviceLocationException(
        DeviceLocationFailure.permissionDeniedForever,
      ).userMessage,
      contains('系统设置'),
    );
  });
}
