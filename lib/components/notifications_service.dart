import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotiService {
  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  // INITIALIZE
  Future<void> initNotification() async {
    if (_isInitialized) return; // prevent re-initialization

    // init timezone handling
    tz.initializeTimeZones();
    final currentTimeZone = await FlutterTimezone.getLocalTimezone();

// Extract just the timezone ID from the TimezoneInfo object
    final timezoneName = currentTimeZone.toString().split(',').first.replaceAll('TimezoneInfo(', '');

// Try to get the timezone, fallback to a safe default if not found
    tz.Location location;
    try {
      location = tz.getLocation(timezoneName);
      print('✅ Using timezone: $timezoneName');
    } catch (e) {
      print('⚠️ Timezone $timezoneName not found, using America/New_York as fallback');
      location = tz.getLocation('America/New_York');
    }

    tz.setLocalLocation(location);
    // init android
    const AndroidInitializationSettings initSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // init ios
    const DarwinInitializationSettings initSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // init settings
    const InitializationSettings initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    // initialize plugin
    await notificationsPlugin.initialize(initSettings);

    _isInitialized = true;
  }

  // NOTI DETAILS SETUP
  NotificationDetails notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_channel_id',
        'Daily Notifications',
        channelDescription: 'Daily Notification Channel',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  // Show an immediate notification
  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
    String? payload,
  }) async {
    return notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails(),
    );
  }

  // Schedule a notification
  Future<void> scheduleNotification({
    int id = 1,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    // Get the current date/time in device's local timezone
    final now = tz.TZDateTime.now(tz.local);

    // Create a date/time for today at the specified hour/min
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the scheduled time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Schedule the notification
    await notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await notificationsPlugin.cancelAll();
  }

  // Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await notificationsPlugin.cancel(id);
  }

  // Schedule multiple notifications for a tablet based on schedule
  Future<void> scheduleTabletNotifications({
    required String tabletId,
    required String medicationName,
    required List<String> daysOfWeek,
    required List<String> times, // ["8:00 AM", "2:00 PM", "8:00 PM"]
  }) async {
    // Parse each time and schedule notifications
    for (int i = 0; i < times.length; i++) {
      final time = _parseTime(times[i]);
      if (time == null) continue;

      // Create unique ID for each notification (tablet-specific + time index)
      final notificationId = tabletId.hashCode + i;

      // Check if we should schedule for specific days or all days
      if (daysOfWeek.contains('All') || daysOfWeek.length == 7) {
        // Schedule daily
        await scheduleNotification(
          id: notificationId,
          title: 'Medication Reminder',
          body: 'Time to take your $medicationName!',
          hour: time['hour']!,
          minute: time['minute']!,
        );
        print('✅ Scheduled daily notification for $medicationName at ${times[i]}');
      } else {
        // Schedule for specific days
        await _scheduleDaySpecificNotification(
          id: notificationId,
          title: 'Medication Reminder',
          body: 'Time to take your $medicationName!',
          hour: time['hour']!,
          minute: time['minute']!,
          daysOfWeek: daysOfWeek,
        );
        print('✅ Scheduled notification for $medicationName on $daysOfWeek at ${times[i]}');
      }
    }
  }

// Helper: Parse time string "8:00 AM" to hour and minute
  Map<String, int>? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final isPM = parts[1] == 'PM';

      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;

      return {'hour': hour, 'minute': minute};
    } catch (e) {
      print('❌ Error parsing time: $timeStr - $e');
      return null;
    }
  }

// Helper: Schedule notification for specific days of the week
  Future<void> _scheduleDaySpecificNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required List<String> daysOfWeek,
  }) async {
    // Map day names to day numbers (Monday = 1, Sunday = 7)
    final dayMap = {
      'Mo': DateTime.monday,
      'Tu': DateTime.tuesday,
      'We': DateTime.wednesday,
      'Th': DateTime.thursday,
      'Fr': DateTime.friday,
      'Sa': DateTime.saturday,
      'Su': DateTime.sunday,
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
      'Saturday': DateTime.saturday,
      'Sunday': DateTime.sunday,
    };

    final now = tz.TZDateTime.now(tz.local);

    // Find the next occurrence of the first selected day
    int? targetDay;
    for (String day in daysOfWeek) {
      if (dayMap.containsKey(day)) {
        targetDay = dayMap[day];
        break;
      }
    }

    if (targetDay == null) return;

    // Calculate days until next target day
    int daysUntilTarget = (targetDay - now.weekday) % 7;
    if (daysUntilTarget == 0 && (now.hour > hour || (now.hour == hour && now.minute >= minute))) {
      daysUntilTarget = 7; // If time has passed today, schedule for next week
    }

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + daysUntilTarget,
      hour,
      minute,
    );

    // For day-specific notifications, we need to schedule weekly
    await notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

// Cancel all notifications for a specific tablet
  Future<void> cancelTabletNotifications(String tabletId, int numberOfTimes) async {
    for (int i = 0; i < numberOfTimes; i++) {
      final notificationId = tabletId.hashCode + i;
      await cancelNotification(notificationId);
    }
    print('✅ Cancelled all notifications for tablet: $tabletId');
  }

}