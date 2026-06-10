import 'package:flutter/material.dart';
import 'studentFilteredLogsPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';

class AttendanceMainPage extends StatelessWidget {
  const AttendanceMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AttendanceTrackerTab();
  }
}

// --- TAB 1: TRACKER LOGIC ---
class AttendanceTrackerTab extends StatefulWidget {
  const AttendanceTrackerTab({super.key});

  @override
  State<AttendanceTrackerTab> createState() => _AttendanceTrackerTabState();
}

class _AttendanceTrackerTabState extends State<AttendanceTrackerTab> {
  final supabase = Supabase.instance.client;
  String _selectedActivity = 'Field Work';
  String _selectedFieldWorkType = 'Standard';
  bool _isCheckIn = true;
  String? _activeRecordId;
  String? _activeCheckInTime;
  bool _isLoading = false;
  bool _isAbsent = false;
  bool _isHoliday = false;

  String? _semester;
  int? _collegeCode;
  String? _reportDeadlineStr;

  double _semesterHours = 0.0;
  int _reportsTotal = 0;
  int _confAttended = 0;

  @override
  void initState() {
    super.initState();
    _checkActiveSession();
  }

  Future<void> _checkActiveSession() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        // Fetch User Profile display_name, college_code, semester
        final profileResponse = await supabase
            .from('profiles')
            .select('display_name, college_code, semester')
            .eq('id', userId)
            .maybeSingle();

        if (profileResponse != null) {
          _semester = profileResponse['semester'] as String?;
          final rawCode = profileResponse['college_code'];
          if (rawCode != null) {
            _collegeCode = int.tryParse(rawCode.toString());
          }
        }

        // Fetch Schedule report_deadline & college_options if college_code is available
        if (_collegeCode != null) {
          final schedule = await supabase
              .from('college_schedule')
              .select('report_deadline')
              .eq('college_code', _collegeCode!)
              .maybeSingle();
          if (schedule != null) {
            _reportDeadlineStr = schedule['report_deadline']?.toString();
          }

          // Fetch semesters options
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

          final firstSem = sems.isNotEmpty ? sems.first : 'Semester I';

          // Fetch Student Logs
          final logsData = await supabase
              .from('attendance_logs')
              .select()
              .eq('user_id', userId);

          final List<Map<String, dynamic>> allLogs = List<Map<String, dynamic>>.from(logsData);

          // Filter by selected semester
          final semesterLogs = allLogs.where((l) {
            final lSem = l['semester']?.toString().trim();
            return lSem == _semester || (lSem == null && _semester == firstSem);
          }).toList();

          // Calculate actual stats
          final double semHrs = semesterLogs
              .where((l) => l['activity_type'] == 'Field Work' && l['hours_logged'] != null)
              .fold<double>(0.0, (sum, l) => sum + ((l['hours_logged'] as num?)?.toDouble() ?? 0.0));

          final int repTotal = semesterLogs.where((l) =>
              l['activity_type'] == 'Report' &&
              (l['status'] == 'On Time' || l['status'] == 'Late')
          ).length;

          final int confAtt = semesterLogs.where((l) =>
              l['activity_type'] == 'Conference' &&
              l['status'] == 'Present'
          ).length;

          setState(() {
            _semesterHours = semHrs;
            _reportsTotal = repTotal;
            _confAttended = confAtt;
          });
        }

        final response = await supabase
            .from('attendance_logs')
            .select()
            .eq('user_id', userId)
            .order('check_in_time', ascending: false)
            .limit(1);

        if (response.isNotEmpty) {
          final lastRecord = response.first;
          final bool isCheckedIn = lastRecord['check_out_time'] == null;
          if (isCheckedIn) {
            setState(() {
              _activeRecordId = lastRecord['id'];
              _activeCheckInTime = lastRecord['check_in_time']?.toString();
              _isCheckIn = false;
              _selectedActivity = lastRecord['activity_type'] ?? 'Field Work';
              _selectedFieldWorkType = lastRecord['field_work_type'] ?? 'Standard';
              _isAbsent = false; // Reset toggle if we are currently checked in
              _isHoliday = false;
            });
          } else {
            setState(() {
              _activeRecordId = null;
              _activeCheckInTime = null;
              _isCheckIn = true;
            });
          }
        } else {
          setState(() {
            _activeRecordId = null;
            _activeCheckInTime = null;
            _isCheckIn = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Error checking active session: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAction() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final nowStr = DateTime.now().toUtc().toIso8601String();

    if (_isAbsent || _isHoliday) {
      // One-shot check-in and check-out for Absent / Holiday (no camera, no location)
      setState(() => _isLoading = true);
      try {
        final statusVal = _isAbsent ? 'Absent' : 'Holiday';
        final oldIsAbsent = _isAbsent;

        await supabase.from('attendance_logs').insert({
          'user_id': userId,
          'activity_type': _selectedActivity,
          'status': statusVal,
          'check_in_lat': null,
          'check_in_lng': null,
          'check_in_img_url': null,
          'check_in_time': nowStr,
          'check_out_lat': null,
          'check_out_lng': null,
          'check_out_img_url': null,
          'check_out_time': nowStr,
          'is_active': false,
          'semester': _semester,
          'field_work_type': _selectedActivity == 'Field Work'
              ? (_isHoliday ? 'Holiday' : _selectedFieldWorkType)
              : null,
        });

        setState(() {
          _activeRecordId = null;
          _isCheckIn = true;
          _isAbsent = false;
          _isHoliday = false;
        });

        // Refresh stats and active session
        await _checkActiveSession();

        final snackMessage = oldIsAbsent ? "Absence recorded successfully!" : "Holiday recorded successfully!";
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              snackMessage,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
      return;
    }

    // --- STANDARD FLOW (Requires Location & Camera Photo) ---
    // 1. Check/Request Permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // 2. Open Camera Directly (mandatory for all actions)
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 25,
    );

    if (photo == null) return; // User cancelled

    setState(() => _isLoading = true);

    try {
      // 3. Get Location
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 4. Upload Photo
      final bytes = await photo.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$userId/$fileName';

      await supabase.storage
          .from('attendance')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final imgUrl = supabase.storage.from('attendance').getPublicUrl(path);
      
      final isOneShot = _selectedActivity == 'Report' || _selectedActivity == 'Conference';
      String statusVal = 'Present';
      if (_selectedActivity == 'Report') {
        if (_reportDeadlineStr != null) {
          try {
            final now = DateTime.now();
            final parts = _reportDeadlineStr!.split(':');
            final hour = int.parse(parts[0]);
            final minute = int.parse(parts[1]);
            final deadline = DateTime(now.year, now.month, now.day, hour, minute);
            if (now.isBefore(deadline) || now.isAtSameMomentAs(deadline)) {
              statusVal = 'On Time';
            } else {
              statusVal = 'Late';
            }
          } catch (_) {
            statusVal = 'On Time';
          }
        } else {
          statusVal = 'On Time';
        }
      }

      if (isOneShot) {
        await supabase.from('attendance_logs').insert({
          'user_id': userId,
          'activity_type': _selectedActivity,
          'status': statusVal,
          'check_in_lat': pos.latitude,
          'check_in_lng': pos.longitude,
          'check_in_img_url': imgUrl,
          'check_in_time': nowStr,
          'check_out_lat': pos.latitude,
          'check_out_lng': pos.longitude,
          'check_out_img_url': imgUrl,
          'check_out_time': nowStr,
          'is_active': false,
          'semester': _semester,
          'field_work_type': null,
        });

        setState(() {
          _activeRecordId = null;
          _isCheckIn = true;
        });
      } else {
        if (_isCheckIn) {
          final res = await supabase
              .from('attendance_logs')
              .insert({
                'user_id': userId,
                'activity_type': _selectedActivity,
                'status': 'Present',
                'check_in_lat': pos.latitude,
                'check_in_lng': pos.longitude,
                'check_in_img_url': imgUrl,
                'check_in_time': nowStr,
                'is_active': true,
                'semester': _semester,
                'field_work_type': _selectedActivity == 'Field Work' ? _selectedFieldWorkType : null,
              })
              .select()
              .single();

          setState(() {
            _activeRecordId = res['id'];
            _activeCheckInTime = nowStr;
            _isCheckIn = false;
          });
        } else {
          double hoursLogged = 0.0;
          String? checkInTimeStr = _activeCheckInTime;

          if (checkInTimeStr == null) {
            final record = await supabase
                .from('attendance_logs')
                .select('check_in_time')
                .eq('id', _activeRecordId!)
                .maybeSingle();
            if (record != null) {
              checkInTimeStr = record['check_in_time']?.toString();
            }
          }

          if (checkInTimeStr != null) {
            try {
              final checkIn = DateTime.parse(checkInTimeStr).toUtc();
              final checkOut = DateTime.parse(nowStr).toUtc();
              final diff = checkOut.difference(checkIn);
              hoursLogged = double.parse((diff.inMinutes / 60.0).toStringAsFixed(2));
              if (hoursLogged < 0) {
                hoursLogged = 0.0;
              }
            } catch (_) {}
          }

          await supabase
              .from('attendance_logs')
              .update({
                'check_out_time': nowStr,
                'check_out_lat': pos.latitude,
                'check_out_lng': pos.longitude,
                'check_out_img_url': imgUrl,
                'is_active': false,
                'hours_logged': hoursLogged,
              })
              .eq('id', _activeRecordId!);

          setState(() {
            _activeRecordId = null;
            _activeCheckInTime = null;
            _isCheckIn = true;
          });
        }
      }

      await _checkActiveSession();

      String snackMessage = "Action recorded successfully!";
      if (_selectedActivity == 'Report') {
        snackMessage = "Report submitted successfully!";
      } else if (_selectedActivity == 'Conference') {
        snackMessage = "Presented successfully!";
      } else {
        snackMessage = _isCheckIn ? "Checked Out successfully!" : "Checked In successfully!";
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            snackMessage,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
          ),
          backgroundColor: (_selectedActivity == 'Report' || _selectedActivity == 'Conference' || !_isCheckIn) 
              ? Colors.teal 
              : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }



  Widget _buildUnifiedStatsCard(String clockedHoursText) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!, width: 1.5),
      ),
      child: Column(
        children: [
          _buildStatRow(
            icon: Icons.access_time_rounded,
            title: "Field work hours",
            value: clockedHoursText,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StudentFilteredLogsPage(
                  filterActivity: 'Field Work',
                ),
              ),
            ),
          ),
          Divider(height: 16, color: Colors.grey[200]),
          _buildStatRow(
            icon: Icons.assignment_outlined,
            title: "Reports",
            value: "$_reportsTotal",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StudentFilteredLogsPage(
                  filterActivity: 'Report',
                ),
              ),
            ),
          ),
          Divider(height: 16, color: Colors.grey[200]),
          _buildStatRow(
            icon: Icons.forum_outlined,
            title: "Confs",
            value: "$_confAttended",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StudentFilteredLogsPage(
                  filterActivity: 'Conference',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF1E88E5), size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E88E5),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomDropdownCard({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.grey[600],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 28),
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              selectedItemBuilder: (BuildContext context) {
                return items.map<Widget>((String item) {
                  return Row(
                    children: [
                      Icon(icon, color: const Color(0xFF1E88E5), size: 24),
                      const SizedBox(width: 12),
                      Text(
                        item,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Row(
                    children: [
                      Icon(icon, color: const Color(0xFF1E88E5), size: 24),
                      const SizedBox(width: 12),
                      Text(
                        item,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF1E88E5),
            activeTrackColor: const Color(0xFF1E88E5).withValues(alpha: 0.2),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionCard() {
    final activityName = _selectedActivity == 'Field Work'
        ? 'Field Work - $_selectedFieldWorkType'
        : _selectedActivity;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFB2DFDB), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFB2DFDB),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sensors_rounded,
              color: Color(0xFF00796B),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activityName,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00796B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Tracking active. Make sure to check out.",
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: const Color(0xFF004D40),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final String buttonText;
    final IconData buttonIcon;

    if (_selectedActivity == 'Report') {
      buttonText = "SUBMIT REPORT";
      buttonIcon = Icons.assignment_outlined;
    } else if (_isAbsent) {
      buttonText = "RECORD ABSENCE";
      buttonIcon = Icons.person_off_outlined;
    } else if (_isHoliday) {
      buttonText = "RECORD HOLIDAY";
      buttonIcon = Icons.beach_access_outlined;
    } else if (_selectedActivity == 'Conference' && _isCheckIn) {
      buttonText = "PRESENT";
      buttonIcon = Icons.co_present_outlined;
    } else {
      buttonText = _isCheckIn ? "CHECK IN" : "CHECK OUT";
      buttonIcon = _isCheckIn ? Icons.camera_alt_outlined : Icons.logout_outlined;
    }

    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withValues(alpha: 0.25),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _handleAction,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Icon(buttonIcon, color: Colors.white, size: 24),
        label: Text(
          buttonText,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E88E5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Format clocked hours cleanly (omit decimal if it is integer)
    final String clockedHoursText = _semesterHours % 1 == 0
        ? "${_semesterHours.toInt()}h"
        : "${_semesterHours.toStringAsFixed(1)}h";

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unified Statistics Card
            _buildUnifiedStatsCard(clockedHoursText),
            const SizedBox(height: 24),

            // Dropdowns / Switched Action Panel
            if (_isCheckIn) ...[
              _buildCustomDropdownCard(
                label: "WORK CATEGORY",
                icon: Icons.work_outline_rounded,
                value: _selectedActivity,
                items: ['Field Work', 'Report', 'Conference'],
                onChanged: (v) {
                  setState(() {
                    _selectedActivity = v!;
                    if (_selectedActivity != 'Field Work' && _selectedActivity != 'Conference') {
                      _isHoliday = false;
                      _isAbsent = false;
                    }
                  });
                },
              ),
              if (_selectedActivity == 'Field Work') ...[
                const SizedBox(height: 16),
                _buildCustomDropdownCard(
                  label: "FIELD WORK TYPE",
                  icon: Icons.assignment_turned_in_outlined,
                  value: _selectedFieldWorkType,
                  items: ['Standard', 'Compensatory', 'Additional'],
                  onChanged: (v) {
                    setState(() {
                      _selectedFieldWorkType = v!;
                    });
                  },
                ),
              ],
              if (_selectedActivity != 'Report') ...[
                const SizedBox(height: 16),
                _buildSwitchCard(
                  title: "Mark as Absent",
                  subtitle: "Not attending today",
                  icon: Icons.person_off_outlined,
                  iconColor: const Color(0xFFE53935),
                  iconBgColor: const Color(0xFFFFEBEE),
                  value: _isAbsent,
                  onChanged: (bool value) {
                    setState(() {
                      _isAbsent = value;
                      if (value) {
                        _isHoliday = false;
                      }
                    });
                  },
                ),
              ],
              if (_selectedActivity == 'Field Work' || _selectedActivity == 'Conference') ...[
                const SizedBox(height: 16),
                _buildSwitchCard(
                  title: "Mark as Holiday",
                  subtitle: "Public or field holiday",
                  icon: Icons.beach_access_outlined,
                  iconColor: const Color(0xFFF2994A),
                  iconBgColor: const Color(0xFFFFF3E0),
                  value: _isHoliday,
                  onChanged: (bool value) {
                    setState(() {
                      _isHoliday = value;
                      if (value) {
                        _isAbsent = false;
                      }
                    });
                  },
                ),
              ],
            ] else ...[
              _buildActiveSessionCard(),
            ],
            const SizedBox(height: 48),

            // Action Button & Instructions
            Center(
              child: _buildActionButton(),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                "Face capture and location will be logged",
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TAB 2: LOGS VIEW ---
class AttendanceLogsView extends StatelessWidget {
  const AttendanceLogsView({super.key});

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '--:--';
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return "$hour:$min $period";
    } catch (e) {
      return timeStr;
    }
  }

  String _formatDate(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return "${dt.day} ${months[dt.month - 1]}";
    } catch (e) {
      return timeStr;
    }
  }

  Widget _buildActivityBadge(String activity) {
    Color bgColor;
    Color textColor;
    switch (activity) {
      case 'Field Work':
        bgColor = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1E88E5);
        break;
      case 'Conference':
        bgColor = const Color(0xFFF3E5F5);
        textColor = const Color(0xFF8E24AA);
        break;
      case 'Report':
        bgColor = const Color(0xFFE0F2F1);
        textColor = const Color(0xFF00897B);
        break;
      default:
        bgColor = const Color(0xFFECEFF1);
        textColor = const Color(0xFF607D8B);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        activity,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    if (status != 'Absent' && status != 'Holiday') return const SizedBox.shrink();
    final isAbsent = status == 'Absent';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAbsent ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAbsent ? const Color(0xFFFFCDD2) : const Color(0xFFFFE0B2),
          width: 1,
        ),
      ),
      child: Text(
        status,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isAbsent ? const Color(0xFFC62828) : const Color(0xFFE65100),
        ),
      ),
    );
  }

  Widget _buildDurationBadge(String checkInStr, String? checkOutStr) {
    if (checkOutStr == null) return const SizedBox.shrink();
    try {
      final checkIn = DateTime.parse(checkInStr);
      final checkOut = DateTime.parse(checkOutStr);
      final diff = checkOut.difference(checkIn);
      final hours = diff.inHours;
      final minutes = diff.inMinutes.remainder(60);
      
      String durationText = "";
      if (hours > 0) {
        durationText += "${hours}h ";
      }
      durationText += "${minutes}m";

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, size: 12, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              durationText,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      return Center(
        child: Text(
          "No user logged in",
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('attendance_logs')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('check_in_time'),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error loading logs: ${snapshot.error}",
              style: GoogleFonts.outfit(),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.black));
        }

        final logs = snapshot.data!;
        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  "No attendance records found",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        // We sort the list descending (newest first) based on check_in_time
        final displayedLogs = List<Map<String, dynamic>>.from(logs);
        displayedLogs.sort((a, b) {
          final aTimeStr = a['check_in_time'] as String?;
          final bTimeStr = b['check_in_time'] as String?;
          if (aTimeStr == null && bTimeStr == null) return 0;
          if (aTimeStr == null) return 1;
          if (bTimeStr == null) return -1;
          final aTime = DateTime.tryParse(aTimeStr);
          final bTime = DateTime.tryParse(bTimeStr);
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: displayedLogs.length,
          itemBuilder: (context, i) {
            final log = displayedLogs[i];
            final checkOutTime = log['check_out_time'];
            final logStatus = log['status'] ?? 'Present';
            final isAbsent = logStatus == 'Absent';
            final isHoliday = logStatus == 'Holiday';
            final isReport = log['activity_type'] == 'Report';

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey[100]!, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Thumbnail Image
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey[200]!, width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: log['check_in_img_url'] != null
                              ? Image.network(
                                  log['check_in_img_url'] as String,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Icon(
                                    isAbsent
                                        ? Icons.person_off_rounded
                                        : (isHoliday
                                            ? Icons.beach_access_rounded
                                            : Icons.person_rounded),
                                    color: Colors.grey,
                                    size: 28,
                                  ),
                                )
                              : Icon(
                                  isAbsent
                                      ? Icons.person_off_rounded
                                      : (isHoliday
                                          ? Icons.beach_access_rounded
                                          : Icons.person_rounded),
                                  color: Colors.grey,
                                  size: 28,
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Log Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    _buildActivityBadge(log['activity_type'] ?? 'Field Work'),
                                    if (isAbsent || isHoliday) ...[
                                      const SizedBox(width: 8),
                                      _buildStatusBadge(logStatus),
                                    ],
                                  ],
                                ),
                                if (checkOutTime != null &&
                                     !isAbsent &&
                                     !isHoliday &&
                                     log['activity_type'] == 'Field Work')
                                   _buildDurationBadge(log['check_in_time'], checkOutTime),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            if (isAbsent || isHoliday) ...[
                              // Absent / Holiday representation
                              Row(
                                children: [
                                  Icon(
                                    isAbsent ? Icons.person_off_rounded : Icons.beach_access_rounded,
                                    color: isAbsent ? Colors.redAccent : const Color(0xFFF2994A),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${isAbsent ? 'Logged' : 'Holiday'}: ${_formatTime(log['check_in_time'])} (${_formatDate(log['check_in_time'])})",
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (isReport || log['activity_type'] == 'Conference') ...[
                              // One-shot representation (Report or Conference)
                              Row(
                                children: [
                                  Icon(
                                    isReport ? Icons.task_alt_rounded : Icons.co_present_rounded,
                                    color: isReport ? Colors.teal : Colors.purple,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${isReport ? 'Submitted' : 'Presented'}: ${_formatTime(log['check_in_time'])} (${_formatDate(log['check_in_time'])})",
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              // Check-in info
                              Row(
                                children: [
                                  const Icon(Icons.login_rounded, color: Colors.green, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    "In: ${_formatTime(log['check_in_time'])} (${_formatDate(log['check_in_time'])})",
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              // Check-out info
                              Row(
                                children: [
                                  Icon(
                                    Icons.logout_rounded,
                                    color: checkOutTime != null ? Colors.red : Colors.orange,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    checkOutTime != null
                                        ? "Out: ${_formatTime(checkOutTime)} (${_formatDate(checkOutTime)})"
                                        : "Active session",
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: checkOutTime != null ? Colors.black87 : Colors.orange[800],
                                      fontWeight: checkOutTime != null ? FontWeight.w400 : FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Map View Button
                      if (log['check_in_lat'] != null && log['check_in_lng'] != null)
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!, width: 1),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.map_rounded, color: Colors.blueAccent, size: 20),
                            onPressed: () => _openMap(context, log),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openMap(BuildContext context, Map log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Bottom sheet drag handle
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 16),
            
            // Header Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${log['activity_type']} Route",
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          "Visualizing logging locations",
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Colors.black87),
                      onPressed: () => Navigator.pop(c),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Map Widget Area
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
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
                        // Check In Marker
                        Marker(
                          point: LatLng(log['check_in_lat'], log['check_in_lng']),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const Icon(
                                Icons.location_on_rounded,
                                color: Colors.green,
                                size: 30,
                              ),
                            ],
                          ),
                        ),
                        // Check Out Marker
                        if (log['check_out_lat'] != null)
                          Marker(
                            point: LatLng(log['check_out_lat'], log['check_out_lng']),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.red,
                                  size: 30,
                                ),
                              ],
                            ),
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
