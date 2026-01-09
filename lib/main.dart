import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'theme/theme_provider.dart';
import 'package:tablet_reminder/components/notifications_service.dart';
import 'app/app.dart';
import 'package:alarm/alarm.dart';
import 'package:tablet_reminder/screens/AlarmPage.dart';
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotiService().initNotification();
  await Alarm.init();
  Alarm.ringStream.stream.listen((alarmSettings) {
    // Navigate to alarm screen when alarm rings
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => AlarmScreen(alarmSettings: alarmSettings),
      ),
    );
  });

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const TabletReminderApp(),
    ),
  );
}