import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tablet_reminder/components/Backend_Integration/caregivers_notifications_service.dart';
class MedicationTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get today's scheduled medications for the patient
  Future<List<Map<String, dynamic>>> getTodaysMedications(String patientGroupID) async {
    try {
      // Get current day of week
      final now = DateTime.now();
      final dayOfWeek = _getDayAbbreviation(now.weekday);

      print("📅 Fetching medications for: $dayOfWeek");

      // Fetch all tablets for this patient group
      final tabletsSnapshot = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .collection('tablets')
          .get();

      List<Map<String, dynamic>> todaysMeds = [];

      for (var doc in tabletsSnapshot.docs) {
        final data = doc.data();
        final schedule = data['schedule'];
        final medication = data['medication'];

        if (schedule == null || medication == null) continue;

        // Check if medication is scheduled for today
        List<String> scheduledDays = List<String>.from(schedule['daysOfWeek'] ?? []);

        // Check if today is in the scheduled days (or if "All" days selected)
        if (scheduledDays.contains('All') || scheduledDays.contains(dayOfWeek)) {
          // Get all scheduled times for today
          List<String> times = List<String>.from(schedule['times'] ?? []);

          for (String time in times) {
            // Check if this dose should be visible now
            final scheduledTime = _parseScheduledTime(time);
            if (scheduledTime != null && _shouldShowDose(scheduledTime, now)) {
              // Check if already taken today
              final takenData = await _isDoseTakenToday(
                patientGroupID: patientGroupID,
                tabletId: doc.id,
                scheduledTime: time,
              );

              final lateWindowMinutes = _getLateWindowMinutes(data['caregiverSettings']?['lateWindow']);

              // Determine status: "taken_on_time", "taken_late", "missed", "pending"
              // Determine status
              String status = 'pending';

              if (takenData['taken']) {
                // Already taken - check if it was late
                status = takenData['takenLate'] == true ? 'taken_late' : 'taken_on_time';
              } else {
                // Not taken yet - check if late window has passed
                if (lateWindowMinutes != null) {
                  final lateWindowExpiry = scheduledTime.add(Duration(minutes: lateWindowMinutes));
                  if (now.isAfter(lateWindowExpiry)) {
                    status = 'missed'; // Time + late window has passed
                  } else {
                    status = 'pending'; // Still within window
                  }
                } else {
                  // No late window set - just check if time has passed
                  status = 'pending';
                }
              }

              print("📊 Status for ${medication['name']} at $time: $status (taken: ${takenData['taken']}, takenLate: ${takenData['takenLate']})");

              todaysMeds.add({
                'tabletId': doc.id,
                'name': medication['name'],
                'strength': medication['strength'],
                'frequency': medication['frequency'],
                'scheduledTime': time,
                'scheduledDateTime': scheduledTime,
                'taken': takenData['taken'],
                'takenAt': takenData['takenAt'],
                'status': status, // ADD THIS
                'caregiverSettings': data['caregiverSettings'],
                'lateWindow': lateWindowMinutes,
              });
            }
          }
        }
      }

      // Sort by scheduled time
      todaysMeds.sort((a, b) {
        final timeA = a['scheduledDateTime'] as DateTime;
        final timeB = b['scheduledDateTime'] as DateTime;
        return timeA.compareTo(timeB);
      });

      print("✅ Found ${todaysMeds.length} medications for today");
      return todaysMeds;
    } catch (e) {
      print("❌ Error fetching today's medications: $e");
      return [];
    }
  }

  /// Mark a dose as taken
  /// Mark a dose as taken
  Future<Map<String, dynamic>> markDoseAsTaken({
    required String patientGroupID,
    required String tabletId,
    required String scheduledTime,
    required String medicationName,
    Map<String, dynamic>? caregiverSettings,
    int? lateWindowMinutes,
  }) async {
    try {
      final now = DateTime.now();
      final takenAt = Timestamp.fromDate(now);
      bool takenLate = false;

      // Check if taken late (past late window)
      if (lateWindowMinutes != null) {
        final scheduledDateTime = _parseScheduledTime(scheduledTime);
        if (scheduledDateTime != null) {
          final lateWindowExpiry = scheduledDateTime.add(Duration(minutes: lateWindowMinutes));
          takenLate = now.isAfter(lateWindowExpiry);
        }
      }

      // Create log entry for today
      final logId = '${tabletId}_${_getTodayDateString()}_${scheduledTime.replaceAll(':', '-').replaceAll(' ', '_')}';

      await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .collection('medicationLogs')
          .doc(logId)
          .set({
        'tabletId': tabletId,
        'medicationName': medicationName,
        'scheduledTime': scheduledTime,
        'takenAt': takenAt,
        'date': _getTodayDateString(),
        'status': takenLate ? 'taken_late' : 'taken',
        'takenLate': takenLate,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print("✅ Marked $medicationName as taken at ${now.hour}:${now.minute}");

      // Send caregiver notifications if enabled
      if (caregiverSettings?['notifyCaregivers'] == true) {
        // Get patient name
        final patientName = await _getPatientName(patientGroupID);

        // Import caregiver notification service
        final CaregiverNotificationService notificationService = CaregiverNotificationService();

        // Send notification
        await notificationService.notifyCaregiversMedicationTaken(
          patientGroupID: patientGroupID,
          patientName: patientName,
          medicationName: medicationName,
          takenAt: now,
          takenLate: takenLate,
        );
      }

      return {
        'success': true,
        'takenLate': takenLate,
        'takenAt': now,
      };
    } catch (e) {
      print("❌ Error marking dose as taken: $e");
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get patient's full name
  Future<String> _getPatientName(String patientGroupID) async {
    try {
      final groupDoc = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .get();

      if (groupDoc.exists) {
        final patientUid = groupDoc.data()?['patient_uid'] as String?;

        if (patientUid != null) {
          final userDoc = await _firestore.collection('users').doc(patientUid).get();
          if (userDoc.exists) {
            return userDoc.data()?['fullName'] ?? 'Patient';
          }
        }
      }

      return 'Patient';
    } catch (e) {
      print('❌ Error getting patient name: $e');
      return 'Patient';
    }
  }

  /// Check if a dose was taken today
  Future<Map<String, dynamic>> _isDoseTakenToday({
    required String patientGroupID,
    required String tabletId,
    required String scheduledTime,
  }) async {
    try {
      final logId = '${tabletId}_${_getTodayDateString()}_${scheduledTime.replaceAll(':', '-').replaceAll(' ', '_')}';

      final logDoc = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .collection('medicationLogs')
          .doc(logId)
          .get();

      if (logDoc.exists) {
        final data = logDoc.data()!;
        final status = data['status'] as String?;

        // Only return taken: true if status is actually "taken" or "taken_late"
        final isTaken = status == 'taken' || status == 'taken_late';

        return {
          'taken': isTaken,  // CHANGED: Only true if actually taken, not if just "missed"
          'takenAt': data['takenAt'],
          'takenLate': data['takenLate'] ?? false,
        };
      }

      return {
        'taken': false,
        'takenAt': null,
        'takenLate': false,
      };
    } catch (e) {
      print("❌ Error checking if dose taken: $e");
      return {
        'taken': false,
        'takenAt': null,
        'takenLate': false,
      };
    }
  }

  /// Schedule a check for missed medication (after late window)
  Future<void> scheduleMissedMedicationCheck({
    required String patientGroupID,
    required String tabletId,
    required String medicationName,
    required String scheduledTime,
    required int lateWindowMinutes,
    Map<String, dynamic>? caregiverSettings,
  }) async {
    // This will be called when app starts to check if any doses were missed

    final scheduledDateTime = _parseScheduledTime(scheduledTime);
    if (scheduledDateTime == null) return;

    final lateWindowExpiry = scheduledDateTime.add(Duration(minutes: lateWindowMinutes));
    final now = DateTime.now();

    // If late window has expired and dose not taken
    if (now.isAfter(lateWindowExpiry)) {
      final taken = await _isDoseTakenToday(
        patientGroupID: patientGroupID,
        tabletId: tabletId,
        scheduledTime: scheduledTime,
      );

      if (!taken['taken']) {
        print("❌ MISSED: $medicationName at $scheduledTime");

        // Mark as missed in logs
        final logId = '${tabletId}_${_getTodayDateString()}_${scheduledTime.replaceAll(':', '-').replaceAll(' ', '_')}';
        await _firestore
            .collection('patientGroups')
            .doc(patientGroupID)
            .collection('medicationLogs')
            .doc(logId)
            .set({
          'tabletId': tabletId,
          'medicationName': medicationName,
          'scheduledTime': scheduledTime,
          'date': _getTodayDateString(),
          'status': 'missed',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Send caregiver notifications if enabled
        if (caregiverSettings?['notifyCaregivers'] == true) {
          // Get patient name
          final patientName = await _getPatientName(patientGroupID);

          // Send notification
          final CaregiverNotificationService notificationService = CaregiverNotificationService();
          await notificationService.notifyCaregiversMedicationMissed(
            patientGroupID: patientGroupID,
            patientName: patientName,
            medicationName: medicationName,
            scheduledTime: scheduledTime,
          );
        }
      }
    }
  }

  // ========================
  // HELPER METHODS
  // ========================

  /// Get day abbreviation (Mo, Tu, We, etc.)
  String _getDayAbbreviation(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mo';
      case DateTime.tuesday:
        return 'Tu';
      case DateTime.wednesday:
        return 'We';
      case DateTime.thursday:
        return 'Th';
      case DateTime.friday:
        return 'Fr';
      case DateTime.saturday:
        return 'Sa';
      case DateTime.sunday:
        return 'Su';
      default:
        return '';
    }
  }

  /// Parse time string "9:00 AM" to DateTime for today
  DateTime? _parseScheduledTime(String timeStr) {
    try {
      final now = DateTime.now();
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final isPM = parts[1] == 'PM';

      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;

      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      print("❌ Error parsing time: $timeStr - $e");
      return null;
    }
  }

  /// Check if dose should be shown now (current time >= scheduled time)
  bool _shouldShowDose(DateTime scheduledTime, DateTime now) {
    return now.isAfter(scheduledTime) || now.isAtSameMomentAs(scheduledTime);
  }

  /// Get today's date as string (YYYY-MM-DD)
  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Convert late window string to minutes
  int? _getLateWindowMinutes(String? lateWindow) {
    if (lateWindow == null) return null;

    final minutes = int.tryParse(lateWindow.replaceAll(' Min', ''));
    return minutes;
  }
}