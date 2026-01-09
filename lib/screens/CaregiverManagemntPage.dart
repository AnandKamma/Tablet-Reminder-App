import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tablet_reminder/Widgets/Search_Bar.dart';
import 'package:tablet_reminder/Widgets/Caregiver_Tile.dart';
import 'package:tablet_reminder/components/Backend_Integration/caregivers_service.dart';

class CaregiverManagementScreen extends StatefulWidget {
  const CaregiverManagementScreen({super.key});

  @override
  State<CaregiverManagementScreen> createState() => _CaregiverManagementScreenState();
}

class _CaregiverManagementScreenState extends State<CaregiverManagementScreen> {
  final TextEditingController _caregiverSearchController = TextEditingController();
  final TextEditingController _doctorSearchController = TextEditingController();
  final CaregiverService _caregiverService = CaregiverService();

  List<Map<String, dynamic>> _filteredCaregivers = [];
  List<Map<String, dynamic>> _addedCaregivers = [];

  List<Map<String, dynamic>> _filteredDoctors = [];
  Map<String, dynamic>? _addedDoctor;

  String? patientGroupID;
  String? currentUserId;
  bool isLoading = false;
  bool isSearchingCaregivers = false;
  bool isSearchingDoctors = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      patientGroupID = prefs.getString('patientGroupID');
      currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (patientGroupID == null || currentUserId == null) {
        print("❌ Missing patient group or user ID");
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        return;
      }

      await _loadAddedCaregivers();
      await _loadAddedDoctor();
    } catch (e) {
      print("❌ Error initializing: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAddedCaregivers() async {
    if (patientGroupID == null || currentUserId == null) return;

    try {
      final caregivers = await _caregiverService.getAddedCaregivers(
        patientGroupID: patientGroupID!,
        patientUid: currentUserId!,
      );

      if (mounted) {
        setState(() {
          _addedCaregivers = caregivers;
        });
      }
    } catch (e) {
      print("❌ Error loading caregivers: $e");
    }
  }

  Future<void> _loadAddedDoctor() async {
    if (patientGroupID == null) return;

    try {
      final doctor = await _caregiverService.getAddedDoctor(
        patientGroupID: patientGroupID!,
      );

      if (mounted) {
        setState(() {
          _addedDoctor = doctor;
        });
      }
    } catch (e) {
      print("❌ Error loading doctor: $e");
    }
  }

  Future<void> _searchCaregivers(String query) async {
    if (patientGroupID == null || currentUserId == null) return;

    if (query.trim().isEmpty) {
      setState(() {
        _filteredCaregivers = [];
        isSearchingCaregivers = false;
      });
      return;
    }

    setState(() {
      isSearchingCaregivers = true;
    });

    try {
      // Get existing caregiver IDs to exclude from search
      final existingIds = _addedCaregivers.map((c) => c['uid'] as String).toList();

      final results = await _caregiverService.searchUsersByEmail(
        email: query,
        currentUserId: currentUserId!,
        existingCaregiverIds: existingIds,
        roleFilter: 'caregiver', // Only search for caregivers
      );

      if (mounted) {
        setState(() {
          _filteredCaregivers = results;
          isSearchingCaregivers = false;
        });
      }
    } catch (e) {
      print("❌ Error searching caregivers: $e");
      if (mounted) {
        setState(() {
          isSearchingCaregivers = false;
        });
      }
    }
  }

  Future<void> _searchDoctors(String query) async {
    if (patientGroupID == null || currentUserId == null) return;

    if (query.trim().isEmpty) {
      setState(() {
        _filteredDoctors = [];
        isSearchingDoctors = false;
      });
      return;
    }

    setState(() {
      isSearchingDoctors = true;
    });

    try {
      final results = await _caregiverService.searchUsersByEmail(
        email: query,
        currentUserId: currentUserId!,
        existingCaregiverIds: [],
        roleFilter: 'doctor', // Only search for doctors
      );

      if (mounted) {
        setState(() {
          _filteredDoctors = results;
          isSearchingDoctors = false;
        });
      }
    } catch (e) {
      print("❌ Error searching doctors: $e");
      if (mounted) {
        setState(() {
          isSearchingDoctors = false;
        });
      }
    }
  }

  Future<void> _addCaregiver(Map<String, dynamic> caregiver) async {
    if (patientGroupID == null) return;

    try {
      await _caregiverService.addCaregiver(
        patientGroupID: patientGroupID!,
        caregiverUid: caregiver['uid'],
      );

      // Reload caregivers
      await _loadAddedCaregivers();

      // Clear search
      _caregiverSearchController.clear();
      setState(() {
        _filteredCaregivers = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  '${caregiver['name']} added as caregiver',
                  style: GoogleFonts.dmSerifText(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: EdgeInsets.all(16),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("❌ Error adding caregiver: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error adding caregiver',
                    style: GoogleFonts.dmSerifText(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: EdgeInsets.all(16),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _addDoctor(Map<String, dynamic> doctor) async {
    if (patientGroupID == null) return;

    try {
      await _caregiverService.addDoctor(
        patientGroupID: patientGroupID!,
        doctorUid: doctor['uid'],
      );

      // Reload doctor
      await _loadAddedDoctor();

      // Clear search
      _doctorSearchController.clear();
      setState(() {
        _filteredDoctors = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  '${doctor['name']} added as doctor',
                  style: GoogleFonts.dmSerifText(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: EdgeInsets.all(16),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("❌ Error adding doctor: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error adding doctor',
                    style: GoogleFonts.dmSerifText(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: EdgeInsets.all(16),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _removeCaregiver(Map<String, dynamic> caregiver) async {
    if (patientGroupID == null) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          "Remove Caregiver",
          style: GoogleFonts.dmSerifText(
            color: Theme.of(context).colorScheme.inversePrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Remove ${caregiver['name']} as caregiver?',
          style: GoogleFonts.dmSerifText(
            color: Theme.of(context).colorScheme.inversePrimary,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: GoogleFonts.dmSerifText(
                color: Theme.of(context).colorScheme.inversePrimary,
                fontSize: 16,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Remove",
              style: GoogleFonts.dmSerifText(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _caregiverService.removeCaregiver(
        patientGroupID: patientGroupID!,
        caregiverUid: caregiver['uid'],
      );

      // Reload caregivers
      await _loadAddedCaregivers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  '${caregiver['name']} removed',
                  style: GoogleFonts.dmSerifText(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: EdgeInsets.all(16),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("❌ Error removing caregiver: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error removing caregiver',
                    style: GoogleFonts.dmSerifText(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: EdgeInsets.all(16),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _removeDoctor() async {
    if (patientGroupID == null || _addedDoctor == null) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          "Remove Doctor",
          style: GoogleFonts.dmSerifText(
            color: Theme.of(context).colorScheme.inversePrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Remove ${_addedDoctor!['name']} as your doctor?',
          style: GoogleFonts.dmSerifText(
            color: Theme.of(context).colorScheme.inversePrimary,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: GoogleFonts.dmSerifText(
                color: Theme.of(context).colorScheme.inversePrimary,
                fontSize: 16,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Remove",
              style: GoogleFonts.dmSerifText(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _caregiverService.removeDoctor(
        patientGroupID: patientGroupID!,
      );

      // Reload doctor
      await _loadAddedDoctor();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Doctor removed',
                  style: GoogleFonts.dmSerifText(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: EdgeInsets.all(16),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("❌ Error removing doctor: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error removing doctor',
                    style: GoogleFonts.dmSerifText(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: EdgeInsets.all(16),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _caregiverSearchController.dispose();
    _doctorSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            'Manage Care Team',
            style: GoogleFonts.dmSerifText(
              fontSize: 30,
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.inversePrimary,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Manage Care Team',
          style: GoogleFonts.dmSerifText(
            fontSize: 30,
            color: Theme.of(context).colorScheme.inversePrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CAREGIVERS SECTION
            Text(
              'Your Caregivers',
              style: GoogleFonts.dmSerifText(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Caregiver Search Bar
            SearchBarField(
              controller: _caregiverSearchController,
              hintText: 'Search caregiver by email...',
              onChanged: (value) => _searchCaregivers(value),
              onClear: () {
                _caregiverSearchController.clear();
                setState(() {
                  _filteredCaregivers = [];
                });
              },
            ),
            const SizedBox(height: 12),

            // Caregiver Search Results
            if (_caregiverSearchController.text.isNotEmpty) ...[
              Text(
                'Search Results',
                style: GoogleFonts.dmSerifText(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
              ),
              const SizedBox(height: 12),

              if (isSearchingCaregivers)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                  ),
                )
              else if (_filteredCaregivers.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No caregivers found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .inversePrimary
                            .withOpacity(0.5),
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredCaregivers.length,
                  itemBuilder: (context, index) {
                    final caregiver = _filteredCaregivers[index];
                    return CaregiverTile(
                      name: caregiver['name'],
                      email: caregiver['email'],
                      isAdded: false,
                      onTap: () => _addCaregiver(caregiver),
                    );
                  },
                ),

              const SizedBox(height: 30),
            ],

            // Added Caregivers List
            if (_addedCaregivers.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_add_outlined,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .inversePrimary
                            .withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No caregivers added yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .inversePrimary
                              .withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Search by email to add caregivers',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .inversePrimary
                              .withOpacity(0.4),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _addedCaregivers.length,
                itemBuilder: (context, index) {
                  final caregiver = _addedCaregivers[index];
                  return CaregiverTile(
                    name: caregiver['name'],
                    email: caregiver['email'],
                    isAdded: true,
                    onTap: () => _removeCaregiver(caregiver),
                  );
                },
              ),

            const SizedBox(height: 40),
            // DOCTOR SECTION
            Text(
              'Your Doctor',
              style: GoogleFonts.dmSerifText(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Doctor Search Bar (only show if no doctor added)
            if (_addedDoctor == null) ...[
              SearchBarField(
                controller: _doctorSearchController,
                hintText: 'Search doctor by email...',
                onChanged: (value) => _searchDoctors(value),
                onClear: () {
                  _doctorSearchController.clear();
                  setState(() {
                    _filteredDoctors = [];
                  });
                },
              ),
              const SizedBox(height: 12),
            ],

            // Doctor Search Results
            if (_doctorSearchController.text.isNotEmpty && _addedDoctor == null) ...[
              if (isSearchingDoctors)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                  ),
                )
              else if (_filteredDoctors.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No doctors found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .inversePrimary
                            .withOpacity(0.5),
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredDoctors.length,
                  itemBuilder: (context, index) {
                    final doctor = _filteredDoctors[index];
                    return CaregiverTile(
                      name: doctor['name'],
                      email: doctor['email'],
                      isAdded: false,
                      onTap: () => _addDoctor(doctor),
                    );
                  },
                ),
              const SizedBox(height: 20),
            ],

            // Current Doctor Display
            if (_addedDoctor != null)
              CaregiverTile(
                name: _addedDoctor!['name'],
                email: _addedDoctor!['email'],
                isAdded: true,
                onTap: _removeDoctor,
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.medical_services_outlined,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .inversePrimary
                            .withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No doctor added yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .inversePrimary
                              .withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Search by email to add your doctor',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .inversePrimary
                              .withOpacity(0.4),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}