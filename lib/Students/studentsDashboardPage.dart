import 'package:flutter/material.dart';
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.grey[50],
          elevation: 0,
          toolbarHeight: 0, // Hides standard App Bar title area to stack seamlessly
          bottom: TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey[500],
            indicatorColor: Colors.black,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            unselectedLabelStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on_rounded, size: 20),
                    SizedBox(width: 8),
                    Text("Track"),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_rounded, size: 20),
                    SizedBox(width: 8),
                    Text("History"),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AttendanceTrackerTab(),
            AttendanceLogsView(),
          ],
        ),
      ),
    );
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
  String _displayName = 'Student';
  bool _isAbsent = false;
  bool _isHoliday = false;

  String? _semester;
  int? _collegeCode;
  String? _reportDeadlineStr;

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
          if (profileResponse['display_name'] != null) {
            _displayName = profileResponse['display_name'] as String;
          }
          _semester = profileResponse['semester'] as String?;
          final rawCode = profileResponse['college_code'];
          if (rawCode != null) {
            _collegeCode = int.tryParse(rawCode.toString());
          }
        }

        // Fetch Schedule report_deadline if college_code is available
        if (_collegeCode != null) {
          final schedule = await supabase
              .from('college_schedule')
              .select('report_deadline')
              .eq('college_code', _collegeCode!)
              .maybeSingle();
          if (schedule != null) {
            _reportDeadlineStr = schedule['report_deadline']?.toString();
          }
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
    // 1. Check/Request Permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // 2. Open Camera Directly (mandatory for all actions)
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera, // Forces the camera UI
      preferredCameraDevice: CameraDevice.front, // Suggested for attendance
      imageQuality: 25, // Compress to save Supabase storage space
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
      final userId = supabase.auth.currentUser!.id;
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
      
      final nowStr = DateTime.now().toIso8601String();
      final isOneShot = _selectedActivity == 'Report' || _isAbsent || _isHoliday;
      String statusVal = 'Present';
      if (_isAbsent) {
        statusVal = 'Absent';
      } else if (_isHoliday) {
        statusVal = 'Holiday';
      } else if (_selectedActivity == 'Report') {
        // Calculate On Time vs Late status based on deadline
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
          statusVal = 'On Time'; // Fallback
        }
      }

      if (isOneShot) {
        // One-shot session completion: populate both check-in and check-out fields instantly
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
          'field_work_type': _selectedActivity == 'Field Work'
              ? (_isHoliday ? 'Holiday' : _selectedFieldWorkType)
              : null,
        });

        setState(() {
          _activeRecordId = null;
          _isCheckIn = true;
          _isAbsent = false;
          _isHoliday = false; // Reset switch state
        });
      } else {
        // Standard check-in / check-out session flow
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
            // Fetch check-in time from Supabase as a fallback
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
              final checkIn = DateTime.parse(checkInTimeStr);
              final checkOut = DateTime.parse(nowStr);
              final diff = checkOut.difference(checkIn);
              hoursLogged = double.parse((diff.inMinutes / 60.0).toStringAsFixed(2));
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

      String snackMessage = "Action recorded successfully!";
      if (_selectedActivity == 'Report') {
        snackMessage = "Report submitted successfully!";
      } else if (_isAbsent) {
        snackMessage = "Absence recorded successfully!";
      } else if (_isHoliday) {
        snackMessage = "Holiday recorded successfully!";
      } else {
        snackMessage = _isCheckIn ? "Checked Out!" : "Checked In!";
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            snackMessage,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
          ),
          backgroundColor: (_selectedActivity == 'Report' || !_isCheckIn) ? Colors.teal : Colors.redAccent,
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
      setState(() => _isLoading = false);
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return "${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}";
  }

  @override
  Widget build(BuildContext context) {
    // Determine button properties based on state
    final String buttonText;
    final String buttonSubtitle;
    final List<Color> buttonGradient;
    final Color shadowColor;

    if (_selectedActivity == 'Report') {
      buttonText = "SUBMIT REPORT";
      buttonSubtitle = "Tap to submit report";
      buttonGradient = [const Color(0xFF11998E), const Color(0xFF38EF7D)];
      shadowColor = const Color(0xFF38EF7D);
    } else if (_isAbsent) {
      buttonText = "RECORD ABSENCE";
      buttonSubtitle = "Tap to record absence";
      buttonGradient = [const Color(0xFFE53935), const Color(0xFFD32F2F)];
      shadowColor = const Color(0xFFE53935);
    } else if (_isHoliday) {
      buttonText = "RECORD HOLIDAY";
      buttonSubtitle = "Tap to record holiday";
      buttonGradient = [const Color(0xFFF2994A), const Color(0xFFF2C94C)]; // Golden orange gradient
      shadowColor = const Color(0xFFF2C94C);
    } else {
      if (_selectedActivity == 'Conference' && _isCheckIn) {
        buttonText = "PRESENT";
      } else {
        buttonText = _isCheckIn ? "CHECK IN" : "CHECK OUT";
      }
      buttonSubtitle = _isCheckIn ? "Tap to record" : "Tap to complete";
      buttonGradient = _isCheckIn
          ? [const Color(0xFF11998E), const Color(0xFF38EF7D)]
          : [const Color(0xFFE53935), const Color(0xFFE35D5B)];
      shadowColor = _isCheckIn ? const Color(0xFF38EF7D) : const Color(0xFFE53935);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hey, Welcome 👋",
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _displayName,
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  _getFormattedDate(),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Main Status / Config Panel
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isCheckIn ? "Start a New Session" : "Active Session In Progress",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Dropdown / Active Info
                  if (_isCheckIn) ...[
                    Text(
                      "Select Activity Type",
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedActivity,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.work_outline_rounded, color: Colors.black54),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black54),
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      dropdownColor: Colors.white,
                      items: ['Report', 'Conference', 'Field Work']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedActivity = v!;
                          if (_selectedActivity != 'Field Work') {
                            _isHoliday = false;
                          }
                          if (_selectedActivity == 'Report') {
                            _isAbsent = false;
                          }
                        });
                      },
                    ),
                    if (_selectedActivity == 'Field Work') ...[
                      const SizedBox(height: 16),
                      Text(
                        "Select Field Work Type",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedFieldWorkType,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.assignment_turned_in_outlined, color: Colors.black54),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.black, width: 2),
                          ),
                        ),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black54),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        dropdownColor: Colors.white,
                        items: ['Standard', 'Compensatory', 'Additional']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedFieldWorkType = v!;
                          });
                        },
                      ),
                    ],
                    if (_selectedActivity != 'Report') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isAbsent ? Colors.red[50] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isAbsent ? Colors.red[200]! : Colors.grey[200]!,
                            width: 1.5,
                          ),
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            "Mark as Absent today",
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _isAbsent ? Colors.red[900] : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            "Toggle this if you are not attending",
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: _isAbsent ? Colors.red[700] : Colors.grey[500],
                            ),
                          ),
                          secondary: Icon(
                            _isAbsent ? Icons.person_off_rounded : Icons.person_rounded,
                            color: _isAbsent ? Colors.red : Colors.grey,
                          ),
                          activeColor: Colors.redAccent,
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
                      ),
                    ],
                    if (_selectedActivity == 'Field Work') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isHoliday ? Colors.orange[50] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isHoliday ? Colors.orange[200]! : Colors.grey[200]!,
                            width: 1.5,
                          ),
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            "Mark as Holiday today",
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _isHoliday ? Colors.orange[900] : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            "Toggle this if today is a field work holiday",
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: _isHoliday ? Colors.orange[700] : Colors.grey[500],
                            ),
                          ),
                          secondary: Icon(
                            _isHoliday ? Icons.beach_access_rounded : Icons.beach_access_outlined,
                            color: _isHoliday ? Colors.orange : Colors.grey,
                          ),
                          activeColor: Colors.orangeAccent,
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
                      ),
                    ],
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFB2DFDB), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sensors_rounded, color: Color(0xFF00796B), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedActivity == 'Field Work' ? 'Field Work - $_selectedFieldWorkType' : _selectedActivity,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF00796B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Tracking active. Make sure to check out.",
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF004D40),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 48),

            // High Fidelity Action Button
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : GestureDetector(
                      onTap: _handleAction,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: shadowColor.withValues(alpha: 0.25),
                              blurRadius: 35,
                              spreadRadius: 8,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer decorative ring
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: shadowColor.withValues(alpha: 0.15),
                                  width: 8,
                                ),
                              ),
                            ),
                            // Button body
                            Container(
                              margin: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: buttonGradient,
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.photo_camera_rounded,
                                      color: Colors.white,
                                      size: 44,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      buttonText,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      buttonSubtitle,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                "Face capture and location will be logged",
                style: GoogleFonts.outfit(
                  fontSize: 12,
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
    if (status != 'Absent') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFCDD2), width: 1),
      ),
      child: Text(
        "Absent",
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFC62828),
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
                          child: Image.network(
                            log['check_in_img_url'] ?? '',
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.person_rounded,
                              color: Colors.grey,
                              size: 28,
                            ),
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
                                    if (isAbsent) ...[
                                      const SizedBox(width: 8),
                                      _buildStatusBadge('Absent'),
                                    ],
                                  ],
                                ),
                                if (checkOutTime != null && !isAbsent && !isReport)
                                  _buildDurationBadge(log['check_in_time'], checkOutTime),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            if (isAbsent) ...[
                              // Absent representation
                              Row(
                                children: [
                                  const Icon(Icons.person_off_rounded, color: Colors.redAccent, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Logged: ${_formatTime(log['check_in_time'])} (${_formatDate(log['check_in_time'])})",
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (isReport) ...[
                              // Report representation
                              Row(
                                children: [
                                  const Icon(Icons.task_alt_rounded, color: Colors.teal, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Submitted: ${_formatTime(log['check_in_time'])} (${_formatDate(log['check_in_time'])})",
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
