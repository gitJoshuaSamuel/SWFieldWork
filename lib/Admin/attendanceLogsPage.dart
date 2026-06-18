import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../widgets/adaptive_map_view.dart';

class AttendanceLogsPage extends StatefulWidget {
  const AttendanceLogsPage({super.key});

  @override
  State<AttendanceLogsPage> createState() => _AttendanceLogsPageState();
}

class _AttendanceLogsPageState extends State<AttendanceLogsPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  int? _collegeCode;
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _allLogs = [];

  // Filter States
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedStudentId; // null means "All Students"
  String _studentPickerSearch = '';

  // Dynamic Grouping Levels
  String _groupLevel1 = 'None';
  String _groupLevel2 = 'None';
  String _groupLevel3 = 'None';
  String _groupLevel4 = 'None';

  final List<String> _groupingOptions = [
    'None',
    'Batch',
    'Semester',
    'Activity Type',
    'Status',
    'Student Name',
    'Faculty Supervisor (Professor)'
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
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

          // 2. Fetch Student Profiles
          final studentsData = await supabase
              .from('profiles')
              .select()
              .eq('role', 'Student');

          final List<Map<String, dynamic>> allProfiles = List<Map<String, dynamic>>.from(studentsData);
          _allStudents = allProfiles.where((p) {
            final pCode = p['college_code'] ?? p['secret_code'];
            return pCode?.toString() == code.toString();
          }).toList();

          // Sort students by name
          _allStudents.sort((a, b) => (a['display_name']?.toString() ?? '')
              .toLowerCase()
              .compareTo((b['display_name']?.toString() ?? '').toLowerCase()));

          // 3. Fetch Attendance Logs
          final logsData = await supabase
              .from('attendance_logs')
              .select('*, profiles(id, display_name, registration_no, college_code, secret_code, class, batch, semester, faculty_supervisor, agency_supervisor, organisation_placed)')
              .order('check_in_time', ascending: false);

          final List<Map<String, dynamic>> allLogs = List<Map<String, dynamic>>.from(logsData);
          _allLogs = allLogs.where((log) {
            if (log['profiles'] == null) return false;
            final lCode = log['profiles']['college_code'];
            return lCode?.toString() == code.toString();
          }).toList();
        }
      }
    } catch (e) {
      debugPrint("Error loading logs page data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
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

  void _showStudentPicker(BuildContext context) {
    _studentPickerSearch = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final List<Map<String, dynamic>> filteredModalStudents = _allStudents.where((student) {
              final name = student['display_name']?.toString().toLowerCase() ?? '';
              return name.contains(_studentPickerSearch.toLowerCase());
            }).toList();

            return Container(
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
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5))),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Select Student", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search student by name...",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          _studentPickerSearch = val;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        ListTile(
                          title: Text("All Students", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          selected: _selectedStudentId == null,
                          onTap: () {
                            setState(() {
                              _selectedStudentId = null;
                            });
                            Navigator.pop(context);
                          },
                        ),
                        const Divider(),
                        ...filteredModalStudents.map((student) {
                          final sId = student['id']?.toString();
                          final name = student['display_name'] ?? 'Student';
                          final regNo = student['registration_no'] ?? 'N/A';
                          return ListTile(
                            title: Text(name, style: GoogleFonts.inter(fontSize: 14)),
                            subtitle: Text("Reg: $regNo",
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
                            selected: _selectedStudentId == sId,
                            onTap: () {
                              setState(() {
                                _selectedStudentId = sId;
                              });
                              Navigator.pop(context);
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLogDetailsDialog(Map<String, dynamic> log) {
    final profile = log['profiles'] ?? {};
    final display = profile['display_name'] ?? 'Student';
    final regNo = profile['registration_no'] ?? 'N/A';
    final activityType = log['activity_type'] ?? 'Field Work';
    final status = log['status'] ?? 'Present';
    final checkIn = log['check_in_time'] != null ? DateTime.parse(log['check_in_time']).toLocal() : null;
    final checkOut = log['check_out_time'] != null ? DateTime.parse(log['check_out_time']).toLocal() : null;

    final dateStr = checkIn != null ? DateFormat('EEEE, dd MMMM yyyy').format(checkIn) : 'N/A';
    final checkInStr = checkIn != null ? DateFormat('hh:mm a').format(checkIn) : '--:--';
    final checkOutStr = checkOut != null ? DateFormat('hh:mm a').format(checkOut) : '--:--';
    final hasCoords = log['check_in_lat'] != null && log['check_in_lng'] != null;

    double hours = 0.0;
    if (log['hours_logged'] != null) {
      hours = (log['hours_logged'] as num).toDouble();
    } else if (log['check_in_time'] != null && log['check_out_time'] != null) {
      final inT = DateTime.parse(log['check_in_time'].toString());
      final outT = DateTime.parse(log['check_out_time'].toString());
      hours = outT.difference(inT).inMinutes / 60.0;
    }

    final int h = hours.toInt();
    final int m = ((hours - h) * 60).round();
    final String durationStr = "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
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
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5))),
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
                        Text(display, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text("Reg: $regNo | $activityType | $dateStr",
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(height: 20),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Photo Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Logged Image",
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              color: Colors.grey[100],
                              width: double.infinity,
                              height: 200,
                              child: log['check_in_img_url'] != null
                                  ? Image.network(
                                      log['check_in_img_url']!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey)),
                                    )
                                  : const Center(child: Icon(Icons.person_outline_rounded, size: 48, color: Colors.grey)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Details Metadata Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Log Details", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Status", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                                    Text(status, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _getStatusColor(status))),
                                  ],
                                ),
                                if (hours > 0 || checkOut != null) ...[
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Total Time Logged", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                                      Text(durationStr, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    ],
                                  ),
                                ],
                                const Divider(height: 16),
                                if (activityType == 'Field Work') ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Check In Time", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                                      Text(checkInStr, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Check Out Time", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                                      Text(checkOutStr, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                                    ],
                                  ),
                                ] else if (activityType == 'Report') ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Submission Time", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                                      Text(checkInStr, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                                    ],
                                  ),
                                ] else if (activityType == 'Conference') ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Attendance Time", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                                      Text(checkInStr, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Map Section
                    if (hasCoords) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Location Coordinates",
                              style:
                                  GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 250,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AdaptiveMapView(
                            checkInLat: log['check_in_lat'],
                            checkInLng: log['check_in_lng'],
                            checkOutLat: log['check_out_lat'],
                            checkOutLng: log['check_out_lng'],
                            largeMarkers: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityChip(String type) {
    Color color;
    if (type == 'Field Work') {
      color = Colors.blue;
    } else if (type == 'Report') {
      color = Colors.teal;
    } else {
      color = Colors.purple;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        type,
        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'Present' || status == 'On Time') return Colors.green[700]!;
    if (status == 'Late') return Colors.orange[800]!;
    return Colors.red[700]!;
  }

  Color _getGroupColor(String field) {
    if (field == 'Semester') return Colors.indigo[800]!;
    if (field == 'Batch') return Colors.orange[800]!;
    if (field == 'Activity Type') return Colors.teal[800]!;
    if (field == 'Status') return Colors.purple[800]!;
    if (field == 'Student Name') return Colors.pink[800]!;
    if (field == 'Faculty Supervisor (Professor)') return Colors.blueGrey[800]!;
    return Colors.black87;
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final profile = log['profiles'] ?? {};
    final display = profile['display_name'] ?? 'Student';
    final regNo = profile['registration_no'] ?? 'N/A';
    final activityType = log['activity_type'] ?? 'Field Work';
    final status = log['status'] ?? 'Present';
    final checkIn = log['check_in_time'] != null ? DateTime.parse(log['check_in_time']).toLocal() : null;
    final checkOut = log['check_out_time'] != null ? DateTime.parse(log['check_out_time']).toLocal() : null;

    final dateStr = checkIn != null ? DateFormat('dd/MM/yyyy').format(checkIn) : 'N/A';
    final checkInStr = checkIn != null ? DateFormat('hh:mm a').format(checkIn) : '--:--';
    final checkOutStr = checkOut != null ? DateFormat('hh:mm a').format(checkOut) : 'Active';

    double hours = 0.0;
    if (log['hours_logged'] != null) {
      hours = (log['hours_logged'] as num).toDouble();
    } else if (log['check_in_time'] != null && log['check_out_time'] != null) {
      final inT = DateTime.parse(log['check_in_time'].toString());
      final outT = DateTime.parse(log['check_out_time'].toString());
      hours = outT.difference(inT).inMinutes / 60.0;
    }

    final int h = hours.toInt();
    final int m = ((hours - h) * 60).round();
    final String durationStr = "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1.0),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showLogDetailsDialog(log),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      display,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                  _buildActivityChip(activityType),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Reg: $regNo | $dateStr", style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 12),
              if (activityType == 'Field Work') ...[
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
                ),
                if (hours > 0 || checkOut != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Text(
                      "Hours: $durationStr",
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ),
                ],
              ] else if (activityType == 'Report') ...[
                Row(
                  children: [
                    Icon(Icons.description_rounded, size: 12, color: Colors.teal[600]),
                    const SizedBox(width: 4),
                    Text("Report Submitted: $checkInStr", style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[700])),
                  ],
                ),
                if (hours > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.teal[100]!),
                    ),
                    child: Text(
                      "Hours: $durationStr",
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800],
                      ),
                    ),
                  ),
                ],
              ] else if (activityType == 'Conference') ...[
                Row(
                  children: [
                    Icon(Icons.forum_rounded, size: 12, color: Colors.purple[600]),
                    const SizedBox(width: 4),
                    Text("Conference In: $checkInStr", style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[700])),
                  ],
                ),
                if (hours > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.purple[100]!),
                    ),
                    child: Text(
                      "Hours: $durationStr",
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[800],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupTree(List<Map<String, dynamic>> items, List<String> groupingFields, int fieldIndex) {
    if (fieldIndex >= groupingFields.length || groupingFields[fieldIndex] == 'None') {
      return Column(
        children: items.map((log) => _buildLogCard(log)).toList(),
      );
    }

    final field = groupingFields[fieldIndex];
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in items) {
      final profile = item['profiles'] ?? {};
      String key = 'Unknown';
      if (field == 'Semester') {
        key = profile['semester']?.toString() ?? 'Unknown Semester';
      } else if (field == 'Batch') {
        key = item['batch']?.toString() ?? profile['batch']?.toString() ?? 'Unknown Batch';
      } else if (field == 'Activity Type') {
        key = item['activity_type']?.toString() ?? 'Unknown Activity';
      } else if (field == 'Status') {
        key = item['status']?.toString() ?? 'Unknown Status';
      } else if (field == 'Student Name') {
        key = profile['display_name']?.toString() ?? 'Unknown Student';
      } else if (field == 'Faculty Supervisor (Professor)') {
        key = profile['faculty_supervisor']?.toString() ?? 'No Faculty Supervisor';
      }
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(item);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    return Column(
      children: sortedKeys.map((key) {
        final list = grouped[key]!;
        final themeColor = _getGroupColor(field);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: themeColor.withValues(alpha: 0.15), width: 1.0),
          ),
          color: themeColor.withValues(alpha: 0.02),
          child: ExpansionTile(
            title: Text(
              "$key (${list.length})",
              style: GoogleFonts.inter(
                fontSize: 13.5 - (fieldIndex * 0.5),
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ),
            childrenPadding: const EdgeInsets.only(left: 12, right: 8, bottom: 8),
            shape: const Border(),
            collapsedShape: const Border(),
            children: [
              _buildGroupTree(list, groupingFields, fieldIndex + 1),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
      ),
    );
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

    // Filter Logs according to state
    final List<Map<String, dynamic>> filteredLogs = _allLogs.where((log) {
      final profile = log['profiles'] ?? {};
      final sId = profile['id']?.toString();

      // Student filter
      if (_selectedStudentId != null && sId != _selectedStudentId) return false;

      // Date Range Filters
      final checkInTimeStr = log['check_in_time']?.toString();
      if (checkInTimeStr != null) {
        try {
          final dt = DateTime.parse(checkInTimeStr).toLocal();
          if (_startDate != null) {
            final startMidnight = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
            if (dt.isBefore(startMidnight)) return false;
          }
          if (_endDate != null) {
            final endMidnight = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
            if (dt.isAfter(endMidnight)) return false;
          }
        } catch (_) {
          return false;
        }
      } else {
        return false;
      }

      return true;
    }).toList();

    // Collect grouping fields in order
    final List<String> groupingFields = [_groupLevel1, _groupLevel2, _groupLevel3, _groupLevel4];

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
                    "Attendance Logs Viewer",
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchData,
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

            // --- FILTERS & ACCORDION SETTINGS PANEL ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey[200]!, width: 1.5),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Date and Search Picker
                      Row(
                        children: [
                          // Searchable Student Picker Tile
                          Expanded(
                            child: InkWell(
                              onTap: () => _showStudentPicker(context),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedStudentId == null
                                            ? "All Students"
                                            : _allStudents.firstWhere(
                                                (s) => s['id']?.toString() == _selectedStudentId,
                                                orElse: () => {'display_name': 'Select Student'},
                                              )['display_name'] ?? 'Select Student',
                                        style: GoogleFonts.inter(
                                            fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(Icons.arrow_drop_down, color: Colors.grey[600], size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Date range picker trigger button
                          InkWell(
                            onTap: () => _selectDateRange(context),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_month_rounded, color: Colors.grey[600], size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    _startDate == null || _endDate == null
                                        ? "Date Range"
                                        : "${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}",
                                    style: GoogleFonts.inter(
                                        fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                                  ),
                                  if (_startDate != null) ...[
                                    const SizedBox(width: 4),
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
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Group By Configuration Dropdowns (Expansion accordion hierarchy)
                      ExpansionTile(
                        title: Text(
                          "Configure Grouping Accordions",
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                        ),
                        leading: const Icon(Icons.layers_rounded, size: 18),
                        collapsedBackgroundColor: Colors.grey[50],
                        backgroundColor: Colors.grey[50],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        childrenPadding: const EdgeInsets.all(12),
                        dense: true,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildFilterDropdown(
                                  label: "Level 1 Group",
                                  value: _groupLevel1,
                                  items: _groupingOptions,
                                  onChanged: (val) => setState(() => _groupLevel1 = val!),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildFilterDropdown(
                                  label: "Level 2 Group",
                                  value: _groupLevel2,
                                  items: _groupingOptions,
                                  onChanged: (val) => setState(() => _groupLevel2 = val!),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildFilterDropdown(
                                  label: "Level 3 Group",
                                  value: _groupLevel3,
                                  items: _groupingOptions,
                                  onChanged: (val) => setState(() => _groupLevel3 = val!),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildFilterDropdown(
                                  label: "Level 4 Group",
                                  value: _groupLevel4,
                                  items: _groupingOptions,
                                  onChanged: (val) => setState(() => _groupLevel4 = val!),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // --- ACCORDION TREES BODY ---
            Expanded(
              child: filteredLogs.isEmpty
                  ? _buildEmptyState("No matching records found")
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        _buildGroupTree(filteredLogs, groupingFields, 0),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600]),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        filled: true,
        fillColor: Colors.white,
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
      style: GoogleFonts.inter(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500),
      items: items.map((e) => DropdownMenuItem(
        value: e,
        child: Text(
          e,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      )).toList(),
      onChanged: onChanged,
    );
  }
}
