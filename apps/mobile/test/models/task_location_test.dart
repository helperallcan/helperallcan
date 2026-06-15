import 'package:flutter_test/flutter_test.dart';
import 'package:helper/models/task_location.dart';

void main() {
  test('TaskTrackingStatus maps database values safely', () {
    expect(TaskTrackingStatus.fromValue('paused'), TaskTrackingStatus.paused);
    expect(TaskTrackingStatus.fromValue('arrived'), TaskTrackingStatus.arrived);
    expect(TaskTrackingStatus.fromValue('unknown'), TaskTrackingStatus.active);
    expect(TaskTrackingStatus.fromValue(null), TaskTrackingStatus.active);
  });

  test('TaskLocation.fromMap maps coordinates and optional telemetry', () {
    final location = TaskLocation.fromMap({
      'id': 'location-id',
      'task_id': 'task-id',
      'user_id': 'user-id',
      'latitude': 3.139,
      'longitude': 101.6869,
      'accuracy_meters': 8,
      'heading_degrees': 90,
      'speed_mps': 1.5,
      'sharing_status': 'arrived',
      'source': 'device',
      'label': 'Lobby entrance',
      'updated_at': '2026-06-15T08:10:00.000Z',
      'created_at': '2026-06-15T08:00:00.000Z',
    });

    expect(location.taskId, 'task-id');
    expect(location.userId, 'user-id');
    expect(location.latitude, 3.139);
    expect(location.longitude, 101.6869);
    expect(location.accuracyMeters, 8);
    expect(location.headingDegrees, 90);
    expect(location.speedMps, 1.5);
    expect(location.status, TaskTrackingStatus.arrived);
    expect(location.source, 'device');
    expect(location.label, 'Lobby entrance');
    expect(location.coordinateLabel, '3.13900, 101.68690');
    expect(location.accuracyLabel, '约 8 米');
    expect(location.sourceLabel, '手机定位');
    expect(location.isActive, isFalse);
  });

  test('TaskLocation exposes readable source labels', () {
    TaskLocation location(String source) {
      return TaskLocation.fromMap({
        'id': 'location-id',
        'task_id': 'task-id',
        'user_id': 'user-id',
        'latitude': 3.139,
        'longitude': 101.6869,
        'sharing_status': 'active',
        'source': source,
        'updated_at': '2026-06-15T08:10:00.000Z',
        'created_at': '2026-06-15T08:00:00.000Z',
      });
    }

    expect(location('manual').sourceLabel, '手动坐标');
    expect(location('device').sourceLabel, '手机定位');
    expect(location('system').sourceLabel, '系统定位');
  });
}
