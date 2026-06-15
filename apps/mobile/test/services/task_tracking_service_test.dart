import 'package:flutter_test/flutter_test.dart';
import 'package:helper/models/task_location.dart';
import 'package:helper/services/task_tracking_service.dart';

void main() {
  group('TaskTrackingService coordinate validation', () {
    test('accepts valid coordinate boundaries', () {
      expect(TaskTrackingService.isValidLatitude(-90), isTrue);
      expect(TaskTrackingService.isValidLatitude(90), isTrue);
      expect(TaskTrackingService.isValidLongitude(-180), isTrue);
      expect(TaskTrackingService.isValidLongitude(180), isTrue);
    });

    test('rejects coordinates outside map boundaries', () {
      expect(TaskTrackingService.isValidLatitude(-90.1), isFalse);
      expect(TaskTrackingService.isValidLatitude(90.1), isFalse);
      expect(TaskTrackingService.isValidLongitude(-180.1), isFalse);
      expect(TaskTrackingService.isValidLongitude(180.1), isFalse);
    });
  });

  test('normalizeRows keeps the newest location for each user', () {
    final locations = TaskTrackingService.normalizeRows([
      _row(
        id: 'old-owner',
        userId: 'owner-id',
        latitude: 3.1,
        longitude: 101.1,
        updatedAt: '2026-06-15T08:00:00.000Z',
      ),
      _row(
        id: 'helper',
        userId: 'helper-id',
        latitude: 3.2,
        longitude: 101.2,
        updatedAt: '2026-06-15T08:05:00.000Z',
      ),
      _row(
        id: 'new-owner',
        userId: 'owner-id',
        latitude: 3.3,
        longitude: 101.3,
        updatedAt: '2026-06-15T08:10:00.000Z',
      ),
    ]);

    expect(locations, hasLength(2));
    expect(locations.first.id, 'new-owner');
    expect(locations.last.id, 'helper');
    expect(
      TaskTrackingService.locationForUser(locations, 'owner-id')?.latitude,
      3.3,
    );
  });

  test('navigationUri builds a Google Maps destination link', () {
    final uri = TaskTrackingService.navigationUri(
      TaskLocation.fromMap(
        _row(
          id: 'location-id',
          userId: 'helper-id',
          latitude: 3.139,
          longitude: 101.6869,
          updatedAt: '2026-06-15T08:00:00.000Z',
        ),
      ),
    );

    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['destination'], '3.139,101.6869');
  });

  test('normalizeOptionalText trims blank labels', () {
    expect(TaskTrackingService.normalizeOptionalText(null), isNull);
    expect(TaskTrackingService.normalizeOptionalText('   '), isNull);
    expect(TaskTrackingService.normalizeOptionalText('  Lobby  '), 'Lobby');
  });
}

Map<String, dynamic> _row({
  required String id,
  required String userId,
  required double latitude,
  required double longitude,
  required String updatedAt,
}) {
  return {
    'id': id,
    'task_id': 'task-id',
    'user_id': userId,
    'latitude': latitude,
    'longitude': longitude,
    'accuracy_meters': null,
    'heading_degrees': null,
    'speed_mps': null,
    'sharing_status': 'active',
    'source': 'manual',
    'label': null,
    'updated_at': updatedAt,
    'created_at': '2026-06-15T07:50:00.000Z',
  };
}
