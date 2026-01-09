import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';



class PDFExportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Main export function - generates and shares PDF for 7 months
  Future<void> exportCalendarPDF({
    required String patientGroupID,
    String? selectedMedicationId,
    String? medicationName,
  }) async {
    try {
      print('📄 Starting 7-month PDF generation...');

      // Calculate 7 month range: 3 past + current + 3 future
      final now = DateTime.now();
      final List<DateTime> months = [];
      for (int i = -3; i <= 3; i++) {
        months.add(DateTime(now.year, now.month + i, 1));
      }

      print('📅 Exporting months: ${months.first.month}/${months.first.year} to ${months.last.month}/${months.last.year}');

      // Fetch data for all 7 months
      final exportData = await _fetchMultiMonthData(
        patientGroupID: patientGroupID,
        months: months,
        selectedMedicationId: selectedMedicationId,
      );

      // Generate PDF
      final pdf = await _generateMultiMonthPDF(
        exportData: exportData,
        months: months,
        medicationName: medicationName,
        isAllMedications: selectedMedicationId == null,
      );

      // Save and share
      await _saveAndSharePDF(pdf, months, medicationName);

      print('✅ 7-month PDF generated and shared successfully');
    } catch (e) {
      print('❌ Error exporting PDF: $e');
      rethrow;
    }
  }

  /// Fetch data for multiple months
  Future<Map<String, dynamic>> _fetchMultiMonthData({
    required String patientGroupID,
    required List<DateTime> months,
    String? selectedMedicationId,
  }) async {
    final firstMonth = months.first;
    final lastMonth = months.last;
    final firstDay = DateTime(firstMonth.year, firstMonth.month, 1);
    final lastDay = DateTime(lastMonth.year, lastMonth.month + 1, 0);

    print('📊 Fetching logs from ${_formatDate(firstDay)} to ${_formatDate(lastDay)}');

    // Fetch ALL medication logs for the entire date range
    final logsQuery = _firestore
        .collection('patientGroups')
        .doc(patientGroupID)
        .collection('medicationLogs')
        .where('date', isGreaterThanOrEqualTo: _formatDate(firstDay))
        .where('date', isLessThanOrEqualTo: _formatDate(lastDay));

    final logsSnapshot = await logsQuery.get();

    print('📦 Retrieved ${logsSnapshot.docs.length} total logs');

    // Fetch medication details
    List<Map<String, dynamic>> medications = [];
    if (selectedMedicationId != null) {
      // Single medication
      final tabletDoc = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .collection('tablets')
          .doc(selectedMedicationId)
          .get();

      if (tabletDoc.exists) {
        medications.add({
          'id': tabletDoc.id,
          'data': tabletDoc.data(),
        });
      }
    } else {
      // All medications
      final tabletsSnapshot = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .collection('tablets')
          .get();

      medications = tabletsSnapshot.docs
          .map((doc) => {'id': doc.id, 'data': doc.data()})
          .toList();
    }

    print('💊 Processing ${medications.length} medication(s)');

    // Process data per medication
    Map<String, Map<String, dynamic>> perMedicationData = {};

    for (var medication in medications) {
      final medId = medication['id'] as String;
      final medData = medication['data'] as Map<String, dynamic>;

      // Filter logs for this medication
      final medLogs = logsSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['tabletId'] == medId;
      }).toList();

      // Build daily status map for this medication
      Map<String, Map<String, dynamic>> dailyStatus = {};
      int totalDoses = 0;
      int takenOnTime = 0;
      int takenLate = 0;
      int missed = 0;

      for (var doc in medLogs) {
        final data = doc.data();
        final date = data['date'] as String;

        if (!dailyStatus.containsKey(date)) {
          dailyStatus[date] = {
            'complete': 0,
            'late': 0,
            'missed': 0,
            'total': 0,
          };
        }

        dailyStatus[date]!['total'] = (dailyStatus[date]!['total'] as int) + 1;
        totalDoses++;

        final status = data['status'] as String?;
        if (status == 'taken' || status == 'taken_on_time') {
          dailyStatus[date]!['complete'] = (dailyStatus[date]!['complete'] as int) + 1;
          takenOnTime++;
        } else if (status == 'taken_late') {
          dailyStatus[date]!['late'] = (dailyStatus[date]!['late'] as int) + 1;
          takenLate++;
        } else if (status == 'missed') {
          dailyStatus[date]!['missed'] = (dailyStatus[date]!['missed'] as int) + 1;
          missed++;
        }
      }

      perMedicationData[medId] = {
        'medication': medData,
        'dailyStatus': dailyStatus,
        'statistics': {
          'totalDoses': totalDoses,
          'takenOnTime': takenOnTime,
          'takenLate': takenLate,
          'missed': missed,
        },
        'logs': medLogs.map((doc) => doc.data()).toList(),
      };

      print('  ✓ ${medData['medication']['name']}: $totalDoses doses across 7 months');
    }

    return {
      'medications': medications,
      'perMedicationData': perMedicationData,
    };
  }

  /// Generate multi-month PDF
  Future<pw.Document> _generateMultiMonthPDF({
    required Map<String, dynamic> exportData,
    required List<DateTime> months,
    String? medicationName,
    required bool isAllMedications,
  }) async {
    final pdf = pw.Document();
    final fontData = await PdfGoogleFonts.dMSerifDisplayRegular();
    final fontBold = await PdfGoogleFonts.dMSerifDisplayRegular();

    final medications = exportData['medications'] as List<Map<String, dynamic>>;
    final perMedicationData = exportData['perMedicationData'] as Map<String, Map<String, dynamic>>;

    // Generate report title
    String reportTitle = medicationName ?? 'All Medications';

    if (isAllMedications) {
      // Generate separate section for EACH medication
      for (var medication in medications) {
        final medId = medication['id'] as String;
        final medData = medication['data'] as Map<String, dynamic>;
        final medInfo = medData['medication'] as Map<String, dynamic>;
        final scheduleInfo = medData['schedule'] as Map<String, dynamic>;
        final medicationData = perMedicationData[medId]!;

        final medName = '${medInfo['name']} ${medInfo['strength']}'.trim();

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.all(40),
            build: (context) => [
              // Header
              _buildHeader(
                months.first,
                months.last,
                medName,
                fontBold,
              ),
              pw.SizedBox(height: 20),

              // Medication Details
              _buildMedicationDetails(medInfo, scheduleInfo, fontData),
              pw.SizedBox(height: 20),

              // Statistics
              _buildStatisticsSummary(
                medicationData['statistics'] as Map<String, int>,
                fontData,
                fontBold,
              ),
              pw.SizedBox(height: 30),

              // All 7 months calendars
              _buildMultiMonthCalendars(
                months,
                medicationData['dailyStatus'] as Map<String, Map<String, dynamic>>,
                fontBold,
              ),
              pw.SizedBox(height: 20),

              // Legend
              _buildLegend(fontData),
              pw.SizedBox(height: 20),

              // Daily breakdown
              _buildDailyBreakdown(
                medicationData['logs'] as List,
                months,
                fontData,
              ),

              pw.SizedBox(height: 20),
              _buildFooter(fontData),
            ],
          ),
        );
      }
    } else {
      // Single medication report
      final medId = medications.first['id'] as String;
      final medData = medications.first['data'] as Map<String, dynamic>;
      final medInfo = medData['medication'] as Map<String, dynamic>;
      final scheduleInfo = medData['schedule'] as Map<String, dynamic>;
      final medicationData = perMedicationData[medId]!;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(40),
          build: (context) => [
            // Header
            _buildHeader(
              months.first,
              months.last,
              reportTitle,
              fontBold,
            ),
            pw.SizedBox(height: 20),

            // Medication Details
            _buildMedicationDetails(medInfo, scheduleInfo, fontData),
            pw.SizedBox(height: 20),

            // Statistics
            _buildStatisticsSummary(
              medicationData['statistics'] as Map<String, int>,
              fontData,
              fontBold,
            ),
            pw.SizedBox(height: 30),

            // All 7 months calendars
            _buildMultiMonthCalendars(
              months,
              medicationData['dailyStatus'] as Map<String, Map<String, dynamic>>,
              fontBold,
            ),
            pw.SizedBox(height: 20),

            // Legend
            _buildLegend(fontData),
            pw.SizedBox(height: 20),

            // Daily breakdown
            _buildDailyBreakdown(
              medicationData['logs'] as List,
              months,
              fontData,
            ),

            pw.SizedBox(height: 20),
            _buildFooter(fontData),
          ],
        ),
      );
    }

    return pdf;
  }

  /// Build header with date range
  pw.Widget _buildHeader(
      DateTime startMonth,
      DateTime endMonth,
      String medicationTitle,
      pw.Font fontBold,
      ) {
    final periodStr = '${DateFormat('MMMM yyyy').format(startMonth)} - ${DateFormat('MMMM yyyy').format(endMonth)}';

    return pw.Container(
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'MEDICATION ADHERENCE REPORT',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 24,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Report Period: $periodStr',
            style: pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
          ),
          pw.Text(
            'Generated: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            medicationTitle,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 18,
              color: PdfColors.blue800,
            ),
          ),
        ],
      ),
    );
  }

  /// Medication details
  pw.Widget _buildMedicationDetails(
      Map<String, dynamic> medData,
      Map<String, dynamic> scheduleData,
      pw.Font font,
      ) {
    final times = (scheduleData['times'] as List).join(', ');
    final days = (scheduleData['daysOfWeek'] as List).join(', ');

    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Medication Details',
            style: pw.TextStyle(font: font, fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Name: ${medData['name']}', style: pw.TextStyle(fontSize: 12)),
          pw.Text('Strength: ${medData['strength']}', style: pw.TextStyle(fontSize: 12)),
          pw.Text('Frequency: ${medData['frequency']}', style: pw.TextStyle(fontSize: 12)),
          pw.Text('Schedule: $times', style: pw.TextStyle(fontSize: 12)),
          pw.Text('Days: $days', style: pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  /// Statistics summary
  pw.Widget _buildStatisticsSummary(
      Map<String, int> stats,
      pw.Font font,
      pw.Font fontBold,
      ) {
    final totalDoses = stats['totalDoses']!;
    final takenOnTime = stats['takenOnTime']!;
    final takenLate = stats['takenLate']!;
    final missed = stats['missed']!;

    final onTimePercent = totalDoses > 0 ? (takenOnTime / totalDoses * 100).toInt() : 0;
    final latePercent = totalDoses > 0 ? (takenLate / totalDoses * 100).toInt() : 0;
    final missedPercent = totalDoses > 0 ? (missed / totalDoses * 100).toInt() : 0;

    return pw.Container(
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ADHERENCE SUMMARY (7 Months)',
            style: pw.TextStyle(font: fontBold, fontSize: 16),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildStatBox('Total Doses', '$totalDoses', PdfColors.grey800, font),
              _buildStatBox('On Time', '$takenOnTime ($onTimePercent%)', PdfColors.green, font),
              _buildStatBox('Late', '$takenLate ($latePercent%)', PdfColors.orange, font),
              _buildStatBox('Missed', '$missed ($missedPercent%)', PdfColors.red, font),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStatBox(String label, String value, PdfColor color, pw.Font font) {
    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color, width: 2),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  /// Build all 7 month calendars in a grid layout
  pw.Widget _buildMultiMonthCalendars(
      List<DateTime> months,
      Map<String, Map<String, dynamic>> dailyStatus,
      pw.Font fontBold,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '7-MONTH CALENDAR VIEW',
          style: pw.TextStyle(font: fontBold, fontSize: 16),
        ),
        pw.SizedBox(height: 16),

        // Create grid: 2 columns x 4 rows (7 months + 1 empty space)
        ...List.generate(4, (rowIndex) {
          return pw.Padding(
            padding: pw.EdgeInsets.only(bottom: 16),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: List.generate(2, (colIndex) {
                final monthIndex = rowIndex * 2 + colIndex;
                if (monthIndex >= months.length) {
                  return pw.Expanded(child: pw.Container());
                }

                return pw.Expanded(
                  child: pw.Padding(
                    padding: pw.EdgeInsets.symmetric(horizontal: 8),
                    child: _buildSingleMonthCalendar(
                      months[monthIndex],
                      dailyStatus,
                      fontBold,
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }

  /// Build single month calendar (compact version)
  pw.Widget _buildSingleMonthCalendar(
      DateTime month,
      Map<String, Map<String, dynamic>> dailyStatus,
      pw.Font fontBold,
      ) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final firstWeekday = firstDay.weekday % 7;
    final daysInMonth = lastDay.day;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Month name
        pw.Text(
          DateFormat('MMMM yyyy').format(month),
          style: pw.TextStyle(font: fontBold, fontSize: 12),
        ),
        pw.SizedBox(height: 6),

        // Week day headers
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map((day) => pw.Container(
            width: 30,
            child: pw.Center(
              child: pw.Text(
                day,
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ))
              .toList(),
        ),
        pw.SizedBox(height: 4),

        // Calendar grid
        ...List.generate((daysInMonth + firstWeekday) ~/ 7 + 1, (weekIndex) {
          return pw.Padding(
            padding: pw.EdgeInsets.only(bottom: 2),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: List.generate(7, (dayIndex) {
                final cellIndex = weekIndex * 7 + dayIndex;
                final dayNum = cellIndex - firstWeekday + 1;

                if (dayNum < 1 || dayNum > daysInMonth) {
                  return pw.Container(width: 30, height: 30);
                }

                final date = DateTime(month.year, month.month, dayNum);
                final dateStr = _formatDate(date);
                final dayStats = dailyStatus[dateStr];

                PdfColor? bgColor;
                if (dayStats != null) {
                  final total = dayStats['total'] as int;
                  final complete = dayStats['complete'] as int;
                  final late = dayStats['late'] as int;
                  final missed = dayStats['missed'] as int;

                  if (missed > 0) {
                    bgColor = PdfColors.red300;
                  } else if (late > 0) {
                    bgColor = PdfColors.orange300;
                  } else if (complete == total) {
                    bgColor = PdfColors.green300;
                  }
                }

                return pw.Container(
                  width: 30,
                  height: 30,
                  decoration: pw.BoxDecoration(
                    color: bgColor ?? PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      '$dayNum',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: bgColor != null ? pw.FontWeight.bold : pw.FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }

  /// Legend
  pw.Widget _buildLegend(pw.Font font) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        _buildLegendItem('Taken on time', PdfColors.green300, font),
        pw.SizedBox(width: 20),
        _buildLegendItem('Taken late', PdfColors.orange300, font),
        pw.SizedBox(width: 20),
        _buildLegendItem('Missed', PdfColors.red300, font),
      ],
    );
  }

  pw.Widget _buildLegendItem(String label, PdfColor color, pw.Font font) {
    return pw.Row(
      children: [
        pw.Container(
          width: 16,
          height: 16,
          decoration: pw.BoxDecoration(
            color: color,
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text(label, style: pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  /// Daily breakdown table (limited to recent entries)
  pw.Widget _buildDailyBreakdown(List logs, List<DateTime> months, pw.Font font) {
    if (logs.isEmpty) {
      return pw.Container(
        padding: pw.EdgeInsets.all(16),
        child: pw.Center(
          child: pw.Text(
            'No medication logs available for this period',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          ),
        ),
      );
    }

    // Sort logs by date and time
    logs.sort((a, b) {
      final dateCompare = (b['date'] as String).compareTo(a['date'] as String);
      if (dateCompare != 0) return dateCompare;
      return (b['scheduledTime'] as String? ?? '').compareTo(a['scheduledTime'] as String? ?? '');
    });

    // Limit to 30 most recent entries
    final limitedLogs = logs.take(30).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'RECENT MEDICATION LOG (Last 30 entries)',
          style: pw.TextStyle(font: font, fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: pw.FlexColumnWidth(1.5),
            1: pw.FlexColumnWidth(3),
            2: pw.FlexColumnWidth(1.5),
            3: pw.FlexColumnWidth(1.5),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('Date', isHeader: true),
                _buildTableCell('Medication', isHeader: true),
                _buildTableCell('Time', isHeader: true),
                _buildTableCell('Status', isHeader: true),
              ],
            ),
            // Data rows
            ...limitedLogs.map((log) {
              final date = log['date'] as String? ?? '';
              final medName = log['medicationName'] as String? ?? 'Unknown';
              final time = log['scheduledTime'] as String? ?? '';
              final status = log['status'] as String? ?? 'unknown';

              String statusText = '';
              PdfColor statusColor = PdfColors.grey600;

              if (status == 'taken' || status == 'taken_on_time') {
                statusText = 'On time';
                statusColor = PdfColors.green;
              } else if (status == 'taken_late') {
                statusText = 'Late';
                statusColor = PdfColors.orange;
              } else if (status == 'missed') {
                statusText = 'Missed';
                statusColor = PdfColors.red;
              }

              return pw.TableRow(
                children: [
                  _buildTableCell(date),
                  _buildTableCell(medName),
                  _buildTableCell(time),
                  _buildTableCell(statusText, color: statusColor),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false, PdfColor? color}) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.grey800,
        ),
      ),
    );
  }

  /// Footer
  pw.Widget _buildFooter(pw.Font font) {
    return pw.Container(
      padding: pw.EdgeInsets.only(top: 16),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
      ),
      child: pw.Center(
        child: pw.Text(
          'Generated by Tablet Reminder App',
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      ),
    );
  }

  /// Save and share PDF
  Future<void> _saveAndSharePDF(
      pw.Document pdf,
      List<DateTime> months,
      String? medicationName,
      ) async {
    // Generate filename
    final startMonth = DateFormat('yyyy-MM').format(months.first);
    final endMonth = DateFormat('yyyy-MM').format(months.last);
    final medStr = medicationName?.replaceAll(' ', '_') ?? 'All_Medications';
    final filename = 'Adherence_Report_${medStr}_${startMonth}_to_$endMonth.pdf';

    // Save to temporary directory
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/$filename');
    await file.writeAsBytes(await pdf.save());

    print('✅ PDF saved to: ${file.path}');

    // Share using native share sheet
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Medication Adherence Report (7 Months)',
      text: 'Medication adherence report for ${medicationName ?? 'all medications'} - $startMonth to $endMonth',
    );
  }

  /// Helper: Format date to YYYY-MM-DD
  String _formatDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}