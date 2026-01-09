import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Widgets/Calendar_App_Bar.dart';
import '../Widgets/Month_Calendar_Grid.dart';
import '../components/calendar_progress_service.dart';
import '../components/pdf_export_service.dart'; // NEW IMPORT

class MedicationCalendar extends StatefulWidget {
  const MedicationCalendar({Key? key}) : super(key: key);

  @override
  State<MedicationCalendar> createState() => _MedicationCalendarState();
}

class _MedicationCalendarState extends State<MedicationCalendar> {
  DateTime? _selectedDay;
  final ScrollController _scrollController = ScrollController();
  final CalendarProgressService _progressService = CalendarProgressService();
  final PDFExportService _pdfExportService = PDFExportService(); // NEW

  List<DateTime> _months = [];
  List<Map<String, String>> _medications = [];
  String? _selectedMedicationId;
  bool _isLoadingMedications = true;
  bool _isExporting = false; // NEW

  @override
  void initState() {
    super.initState();
    _generateMonths();
    _selectedDay = DateTime.now();
    _loadMedications();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday(animate: false);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _generateMonths() {
    _months.clear();
    final now = DateTime.now();
    for (int i = -3; i <= 3; i++) {
      _months.add(DateTime(now.year, now.month + i, 1));
    }
  }

  Future<void> _loadMedications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final patientGroupID = prefs.getString('patientGroupID');

      if (patientGroupID == null) {
        if (mounted) {
          setState(() {
            _isLoadingMedications = false;
          });
        }
        return;
      }

      final meds = await _progressService.getMedicationList(
        patientGroupID: patientGroupID,
      );

      if (mounted) {
        setState(() {
          _medications = meds;
          _isLoadingMedications = false;
        });
      }

      print('✅ Loaded ${meds.length} medications for calendar filter');
    } catch (e) {
      print('❌ Error loading medications: $e');
      if (mounted) {
        setState(() {
          _isLoadingMedications = false;
        });
      }
    }
  }

  void _scrollToToday({bool animate = true}) {
    final todayIndex = _months.indexWhere((month) =>
    month.year == DateTime.now().year &&
        month.month == DateTime.now().month);

    if (todayIndex != -1 && _scrollController.hasClients) {
      final targetOffset = todayIndex * 380.0;

      if (animate) {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        _scrollController.jumpTo(targetOffset);
      }

      setState(() {
        _selectedDay = DateTime.now();
      });
    }
  }

  // UPDATED: Export 7 months of data
  Future<void> _handleShare() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final patientGroupID = prefs.getString('patientGroupID');

      if (patientGroupID == null) {
        throw Exception('No patient group found');
      }

      // Get medication name for display
      String? medicationName;
      if (_selectedMedicationId != null) {
        final med = _medications.firstWhere(
              (m) => m['id'] == _selectedMedicationId,
          orElse: () => {'name': 'Unknown', 'strength': ''},
        );
        medicationName = '${med['name']} ${med['strength']}'.trim();
      }

      // Show loading snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Generating 7-month report...',
                  style: GoogleFonts.dmSerifText(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.all(16),
          duration: Duration(seconds: 30), // Long duration while generating
        ),
      );

      // Generate and share 7-month PDF
      await _pdfExportService.exportCalendarPDF(
        patientGroupID: patientGroupID,
        selectedMedicationId: _selectedMedicationId,
        medicationName: medicationName,
      );

      // Clear loading snackbar
      ScaffoldMessenger.of(context).clearSnackBars();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  '7-month report generated!',
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
      print('❌ Error exporting PDF: $e');

      // Clear any existing snackbars
      ScaffoldMessenger.of(context).clearSnackBars();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to generate report: ${e.toString()}',
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
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  void _handleDaySelected(DateTime date) {
    setState(() {
      _selectedDay = date;
    });
  }

  void _handleMedicationChanged(String? medicationId) {
    setState(() {
      _selectedMedicationId = medicationId;
    });

    // Show feedback
    String displayName = 'All Medications';
    if (medicationId != null) {
      final med = _medications.firstWhere(
            (m) => m['id'] == medicationId,
        orElse: () => {'name': 'Unknown', 'strength': ''},
      );
      displayName = '${med['name']} ${med['strength']}'.trim();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(
              child: Text(
                'Showing: $displayName',
                style: GoogleFonts.dmSerifText(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            CalendarAppBar(
              onShare: _handleShare, // Connected to export function
              medications: _medications,
              selectedMedicationId: _selectedMedicationId,
              onMedicationChanged: _handleMedicationChanged,
              isLoading: _isLoadingMedications,
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _months.length,
                itemBuilder: (context, index) {
                  return MonthCalendarGrid(
                    monthDate: _months[index],
                    selectedDay: _selectedDay,
                    onDaySelected: _handleDaySelected,
                    selectedMedicationId: _selectedMedicationId,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildTodayButton(context, isDarkMode),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  Widget _buildTodayButton(BuildContext context, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(left: 30, bottom: 20),
      child: GestureDetector(
        onTap: () => _scrollToToday(animate: true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(30),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.today,
                color: Theme.of(context).colorScheme.inversePrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Today',
                style: GoogleFonts.dmSerifText(
                  color: Theme.of(context).colorScheme.inversePrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}