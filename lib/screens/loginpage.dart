import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:tablet_reminder/components/Auth_Service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_reminder/app/routes.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  static const String id = 'login_screen';
  final AuthService authService = AuthService();

  LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// [Keep your checkUserRegistration function exactly as is - no changes needed]
Future<void> checkUserRegistration(BuildContext context, String userId) async {
  print("🔍 Checking user registration...");

  try {
    final firestore = FirebaseFirestore.instance;
    String? patientGroupID = await AuthService().getPatientGroupID(userId);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    print("🔍 Retrieved patientGroupID: $patientGroupID");

    print("🔍 Retrieved patientGroupID from Firestore: $patientGroupID");

    if (patientGroupID == null || patientGroupID.isEmpty) {
      print("❌ No patient group assigned in Firestore.");
      await prefs.remove('patientGroupID');
      String? storedPatientGroupID = prefs.getString('patientGroupID');
      if (storedPatientGroupID != null && storedPatientGroupID.isNotEmpty) {
        print("⚠️ WARNING: Using outdated PatientGroupID from SharedPreferences: $storedPatientGroupID");
        Navigator.pushReplacementNamed(context, Routes.navigation);
        return;
      }
      print("🚨 No valid patient group found. Redirecting to PatientPage...");
      Navigator.pushReplacementNamed(context, Routes.patientpage);
      return;
    }

    print("📡 Fetching user document from Firestore...");
    DocumentSnapshot userDoc = await firestore
        .collection('users')
        .doc(userId)
        .get(const GetOptions(source: Source.server));

    if (!userDoc.exists || userDoc.data() == null) {
      print("❌ User does NOT exist in Firestore. Clearing old data...");
      await prefs.remove('patientGroupID');
      Navigator.pushReplacementNamed(context, Routes.patientpage);
      return;
    }

    print("📡 Fetching patient group document with ID: $patientGroupID...");
    DocumentSnapshot patientGroupDoc = await firestore
        .collection('patientGroups')
        .doc(patientGroupID)
        .get(const GetOptions(source: Source.server));

    if (!patientGroupDoc.exists) {
      print("❌ Patient group with ID $patientGroupID does NOT exist. Clearing old data...");
      await firestore.collection('users').doc(userId).update({'patientGroupID': FieldValue.delete()});
      await prefs.remove('patientGroupID');
      Navigator.pushReplacementNamed(context, Routes.patientpage);
      return;
    }

    print("✅ Patient group document found: ${patientGroupDoc.data()}");

    Map<String, dynamic>? patientGroupData = patientGroupDoc.data() as Map<String, dynamic>?;
    if (patientGroupData == null) {
      print("❌ Patient group data is NULL. Clearing SharedPreferences and redirecting...");
      await prefs.remove('patientGroupID');
      Navigator.pushReplacementNamed(context, Routes.patientpage);
      return;
    }

    List<dynamic>? caregivers = patientGroupData['caregivers'];
    if (caregivers == null || !caregivers.contains(userId)) {
      print("❌ User is NOT in the patient group caregivers list. Redirecting...");
      await prefs.remove('patientGroupID');
      Navigator.pushReplacementNamed(context, Routes.patientpage);
      return;
    }

    await prefs.setString('patientGroupID', patientGroupID);
    print("✅ PatientGroupID stored in SharedPreferences: ${prefs.getString('patientGroupID')}");

    print("✅ User verified in Firestore. Redirecting to HomeScreen...");
    Navigator.pushReplacementNamed(context, Routes.navigation);

  } catch (e) {
    print("❌ Error during user check: $e");
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('patientGroupID');
    Navigator.pushReplacementNamed(context, Routes.patientpage);
  }
}

class _LoginScreenState extends State<LoginScreen> {
  bool showSpinner = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: ModalProgressHUD(
        color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.5),
        inAsyncCall: showSpinner,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Title
                Text(
                  'Tablet Reminder',
                  style: GoogleFonts.dmSerifText(
                    fontSize: 50,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 100),

                // Subtitle

                // Sign in with text
                Text(
                  'Sign in with',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.6),
                  ),
                ),

                const SizedBox(height: 20),

                // Login Buttons Row
                Row(
                  children: [
                    // Google Sign-In Button
                    Expanded(
                      child: _LoginButton(
                        icon: FontAwesomeIcons.google,
                        iconColor: const Color(0xFFDB4437), // Google red
                        onPressed: () async {
                          setState(() {
                            showSpinner = true;
                          });

                          try {
                            final authService = AuthService();
                            UserCredential? userCredential =
                            await authService.loginWithGoogle(context);

                            if (userCredential != null) {
                              print("✅ Google Sign-In successful!");
                              await checkUserRegistration(
                                  context, userCredential.user!.uid);
                            } else {
                              print("❌ Google Sign-In Failed or Cancelled");
                            }
                          } catch (e) {
                            print("❌ Error during sign in with Google: $e");
                          } finally {
                            setState(() {
                              showSpinner = false;
                            });
                          }
                        },
                        isDarkMode: isDarkMode,
                      ),
                    ),

                    const SizedBox(width: 20),

                    // Apple Sign-In Button
                    Expanded(
                      child: _LoginButton(
                        icon: FontAwesomeIcons.apple,
                        iconColor: Theme.of(context).colorScheme.inversePrimary,
                        onPressed: () async {
                          setState(() {
                            showSpinner = true;
                          });

                          try {
                            final authService = AuthService();
                            UserCredential? userCredential =
                            await authService.loginWithApple(context);

                            if (userCredential != null) {
                              print("✅ Apple Sign-In successful!");
                              await checkUserRegistration(
                                  context, userCredential.user!.uid);
                            } else {
                              print("❌ Apple Sign-In Failed or Cancelled");
                            }
                          } catch (e) {
                            print("❌ Error during sign in with Apple: $e");
                          } finally {
                            setState(() {
                              showSpinner = false;
                            });
                          }
                        },
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Neomorphic Login Button Widget
class _LoginButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onPressed;
  final bool isDarkMode;

  const _LoginButton({
    required this.icon,
    required this.iconColor,
    required this.onPressed,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            // Bottom-right shadow (darker)
            BoxShadow(
              color: isDarkMode ? Colors.black : Colors.grey.shade500,
              offset: const Offset(5, 5),
              blurRadius: 15,
              spreadRadius: 5,
            ),
            // Top-left shadow (lighter)
            BoxShadow(
              color: isDarkMode ? Colors.grey.shade800 : Colors.white,
              offset: const Offset(-4, -4),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: FaIcon(
            icon,
            size: 50,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}