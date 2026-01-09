import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get status for multiple days in a month
  /// Can filter by specific tabletId or show aggregated status for all medications
  Future<Map<String, String>> getMonthStatus({
    required String patientGroupID,
    required DateTime month,
    String? tabletId, // NEW: Optional filter for specific medication
  }) async {
    try {
      final lastDay = DateTime(month.year, month.month + 1, 0);
      final today = DateTime.now();
      final todayDateOnly = DateTime(today.year, today.month, today.day);

      final Map<String, String> statusMap = {};

      // Get all logs for the month
      for (int day = 1; day <= lastDay.day; day++) {
        final date = DateTime(month.year, month.month, day);
        final dateStr = _formatDate(date);

        // IMPORTANT: Only process days BEFORE today
        if (date.isAfter(todayDateOnly) || date.isAtSameMomentAs(todayDateOnly)) {
          continue; // Skip today and future days
        }

        // Build query with optional tabletId filter
        Query query = _firestore
            .collection('patientGroups')
            .doc(patientGroupID)
            .collection('medicationLogs')
            .where('date', isEqualTo: dateStr);

        // Add tablet filter if specified
        if (tabletId != null) {
          query = query.where('tabletId', isEqualTo: tabletId);
        }

        final logsSnapshot = await query.get();

        if (logsSnapshot.docs.isEmpty) continue;

        bool hasAnyMissed = false;
        bool hasAnyLate = false;
        bool hasAnyTaken = false;

        for (var doc in logsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String?;

          if (status == 'missed') {
            hasAnyMissed = true;
          } else if (status == 'taken_late') {
            hasAnyLate = true;
            hasAnyTaken = true;
          } else if (status == 'taken' || status == 'taken_on_time') {
            hasAnyTaken = true;
          }
        }

        // Determine status (priority: missed > late > complete)
        if (hasAnyMissed) {
          statusMap[dateStr] = 'missed';      // 🔴 RED
        } else if (hasAnyLate) {
          statusMap[dateStr] = 'late';        // 🟡 YELLOW
        } else if (hasAnyTaken) {
          statusMap[dateStr] = 'complete';    // 🟢 GREEN
        }
      }

      return statusMap;
    } catch (e) {
      print('❌ Error getting month status: $e');
      return {};
    }
  }

  /// Get list of all medications for dropdown
  Future<List<Map<String, String>>> getMedicationList({
    required String patientGroupID,
  }) async {
    try {
      final tabletsSnapshot = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .collection('tablets')
          .orderBy('createdAt', descending: false)
          .get();

      List<Map<String, String>> medications = [];

      for (var doc in tabletsSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('medication')) {
          final medication = data['medication'] as Map<String, dynamic>;
          medications.add({
            'id': doc.id,
            'name': medication['name'] ?? 'Unknown',
            'strength': medication['strength'] ?? '',
          });
        }
      }

      return medications;
    } catch (e) {
      print('❌ Error getting medication list: $e');
      return [];
    }
  }

  String _formatDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}