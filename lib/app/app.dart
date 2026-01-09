import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'routes.dart';
import '../theme/theme_provider.dart';
import 'package:tablet_reminder/components/pre_auth_check.dart';
import 'package:tablet_reminder/main.dart';



class TabletReminderApp extends StatelessWidget {
  const TabletReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
// Provide both light and dark themes
      darkTheme: Provider.of<ThemeProvider>(context).darkTheme,

      // Use themeMode to control which one is active
      themeMode: Provider.of<ThemeProvider>(context).themeMode,
      navigatorKey: navigatorKey, // ADD THIS

      theme: Provider.of<ThemeProvider>(context).themeData,

      home:  const AuthCheck(),

      // Routing
      onGenerateRoute: Routes.onGenerateRoute,

      // Fallback
      onUnknownRoute: (settings) =>
          MaterialPageRoute(builder: (_) => const _UnknownRouteScreen()),
    );
  }
}

class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Unknown route')));
  }
}