import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_reminder/components/Registration_service.dart';
import 'package:tablet_reminder/app/routes.dart';

class PatientPage extends StatefulWidget {
  static const String id = 'PatientPage';

  const PatientPage({super.key});

  @override
  State<PatientPage> createState() => _PatientPageState();
}

class _PatientPageState extends State<PatientPage> {
  final PatientGroupService patientGroupService = PatientGroupService();
  TextEditingController patientGroupIDController = TextEditingController();
  TextEditingController deviceIDController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    patientGroupIDController.dispose();
    deviceIDController.dispose();
    super.dispose();
  }

  /// Show Information Modal
  void showInformationAboutRole(BuildContext context, String role) {
    final rootContext = context;
    FocusNode patientGroupIDFocus = FocusNode();
    bool showInputs = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: DraggableScrollableSheet(
                initialChildSize: showInputs ? 0.85 : 0.70,
                minChildSize: 0.6,
                maxChildSize: 0.95,
                expand: false,
                builder: (context, scrollController) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Drag handle
                          Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          if (!showInputs)
                          // Information Text
                            Column(
                              children: [
                                Text(
                                  role == 'Patient'
                                      ? 'Patient Registration'
                                      : role == 'Caregiver'
                                      ? 'Caregiver Registration'
                                      : 'Doctor Registration',
                                  style: GoogleFonts.dmSerifText(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.inversePrimary,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildInfoText(context, role),
                                const SizedBox(height: 32),
                                _buildActionButton(
                                  context,
                                  role == "Patient" ? 'Next' : 'Got it!',
                                      () async {
                                    if (role == 'Patient') {
                                      setModalState(() {
                                        showInputs = true;
                                      });
                                      Future.delayed(
                                        const Duration(milliseconds: 300),
                                            () => patientGroupIDFocus.requestFocus(),
                                      );
                                    } else {
                                      // For Caregiver and Doctor - just register the role
                                      setModalState(() => isLoading = true);

                                      final user = FirebaseAuth.instance.currentUser;
                                      if (user == null) return;

                                      try {
                                        await patientGroupService.registerUserRole(
                                          user.uid,
                                          role.toLowerCase(), // 'caregiver' or 'doctor'
                                        );

                                        if (mounted) Navigator.pop(context);

                                        // For Doctor, navigate to Doctor Dashboard
                                        // For Caregiver, they'll wait for patient to add them
                                        if (role == 'Doctor') {
                                          Future.delayed(
                                            const Duration(milliseconds: 250),
                                                () {
                                              if (mounted) {
                                                Navigator.of(rootContext).pushReplacementNamed(Routes.doctorDashboard);
                                              }
                                            },
                                          );
                                        }
                                      } catch (e) {
                                        print("❌ Error registering role: $e");
                                      }

                                      setModalState(() => isLoading = false);
                                    }
                                  },
                                ),
                              ],
                            )
                          else
                          // Input Fields (Only for Patient)
                            Column(
                              children: [
                                Text(
                                  'Setup Your Account',
                                  style: GoogleFonts.dmSerifText(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.inversePrimary,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildInputField(
                                  context,
                                  controller: patientGroupIDController,
                                  label: "Patient Group ID",
                                  focusNode: patientGroupIDFocus,
                                ),
                                const SizedBox(height: 20),
                                _buildInputField(
                                  context,
                                  controller: deviceIDController,
                                  label: "Name of your reminder device",
                                ),
                                const SizedBox(height: 32),
                                _buildActionButton(
                                  context,
                                  isLoading ? '' : 'Submit',
                                  isLoading
                                      ? null
                                      : () async {
                                    FocusScope.of(context).unfocus();
                                    setModalState(() => isLoading = true);

                                    final user = FirebaseAuth.instance.currentUser;
                                    if (user == null) return;

                                    try {
                                      await patientGroupService.registerPatientGroup(
                                        user.uid,
                                        patientGroupIDController.text.trim(),
                                        deviceIDController.text.trim(),
                                      );
                                      if (mounted) Navigator.pop(context);
                                      Future.delayed(
                                        const Duration(milliseconds: 250),
                                            () {
                                          if (mounted) {
                                            Navigator.of(rootContext).pushReplacementNamed(Routes.navigation);
                                          }
                                        },
                                      );
                                    } catch (e) {
                                      print("❌ Error: $e");
                                    }

                                    setModalState(() => isLoading = false);
                                  },
                                  isLoading: isLoading,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoText(BuildContext context, String role) {
    final textStyle = TextStyle(
      fontSize: 16,
      height: 1.5,
      color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.8),
    );

    final boldStyle = TextStyle(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.inversePrimary,
    );

    if (role == 'Patient') {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: "As a Patient, ", style: boldStyle),
            TextSpan(text: "you need to create a unique patient group identifier and type the device name.\n\n", style: textStyle),
            TextSpan(text: "You can add caregivers and a doctor ", style: textStyle),
            TextSpan(text: "who will have the option to receive reminders when you have taken your meds.\n\n", style: boldStyle),
            TextSpan(text: "They will also be able to track your progress.\n\n", style: textStyle),
            TextSpan(text: "To add caregivers or a doctor, ", style: textStyle),
            TextSpan(text: "you will be directed into the homepage, where you can click the plus button on top left of your screen.", style: boldStyle),
          ],
        ),
        textAlign: TextAlign.center,
      );
    } else if (role == 'Caregiver') {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: "Awesome! ", style: boldStyle),
            TextSpan(text: "You are registered in our system.\n\n", style: textStyle),
            TextSpan(text: "Notify the patient.\n\n", style: boldStyle),
            TextSpan(text: "Ensure that the exact ", style: textStyle),
            TextSpan(text: "email ID (Google Sign-In) or name (Apple Sign-In) ", style: boldStyle),
            TextSpan(text: "is used by the patient to identify you.\n\n", style: textStyle),
            TextSpan(text: "Wait for the patient to add you and restart the app.", style: boldStyle),
          ],
        ),
        textAlign: TextAlign.center,
      );
    } else {
      // Doctor role
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: "Welcome, Doctor! ", style: boldStyle),
            TextSpan(text: "You are registered in our system.\n\n", style: textStyle),
            TextSpan(text: "Notify your patients.\n\n", style: boldStyle),
            TextSpan(text: "Ensure that the exact ", style: textStyle),
            TextSpan(text: "email ID (Google Sign-In) or name (Apple Sign-In) ", style: boldStyle),
            TextSpan(text: "is used by your patients to identify you.\n\n", style: textStyle),
            TextSpan(text: "Once patients add you, you'll see them in your dashboard.", style: boldStyle),
          ],
        ),
        textAlign: TextAlign.center,
      );
    }
  }

  Widget _buildInputField(
      BuildContext context, {
        required TextEditingController controller,
        required String label,
        FocusNode? focusNode,
      }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black : Colors.grey.shade500,
            offset: const Offset(4, 4),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: isDarkMode ? Colors.grey.shade800 : Colors.white,
            offset: const Offset(-4, -4),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        cursorColor: Theme.of(context).colorScheme.inversePrimary,
        style: GoogleFonts.dmSerifText(
          color: Theme.of(context).colorScheme.inversePrimary,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.dmSerifText(
            color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.6),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context,
      String text,
      VoidCallback? onPressed, {
        bool isLoading = false,
      }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: onPressed != null
              ? [
            BoxShadow(
              color: isDarkMode ? Colors.black : Colors.grey.shade500,
              offset: const Offset(4, 4),
              blurRadius: 10,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: isDarkMode ? Colors.grey.shade800 : Colors.white,
              offset: const Offset(-4, -4),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ]
              : null,
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
          )
              : Text(
            text,
            style: GoogleFonts.dmSerifText(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              Text(
                'Select Your Role',
                style: GoogleFonts.dmSerifText(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 50),

              // Patient Button
              Expanded(
                child: _buildRoleButton(
                  context,
                  'Patient',
                  Icons.person,
                  isDarkMode,
                      () => showInformationAboutRole(context, 'Patient'),
                ),
              ),

              const SizedBox(height: 20),

              // Caregiver Button
              Expanded(
                child: _buildRoleButton(
                  context,
                  'Caregiver',
                  Icons.favorite,
                  isDarkMode,
                      () => showInformationAboutRole(context, 'Caregiver'),
                ),
              ),

              const SizedBox(height: 20),

              // Doctor Button (NEW)
              Expanded(
                child: _buildRoleButton(
                  context,
                  'Doctor',
                  Icons.medical_services,
                  isDarkMode,
                      () => showInformationAboutRole(context, 'Doctor'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton(
      BuildContext context,
      String role,
      IconData icon,
      bool isDarkMode,
      VoidCallback onPressed,
      ) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black : Colors.grey.shade500,
              offset: const Offset(5, 5),
              blurRadius: 15,
              spreadRadius: 5,
            ),
            BoxShadow(
              color: isDarkMode ? Colors.grey.shade800 : Colors.white,
              offset: const Offset(-4, -4),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
            const SizedBox(height: 16),
            Text(
              role,
              style: GoogleFonts.dmSerifText(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}