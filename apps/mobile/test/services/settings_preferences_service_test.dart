import 'package:flutter_test/flutter_test.dart';
import 'package:helper/services/settings_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads default settings for a new device', () async {
    final settings = await SettingsPreferencesService().load();

    expect(settings.taskUpdates, isTrue);
    expect(settings.chatMessages, isTrue);
    expect(settings.urgentTasks, isTrue);
    expect(settings.platformNews, isFalse);
    expect(settings.hidePhone, isTrue);
    expect(settings.showDistrict, isTrue);
  });

  test('persists local notification and privacy settings', () async {
    final service = SettingsPreferencesService();
    await service.save(
      const SettingsPreferences(
        taskUpdates: false,
        chatMessages: true,
        urgentTasks: false,
        platformNews: true,
        hidePhone: false,
        showDistrict: false,
      ),
    );

    final settings = await service.load();

    expect(settings.taskUpdates, isFalse);
    expect(settings.chatMessages, isTrue);
    expect(settings.urgentTasks, isFalse);
    expect(settings.platformNews, isTrue);
    expect(settings.hidePhone, isFalse);
    expect(settings.showDistrict, isFalse);
  });
}
