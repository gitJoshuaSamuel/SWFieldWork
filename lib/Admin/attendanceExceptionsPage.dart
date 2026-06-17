import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AttendanceExceptionsPage extends StatefulWidget {
  const AttendanceExceptionsPage({super.key});

  @override
  State<AttendanceExceptionsPage> createState() =>
      _AttendanceExceptionsPageState();
}

class _AttendanceExceptionsPageState extends State<AttendanceExceptionsPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  int? _collegeCode;

  // Data lists
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _logs = [];
  List<String> _semesters = [];
  String? _selectedSemester;
  List<String> _batches = [];
  String? _selectedBatch;

  // Configuration thresholds
  double _weeklyQuota = 24.0;
  double _monthlyQuota = 96.0;

  // Dates definition
  late DateTime _firstDayOfLastMonth;
  late DateTime _lastDayOfLastMonth;
  late DateTime _startOfLastWeek;
  late DateTime _endOfLastWeek;

  @override
  void initState() {
    super.initState();
    _calculateDateRanges();
    _loadData();
  }

  void _calculateDateRanges() {
    final now = DateTime.now();

    // Last Month
    final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);
    _lastDayOfLastMonth = firstDayOfCurrentMonth.subtract(
      const Duration(seconds: 1),
    );
    _firstDayOfLastMonth = DateTime(
      _lastDayOfLastMonth.year,
      _lastDayOfLastMonth.month,
      1,
    );

    // Last Week (Monday to Sunday of previous week)
    final startOfCurrentWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    _startOfLastWeek = DateTime(
      startOfCurrentWeek.year,
      startOfCurrentWeek.month,
      startOfCurrentWeek.day,
    ).subtract(const Duration(days: 7));
    _endOfLastWeek = DateTime(
      startOfCurrentWeek.year,
      startOfCurrentWeek.month,
      startOfCurrentWeek.day,
      23,
      59,
      59,
    ).subtract(const Duration(days: 1));
  }

  Future<void> _loadData() async {
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
          final rawCode =
              user.userMetadata?['secret_code'] ??
              user.userMetadata?['college_code'];
          if (rawCode != null) {
            code = int.tryParse(rawCode.toString());
          }
        }

        if (code != null) {
          _collegeCode = code;

          // 2. Fetch Semester & Batch Options
          final optionsData = await supabase
              .from('college_options')
              .select('category, value')
              .eq('college_code', code)
              .inFilter('category', ['semester', 'batch']);

          final List<String> loadedSems = [];
          final List<String> loadedBatches = [];

          for (var opt in optionsData) {
            final cat = opt['category']?.toString().toLowerCase().trim() ?? '';
            final val = opt['value']?.toString().trim() ?? '';
            if (val.isEmpty) continue;
            if (cat == 'semester') {
              loadedSems.add(val);
            } else if (cat == 'batch') {
              loadedBatches.add(val);
            }
          }

          _semesters = loadedSems.toSet().toList();
          _batches = loadedBatches.toSet().toList();

          if (_selectedSemester == null && _semesters.isNotEmpty) {
            _selectedSemester = _semesters.first;
          }
          if (_selectedBatch == null && _batches.isNotEmpty) {
            _selectedBatch = _batches.first;
          }

          // 3. Fetch Targets (Weekly FW & Monthly FW)
          final targetsData = await supabase
              .from('college_options')
              .select()
              .eq('college_code', code)
              .inFilter('category', ['Weekly FW', 'Monthly FW']);

          for (var t in targetsData) {
            if (t['category'] == 'Weekly FW') {
              _weeklyQuota =
                  double.tryParse(t['value']?.toString() ?? '') ?? 24.0;
            } else if (t['category'] == 'Monthly FW') {
              _monthlyQuota =
                  double.tryParse(t['value']?.toString() ?? '') ?? 96.0;
            }
          }

          // 4. Fetch Students
          final studentsData = await supabase
              .from('profiles')
              .select()
              .eq('role', 'Student');

          final List<Map<String, dynamic>> allProfiles =
              List<Map<String, dynamic>>.from(studentsData);
          _students = allProfiles.where((p) {
            final pCode = p['college_code'] ?? p['secret_code'];
            return pCode?.toString() == code.toString();
          }).toList();

          // 5. Fetch Attendance Logs
          final logsData = await supabase
              .from('attendance_logs')
              .select(
                '*, profiles(id, display_name, college_code, secret_code, class, batch, semester)',
              )
              .order('check_in_time', ascending: false);

          final List<Map<String, dynamic>> allLogs =
              List<Map<String, dynamic>>.from(logsData);
          _logs = allLogs.where((log) {
            if (log['profiles'] == null) return false;
            final profile = log['profiles'];
            final lCode = profile['college_code'] ?? profile['secret_code'];
            return lCode?.toString() == code.toString();
          }).toList();
        }
      }
    } catch (e) {
      debugPrint("Error loading exceptions data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _canonicalizeSemester(String sem) {
    final clean = sem.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (clean.contains('viii') ||
        clean.contains('8') ||
        clean.contains('eighth')) {
      return '8';
    }
    if (clean.contains('vii') ||
        clean.contains('7') ||
        clean.contains('seventh')) {
      return '7';
    }
    if (clean.contains('vi') ||
        clean.contains('6') ||
        clean.contains('sixth')) {
      return '6';
    }
    if (clean.contains('iv') ||
        clean.contains('4') ||
        clean.contains('fourth')) {
      return '4';
    }
    if (clean.contains('v') || clean.contains('5') || clean.contains('fifth')) {
      return '5';
    }
    if (clean.contains('iii') ||
        clean.contains('3') ||
        clean.contains('third')) {
      return '3';
    }
    if (clean.contains('ii') ||
        clean.contains('2') ||
        clean.contains('second')) {
      return '2';
    }
    if (clean.contains('i') || clean.contains('1') || clean.contains('first')) {
      return '1';
    }
    return clean;
  }

  bool _matchesSemester(
    String? logSem,
    String? studentSem,
    String selectedSem,
  ) {
    final targetSem = logSem ?? studentSem;
    if (targetSem == null) return false;
    return _canonicalizeSemester(targetSem) ==
        _canonicalizeSemester(selectedSem);
  }

  // ABSENT LIST & LOGS FETCH
  List<Map<String, dynamic>> _getAbsentStudents() {
    if (_selectedSemester == null || _selectedBatch == null) return [];

    // Filter students belonging to the selected batch & semester
    final filteredStudents = _students
        .where(
          (s) =>
              s['batch']?.toString() == _selectedBatch &&
              _matchesSemester(
                null,
                s['semester']?.toString(),
                _selectedSemester!,
              ),
        )
        .toList();
    final List<Map<String, dynamic>> result = [];

    for (var student in filteredStudents) {
      final sId = student['id']?.toString();
      if (sId == null) continue;

      // Find absent logs for Field Work in this semester
      final absentLogs = _logs
          .where(
            (l) =>
                l['user_id']?.toString() == sId &&
                l['activity_type'] == 'Field Work' &&
                l['status'] == 'Absent' &&
                _matchesSemester(
                  l['semester']?.toString(),
                  student['semester']?.toString(),
                  _selectedSemester!,
                ),
          )
          .toList();

      if (absentLogs.isNotEmpty) {
        result.add({
          'student': student,
          'logs': absentLogs,
          'count': absentLogs.length,
        });
      }
    }

    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return result;
  }

  // WEEKLY LOW HOURS LIST
  List<Map<String, dynamic>> _getWeeklyLowStudents() {
    if (_selectedSemester == null || _selectedBatch == null) return [];

    final filteredStudents = _students
        .where(
          (s) =>
              s['batch']?.toString() == _selectedBatch &&
              _matchesSemester(
                null,
                s['semester']?.toString(),
                _selectedSemester!,
              ),
        )
        .toList();
    final List<Map<String, dynamic>> result = [];

    for (var student in filteredStudents) {
      final sId = student['id']?.toString();
      if (sId == null) continue;

      // Find logs for last week
      final weekLogs = _logs.where((l) {
        if (l['user_id']?.toString() != sId) return false;
        if (l['activity_type'] != 'Field Work') return false;

        final checkInStr = l['check_in_time']?.toString();
        if (checkInStr == null) return false;

        final checkInTime = DateTime.parse(checkInStr).toLocal();
        return !checkInTime.isBefore(_startOfLastWeek) &&
            !checkInTime.isAfter(_endOfLastWeek);
      }).toList();

      double totalHours = 0.0;
      for (var log in weekLogs) {
        if (log['status'] == 'Absent' || log['status'] == 'Holiday') continue;
        if (log['hours_logged'] != null) {
          totalHours += (log['hours_logged'] as num).toDouble();
        } else if (log['check_in_time'] != null &&
            log['check_out_time'] != null) {
          final inT = DateTime.parse(log['check_in_time'].toString());
          final outT = DateTime.parse(log['check_out_time'].toString());
          totalHours += outT.difference(inT).inMinutes / 60.0;
        }
      }

      if (totalHours < _weeklyQuota) {
        result.add({
          'student': student,
          'hours': double.parse(totalHours.toStringAsFixed(2)),
          'logs': weekLogs,
        });
      }
    }

    result.sort(
      (a, b) => (a['hours'] as double).compareTo(b['hours'] as double),
    );
    return result;
  }

  // MONTHLY LOW HOURS LIST
  List<Map<String, dynamic>> _getMonthlyLowStudents() {
    if (_selectedSemester == null || _selectedBatch == null) return [];

    final filteredStudents = _students
        .where(
          (s) =>
              s['batch']?.toString() == _selectedBatch &&
              _matchesSemester(
                null,
                s['semester']?.toString(),
                _selectedSemester!,
              ),
        )
        .toList();
    final List<Map<String, dynamic>> result = [];

    for (var student in filteredStudents) {
      final sId = student['id']?.toString();
      if (sId == null) continue;

      // Find logs for last month
      final monthLogs = _logs.where((l) {
        if (l['user_id']?.toString() != sId) return false;
        if (l['activity_type'] != 'Field Work') return false;

        final checkInStr = l['check_in_time']?.toString();
        if (checkInStr == null) return false;

        final checkInTime = DateTime.parse(checkInStr).toLocal();
        return !checkInTime.isBefore(_firstDayOfLastMonth) &&
            !checkInTime.isAfter(_lastDayOfLastMonth);
      }).toList();

      double totalHours = 0.0;
      for (var log in monthLogs) {
        if (log['status'] == 'Absent' || log['status'] == 'Holiday') continue;
        if (log['hours_logged'] != null) {
          totalHours += (log['hours_logged'] as num).toDouble();
        } else if (log['check_in_time'] != null &&
            log['check_out_time'] != null) {
          final inT = DateTime.parse(log['check_in_time'].toString());
          final outT = DateTime.parse(log['check_out_time'].toString());
          totalHours += outT.difference(inT).inMinutes / 60.0;
        }
      }

      if (totalHours < _monthlyQuota) {
        result.add({
          'student': student,
          'hours': double.parse(totalHours.toStringAsFixed(2)),
          'logs': monthLogs,
        });
      }
    }

    result.sort(
      (a, b) => (a['hours'] as double).compareTo(b['hours'] as double),
    );
    return result;
  }

  List<Map<String, dynamic>> _getLateReportsStudents() {
    if (_selectedSemester == null || _selectedBatch == null) return [];

    final filteredStudents = _students
        .where(
          (s) =>
              s['batch']?.toString() == _selectedBatch &&
              _matchesSemester(
                null,
                s['semester']?.toString(),
                _selectedSemester!,
              ),
        )
        .toList();
    final List<Map<String, dynamic>> result = [];

    for (var student in filteredStudents) {
      final sId = student['id']?.toString();
      if (sId == null) continue;

      final lateLogs = _logs
          .where(
            (l) =>
                l['user_id']?.toString() == sId &&
                l['activity_type'] == 'Report' &&
                l['status'] == 'Late' &&
                _matchesSemester(
                  l['semester']?.toString(),
                  student['semester']?.toString(),
                  _selectedSemester!,
                ),
          )
          .toList();

      if (lateLogs.isNotEmpty) {
        result.add({
          'student': student,
          'logs': lateLogs,
          'count': lateLogs.length,
        });
      }
    }

    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return result;
  }

  List<Map<String, dynamic>> _getLateReportsMonthStudents() {
    if (_selectedSemester == null || _selectedBatch == null) return [];

    final filteredStudents = _students
        .where(
          (s) =>
              s['batch']?.toString() == _selectedBatch &&
              _matchesSemester(
                null,
                s['semester']?.toString(),
                _selectedSemester!,
              ),
        )
        .toList();
    final List<Map<String, dynamic>> result = [];

    for (var student in filteredStudents) {
      final sId = student['id']?.toString();
      if (sId == null) continue;

      final lateLogs = _logs.where((l) {
        if (l['user_id']?.toString() != sId) return false;
        if (l['activity_type'] != 'Report') return false;
        if (l['status'] != 'Late') return false;
        if (!_matchesSemester(
          l['semester']?.toString(),
          student['semester']?.toString(),
          _selectedSemester!,
        )) {
          return false;
        }

        final checkInStr = l['check_in_time']?.toString();
        if (checkInStr == null) return false;

        final checkInTime = DateTime.parse(checkInStr).toLocal();
        return !checkInTime.isBefore(_firstDayOfLastMonth) &&
            !checkInTime.isAfter(_lastDayOfLastMonth);
      }).toList();

      if (lateLogs.isNotEmpty) {
        result.add({
          'student': student,
          'logs': lateLogs,
          'count': lateLogs.length,
        });
      }
    }

    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return result;
  }

  List<Map<String, dynamic>> _getConfAbsentSemesterStudents() {
    if (_selectedSemester == null || _selectedBatch == null) return [];

    final filteredStudents = _students
        .where(
          (s) =>
              s['batch']?.toString() == _selectedBatch &&
              _matchesSemester(
                null,
                s['semester']?.toString(),
                _selectedSemester!,
              ),
        )
        .toList();
    final List<Map<String, dynamic>> result = [];

    for (var student in filteredStudents) {
      final sId = student['id']?.toString();
      if (sId == null) continue;

      final absentLogs = _logs
          .where(
            (l) =>
                l['user_id']?.toString() == sId &&
                l['activity_type'] == 'Conference' &&
                l['status'] == 'Absent' &&
                _matchesSemester(
                  l['semester']?.toString(),
                  student['semester']?.toString(),
                  _selectedSemester!,
                ),
          )
          .toList();

      if (absentLogs.isNotEmpty) {
        result.add({
          'student': student,
          'logs': absentLogs,
          'count': absentLogs.length,
        });
      }
    }

    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return result;
  }

  List<Map<String, dynamic>> _getConfAbsentMonthStudents() {
    if (_selectedSemester == null || _selectedBatch == null) return [];

    final filteredStudents = _students
        .where(
          (s) =>
              s['batch']?.toString() == _selectedBatch &&
              _matchesSemester(
                null,
                s['semester']?.toString(),
                _selectedSemester!,
              ),
        )
        .toList();
    final List<Map<String, dynamic>> result = [];

    for (var student in filteredStudents) {
      final sId = student['id']?.toString();
      if (sId == null) continue;

      final absentLogs = _logs.where((l) {
        if (l['user_id']?.toString() != sId) return false;
        if (l['activity_type'] != 'Conference') return false;
        if (l['status'] != 'Absent') return false;
        if (!_matchesSemester(
          l['semester']?.toString(),
          student['semester']?.toString(),
          _selectedSemester!,
        )) {
          return false;
        }

        final checkInStr = l['check_in_time']?.toString();
        if (checkInStr == null) return false;

        final checkInTime = DateTime.parse(checkInStr).toLocal();
        return !checkInTime.isBefore(_firstDayOfLastMonth) &&
            !checkInTime.isAfter(_lastDayOfLastMonth);
      }).toList();

      if (absentLogs.isNotEmpty) {
        result.add({
          'student': student,
          'logs': absentLogs,
          'count': absentLogs.length,
        });
      }
    }

    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return result;
  }

  List<Map<String, dynamic>> _getConfAbsentWeekStudents() {
    if (_selectedSemester == null || _selectedBatch == null) return [];

    final filteredStudents = _students
        .where(
          (s) =>
              s['batch']?.toString() == _selectedBatch &&
              _matchesSemester(
                null,
                s['semester']?.toString(),
                _selectedSemester!,
              ),
        )
        .toList();
    final List<Map<String, dynamic>> result = [];

    for (var student in filteredStudents) {
      final sId = student['id']?.toString();
      if (sId == null) continue;

      final absentLogs = _logs.where((l) {
        if (l['user_id']?.toString() != sId) return false;
        if (l['activity_type'] != 'Conference') return false;
        if (l['status'] != 'Absent') return false;
        if (!_matchesSemester(
          l['semester']?.toString(),
          student['semester']?.toString(),
          _selectedSemester!,
        )) {
          return false;
        }

        final checkInStr = l['check_in_time']?.toString();
        if (checkInStr == null) return false;

        final checkInTime = DateTime.parse(checkInStr).toLocal();
        return !checkInTime.isBefore(_startOfLastWeek) &&
            !checkInTime.isAfter(_endOfLastWeek);
      }).toList();

      if (absentLogs.isNotEmpty) {
        result.add({
          'student': student,
          'logs': absentLogs,
          'count': absentLogs.length,
        });
      }
    }

    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return result;
  }

  void _showStudentLogsDetail(
    BuildContext context,
    Map<String, dynamic> studentData,
    String mode,
  ) {
    final student = studentData['student'];
    final display = student['display_name'] ?? 'Student';
    final regNo = student['registration_no'] ?? 'N/A';
    final List<dynamic> logs = studentData['logs'] ?? [];

    String titleSuffix = '';
    if (mode == 'absent') {
      titleSuffix = 'Absent Records';
    } else if (mode == 'weekly') {
      titleSuffix = 'Weekly Field Work Logs';
    } else if (mode == 'monthly') {
      titleSuffix = 'Monthly Field Work Logs';
    } else if (mode == 'late_reports' || mode == 'late_reports_month') {
      titleSuffix = 'Late Report Submissions';
    } else {
      titleSuffix = 'Conference Absences';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          display,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Reg: $regNo | $titleSuffix",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),
            Expanded(
              child: logs.isEmpty
                  ? Center(
                      child: Text(
                        "No logs recorded for this period.",
                        style: GoogleFonts.inter(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: logs.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, i) {
                        final log = logs[i];
                        final checkInStr = log['check_in_time']?.toString();
                        final DateTime? checkIn = checkInStr != null
                            ? DateTime.parse(checkInStr).toLocal()
                            : null;
                        final formattedDate = checkIn != null
                            ? DateFormat('EEEE, dd MMM yyyy').format(checkIn)
                            : 'N/A';

                        double hours = 0.0;
                        if (log['hours_logged'] != null) {
                          hours = (log['hours_logged'] as num).toDouble();
                        } else if (log['check_in_time'] != null &&
                            log['check_out_time'] != null) {
                          final inT = DateTime.parse(
                            log['check_in_time'].toString(),
                          );
                          final outT = DateTime.parse(
                            log['check_out_time'].toString(),
                          );
                          hours = outT.difference(inT).inMinutes / 60.0;
                        }

                        if (mode == 'absent' || log['status'] == 'Absent') {
                          final isConference =
                              log['activity_type'] == 'Conference';
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color:
                                    (isConference ? Colors.purple : Colors.red)
                                        .withValues(alpha: 0.15),
                                width: 1.5,
                              ),
                            ),
                            color: (isConference ? Colors.purple : Colors.red)
                                .withValues(alpha: 0.02),
                            child: ListTile(
                              leading: Icon(
                                Icons.cancel_rounded,
                                color: isConference
                                    ? Colors.purple
                                    : Colors.redAccent,
                              ),
                              title: Text(
                                formattedDate,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                "Status: Absent | ${isConference ? 'Conference Day' : 'Field Work Day'}",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          );
                        } else if (log['status'] == 'Holiday') {
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.teal.withValues(alpha: 0.15),
                                width: 1.5,
                              ),
                            ),
                            color: Colors.teal.withValues(alpha: 0.02),
                            child: ListTile(
                              leading: const Icon(
                                Icons.beach_access_rounded,
                                color: Colors.teal,
                              ),
                              title: Text(
                                formattedDate,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                "Status: Holiday | Field Work Day",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          );
                        } else if (mode == 'late_reports' ||
                            mode == 'late_reports_month' ||
                            log['status'] == 'Late') {
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.amber.withValues(alpha: 0.15),
                                width: 1.5,
                              ),
                            ),
                            color: Colors.amber.withValues(alpha: 0.02),
                            child: ListTile(
                              leading: const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.amber,
                              ),
                              title: Text(
                                formattedDate,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                "Status: Late | Report Submission",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          );
                        } else if (mode.startsWith('conf_absent')) {
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.purple.withValues(alpha: 0.15),
                                width: 1.5,
                              ),
                            ),
                            color: Colors.purple.withValues(alpha: 0.02),
                            child: ListTile(
                              leading: const Icon(
                                Icons.cancel_rounded,
                                color: Colors.purple,
                              ),
                              title: Text(
                                formattedDate,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                "Status: Absent | Conference Day",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          );
                        } else {
                          final checkInStrFormatted = checkIn != null
                              ? DateFormat('hh:mm a').format(checkIn)
                              : '--:--';
                          final checkOutStr = log['check_out_time']?.toString();
                          final DateTime? checkOut = checkOutStr != null
                              ? DateTime.parse(checkOutStr).toLocal()
                              : null;
                          final checkOutStrFormatted = checkOut != null
                              ? DateFormat('hh:mm a').format(checkOut)
                              : 'Active';

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1.5,
                              ),
                            ),
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        formattedDate,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          () {
                                            final int h = hours.toInt();
                                            final int m = ((hours - h) * 60).round();
                                            return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
                                          }(),
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.teal[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.login_rounded,
                                        size: 12,
                                        color: Colors.green[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "In: $checkInStrFormatted",
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.logout_rounded,
                                        size: 12,
                                        color: Colors.red[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Out: $checkOutStrFormatted",
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, top: 24.0, bottom: 12.0),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> colors,
    required String quotaLabel,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 22),
                Icon(
                  Icons.arrow_circle_right_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
                  size: 20,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  quotaLabel,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToStudentList({
    required String title,
    required String description,
    required List<dynamic> studentsList,
    required String activeTab,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentExceptionsListPage(
          title: title,
          description: description,
          studentsList: studentsList,
          activeTab: activeTab,
          weeklyQuota: _weeklyQuota,
          monthlyQuota: _monthlyQuota,
          showDetails: (ctx, studentData, mode) {
            _showStudentLogsDetail(
              ctx,
              Map<String, dynamic>.from(studentData as Map),
              mode,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    if (_collegeCode == null) {
      return Scaffold(
        body: Center(
          child: Text(
            "Exceptions dashboard error: Profile college code missing",
            style: GoogleFonts.inter(),
          ),
        ),
      );
    }

    // Exception Lists
    final absentStudentsList = _getAbsentStudents();
    final weeklyLowList = _getWeeklyLowStudents();
    final monthlyLowList = _getMonthlyLowStudents();
    final lateReportsList = _getLateReportsStudents();
    final lateReportsMonthList = _getLateReportsMonthStudents();
    final confAbsentSemList = _getConfAbsentSemesterStudents();
    final confAbsentMonthList = _getConfAbsentMonthStudents();
    final confAbsentWeekList = _getConfAbsentWeekStudents();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with Page Title & Semester Selector
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  // Batch Dropdown
                  Expanded(
                    child: _buildDropdownContainer(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _batches.contains(_selectedBatch) ? _selectedBatch : null,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        hint: const Text("Batch"),
                        items: _batches.map((batch) {
                          return DropdownMenuItem<String>(
                            value: batch,
                            child: Text(batch, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedBatch = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Semester Dropdown
                  Expanded(
                    child: _buildDropdownContainer(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _semesters.contains(_selectedSemester) ? _selectedSemester : null,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        hint: const Text("Semester"),
                        items: _semesters.map((sem) {
                          return DropdownMenuItem<String>(
                            value: sem,
                            child: Text(sem, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedSemester = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Grid of rectangular exception widgets
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                children: [
                  _buildSectionHeader("Field Work"),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      _buildStatCard(
                        title: "FW Absents",
                        value: absentStudentsList.length.toString(),
                        icon: Icons.cancel_schedule_send_rounded,
                        colors: const [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
                        quotaLabel: "Batch $_selectedBatch | $_selectedSemester",
                        onTap: () => _navigateToStudentList(
                          title: "Field Work Absents",
                          description:
                              "Students in $_selectedSemester (Batch $_selectedBatch) with at least one absent field work day",
                          studentsList: absentStudentsList,
                          activeTab: 'absent',
                        ),
                      ),
                      _buildStatCard(
                        title: "FW Weekly Low",
                        value: weeklyLowList.length.toString(),
                        icon: Icons.date_range_rounded,
                        colors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        quotaLabel: "Target: ${_weeklyQuota.toInt()} hrs",
                        onTap: () => _navigateToStudentList(
                          title: "Weekly Threshold Violations",
                          description:
                              "Students in Batch $_selectedBatch who logged less than $_weeklyQuota hrs last week (${DateFormat('dd/MM').format(_startOfLastWeek)} - ${DateFormat('dd/MM').format(_endOfLastWeek)})",
                          studentsList: weeklyLowList,
                          activeTab: 'weekly',
                        ),
                      ),
                      _buildStatCard(
                        title: "FW Monthly Low",
                        value: monthlyLowList.length.toString(),
                        icon: Icons.calendar_month_rounded,
                        colors: const [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                        quotaLabel: "Target: ${_monthlyQuota.toInt()} hrs",
                        onTap: () => _navigateToStudentList(
                          title: "Monthly Threshold Violations",
                          description:
                              "Students in Batch $_selectedBatch who logged less than $_monthlyQuota hrs last month (${DateFormat('dd/MM').format(_firstDayOfLastMonth)} - ${DateFormat('dd/MM').format(_lastDayOfLastMonth)})",
                          studentsList: monthlyLowList,
                          activeTab: 'monthly',
                        ),
                      ),
                    ],
                  ),

                  _buildSectionHeader("Reports"),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      _buildStatCard(
                        title: "Late Reports",
                        value: lateReportsList.length.toString(),
                        icon: Icons.warning_amber_rounded,
                        colors: const [Color(0xFF115E59), Color(0xFF0F766E)],
                        quotaLabel: "Batch $_selectedBatch | $_selectedSemester",
                        onTap: () => _navigateToStudentList(
                          title: "Late Report Submissions",
                          description:
                              "Students in $_selectedSemester (Batch $_selectedBatch) who submitted report(s) late this semester",
                          studentsList: lateReportsList,
                          activeTab: 'late_reports',
                        ),
                      ),
                      _buildStatCard(
                        title: "Late Rep. (Month)",
                        value: lateReportsMonthList.length.toString(),
                        icon: Icons.assignment_late_rounded,
                        colors: const [Color(0xFF0D9488), Color(0xFF14B8A6)],
                        quotaLabel: "Last Month",
                        onTap: () => _navigateToStudentList(
                          title: "Monthly Late Reports",
                          description:
                              "Students in Batch $_selectedBatch who submitted report(s) late last month (${DateFormat('dd/MM').format(_firstDayOfLastMonth)} - ${DateFormat('dd/MM').format(_lastDayOfLastMonth)})",
                          studentsList: lateReportsMonthList,
                          activeTab: 'late_reports_month',
                        ),
                      ),
                    ],
                  ),

                  _buildSectionHeader("Conferences"),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      _buildStatCard(
                        title: "Conf Absents (Sem)",
                        value: confAbsentSemList.length.toString(),
                        icon: Icons.forum_rounded,
                        colors: const [Color(0xFF581C87), Color(0xFF701A75)],
                        quotaLabel: "Batch $_selectedBatch | $_selectedSemester",
                        onTap: () => _navigateToStudentList(
                          title: "Conf Absentees (Semester)",
                          description:
                              "Students in $_selectedSemester (Batch $_selectedBatch) who were absent for conference day(s) this semester",
                          studentsList: confAbsentSemList,
                          activeTab: 'conf_absent_sem',
                        ),
                      ),
                      _buildStatCard(
                        title: "Conf Absents (Month)",
                        value: confAbsentMonthList.length.toString(),
                        icon: Icons.cancel_presentation_rounded,
                        colors: const [Color(0xFFD946EF), Color(0xFFC084FC)],
                        quotaLabel: "Last Month",
                        onTap: () => _navigateToStudentList(
                          title: "Conf Absentees (Last Month)",
                          description:
                              "Students in Batch $_selectedBatch who were absent for conference day(s) last month (${DateFormat('dd/MM').format(_firstDayOfLastMonth)} - ${DateFormat('dd/MM').format(_lastDayOfLastMonth)})",
                          studentsList: confAbsentMonthList,
                          activeTab: 'conf_absent_month',
                        ),
                      ),
                      _buildStatCard(
                        title: "Conf Absents (Week)",
                        value: confAbsentWeekList.length.toString(),
                        icon: Icons.unpublished_rounded,
                        colors: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                        quotaLabel: "Last Week",
                        onTap: () => _navigateToStudentList(
                          title: "Conf Absentees (Last Week)",
                          description:
                              "Students in Batch $_selectedBatch who were absent for conference day(s) last week (${DateFormat('dd/MM').format(_startOfLastWeek)} - ${DateFormat('dd/MM').format(_endOfLastWeek)})",
                          studentsList: confAbsentWeekList,
                          activeTab: 'conf_absent_week',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );

  }
}

class StudentExceptionsListPage extends StatelessWidget {
  final String title;
  final String description;
  final List<dynamic> studentsList;
  final String activeTab;
  final double weeklyQuota;
  final double monthlyQuota;
  final Function(BuildContext, Map<String, dynamic>, String) showDetails;

  const StudentExceptionsListPage({
    super.key,
    required this.title,
    required this.description,
    required this.studentsList,
    required this.activeTab,
    required this.weeklyQuota,
    required this.monthlyQuota,
    required this.showDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: Text(
                description,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  bottom: 16.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: studentsList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 48,
                                color: Colors.green[200],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "No students violate this threshold!",
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: studentsList.length,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          separatorBuilder: (context, index) => const Divider(
                            height: 8,
                            color: Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, i) {
                            final item = studentsList[i];
                            final student = item['student'];
                            final displayName =
                                student['display_name'] ?? 'Student';
                            final regNo = student['registration_no'] ?? 'N/A';
                            final specialisation =
                                student['specialisation'] ?? 'N/A';

                            String trailingText = '';
                            Color trailingColor = Colors.grey;

                            if (activeTab == 'absent') {
                              trailingText = "${item['count']} Absents";
                              trailingColor = Colors.redAccent;
                            } else if (activeTab == 'weekly') {
                              final double hLogged = (item['hours'] as num).toDouble();
                              final int h = hLogged.toInt();
                              final int m = ((hLogged - h) * 60).round();
                              final String loggedStr = "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
                              final int qH = weeklyQuota.toInt();
                              final String quotaStr = "${qH.toString().padLeft(2, '0')}:00";
                              trailingText = "$loggedStr / $quotaStr";
                              trailingColor = Colors.orangeAccent;
                            } else if (activeTab == 'monthly') {
                              final double hLogged = (item['hours'] as num).toDouble();
                              final int h = hLogged.toInt();
                              final int m = ((hLogged - h) * 60).round();
                              final String loggedStr = "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
                              final int qH = monthlyQuota.toInt();
                              final String quotaStr = "${qH.toString().padLeft(2, '0')}:00";
                              trailingText = "$loggedStr / $quotaStr";
                              trailingColor = Colors.blueAccent;
                            } else if (activeTab == 'late_reports' ||
                                activeTab == 'late_reports_month') {
                              trailingText = "${item['count']} Late";
                              trailingColor = Colors.amber[800]!;
                            } else if (activeTab == 'conf_absent_sem') {
                              trailingText = "${item['count']} Absents";
                              trailingColor = Colors.purple;
                            } else if (activeTab == 'conf_absent_month') {
                              trailingText = "${item['count']} Absents";
                              trailingColor = Colors.pink;
                            } else if (activeTab == 'conf_absent_week') {
                              trailingText = "${item['count']} Absents";
                              trailingColor = Colors.deepOrangeAccent;
                            }

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: trailingColor.withValues(
                                  alpha: 0.1,
                                ),
                                child: Text(
                                  displayName.substring(0, 1).toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: trailingColor,
                                  ),
                                ),
                              ),
                              title: Text(
                                displayName,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                "Reg: $regNo | Spec: $specialisation",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    trailingText,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: trailingColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                              onTap: () => showDetails(
                                context,
                                Map<String, dynamic>.from(item as Map),
                                activeTab,
                              ),
                            );
                          },
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
