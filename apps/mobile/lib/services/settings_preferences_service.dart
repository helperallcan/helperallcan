import 'package:shared_preferences/shared_preferences.dart';

class SettingsPreferences {
  const SettingsPreferences({
    this.taskUpdates = true,
    this.chatMessages = true,
    this.urgentTasks = true,
    this.platformNews = false,
    this.hidePhone = true,
    this.showDistrict = true,
  });

  final bool taskUpdates;
  final bool chatMessages;
  final bool urgentTasks;
  final bool platformNews;
  final bool hidePhone;
  final bool showDistrict;

  SettingsPreferences copyWith({
    bool? taskUpdates,
    bool? chatMessages,
    bool? urgentTasks,
    bool? platformNews,
    bool? hidePhone,
    bool? showDistrict,
  }) {
    return SettingsPreferences(
      taskUpdates: taskUpdates ?? this.taskUpdates,
      chatMessages: chatMessages ?? this.chatMessages,
      urgentTasks: urgentTasks ?? this.urgentTasks,
      platformNews: platformNews ?? this.platformNews,
      hidePhone: hidePhone ?? this.hidePhone,
      showDistrict: showDistrict ?? this.showDistrict,
    );
  }
}

class SettingsPreferencesService {
  static const _taskUpdatesKey = 'settings.task_updates';
  static const _chatMessagesKey = 'settings.chat_messages';
  static const _urgentTasksKey = 'settings.urgent_tasks';
  static const _platformNewsKey = 'settings.platform_news';
  static const _hidePhoneKey = 'settings.hide_phone';
  static const _showDistrictKey = 'settings.show_district';

  Future<SettingsPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsPreferences(
      taskUpdates: prefs.getBool(_taskUpdatesKey) ?? true,
      chatMessages: prefs.getBool(_chatMessagesKey) ?? true,
      urgentTasks: prefs.getBool(_urgentTasksKey) ?? true,
      platformNews: prefs.getBool(_platformNewsKey) ?? false,
      hidePhone: prefs.getBool(_hidePhoneKey) ?? true,
      showDistrict: prefs.getBool(_showDistrictKey) ?? true,
    );
  }

  Future<void> save(SettingsPreferences settings) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_taskUpdatesKey, settings.taskUpdates),
      prefs.setBool(_chatMessagesKey, settings.chatMessages),
      prefs.setBool(_urgentTasksKey, settings.urgentTasks),
      prefs.setBool(_platformNewsKey, settings.platformNews),
      prefs.setBool(_hidePhoneKey, settings.hidePhone),
      prefs.setBool(_showDistrictKey, settings.showDistrict),
    ]);
  }
}
