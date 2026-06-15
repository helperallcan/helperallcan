import 'package:geolocator/geolocator.dart';

class DeviceLocationService {
  Future<DeviceLocationReading> getCurrentReading() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const DeviceLocationException(
        DeviceLocationFailure.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const DeviceLocationException(
          DeviceLocationFailure.permissionDenied);
    }

    if (permission == LocationPermission.deniedForever) {
      throw const DeviceLocationException(
        DeviceLocationFailure.permissionDeniedForever,
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 18),
      ),
    );

    return DeviceLocationReading.fromPosition(position);
  }
}

class DeviceLocationReading {
  const DeviceLocationReading({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.headingDegrees,
    this.speedMps,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? headingDegrees;
  final double? speedMps;

  factory DeviceLocationReading.fromPosition(Position position) {
    return DeviceLocationReading(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: _positiveOrNull(position.accuracy),
      headingDegrees: _headingOrNull(position.heading),
      speedMps: _positiveOrNull(position.speed),
    );
  }

  static double? _positiveOrNull(double value) {
    if (value.isNaN || value.isInfinite || value < 0) return null;
    return value;
  }

  static double? _headingOrNull(double value) {
    if (value.isNaN || value.isInfinite || value < 0 || value > 360) {
      return null;
    }
    return value;
  }
}

enum DeviceLocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.failure);

  final DeviceLocationFailure failure;

  String get userMessage {
    return switch (failure) {
      DeviceLocationFailure.serviceDisabled => '手机定位服务还没打开，请打开定位后再试。',
      DeviceLocationFailure.permissionDenied => '需要允许 Helper 使用定位，才能共享当前位置。',
      DeviceLocationFailure.permissionDeniedForever =>
        '定位权限已被永久拒绝，请到系统设置里允许 Helper 使用定位。',
    };
  }

  @override
  String toString() => userMessage;
}
