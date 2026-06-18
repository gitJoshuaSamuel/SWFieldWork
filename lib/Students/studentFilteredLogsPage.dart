import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../widgets/adaptive_map_view.dart';

class StudentFilteredLogsPage extends StatefulWidget {
  final String filterActivity;
  final bool hideAppBar;
  const StudentFilteredLogsPage({
    super.key,
    required this.filterActivity,
    this.hideAppBar = false,
  });

  @override
  State<StudentFilteredLogsPage> createState() => _StudentFilteredLogsPageState();
}

class _StudentFilteredLogsPageState extends State<StudentFilteredLogsPage> {
  final supabase = Supabase.instance.client;
  final Set<String> _expandedLogIds = {};

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '--:--';
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (e) {
      return timeStr;
    }
  }

  String _formatDateDay(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      return DateFormat('EEEE, MMM d, yyyy').format(dt);
    } catch (e) {
      return timeStr;
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    Color bgColor;
    switch (status) {
      case 'Present':
      case 'On Time':
        color = Colors.green[700]!;
        bgColor = Colors.green[50]!;
        break;
      case 'Late':
        color = Colors.orange[800]!;
        bgColor = Colors.orange[50]!;
        break;
      case 'Absent':
        color = Colors.red[700]!;
        bgColor = Colors.red[50]!;
        break;
      case 'Holiday':
        color = const Color(0xFFE65100);
        bgColor = const Color(0xFFFFF3E0);
        break;
      default:
        color = Colors.grey[700]!;
        bgColor = Colors.grey[50]!;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Text(
        status,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSemesterBadge(String semester) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF8E24AA).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF8E24AA).withValues(alpha: 0.1)),
      ),
      child: Text(
        semester,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF8E24AA),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String activity, String? fwType) {
    String label = activity;
    if (activity == 'Field Work' && fwType != null) {
      label = "Field Work ($fwType)";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1E88E5).withValues(alpha: 0.1)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1E88E5),
        ),
      ),
    );
  }

  Widget _buildPhotoBox({
    required String label,
    required String? imgUrl,
    required bool isAbsent,
    required bool isHoliday,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imgUrl != null
                ? Image.network(
                    imgUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Center(
                      child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 28),
                    ),
                  )
                : Center(
                    child: Icon(
                      isAbsent
                          ? Icons.person_off_rounded
                          : (isHoliday ? Icons.beach_access_rounded : Icons.photo_library_outlined),
                      color: Colors.grey,
                      size: 28,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF1E88E5),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                widget.filterActivity == 'All'
                    ? "Logs"
                    : "${widget.filterActivity} History",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              centerTitle: true,
            ),
      body: userId == null
          ? Center(
              child: Text(
                "User not logged in.",
                style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey[600]),
              ),
            )
            : StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase
                    .from('attendance_logs')
                    .stream(primaryKey: ['id'])
                    .eq('user_id', userId)
                    .order('check_in_time'),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        "Error loading history: ${snapshot.error}",
                        style: GoogleFonts.outfit(),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
                    );
                  }

                  final allLogs = snapshot.data!;
                  final logs = widget.filterActivity == 'All'
                      ? allLogs
                      : allLogs.where((l) => l['activity_type'] == widget.filterActivity).toList();

                  if (logs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_toggle_off_rounded,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.filterActivity == 'All'
                                ? "No attendance logs found"
                                : "No records found for ${widget.filterActivity}",
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

                // Sort logs descending (newest check_in_time first)
                final sortedLogs = List<Map<String, dynamic>>.from(logs);
                sortedLogs.sort((a, b) {
                  final aTime = DateTime.tryParse(a['check_in_time'] ?? '') ?? DateTime(1970);
                  final bTime = DateTime.tryParse(b['check_in_time'] ?? '') ?? DateTime(1970);
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedLogs.length,
                  itemBuilder: (context, index) {
                    final log = sortedLogs[index];
                    final logId = log['id']?.toString() ?? index.toString();
                    final isExpanded = _expandedLogIds.contains(logId);
                    final logStatus = log['status'] ?? 'Present';
                    final isAbsent = logStatus == 'Absent';
                    final isHoliday = logStatus == 'Holiday';
                    final isOneShot = log['activity_type'] == 'Report' || log['activity_type'] == 'Conference';
                    final isReport = log['activity_type'] == 'Report';

                    final checkInTimeStr = log['check_in_time'] as String?;
                    final checkOutTimeStr = log['check_out_time'] as String?;
                    final dateDayText = _formatDateDay(checkInTimeStr);

                    // Clocked hours calculation
                    String clockedHoursText = '--:--';
                    if (checkInTimeStr != null && checkOutTimeStr != null && !isAbsent && !isHoliday) {
                      try {
                        final inTime = DateTime.parse(checkInTimeStr);
                        final outTime = DateTime.parse(checkOutTimeStr);
                        final diff = outTime.difference(inTime);
                        final hours = diff.inHours;
                        final minutes = diff.inMinutes.remainder(60);
                        clockedHoursText = "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";
                      } catch (_) {}
                    }

                    final hasCoords = log['check_in_lat'] != null && log['check_in_lng'] != null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: Colors.grey[100]!, width: 1.5),
                      ),
                      child: Column(
                        children: [
                          // Header area (toggles expansion)
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedLogIds.remove(logId);
                                } else {
                                  _expandedLogIds.add(logId);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          dateDayText,
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      _buildStatusBadge(logStatus),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _buildSemesterBadge(log['semester'] ?? 'Semester I'),
                                      const SizedBox(width: 8),
                                      _buildTypeBadge(log['activity_type'] ?? 'Field Work', log['field_work_type']),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isOneShot ? "Time" : "Check In",
                                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatTime(checkInTimeStr),
                                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                                          ),
                                        ],
                                      ),
                                      if (!isOneShot) ...[
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Check Out",
                                              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatTime(checkOutTimeStr),
                                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Clocked",
                                              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              clockedHoursText,
                                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF1E88E5)),
                                            ),
                                          ],
                                        ),
                                      ],
                                      Icon(
                                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                        color: Colors.grey[400],
                                        size: 28,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Collapsible Details section
                          if (isExpanded) ...[
                            const Divider(height: 1, color: Color(0xFFF5F5F5), thickness: 1.5),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Images comparison row
                                  Text(
                                    "Images Logged",
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildPhotoBox(
                                          label: isOneShot
                                              ? (isReport ? "Report Photo" : "Conference Photo")
                                              : "Check-in Picture",
                                          imgUrl: log['check_in_img_url'],
                                          isAbsent: isAbsent,
                                          isHoliday: isHoliday,
                                        ),
                                      ),
                                      if (!isOneShot) ...[
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildPhotoBox(
                                            label: "Check-out Picture",
                                            imgUrl: log['check_out_img_url'],
                                            isAbsent: isAbsent,
                                            isHoliday: isHoliday,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // Inline Map View
                                  if (hasCoords) ...[
                                    Text(
                                      "Locations & Route",
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      height: 180,
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
                                          largeMarkers: false,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
