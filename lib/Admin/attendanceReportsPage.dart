import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AttendanceReportsPage extends StatefulWidget {
  const AttendanceReportsPage({super.key});

  @override
  State<AttendanceReportsPage> createState() => _AttendanceReportsPageState();
}

class _AttendanceReportsPageState extends State<AttendanceReportsPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isExporting = false;
  int? _collegeCode;

  // Data lists
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _logs = [];
  List<String> _semesters = [];

  // Filter States
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';

  String _canonicalizeSemester(String sem) {
    final clean = sem.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (clean.contains('viii') || clean.endsWith('8th') || clean.endsWith('8') || clean == 'eighth') return '8';
    if (clean.contains('vii') || clean.endsWith('7th') || clean.endsWith('7') || clean == 'seventh') return '7';
    if (clean.contains('vi') || clean.endsWith('6th') || clean.endsWith('6') || clean == 'sixth') return '6';
    if (clean.contains('iv') || clean.endsWith('4th') || clean.endsWith('4') || clean == 'fourth') return '4';
    if (clean.contains('v') || clean.endsWith('5th') || clean.endsWith('5') || clean == 'fifth') return '5';
    if (clean.contains('iii') || clean.endsWith('3rd') || clean.endsWith('3') || clean == 'third') return '3';
    if (clean.contains('ii') || clean.endsWith('2nd') || clean.endsWith('2') || clean == 'second') return '2';
    if (clean.contains('i') || clean.endsWith('1st') || clean.endsWith('1') || clean == 'first') return '1';
    return clean;
  }

  String? _findMatchingSemester(String target, List<String> options) {
    if (target.isEmpty) return null;
    final targetLower = target.trim().toLowerCase();
    for (var opt in options) {
      if (opt.trim().toLowerCase() == targetLower) {
        return opt;
      }
    }
    final targetCanonical = _canonicalizeSemester(target);
    for (var opt in options) {
      if (_canonicalizeSemester(opt) == targetCanonical) {
        return opt;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // 1. Get college code
        final profile = await supabase
            .from('profiles')
            .select('secret_code, college_code')
            .eq('id', user.id)
            .maybeSingle();

        int? code;
        if (profile != null) {
          final rawCode = profile['secret_code'] ?? profile['college_code'];
          if (rawCode != null) {
            code = int.tryParse(rawCode.toString());
          }
        }

        if (code == null) {
          final rawCode = user.userMetadata?['secret_code'] ?? user.userMetadata?['college_code'];
          if (rawCode != null) {
            code = int.tryParse(rawCode.toString());
          }
        }

        if (code != null) {
          _collegeCode = code;

          // Fetch Semester Options
          final optionsData = await supabase
              .from('college_options')
              .select('value')
              .eq('college_code', code)
              .eq('category', 'semester');

          final List<String> loadedSems = List<Map<String, dynamic>>.from(optionsData)
              .map((e) => e['value']?.toString().trim() ?? '')
              .where((v) => v.isNotEmpty)
              .toSet()
              .toList();

          if (loadedSems.isEmpty) {
            loadedSems.addAll(['Semester I', 'Semester II', 'Semester III', 'Semester IV']);
          }
          _semesters = loadedSems;

          // 2. Fetch Student Profiles
          final studentsData = await supabase
              .from('profiles')
              .select()
              .eq('role', 'Student');

          final List<Map<String, dynamic>> allProfiles = List<Map<String, dynamic>>.from(studentsData);
          _students = allProfiles.where((p) {
            final pCode = p['college_code'] ?? p['secret_code'];
            return pCode?.toString() == code.toString();
          }).toList();

          // Sort students by name
          _students.sort((a, b) => (a['display_name']?.toString() ?? '')
              .toLowerCase()
              .compareTo((b['display_name']?.toString() ?? '').toLowerCase()));

          // 3. Fetch Attendance Logs
          final logsData = await supabase
              .from('attendance_logs')
              .select('*, profiles(id, display_name, college_code, class, batch, semester)')
              .order('check_in_time', ascending: false);

          final List<Map<String, dynamic>> allLogs = List<Map<String, dynamic>>.from(logsData);
          _logs = allLogs.where((log) {
            if (log['profiles'] == null) return false;
            final lCode = log['profiles']['college_code'];
            return lCode?.toString() == code.toString();
          }).toList();
        }
      }
    } catch (e) {
      debugPrint("Error loading reports initial data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatHours(double hours) {
    final int h = hours.toInt();
    final int m = ((hours - h) * 60).round();
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
  }

  // Compute student stats based on date range bounds
  List<Map<String, dynamic>> _computeReportsData() {
    final List<Map<String, dynamic>> reportRows = [];
    final now = DateTime.now();
    final lastWeekLimit = now.subtract(const Duration(days: 7));
    final lastMonthLimit = now.subtract(const Duration(days: 30));

    // Filter students by search query
    final filteredStudents = _students.where((student) {
      final name = (student['display_name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    for (var student in filteredStudents) {
      final sId = student['id']?.toString();
      if (sId == null) continue;

      // Get student specific logs
      var sLogs = _logs.where((l) => l['user_id']?.toString() == sId).toList();

      // Apply date range filters if they are set
      if (_startDate != null) {
        final startMidnight = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        sLogs = sLogs.where((l) {
          final checkInStr = l['check_in_time']?.toString();
          if (checkInStr == null) return false;
          return DateTime.parse(checkInStr).toLocal().isAfter(startMidnight) ||
                 DateTime.parse(checkInStr).toLocal().isAtSameMomentAs(startMidnight);
        }).toList();
      }
      if (_endDate != null) {
        final endMidnight = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        sLogs = sLogs.where((l) {
          final checkInStr = l['check_in_time']?.toString();
          if (checkInStr == null) return false;
          return DateTime.parse(checkInStr).toLocal().isBefore(endMidnight) ||
                 DateTime.parse(checkInStr).toLocal().isAtSameMomentAs(endMidnight);
        }).toList();
      }

      int fwDaysCompleted = 0;
      int fwDaysAbsent = 0;
      final Map<String, double> semHours = {
        for (var sem in _semesters) sem: 0.0
      };
      double lastWeekHours = 0.0;
      double lastMonthHours = 0.0;
      double todayHours = 0.0;
      int additionalFw = 0;
      int compensatoryFw = 0;
      int confAttended = 0;
      int confAbsent = 0;
      int reportsTotal = 0;
      int reportsLate = 0;
      int reportsOnTime = 0;

      for (var log in sLogs) {
        final activityType = log['activity_type']?.toString() ?? '';
        final status = log['status']?.toString() ?? '';
        final checkInStr = log['check_in_time']?.toString();
        final checkOutStr = log['check_out_time']?.toString();
        final fwType = log['field_work_type']?.toString() ?? 'Standard';

        final DateTime? checkIn = checkInStr != null ? DateTime.parse(checkInStr).toLocal() : null;
        final DateTime? checkOut = checkOutStr != null ? DateTime.parse(checkOutStr).toLocal() : null;

        double duration = 0.0;
        if (log['hours_logged'] != null) {
          duration = (log['hours_logged'] as num).toDouble();
        } else if (checkIn != null && checkOut != null) {
          duration = checkOut.difference(checkIn).inMinutes / 60.0;
        }

        if (activityType == 'Field Work') {
          if (status == 'Absent') {
            fwDaysAbsent++;
          } else if (checkOut != null) {
            fwDaysCompleted++;

            // Semester classification
            final semValue = (log['semester'] ?? student['semester'] ?? '').toString();
            final matchedSem = _findMatchingSemester(semValue, _semesters);
            if (matchedSem != null) {
              semHours[matchedSem] = (semHours[matchedSem] ?? 0.0) + duration;
            }

            // Timeframes
            if (checkIn != null) {
              if (checkIn.isAfter(lastWeekLimit)) {
                lastWeekHours += duration;
              }
              if (checkIn.isAfter(lastMonthLimit)) {
                lastMonthHours += duration;
              }
              if (checkIn.year == now.year && checkIn.month == now.month && checkIn.day == now.day) {
                todayHours += duration;
              }
            }

            // Additional vs Compensatory
            if (fwType == 'Additional') {
              additionalFw++;
            } else if (fwType == 'Compensatory') {
              compensatoryFw++;
            }
          }
        } else if (activityType == 'Conference') {
          if (status == 'Present' || status == 'Attended') {
            confAttended++;
          } else if (status == 'Absent') {
            confAbsent++;
          }
        } else if (activityType == 'Report') {
          reportsTotal++;
          if (status == 'Late') {
            reportsLate++;
          } else if (status == 'On Time') {
            reportsOnTime++;
          }
        }
      }

      final Map<String, dynamic> rowMap = {
        'display_name': student['display_name'] ?? 'Student',
        'fw_days': fwDaysCompleted,
        'fw_absent': fwDaysAbsent,
        'last_week_hours': double.parse(lastWeekHours.toStringAsFixed(2)),
        'last_month_hours': double.parse(lastMonthHours.toStringAsFixed(2)),
        'today_hours': double.parse(todayHours.toStringAsFixed(2)),
        'additional_fw': additionalFw,
        'compensatory_fw': compensatoryFw,
        'conf_attended': confAttended,
        'conf_absent': confAbsent,
        'reports_total': reportsTotal,
        'reports_late': reportsLate,
        'reports_on_time': reportsOnTime,
      };

      for (var sem in _semesters) {
        final hours = semHours[sem] ?? 0.0;
        rowMap['sem_hours_$sem'] = double.parse(hours.toStringAsFixed(2));
      }

      reportRows.add(rowMap);
    }

    return reportRows;
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _exportReportCSV() async {
    final reportData = _computeReportsData();
    if (reportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No records to export."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final List<String> csvLines = [];
      
      // Add CSV Headers dynamically
      final List<String> headers = [
        'Student Name',
        'FW Days Completed',
        'FW Days Absent',
      ];
      for (var sem in _semesters) {
        headers.add('$sem Hours');
      }
      headers.addAll([
        'Last Week Hours',
        'Last Month Hours',
        'Today Hours',
        'Additional FW',
        'Compensatory FW',
        'Conferences Attended',
        'Conferences Absent',
        'Reports Total',
        'Reports Late',
        'Reports On Time',
      ]);
      csvLines.add(headers.map((h) => '"$h"').join(','));

      // Add Data rows dynamically
      for (var row in reportData) {
        final List<String> cells = [
          '"${row['display_name']}"',
          '${row['fw_days']}',
          '${row['fw_absent']}',
        ];
        for (var sem in _semesters) {
          cells.add('${row['sem_hours_$sem'] ?? 0.0}');
        }
        cells.addAll([
          '${row['last_week_hours']}',
          '${row['last_month_hours']}',
          '${row['today_hours']}',
          '${row['additional_fw']}',
          '${row['compensatory_fw']}',
          '${row['conf_attended']}',
          '${row['conf_absent']}',
          '${row['reports_total']}',
          '${row['reports_late']}',
          '${row['reports_on_time']}',
        ]);
        csvLines.add(cells.join(','));
      }

      final csvContent = csvLines.join('\n');
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${tempDir.path}/Attendance_Report_$timestamp.csv');
      await file.writeAsString(csvContent);

      if (!mounted) return;

      final box = context.findRenderObject() as RenderBox?;
      try {
        await SharePlus.instance.share(
          ShareParams(
            text: 'Social Work Field Work Attendance Aggregates Report',
            files: [XFile(file.path)],
            sharePositionOrigin: box != null ? (box.localToGlobal(Offset.zero) & box.size) : null,
          ),
        );
      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                "Exported Successfully",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              content: Text(
                "The CSV report was generated and saved to:\n\n${file.path}\n\nNote: If you are running the app without rebuilding since adding share plugins, please rebuild the app to share files directly.",
                style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("OK", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error exporting report: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to export: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    if (_collegeCode == null) {
      return Scaffold(
        body: Center(
          child: Text(
            "Dashboard error: Profile college code missing",
            style: GoogleFonts.inter(),
          ),
        ),
      );
    }

    final reportRows = _computeReportsData();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Performance Reports",
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _isExporting ? null : _exportReportCSV,
                        icon: _isExporting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.share_rounded, color: Colors.black),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _loadInitialData,
                        icon: const Icon(Icons.refresh_rounded, color: Colors.black),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // --- FILTERS CARD ---
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey[200]!, width: 1.5),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Search Box
                          Expanded(
                            flex: 5,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: "Search student...",
                                hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                                prefixIcon: const Icon(Icons.search, size: 16),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey[200]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Colors.black),
                                ),
                              ),
                              style: GoogleFonts.inter(fontSize: 13),
                              onChanged: (val) => setState(() => _searchQuery = val),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Date range picker trigger button
                          Expanded(
                            flex: 4,
                            child: InkWell(
                              onTap: () => _selectDateRange(context),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Icon(Icons.calendar_month_rounded, color: Colors.grey[600], size: 14),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _startDate == null || _endDate == null
                                            ? "Date Filter"
                                            : "${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}",
                                        style: GoogleFonts.inter(
                                            fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_startDate != null)
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _startDate = null;
                                            _endDate = null;
                                          });
                                        },
                                        child: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- TABULAR DISPLAY ---
            Expanded(
              child: Card(
                elevation: 0,
                margin: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey[200]!, width: 1.5),
                ),
                color: Colors.white,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: reportRows.isEmpty
                      ? Center(
                          child: Text(
                            "No student records matching filters.",
                            style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13),
                          ),
                        )
                      : Scrollbar(
                          thickness: 6,
                          radius: const Radius.circular(3),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            physics: const BouncingScrollPhysics(),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFF1E293B)),
                                headingRowHeight: 48,
                                dataRowMinHeight: 42,
                                dataRowMaxHeight: 42,
                                horizontalMargin: 16,
                                columnSpacing: 20,
                                columns: [
                                  DataColumn(label: Text('Student Name', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('FW Days', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('FW Absent', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                                  ..._semesters.map((sem) => DataColumn(
                                    label: Text('$sem Hrs', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                  )),
                                  DataColumn(label: Text('Last Week Hrs', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('Last Month Hrs', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('Today Hrs', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('Add. FW', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('Comp. FW', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('Conf. Attended', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('Conf. Absent', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('Reports Total', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('Reports Late', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('Reports On Time', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                                ],
                                rows: List<DataRow>.generate(reportRows.length, (index) {
                                  final row = reportRows[index];
                                  final bool isEven = index % 2 == 0;
                                  return DataRow(
                                    color: WidgetStateProperty.all(isEven ? Colors.white : Colors.grey[50]),
                                    cells: [
                                      DataCell(Text(row['display_name'], style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87))),
                                      DataCell(Center(child: Text(row['fw_days'].toString(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)))),
                                      DataCell(Center(child: Text(row['fw_absent'].toString(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: row['fw_absent'] > 0 ? Colors.red[700] : Colors.black87)))),
                                      ..._semesters.map((sem) {
                                        final double val = row['sem_hours_$sem'] ?? 0.0;
                                        return DataCell(Center(child: Text(_formatHours(val), style: GoogleFonts.inter(fontSize: 12, color: Colors.blue[800]))));
                                      }),
                                      DataCell(Center(child: Text(_formatHours(row['last_week_hours']), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal[800])))),
                                      DataCell(Center(child: Text(_formatHours(row['last_month_hours']), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal[800])))),
                                      DataCell(Center(child: Text(_formatHours(row['today_hours']), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[800])))),
                                      DataCell(Center(child: Text(row['additional_fw'].toString(), style: GoogleFonts.inter(fontSize: 12, color: row['additional_fw'] > 0 ? Colors.purple[800] : Colors.black87)))),
                                      DataCell(Center(child: Text(row['compensatory_fw'].toString(), style: GoogleFonts.inter(fontSize: 12, color: row['compensatory_fw'] > 0 ? Colors.purple[800] : Colors.black87)))),
                                      DataCell(Center(child: Text(row['conf_attended'].toString(), style: GoogleFonts.inter(fontSize: 12, color: Colors.green[700])))),
                                      DataCell(Center(child: Text(row['conf_absent'].toString(), style: GoogleFonts.inter(fontSize: 12, color: row['conf_absent'] > 0 ? Colors.red[700] : Colors.black54)))),
                                      DataCell(Center(child: Text(row['reports_total'].toString(), style: GoogleFonts.inter(fontSize: 12)))),
                                      DataCell(Center(child: Text(row['reports_late'].toString(), style: GoogleFonts.inter(fontSize: 12, color: row['reports_late'] > 0 ? Colors.orange[800] : Colors.black54)))),
                                      DataCell(Center(child: Text(row['reports_on_time'].toString(), style: GoogleFonts.inter(fontSize: 12, color: Colors.green[700])))),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
