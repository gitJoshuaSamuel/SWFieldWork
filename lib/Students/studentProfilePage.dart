import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:field_work_2/Students/studentProfileDetailsPage.dart';
import 'package:image_picker/image_picker.dart';

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

  // Date range filter
  DateTime? _rangeStartDate;
  DateTime? _rangeEndDate;

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

  Future<void> _uploadAvatar() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text("Take Photo"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text("Choose from Gallery"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 50,
    );

    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final bytes = await image.readAsBytes();
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '${user.id}/$fileName';

      await supabase.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final avatarUrl = supabase.storage.from('avatars').getPublicUrl(path);

      await supabase
          .from('profiles')
          .update({'avatar_url': avatarUrl})
          .eq('id', user.id);

      setState(() {
        _profile!['avatar_url'] = avatarUrl;
      });

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text("Profile picture updated successfully!", style: GoogleFonts.inter()),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text("Failed to upload image: $e", style: GoogleFonts.inter()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
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

    final int fwStandard = semesterLogs.where((l) =>
        l['activity_type'] == 'Field Work' &&
        l['check_out_time'] != null &&
        l['status'] != 'Absent' &&
        (l['field_work_type'] == 'Standard' || l['field_work_type'] == null)
    ).length;

    final int fwAdditional = semesterLogs.where((l) =>
        l['activity_type'] == 'Field Work' &&
        l['check_out_time'] != null &&
        l['status'] != 'Absent' &&
        l['field_work_type'] == 'Additional'
    ).length;

    final int fwCompensatory = semesterLogs.where((l) =>
        l['activity_type'] == 'Field Work' &&
        l['check_out_time'] != null &&
        l['status'] != 'Absent' &&
        l['field_work_type'] == 'Compensatory'
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

    // Hours logged calculations
    final now = DateTime.now();
    final oneWeekAgo = now.subtract(const Duration(days: 7));
    final oneMonthAgo = now.subtract(const Duration(days: 30));

    final double lastWeekHours = _logs.where((l) {
      if (l['activity_type'] != 'Field Work' || l['hours_logged'] == null) return false;
      final checkInStr = l['check_in_time']?.toString();
      if (checkInStr == null) return false;
      try {
        final dt = DateTime.parse(checkInStr);
        return dt.isAfter(oneWeekAgo);
      } catch (_) {
        return false;
      }
    }).fold<double>(0.0, (sum, l) => sum + ((l['hours_logged'] as num?)?.toDouble() ?? 0.0));

    final double lastMonthHours = _logs.where((l) {
      if (l['activity_type'] != 'Field Work' || l['hours_logged'] == null) return false;
      final checkInStr = l['check_in_time']?.toString();
      if (checkInStr == null) return false;
      try {
        final dt = DateTime.parse(checkInStr);
        return dt.isAfter(oneMonthAgo);
      } catch (_) {
        return false;
      }
    }).fold<double>(0.0, (sum, l) => sum + ((l['hours_logged'] as num?)?.toDouble() ?? 0.0));

    final double semesterHours = semesterLogs
        .where((l) => l['activity_type'] == 'Field Work' && l['hours_logged'] != null)
        .fold<double>(0.0, (sum, l) => sum + ((l['hours_logged'] as num?)?.toDouble() ?? 0.0));

    double? rangeHours;
    if (_rangeStartDate != null && _rangeEndDate != null) {
      final startMidnight = DateTime(_rangeStartDate!.year, _rangeStartDate!.month, _rangeStartDate!.day);
      final endMidnight = DateTime(_rangeEndDate!.year, _rangeEndDate!.month, _rangeEndDate!.day, 23, 59, 59);

      rangeHours = _logs.where((l) {
        if (l['activity_type'] != 'Field Work' || l['hours_logged'] == null) return false;
        final checkInStr = l['check_in_time']?.toString();
        if (checkInStr == null) return false;
        try {
          final dt = DateTime.parse(checkInStr);
          return dt.isAfter(startMidnight) && dt.isBefore(endMidnight);
        } catch (_) {
          return false;
        }
      }).fold<double>(0.0, (sum, l) => sum + ((l['hours_logged'] as num?)?.toDouble() ?? 0.0));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- PROFILE BANNER CARD ---
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentProfileDetailsPage(profile: _profile!),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey[200]!, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _uploadAvatar,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                              backgroundImage: _profile!['avatar_url'] != null
                                  ? NetworkImage(_profile!['avatar_url']?.toString() ?? '')
                                  : null,
                              child: _profile!['avatar_url'] == null
                                  ? const Icon(Icons.person_outline_rounded, color: Color(0xFF1E88E5), size: 32)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1E88E5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Reg: $regNo",
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "$department | $college",
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF1E88E5),
                        size: 24,
                      ),
                    ],
                  ),
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
                      extraDetails: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildDetailBadge("Standard: $fwStandard", Colors.blueAccent),
                          _buildDetailBadge("Additional: $fwAdditional", Colors.teal),
                          _buildDetailBadge("Compensatory: $fwCompensatory", Colors.orange),
                        ],
                      ),
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

              // --- HOURS LOGGED STATISTICS SECTION ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hours Logged Statistics",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildHoursStatCard(
                            title: "Last 7 Days",
                            hours: lastWeekHours,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildHoursStatCard(
                            title: "Last 30 Days",
                            hours: lastMonthHours,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildHoursStatCard(
                            title: "This Semester",
                            hours: semesterHours,
                            color: Colors.indigoAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // --- CUSTOM DATE RANGE PICKER ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: Colors.grey[200]!, width: 1.5),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber[50],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.date_range_rounded, color: Colors.amber, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Custom Date Range Filter",
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            if (_rangeStartDate != null && _rangeEndDate != null)
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                                onPressed: () {
                                  setState(() {
                                    _rangeStartDate = null;
                                    _rangeEndDate = null;
                                  });
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () async {
                            final DateTimeRange? picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2030),
                              initialDateRange: _rangeStartDate != null && _rangeEndDate != null
                                  ? DateTimeRange(start: _rangeStartDate!, end: _rangeEndDate!)
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
                                _rangeStartDate = picked.start;
                                _rangeEndDate = picked.end;
                              });
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.grey[200]!, width: 1.5),
                          ),
                          child: Text(
                            _rangeStartDate != null && _rangeEndDate != null
                                ? "${_rangeStartDate!.day}/${_rangeStartDate!.month}/${_rangeStartDate!.year} - ${_rangeEndDate!.day}/${_rangeEndDate!.month}/${_rangeEndDate!.year}"
                                : "Select Date Range",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (rangeHours != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[100]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Hours in Range:",
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                                ),
                                Text(
                                  () {
                                    final double rhVal = rangeHours!;
                                    final int rhH = rhVal.toInt();
                                    final int rhM = ((rhVal - rhH) * 60).round();
                                    return "${rhH.toString().padLeft(2, '0')}:${rhM.toString().padLeft(2, '0')}";
                                  }(),
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHoursStatCard({
    required String title,
    required double hours,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            () {
              final int h = hours.toInt();
              final int m = ((hours - h) * 60).round();
              return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
            }(),
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
