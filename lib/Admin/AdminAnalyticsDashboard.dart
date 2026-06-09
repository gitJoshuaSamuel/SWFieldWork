import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AdminAnalyticsDashboard extends StatefulWidget {
  const AdminAnalyticsDashboard({super.key});

  @override
  State<AdminAnalyticsDashboard> createState() => _AdminAnalyticsDashboardState();
}

class _AdminAnalyticsDashboardState extends State<AdminAnalyticsDashboard> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  int? _collegeCode;

  // Selected Date for Analysis
  DateTime _selectedDate = DateTime.now();

  // Filters
  String _selectedClass = 'All';
  String _selectedBatch = 'All';
  String _selectedSemester = 'All';
  String _selectedSpecialisation = 'All';

  // Dropdown options
  List<String> _classes = ['All'];
  List<String> _batches = ['All'];
  List<String> _semesters = ['All'];
  List<String> _specialisations = ['All'];

  // Loaded Data
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _semesterRequirements = [];
  Map<String, dynamic>? _schedule;

  // Active Widget Tab
  String _activeWidgetTab = 'Active Field Work'; // 'Active Field Work', 'Completed Field Work', 'Absent', 'Reports', 'Conference', 'Student Progress'

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
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

          // 2. Fetch Schedule
          _schedule = await supabase
              .from('college_schedule')
              .select()
              .eq('college_code', code)
              .maybeSingle();

          // 3. Fetch Semester Requirements
          final reqData = await supabase
              .from('semester_requirements')
              .select()
              .eq('college_code', code);
          _semesterRequirements = List<Map<String, dynamic>>.from(reqData);

          // 4. Fetch College Options for Filters
          final options = await supabase
              .from('college_options')
              .select()
              .eq('college_code', code);

          final List<Map<String, dynamic>> optRows = List<Map<String, dynamic>>.from(options);
          
          final cl = ['All'];
          final ba = ['All'];
          final se = ['All'];
          final sp = ['All'];

          for (var row in optRows) {
            final cat = row['category']?.toString().toLowerCase().trim();
            final val = row['value']?.toString().trim() ?? '';
            if (val.isEmpty) continue;

            if (cat == 'class') cl.add(val);
            if (cat == 'batch') ba.add(val);
            if (cat == 'semester') se.add(val);
            if (cat == 'specialisation') sp.add(val);
          }

          // 5. Fetch Students
          final studentsData = await supabase
              .from('profiles')
              .select()
              .eq('role', 'Student');

          final List<Map<String, dynamic>> allProfiles = List<Map<String, dynamic>>.from(studentsData);
          final filteredStudents = allProfiles.where((p) {
            final pCode = p['college_code'] ?? p['secret_code'];
            return pCode?.toString() == code.toString();
          }).toList();

          // 6. Fetch Attendance Logs
          final logsData = await supabase
              .from('attendance_logs')
              .select('*, profiles(id, display_name, college_code, class, batch, semester, registration_no, faculty_supervisor, agency_supervisor, organisation_placed)')
              .order('check_in_time', ascending: false);

          final List<Map<String, dynamic>> allLogs = List<Map<String, dynamic>>.from(logsData);
          final filteredLogs = allLogs.where((log) {
            if (log['profiles'] == null) return false;
            final lCode = log['profiles']['college_code'];
            return lCode?.toString() == code.toString();
          }).toList();

          setState(() {
            _classes = cl;
            _batches = ba;
            _semesters = se;
            _specialisations = sp;
            _students = filteredStudents;
            _logs = filteredLogs;
            _adjustActiveTabForDate(_selectedDate);
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Helper to check if log matches selected date
  bool _isLogOnSelectedDate(Map<String, dynamic> log) {
    final checkInStr = log['check_in_time']?.toString();
    if (checkInStr == null) return false;
    try {
      final dt = DateTime.parse(checkInStr).toLocal();
      return dt.year == _selectedDate.year &&
          dt.month == _selectedDate.month &&
          dt.day == _selectedDate.day;
    } catch (_) {
      return false;
    }
  }

  void _adjustActiveTabForDate(DateTime date) {
    final List<String> visibleTabs = [];
    if (_schedule != null) {
      final List<dynamic> fwDays = _schedule?['field_work_days'] ?? [];
      final List<dynamic> confDays = _schedule?['conference_days'] ?? [];
      final List<dynamic> repDays = _schedule?['report_submission_days'] ?? [];
      final weekdayName = DateFormat('EEEE').format(date);

      final isFwDay = fwDays.map((e) => e.toString().toLowerCase()).contains(weekdayName.toLowerCase());
      final isConfDay = confDays.map((e) => e.toString().toLowerCase()).contains(weekdayName.toLowerCase());
      final isRepDay = repDays.map((e) => e.toString().toLowerCase()).contains(weekdayName.toLowerCase());

      if (isFwDay) {
        visibleTabs.addAll(['Active Field Work', 'Completed Field Work', 'Absent']);
      }
      if (isRepDay) {
        visibleTabs.addAll(['Reports Submitted', 'Reports On Time', 'Reports Late']);
      }
      if (isConfDay) {
        visibleTabs.addAll(['Conference Present', 'Conference Absent']);
      }
    }
    visibleTabs.add('Student Progress');

    if (!visibleTabs.contains(_activeWidgetTab)) {
      _activeWidgetTab = visibleTabs.first;
    }
  }

  // Filter Student list based on Dropdown states
  bool _studentMatchesFilters(Map<String, dynamic> student) {
    final matchesClass = _selectedClass == 'All' || student['class']?.toString() == _selectedClass;
    final matchesBatch = _selectedBatch == 'All' || student['batch']?.toString() == _selectedBatch;
    final matchesSem = _selectedSemester == 'All' || student['semester']?.toString() == _selectedSemester;
    final matchesSpec = _selectedSpecialisation == 'All' || student['specialisation']?.toString() == _selectedSpecialisation;
    return matchesClass && matchesBatch && matchesSem && matchesSpec;
  }

  // Filter Log based on Dropdown states
  bool _logMatchesFilters(Map<String, dynamic> log) {
    final profile = log['profiles'];
    if (profile == null) return false;
    return _studentMatchesFilters(profile);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _adjustActiveTabForDate(picked);
      });
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

    // Schedule Parsing
    final List<dynamic> fwDays = _schedule?['field_work_days'] ?? [];
    final List<dynamic> confDays = _schedule?['conference_days'] ?? [];
    final List<dynamic> repDays = _schedule?['report_submission_days'] ?? [];
    final String reportDeadlineStr = _schedule?['report_deadline']?.toString() ?? '17:00:00';

    final weekdayName = DateFormat('EEEE').format(_selectedDate); // e.g. "Monday"

    final isFwDay = fwDays.map((e) => e.toString().toLowerCase()).contains(weekdayName.toLowerCase());
    final isConfDay = confDays.map((e) => e.toString().toLowerCase()).contains(weekdayName.toLowerCase());
    final isRepDay = repDays.map((e) => e.toString().toLowerCase()).contains(weekdayName.toLowerCase());

    // Filter students and logs by Class/Batch/Semester/Specialisation
    final filteredStudentsList = _students.where(_studentMatchesFilters).toList();
    final filteredLogsList = _logs.where((l) => _logMatchesFilters(l) && _isLogOnSelectedDate(l)).toList();

    // 1. Calculate Active Field Work
    final activeFw = filteredLogsList.where((l) =>
        l['activity_type'] == 'Field Work' && l['check_out_time'] == null && (l['status'] ?? 'Present') != 'Absent').toList();

    // 2. Calculate Completed Field Work
    final completedFw = filteredLogsList.where((l) =>
        l['activity_type'] == 'Field Work' && l['check_out_time'] != null && (l['status'] ?? 'Present') != 'Absent').toList();

    // 3. Calculate Absent Today (Students who marked absent OR on a FW day have not checked in at all)
    final explicitAbsent = filteredLogsList.where((l) => l['status'] == 'Absent').toList();
    final explicitAbsentUserIds = explicitAbsent.map((e) => e['user_id']?.toString()).toSet();

    final checkedInUserIds = filteredLogsList
        .where((l) => l['activity_type'] == 'Field Work')
        .map((e) => e['user_id']?.toString())
        .toSet();

    final List<Map<String, dynamic>> absentStudents = [];
    if (isFwDay) {
      for (var student in filteredStudentsList) {
        final sId = student['id']?.toString();
        if (sId != null) {
          if (explicitAbsentUserIds.contains(sId)) {
            absentStudents.add({
              'profile': student,
              'reason': 'Marked Absent explicitly',
              'time': explicitAbsent.firstWhere((e) => e['user_id']?.toString() == sId)['check_in_time'],
            });
          } else if (!checkedInUserIds.contains(sId)) {
            absentStudents.add({
              'profile': student,
              'reason': 'No check-in record today',
              'time': null,
            });
          }
        }
      }
    } else {
      for (var student in filteredStudentsList) {
        final sId = student['id']?.toString();
        if (sId != null && explicitAbsentUserIds.contains(sId)) {
          absentStudents.add({
            'profile': student,
            'reason': 'Marked Absent explicitly',
            'time': explicitAbsent.firstWhere((e) => e['user_id']?.toString() == sId)['check_in_time'],
          });
        }
      }
    }

    // 4. Calculate Reports submitted on time / late
    final reports = filteredLogsList.where((l) => l['activity_type'] == 'Report').toList();
    final List<Map<String, dynamic>> onTimeReports = [];
    final List<Map<String, dynamic>> lateReports = [];

    final deadTimeParts = reportDeadlineStr.split(':');
    final deadlineHour = deadTimeParts.isNotEmpty ? (int.tryParse(deadTimeParts[0]) ?? 17) : 17;
    final deadlineMin = deadTimeParts.length > 1 ? (int.tryParse(deadTimeParts[1]) ?? 0) : 0;

    for (var r in reports) {
      final checkInTimeStr = r['check_in_time']?.toString();
      if (checkInTimeStr != null) {
        try {
          final dt = DateTime.parse(checkInTimeStr).toLocal();
          final limitTime = DateTime(dt.year, dt.month, dt.day, deadlineHour, deadlineMin);
          if (dt.isBefore(limitTime) || dt.isAtSameMomentAs(limitTime)) {
            onTimeReports.add(r);
          } else {
            lateReports.add(r);
          }
        } catch (_) {
          onTimeReports.add(r);
        }
      }
    }

    // 5. Conference Attendance
    final confAttendedLogs = filteredLogsList.where((l) => l['activity_type'] == 'Conference').toList();
    final confAttendedUserIds = confAttendedLogs.map((e) => e['user_id']?.toString()).toSet();

    final List<Map<String, dynamic>> confNotAttended = [];
    if (isConfDay) {
      for (var student in filteredStudentsList) {
        final sId = student['id']?.toString();
        if (sId != null && !confAttendedUserIds.contains(sId)) {
          confNotAttended.add(student);
        }
      }
    }

    // Detail Panel list mapper
    List<Widget> detailListWidgets = [];
    if (_activeWidgetTab == 'Active Field Work') {
      detailListWidgets = activeFw.isEmpty
          ? [_buildEmptyState("No students currently checked in")]
          : activeFw.map((log) => _buildLogDetailCard(log, "Active")).toList();
    } else if (_activeWidgetTab == 'Completed Field Work') {
      detailListWidgets = completedFw.isEmpty
          ? [_buildEmptyState("No completed check-outs today")]
          : completedFw.map((log) => _buildLogDetailCard(log, "Completed")).toList();
    } else if (_activeWidgetTab == 'Absent') {
      detailListWidgets = absentStudents.isEmpty
          ? [_buildEmptyState("No absentees on selected date")]
          : absentStudents.map((abs) {
              final profile = abs['profile'];
              return _buildAbsentStudentCard(profile, abs['reason'], abs['time']);
            }).toList();
    } else if (_activeWidgetTab == 'Reports Submitted') {
      detailListWidgets = reports.isEmpty
          ? [_buildEmptyState("No reports submitted on selected date")]
          : reports.map((log) => _buildLogDetailCard(log, log['status'] ?? "Submitted")).toList();
    } else if (_activeWidgetTab == 'Reports On Time') {
      detailListWidgets = onTimeReports.isEmpty
          ? [_buildEmptyState("No on-time reports submitted on selected date")]
          : onTimeReports.map((log) => _buildLogDetailCard(log, "On Time")).toList();
    } else if (_activeWidgetTab == 'Reports Late') {
      detailListWidgets = lateReports.isEmpty
          ? [_buildEmptyState("No late reports submitted on selected date")]
          : lateReports.map((log) => _buildLogDetailCard(log, "Late")).toList();
    } else if (_activeWidgetTab == 'Conference Present') {
      detailListWidgets = confAttendedLogs.isEmpty
          ? [_buildEmptyState("No conference attendance logs on selected date")]
          : confAttendedLogs.map((log) => _buildLogDetailCard(log, "Attended")).toList();
    } else if (_activeWidgetTab == 'Conference Absent') {
      detailListWidgets = confNotAttended.isEmpty
          ? [_buildEmptyState("No conference absentees on selected date")]
          : confNotAttended.map((student) => _buildAbsentStudentCard(student, "Did not check in to Conference", null)).toList();
    } else if (_activeWidgetTab == 'Student Progress') {
      detailListWidgets = filteredStudentsList.isEmpty
          ? [_buildEmptyState("No students match the current filters")]
          : filteredStudentsList.map((student) => _buildProgressStudentCard(student)).toList();
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- DATE SELECTOR & METADATA HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (isFwDay) _buildScheduleBadge("Field Work", Colors.blue),
                            if (isConfDay) ...[
                              const SizedBox(width: 4),
                              _buildScheduleBadge("Conference", Colors.purple),
                            ],
                            if (isRepDay) ...[
                              const SizedBox(width: 4),
                              _buildScheduleBadge("Report", Colors.teal),
                            ],
                            if (!isFwDay && !isConfDay && !isRepDay)
                              _buildScheduleBadge("No Scheduled Activities", Colors.grey),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_month_rounded, color: Colors.black),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shadowColor: Colors.black.withValues(alpha: 0.05),
                      elevation: 4,
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _loadDashboardData,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.black),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shadowColor: Colors.black.withValues(alpha: 0.05),
                      elevation: 4,
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),

            // --- FILTERS EXPANSION GRID ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ExpansionTile(
                title: Text(
                  "Advanced Filters",
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                ),
                leading: const Icon(Icons.tune_rounded, size: 18),
                dense: true,
                visualDensity: VisualDensity.compact,
                collapsedBackgroundColor: Colors.white,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildFilterDropdown("Class", _selectedClass, _classes, (v) => setState(() => _selectedClass = v!))),
                            const SizedBox(width: 8),
                            Expanded(child: _buildFilterDropdown("Batch", _selectedBatch, _batches, (v) => setState(() => _selectedBatch = v!))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildFilterDropdown("Semester", _selectedSemester, _semesters, (v) => setState(() => _selectedSemester = v!))),
                            const SizedBox(width: 8),
                            Expanded(child: _buildFilterDropdown("Specialisation", _selectedSpecialisation, _specialisations, (v) => setState(() => _selectedSpecialisation = v!))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- WIDGET STATISTICS GRID ---
            SizedBox(
              height: 180,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: () {
                  final List<Widget> cards = [];
                  if (isFwDay) {
                    cards.add(_buildStatCard(
                      title: "Active Field Work",
                      value: activeFw.length.toString(),
                      subtitle: "Checked-in",
                      icon: Icons.sensors_rounded,
                      colors: [const Color(0xFF1E88E5), const Color(0xFF1565C0)],
                    ));
                    cards.add(_buildStatCard(
                      title: "Completed Field Work",
                      value: completedFw.length.toString(),
                      subtitle: "Checked-out",
                      icon: Icons.check_circle_rounded,
                      colors: [const Color(0xFF43A047), const Color(0xFF2E7D32)],
                    ));
                    cards.add(_buildStatCard(
                      title: "Absent",
                      value: absentStudents.length.toString(),
                      subtitle: "Unaccounted/Absent",
                      icon: Icons.person_off_rounded,
                      colors: [const Color(0xFFE53935), const Color(0xFFC62828)],
                    ));
                  }
                  if (isRepDay) {
                    cards.add(_buildStatCard(
                      title: "Reports Submitted",
                      value: reports.length.toString(),
                      subtitle: "Total submissions",
                      icon: Icons.description_rounded,
                      colors: [const Color(0xFF00897B), const Color(0xFF00695C)],
                    ));
                    cards.add(_buildStatCard(
                      title: "Reports On Time",
                      value: onTimeReports.length.toString(),
                      subtitle: "On-time submissions",
                      icon: Icons.task_alt_rounded,
                      colors: [const Color(0xFF00B0FF), const Color(0xFF0091EA)],
                    ));
                    cards.add(_buildStatCard(
                      title: "Reports Late",
                      value: lateReports.length.toString(),
                      subtitle: "Late submissions",
                      icon: Icons.watch_later_rounded,
                      colors: [const Color(0xFFFFB300), const Color(0xFFFF8F00)],
                    ));
                  }
                  if (isConfDay) {
                    cards.add(_buildStatCard(
                      title: "Conference Present",
                      value: confAttendedLogs.length.toString(),
                      subtitle: "Attended logs",
                      icon: Icons.forum_rounded,
                      colors: [const Color(0xFF8E24AA), const Color(0xFF6A1B9A)],
                    ));
                    cards.add(_buildStatCard(
                      title: "Conference Absent",
                      value: confNotAttended.length.toString(),
                      subtitle: "Not attended",
                      icon: Icons.no_accounts_rounded,
                      colors: [const Color(0xFFD81B60), const Color(0xFFAD1457)],
                    ));
                  }
                  cards.add(_buildStatCard(
                    title: "Student Progress",
                    value: filteredStudentsList.length.toString(),
                    subtitle: "Target vs completed",
                    icon: Icons.assignment_rounded,
                    colors: [const Color(0xFFEC407A), const Color(0xFFD81B60)],
                  ));

                  final List<Widget> cardWidgets = [];
                  for (int i = 0; i < cards.length; i++) {
                    cardWidgets.add(cards[i]);
                    if (i < cards.length - 1) {
                      cardWidgets.add(const SizedBox(width: 12));
                    }
                  }
                  return cardWidgets;
                }(),
              ),
            ),
            const SizedBox(height: 16),

            // --- DETAILS EXPANDABLE HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "$_activeWidgetTab Details",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    "Count: ${detailListWidgets.length}",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // --- DETAILED LIST ---
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: detailListWidgets,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        filled: true,
        fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black),
        ),
      ),
      dropdownColor: Colors.white,
      style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
  }) {
    final isSelected = _activeWidgetTab == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeWidgetTab = title;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 155,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors[0].withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
          border: isSelected
              ? Border.all(color: Colors.white, width: 2)
              : Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 22),
                if (isSelected)
                  const Icon(Icons.arrow_circle_down_rounded, color: Colors.white, size: 20),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.9)),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 9, color: Colors.white.withValues(alpha: 0.7)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.assignment_turned_in_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniProgressChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  // Generate targets and progress metrics for a student
  Map<String, dynamic> _computeProgressMetrics(Map<String, dynamic> studentProfile) {
    final sId = studentProfile['id']?.toString();
    final sSem = studentProfile['semester']?.toString() ?? 'Semester I';

    int studentFwCount = 0;
    int studentRepCount = 0;
    int studentConfCount = 0;
    int studentFwAbsent = 0;
    int studentRepLate = 0;

    if (sId != null) {
      // Historical aggregate filtered by student current semester (includes null semester logs for safety)
      studentFwCount = _logs.where((l) =>
          l['user_id']?.toString() == sId &&
          l['activity_type'] == 'Field Work' &&
          l['check_out_time'] != null &&
          l['status'] != 'Absent' &&
          (l['semester'] == null || l['semester'] == sSem)
      ).length;

      studentFwAbsent = _logs.where((l) =>
          l['user_id']?.toString() == sId &&
          l['activity_type'] == 'Field Work' &&
          l['status'] == 'Absent' &&
          (l['semester'] == null || l['semester'] == sSem)
      ).length;

      studentRepCount = _logs.where((l) =>
          l['user_id']?.toString() == sId &&
          l['activity_type'] == 'Report' &&
          (l['semester'] == null || l['semester'] == sSem)
      ).length;

      studentRepLate = _logs.where((l) =>
          l['user_id']?.toString() == sId &&
          l['activity_type'] == 'Report' &&
          l['status'] == 'Late' &&
          (l['semester'] == null || l['semester'] == sSem)
      ).length;

      studentConfCount = _logs.where((l) =>
          l['user_id']?.toString() == sId &&
          l['activity_type'] == 'Conference' &&
          l['status'] == 'Present' &&
          (l['semester'] == null || l['semester'] == sSem)
      ).length;
    }

    final req = _semesterRequirements.firstWhere(
      (r) => r['semester']?.toString().trim() == sSem,
      orElse: () => {},
    );

    final targetFw = req['required_field_work'] ?? 24;
    final targetRep = req['required_reports'] ?? 24;
    final targetConf = req['required_conferences'] ?? 5;

    return {
      'fw_count': studentFwCount,
      'fw_target': targetFw,
      'fw_absent': studentFwAbsent,
      'rep_count': studentRepCount,
      'rep_target': targetRep,
      'rep_late': studentRepLate,
      'conf_count': studentConfCount,
      'conf_target': targetConf,
    };
  }

  Widget _buildLogDetailCard(Map<String, dynamic> log, String state) {
    final profile = log['profiles'] ?? {};
    final display = profile['display_name'] ?? 'Student';
    final regNo = profile['registration_no'] ?? 'N/A';
    final faculty = profile['faculty_supervisor'] ?? 'N/A';

    final checkIn = log['check_in_time'] != null ? DateTime.parse(log['check_in_time']).toLocal() : null;
    final checkOut = log['check_out_time'] != null ? DateTime.parse(log['check_out_time']).toLocal() : null;

    final checkInStr = checkIn != null ? DateFormat('hh:mm a').format(checkIn) : '--:--';
    final checkOutStr = checkOut != null ? DateFormat('hh:mm a').format(checkOut) : 'Active';

    final metrics = _computeProgressMetrics(profile);

    final String activityType = log['activity_type'] ?? 'Field Work';
    final String status = log['status'] ?? 'Present';
    final bool hasCoords = log['check_in_lat'] != null && log['check_in_lng'] != null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[100]!, width: 1.5),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  log['check_in_img_url'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.grey, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    display,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  Text(
                    "Reg: $regNo | Faculty: $faculty",
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  if (activityType == 'Field Work')
                    Row(
                      children: [
                        Icon(Icons.login_rounded, size: 12, color: Colors.green[600]),
                        const SizedBox(width: 4),
                        Text("In: $checkInStr", style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[700])),
                        const SizedBox(width: 12),
                        Icon(Icons.logout_rounded, size: 12, color: checkOut != null ? Colors.red : Colors.orange),
                        const SizedBox(width: 4),
                        Text("Out: $checkOutStr", style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[700])),
                      ],
                    )
                  else if (activityType == 'Report')
                    Row(
                      children: [
                        Icon(Icons.description_rounded, size: 12, color: Colors.teal[600]),
                        const SizedBox(width: 4),
                        Text("Submitted: $checkInStr", style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[700])),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: status == 'On Time' ? Colors.green[50] : Colors.orange[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: status == 'On Time' ? Colors.green[100]! : Colors.orange[100]!),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: status == 'On Time' ? Colors.green[700] : Colors.orange[800],
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (activityType == 'Conference')
                    Row(
                      children: [
                        Icon(Icons.forum_rounded, size: 12, color: Colors.purple[600]),
                        const SizedBox(width: 4),
                        Text("Attended: $checkInStr", style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[700])),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.purple[100]!),
                          ),
                          child: Text(
                            "Present",
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildMiniProgressChip("FW: ${metrics['fw_count']}/${metrics['fw_target']}", metrics['fw_count'] >= metrics['fw_target'] ? Colors.green : Colors.blue),
                      const SizedBox(width: 4),
                      _buildMiniProgressChip("REP: ${metrics['rep_count']}/${metrics['rep_target']}", metrics['rep_count'] >= metrics['rep_target'] ? Colors.green : Colors.teal),
                      const SizedBox(width: 4),
                      _buildMiniProgressChip("CONF: ${metrics['conf_count']}/${metrics['conf_target']}", metrics['conf_count'] >= metrics['conf_target'] ? Colors.green : Colors.purple),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_rounded, color: Colors.indigo, size: 20),
                  onPressed: () => _showImageDialog(log['check_in_img_url']),
                ),
                if (hasCoords)
                  IconButton(
                    icon: const Icon(Icons.map_rounded, color: Colors.blueAccent, size: 20),
                    onPressed: () => _showMapDialog(log),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbsentStudentCard(Map<String, dynamic> student, String reason, String? timeStr) {
    final display = student['display_name'] ?? 'Student';
    final regNo = student['registration_no'] ?? 'N/A';
    final faculty = student['faculty_supervisor'] ?? 'N/A';

    String statusText = reason;
    if (timeStr != null) {
      try {
        final t = DateTime.parse(timeStr).toLocal();
        statusText += " at ${DateFormat('hh:mm a').format(t)}";
      } catch (_) {}
    }

    final metrics = _computeProgressMetrics(student);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red[50]!, width: 1.5),
      ),
      color: Colors.red[50]?.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.red[100],
              child: const Icon(Icons.person_off_rounded, color: Colors.redAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    display,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  Text(
                    "Reg: $regNo | Faculty: $faculty",
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildMiniProgressChip("FW: ${metrics['fw_count']}/${metrics['fw_target']}", metrics['fw_count'] >= metrics['fw_target'] ? Colors.green : Colors.blue),
                      const SizedBox(width: 4),
                      _buildMiniProgressChip("REP: ${metrics['rep_count']}/${metrics['rep_target']}", metrics['rep_count'] >= metrics['rep_target'] ? Colors.green : Colors.teal),
                      const SizedBox(width: 4),
                      _buildMiniProgressChip("CONF: ${metrics['conf_count']}/${metrics['conf_target']}", metrics['conf_count'] >= metrics['conf_target'] ? Colors.green : Colors.purple),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStudentCard(Map<String, dynamic> student) {
    final display = student['display_name'] ?? 'Student';
    final regNo = student['registration_no'] ?? 'N/A';
    final faculty = student['faculty_supervisor'] ?? 'N/A';
    final semester = student['semester'] ?? 'Semester I';

    final metrics = _computeProgressMetrics(student);

    final double fwPercent = metrics['fw_target'] > 0 ? (metrics['fw_count'] / metrics['fw_target']).clamp(0.0, 1.0) : 0.0;
    final double repPercent = metrics['rep_target'] > 0 ? (metrics['rep_count'] / metrics['rep_target']).clamp(0.0, 1.0) : 0.0;
    final double confPercent = metrics['conf_target'] > 0 ? (metrics['conf_count'] / metrics['conf_target']).clamp(0.0, 1.0) : 0.0;

    final int fwAbsent = metrics['fw_absent'] ?? 0;
    final int repLate = metrics['rep_late'] ?? 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[100]!, width: 1.5),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.pink[50],
                  child: Icon(Icons.person_rounded, color: Colors.pink[400], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        display,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Text(
                        "Reg: $regNo | $semester | Faculty: $faculty",
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress bar 1: Field work
            _buildProgressBarRow(
              "Field Work",
              metrics['fw_count'],
              metrics['fw_target'],
              fwPercent,
              Colors.blue,
              trailingDetail: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red[100]!),
                ),
                child: Text(
                  "Absences: $fwAbsent",
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Progress bar 2: Reports
            _buildProgressBarRow(
              "Reports",
              metrics['rep_count'],
              metrics['rep_target'],
              repPercent,
              Colors.teal,
              trailingDetail: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange[100]!),
                ),
                child: Text(
                  "Late: $repLate",
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Progress bar 3: Conferences
            _buildProgressBarRow("Conferences", metrics['conf_count'], metrics['conf_target'], confPercent, Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBarRow(String label, int current, int target, double percentage, Color color, {Widget? trailingDetail}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailingDetail != null) ...[
                  trailingDetail,
                  const SizedBox(width: 8),
                ],
                Text("$current / $target", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  void _showImageDialog(String? url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: url != null ? Image.network(url) : const Text("No image logged"),
        ),
        actions: [
          TextButton(
            child: Text("Close", style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showMapDialog(Map log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 500,
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
            Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Logging Location", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(log['check_in_lat'], log['check_in_lng']),
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.joshua.socialworkFieldWork',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(log['check_in_lat'], log['check_in_lng']),
                          child: const Icon(Icons.location_on, color: Colors.green, size: 40),
                        ),
                        if (log['check_out_lat'] != null)
                          Marker(
                            point: LatLng(log['check_out_lat'], log['check_out_lng']),
                            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
