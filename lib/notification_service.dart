import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'prayer_times';
  static const _channelName = 'Namaz Vakitleri';
  static const _channelDescription =
      'Namaz vakitleri için hatırlatma bildirimleri';

  Future<void> initialize() async {
    if (kIsWeb) return;

    tz.initializeTimeZones();

    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(settings: initializationSettings);

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> showTestNotification() async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      id: 1,
      title: 'Vakitim',
      body: 'Bildirimler başarıyla çalışıyor.',
      notificationDetails: details,
    );
  }

  Future<void> schedulePrayerNotifications({
    required Map<String, String> times,
    required Map<String, String> names,
  }) async {
    if (kIsWeb) return;

    const ids = {
      'Fajr': 101,
      'Dhuhr': 102,
      'Asr': 103,
      'Maghrib': 104,
      'Isha': 105,
    };

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
    );

    const details = NotificationDetails(android: androidDetails);
    final now = tz.TZDateTime.now(tz.local);

    for (final entry in ids.entries) {
      final timeText = times[entry.key];
      if (timeText == null) continue;

      final parts = timeText.split(':');
      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      final scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      await _notifications.cancel(id: entry.value);

      if (!scheduledTime.isAfter(now)) continue;

      final prayerName = names[entry.key] ?? 'Namaz';

      await _notifications.zonedSchedule(
        id: entry.value,
        title: '$prayerName vakti',
        body: '$prayerName namazının vakti geldi.',
        scheduledDate: scheduledTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
  }
}
