import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({super.key});

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Student Profile data
  Map<String, dynamic>? _profile;
  int? _collegeCode;

  // Semester dropdown lists & selection
  List<String> _semesters = [];
  String? _selectedSemester;

  // Requirements and Logs
  List<Map<String, dynamic>> _semesterRequirements = [];
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // 1. Fetch Student Profile
        final profileData = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (profileData != null) {
          _profile = profileData;
          final rawCode = profileData['secret_code'] ?? profileData['college_code'];
          if (rawCode != null) {
            _collegeCode = int.tryParse(rawCode.toString());
          }
          _selectedSemester = profileData['semester']?.toString().trim();
        }

        // Fallback college code from metadata if not in profile
        if (_collegeCode == null) {
          final rawCode = user.userMetadata?['secret_code'] ?? user.userMetadata?['college_code'];
          if (rawCode != null) {
            _collegeCode = int.tryParse(rawCode.toString());
          }
        }

        if (_collegeCode != null) {
          // 2. Fetch Semester options configured for this college
          final options = await supabase
              .from('college_options')
              .select('value')
              .eq('college_code', _collegeCode!)
              .eq('category', 'semester');

          final List<String> sems = List<Map<String, dynamic>>.from(options)
              .map((e) => e['value']?.toString().trim() ?? '')
              .where((v) => v.isNotEmpty)
              .toSet()
              .toList();

          if (sems.isEmpty) {
            sems.addAll(['Semester I', 'Semester II', 'Semester III', 'Semester IV']);
          }

          // 3. Fetch Semester requirements
          final reqData = await supabase
              .from('semester_requirements')
              .select()
              .eq('college_code', _collegeCode!);

          // 4. Fetch Student Logs
          final logsData = await supabase
              .from('attendance_logs')
              .select()
              .eq('user_id', user.id);

          setState(() {
            _semesters = sems;
            // Prefill selection if available in options, otherwise pick first option
            if (_selectedSemester == null || !_semesters.contains(_selectedSemester)) {
              _selectedSemester = _semesters.isNotEmpty ? _semesters.first : 'Semester I';
            }
            _semesterRequirements = List<Map<String, dynamic>>.from(reqData);
            _logs = List<Map<String, dynamic>>.from(logsData);
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading student profile details: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    if (_profile == null) {
      return Scaffold(
        body: Center(
          child: Text(
            "Profile error: Student account not found",
            style: GoogleFonts.inter(),
          ),
        ),
      );
    }

    final displayName = _profile!['display_name'] ?? 'Student';
    final regNo = _profile!['registration_no'] ?? 'N/A';
    final college = _profile!['college'] ?? 'N/A';
    final department = _profile!['department'] ?? 'N/A';

    // Filters logs by selected semester (includes null semesters on the first semester for legacy logs)
    final semesterLogs = _logs.where((l) {
      final lSem = l['semester']?.toString().trim();
      return lSem == _selectedSemester || (lSem == null && _selectedSemester == _semesters.first);
    }).toList();

    // Calculate metrics
    final int fwAttended = semesterLogs.where((l) =>
        l['activity_type'] == 'Field Work' &&
        l['check_out_time'] != null &&
        l['status'] != 'Absent'
    ).length;

    final int reportsOnTime = semesterLogs.where((l) =>
        l['activity_type'] == 'Report' &&
        l['status'] == 'On Time'
    ).length;

    final int reportsLate = semesterLogs.where((l) =>
        l['activity_type'] == 'Report' &&
        l['status'] == 'Late'
    ).length;

    final int reportsTotal = reportsOnTime + reportsLate;

    final int confAttended = semesterLogs.where((l) =>
        l['activity_type'] == 'Conference' &&
        l['status'] == 'Present'
    ).length;

    // Fetch Target limits for selected semester
    final req = _semesterRequirements.firstWhere(
      (r) => r['semester']?.toString().trim() == _selectedSemester,
      orElse: () => {},
    );

    final targetFw = req['required_field_work'] ?? 24;
    final targetRep = req['required_reports'] ?? 24;
    final targetConf = req['required_conferences'] ?? 5;

    // Absent calculations
    final int confAbsent = (targetConf - confAttended).clamp(0, targetConf);

    // Percentages for progress bars
    final double fwPercent = targetFw > 0 ? (fwAttended / targetFw).clamp(0.0, 1.0) : 0.0;
    final double repPercent = targetRep > 0 ? (reportsTotal / targetRep).clamp(0.0, 1.0) : 0.0;
    final double confPercent = targetConf > 0 ? (confAttended / targetConf).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- PROFILE BANNER CARD ---
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF232526), Color(0xFF414345)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Reg: $regNo",
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "$department | $college",
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- SEMESTER DROPDOWN SELECTOR ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: DropdownButtonFormField<String>(
                      value: _selectedSemester,
                      decoration: InputDecoration(
                        labelText: "Select Semester",
                        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500]),
                        border: InputBorder.none,
                      ),
                      dropdownColor: Colors.white,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                      items: _semesters.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedSemester = val;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- METRIC TARGET CARDS ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    // Card 1: Field work attendance
                    _buildMetricCard(
                      title: "Field Work Attendance",
                      value: "$fwAttended / $targetFw",
                      unit: "days completed",
                      percentage: fwPercent,
                      color: Colors.blueAccent,
                      icon: Icons.work_history_rounded,
                      extraDetails: const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 16),

                    // Card 2: Report Submissions
                    _buildMetricCard(
                      title: "Reports Submitted",
                      value: "$reportsTotal / $targetRep",
                      unit: "reports uploaded",
                      percentage: repPercent,
                      color: Colors.teal,
                      icon: Icons.analytics_rounded,
                      extraDetails: Row(
                        children: [
                          _buildDetailBadge("On Time: $reportsOnTime", Colors.green),
                          const SizedBox(width: 8),
                          _buildDetailBadge("Late: $reportsLate", Colors.orange),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card 3: Conference Attendance
                    _buildMetricCard(
                      title: "Conferences Attended",
                      value: "$confAttended / $targetConf",
                      unit: "conferences logs",
                      percentage: confPercent,
                      color: Colors.purpleAccent,
                      icon: Icons.forum_rounded,
                      extraDetails: Row(
                        children: [
                          _buildDetailBadge("Absent: $confAbsent", Colors.redAccent),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required double percentage,
    required Color color,
    required IconData icon,
    required Widget extraDetails,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey[100]!, width: 1.5),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            value.split(' ')[0],
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            value.contains('/') ? "/ ${value.split('/')[1]}" : "",
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            unit,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            if (extraDetails is! SizedBox) ...[
              const SizedBox(height: 16),
              extraDetails,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
