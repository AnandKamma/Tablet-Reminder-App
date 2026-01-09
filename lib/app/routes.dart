import 'package:flutter/material.dart';
import 'package:tablet_reminder/screens/AddTablet_HomePage.dart';
import 'package:tablet_reminder/screens/Calendar.dart';
import 'package:tablet_reminder/screens/CaregiverManagemntPage.dart';
import 'package:tablet_reminder/screens/HomePage.dart';
import 'package:tablet_reminder/screens/add_tablet/Inventory_Screen.dart';
import 'package:tablet_reminder/screens/loginpage.dart';
import 'package:tablet_reminder/screens/PatientPage.dart';
import 'package:tablet_reminder/screens/add_tablet/Medication_Page.dart';
import 'package:tablet_reminder/screens/add_tablet/schedule_screen.dart';
import 'package:tablet_reminder/screens/add_tablet/Caregivers_screen.dart';
import 'package:tablet_reminder/components/Navigation.dart';
import 'package:tablet_reminder/screens/DoctorDashBoard.dart'; // NEW: Import Doctor Dashboard


// Import your screens here:
// import '../screens/add_tablet/medication_page.dart';
// import '../screens/add_tablet/schedule_page.dart';
// import '../screens/add_tablet/alerts_page.dart';
// import '../screens/add_tablet/caregivers_page.dart';
// import '../screens/add_tablet/inventory_page.dart';

class Routes {
  // Route names (keep them centralized)
  static const String addTabletHome = '/add-tablet';
  static const String medication = '/add-tablet/medication';
  static const String alerts = '/add-tablet/alerts';
  static const String homepage = '/home-page';
  static const String calendar = '/calendar-page';
  static const String loginpage = '/loginpage';
  static const String patientpage = '/patient-page';
  static const String schedule = '/add-tablet/schedule';
  static const String caregivers = '/add-tablet/caregivers';
  static const String inventory = '/add-tablet/inventory';
  static const String caregiversmanagement = '/caregiversmanagement';
  static const String navigation = '/navigation';
  static const String doctorDashboard = '/doctor-dashboard';


  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case addTabletHome:
        return MaterialPageRoute(
          builder: (_) => const AddTabletHomePage(),
          settings: settings,
        );
      case Routes.medication:
        return MaterialPageRoute(
          builder: (_) => const MedicationScreen(),
          settings: settings,
        );
      case Routes.homepage:
        return MaterialPageRoute(builder: (_) => const HomePage(),settings: settings,
        );
      case Routes.calendar:
        return MaterialPageRoute(builder: (_) => const MedicationCalendar(),settings: settings,
        );

      case loginpage:
        return MaterialPageRoute(
          builder: (_) => LoginScreen(),
          settings: settings,
        );
      case patientpage:
        return MaterialPageRoute(
          builder: (_) => const PatientPage(),
          settings: settings,
        );
      case Routes.schedule:
        return MaterialPageRoute(
          builder: (_) => const ScheduleScreen(),
          settings: settings,
        );
      case Routes.caregivers:
        return MaterialPageRoute(
          builder: (_) => const CaregiversScreen(),
          settings: settings,
        );
      case Routes.inventory:
        return MaterialPageRoute(
          builder: (_) => const InventoryScreen(),
          settings: settings,
        );
      case Routes.caregiversmanagement:
        return MaterialPageRoute(
          builder: (_) => const CaregiverManagementScreen(),
          settings: settings,
        );
      case Routes.navigation:
        final args = settings.arguments as Map<String, dynamic>?;  // ← null for patients
        return MaterialPageRoute(
          builder: (_) => MainNavigation(
            patientGroupID: args?['patientGroupID'],  // ← null, so uses default
            isDoctorView: args?['isDoctorView'] ?? false,  // ← false for patients
          ),
        );
      case Routes.doctorDashboard: // NEW: Doctor Dashboard Route Handler
        return MaterialPageRoute(
          builder: (_) => const DoctorDashboard(),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const _RouteNotFoundScreen(),
          settings: settings,
        );
    }
  }
}

class _RouteNotFoundScreen extends StatelessWidget {
  const _RouteNotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not Found')),
      body: const Center(
        child: Text('Route not found'),
      ),
    );
  }
}