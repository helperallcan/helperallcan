import '../core/supabase_client.dart';
import '../models/task_location.dart';

class TaskTrackingService {
  static const fallbackMapCenter = TaskMapPoint(
    latitude: 3.139,
    longitude: 101.6869,
  );

  Stream<List<TaskLocation>> watchTaskLocations(String taskId) {
    return supabase
        .from('task_locations')
        .stream(primaryKey: ['id'])
        .eq('task_id', taskId)
        .order('updated_at', ascending: false)
        .map(normalizeRows);
  }

  Future<void> shareLocation({
    required String taskId,
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    double? headingDegrees,
    double? speedMps,
    TaskTrackingStatus status = TaskTrackingStatus.active,
    String source = 'manual',
    String? label,
  }) async {
    if (!isValidLatitude(latitude)) {
      throw ArgumentError.value(latitude, 'latitude', 'Invalid latitude.');
    }
    if (!isValidLongitude(longitude)) {
      throw ArgumentError.value(longitude, 'longitude', 'Invalid longitude.');
    }

    final user = supabase.auth.currentUser!;
    await supabase.from('task_locations').upsert(
      {
        'task_id': taskId,
        'user_id': user.id,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_meters': accuracyMeters,
        'heading_degrees': headingDegrees,
        'speed_mps': speedMps,
        'sharing_status': status.value,
        'source': source,
        'label': normalizeOptionalText(label),
      },
      onConflict: 'task_id,user_id',
    );
  }

  Future<void> stopSharing(String taskId) async {
    final user = supabase.auth.currentUser!;
    await supabase
        .from('task_locations')
        .delete()
        .eq('task_id', taskId)
        .eq('user_id', user.id);
  }

  static List<TaskLocation> normalizeRows(Iterable<Map<String, dynamic>> rows) {
    final locationsByUser = <String, TaskLocation>{};
    for (final row in rows) {
      final location = TaskLocation.fromMap(Map<String, dynamic>.from(row));
      final current = locationsByUser[location.userId];
      if (current == null || location.updatedAt.isAfter(current.updatedAt)) {
        locationsByUser[location.userId] = location;
      }
    }

    return locationsByUser.values.toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  }

  static TaskLocation? locationForUser(
    List<TaskLocation> locations,
    String? userId,
  ) {
    if (userId == null) return null;
    for (final location in locations) {
      if (location.userId == userId) return location;
    }
    return null;
  }

  static bool isValidLatitude(double value) => value >= -90 && value <= 90;

  static bool isValidLongitude(double value) => value >= -180 && value <= 180;

  static Uri navigationUri(TaskLocation location) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${location.latitude},${location.longitude}',
    });
  }

  static String? normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static TaskMapPoint mapCenter(List<TaskLocation> locations) {
    if (locations.isEmpty) return fallbackMapCenter;

    final activeLocations =
        locations.where((location) => location.isActive).toList();
    final usefulLocations =
        activeLocations.isEmpty ? locations : activeLocations;
    final latitude = usefulLocations
            .map((location) => location.latitude)
            .reduce((left, right) => left + right) /
        usefulLocations.length;
    final longitude = usefulLocations
            .map((location) => location.longitude)
            .reduce((left, right) => left + right) /
        usefulLocations.length;
    return TaskMapPoint(latitude: latitude, longitude: longitude);
  }
}

class TaskMapPoint {
  const TaskMapPoint({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}
