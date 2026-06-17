import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AttendanceLogsManagerPage extends StatefulWidget {
  const AttendanceLogsManagerPage({super.key});

  @override
  State<AttendanceLogsManagerPage> createState() => _AttendanceLogsManagerPageState();
}

class _AttendanceLogsManagerPageState extends State<AttendanceLogsManagerPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  int? _collegeCode;

  // Data lists
  List<Map<String, dynamic>> _allLogs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  List<String> _semesters = [];

  // Filter & Search States
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchController = TextEditingController();

  // Dialog Options
  final List<String> _statusOptions = ['Present', 'Absent', 'On Time', 'Late', 'Compensation'];
  final List<String> _activityOptions = ['Field Work', 'Conference', 'Additional Field Work', 'Compensation'];
  final List<String> _fieldWorkTypeOptions = ['Regular', 'Holiday'];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

          // 2. Fetch Semester Options from college_options
          final options = await supabase
              .from('college_options')
              .select()
              .eq('college_code', code);

          final List<Map<String, dynamic>> optRows = List<Map<String, dynamic>>.from(options);
          final List<String> loadedSems = [];
          for (var row in optRows) {
            final cat = row['category']?.toString().toLowerCase().trim();
            final val = row['value']?.toString().trim() ?? '';
            if (val.isNotEmpty && cat == 'semester') {
              loadedSems.add(val);
            }
          }

          if (loadedSems.isEmpty) {
            loadedSems.addAll([
              'Semester I',
              'Semester II',
              'Semester III',
              'Semester IV',
              'Semester V',
              'Semester VI'
            ]);
          }

          setState(() {
            _semesters = loadedSems;
          });

          // 3. Fetch logs
          await _fetchLogs();
        }
      }
    } catch (e) {
      debugPrint("Error loading logs manager initial data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLogs() async {
    if (_collegeCode == null) return;
    try {
      final logsData = await supabase
          .from('attendance_logs')
          .select('*, profiles(id, display_name, registration_no, college_code, class, batch, semester)')
          .order('check_in_time', ascending: false);

      final List<Map<String, dynamic>> allLogs = List<Map<String, dynamic>>.from(logsData);
      
      // Filter by college code of the admin/professor profile
      setState(() {
        _allLogs = allLogs.where((log) {
          if (log['profiles'] == null) return false;
          final lCode = log['profiles']['college_code'];
          return lCode?.toString() == _collegeCode.toString();
        }).toList();
        _applyFilters();
      });
    } catch (e) {
      debugPrint("Error fetching logs in manager: $e");
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> temp = List.from(_allLogs);

    // Filter by student name / registration number search
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      temp = temp.where((log) {
        final profile = log['profiles'] ?? {};
        final name = (profile['display_name'] ?? '').toString().toLowerCase();
        final regNo = (profile['registration_no'] ?? '').toString().toLowerCase();
        return name.contains(query) || regNo.contains(query);
      }).toList();
    }

    // Filter by start date
    if (_startDate != null) {
      final startMidnight = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      temp = temp.where((log) {
        final checkInStr = log['check_in_time']?.toString();
        if (checkInStr == null) return false;
        final checkInDate = DateTime.parse(checkInStr).toLocal();
        return checkInDate.isAfter(startMidnight) || checkInDate.isAtSameMomentAs(startMidnight);
      }).toList();
    }

    // Filter by end date
    if (_endDate != null) {
      final endMidnight = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      temp = temp.where((log) {
        final checkInStr = log['check_in_time']?.toString();
        if (checkInStr == null) return false;
        final checkInDate = DateTime.parse(checkInStr).toLocal();
        return checkInDate.isBefore(endMidnight) || checkInDate.isAtSameMomentAs(endMidnight);
      }).toList();
    }

    setState(() {
      _filteredLogs = temp;
    });
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
      _applyFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _searchQuery = '';
      _searchController.clear();
    });
    _applyFilters();
  }

  Future<DateTime?> _pickDateTime(DateTime initialDateTime) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialDateTime,
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
    if (date == null) return null;

    if (!mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
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
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _editLog(Map<String, dynamic> log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _EditLogBottomSheet(
          log: log,
          semesters: _semesters,
          statusOptions: _statusOptions,
          activityOptions: _activityOptions,
          fieldWorkTypeOptions: _fieldWorkTypeOptions,
          onPickDateTime: _pickDateTime,
          onSave: (updatedData) async {
            setState(() => _isLoading = true);
            try {
              await supabase
                  .from('attendance_logs')
                  .update(updatedData)
                  .eq('id', log['id']);

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Record updated successfully!", style: GoogleFonts.inter()),
                  backgroundColor: Colors.teal,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              await _fetchLogs();
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Failed to update record: $e", style: GoogleFonts.inter()),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } finally {
              setState(() => _isLoading = false);
            }
          },
          onDelete: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (dCtx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text("Delete Record", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                content: Text(
                  "Are you sure you want to delete this attendance record? This action cannot be undone.",
                  style: GoogleFonts.inter(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx, false),
                    child: Text("Cancel", style: GoogleFonts.inter(color: Colors.grey[700])),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx, true),
                    child: Text("Delete", style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              setState(() => _isLoading = true);
              try {
                await supabase
                    .from('attendance_logs')
                    .delete()
                    .eq('id', log['id']);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Record deleted successfully!", style: GoogleFonts.inter()),
                    backgroundColor: Colors.grey[850],
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                await _fetchLogs();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Failed to delete record: $e", style: GoogleFonts.inter()),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } finally {
                setState(() => _isLoading = false);
              }
            }
          },
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Present':
      case 'On Time':
        return const Color(0xFF10B981);
      case 'Absent':
        return Colors.redAccent;
      case 'Late':
        return Colors.orange;
      case 'Compensation':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  Color _getActivityColor(String? act) {
    switch (act) {
      case 'Field Work':
        return Colors.indigo[700]!;
      case 'Conference':
        return Colors.purple[700]!;
      case 'Additional Field Work':
        return Colors.teal[700]!;
      case 'Compensation':
        return Colors.blue[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading && _allLogs.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.black,
              ),
            )
          : Column(
              children: [
                // Filter Header Panel
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Search TextField
                      TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() => _searchQuery = val);
                          _applyFilters();
                        },
                        decoration: InputDecoration(
                          hintText: "Search student by name or registration number...",
                          hintStyle: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                      _searchController.clear();
                                    });
                                    _applyFilters();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Date Filters and Reset Button
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectDateRange(context),
                              icon: const Icon(Icons.calendar_today_rounded, size: 16),
                              label: Text(
                                _startDate == null || _endDate == null
                                    ? "Filter by Date Range"
                                    : "${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}",
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[800],
                                side: BorderSide(color: Colors.grey[300]!),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          if (_startDate != null || _endDate != null || _searchQuery.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.filter_alt_off_rounded, color: Colors.redAccent),
                              tooltip: "Clear filters",
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.red[50],
                                padding: const EdgeInsets.all(10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Logs Counter
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Showing ${_filteredLogs.length} records",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        ),
                    ],
                  ),
                ),

                // Logs List
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchLogs,
                    color: Colors.black,
                    child: _filteredLogs.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                              const Icon(Icons.assignment_turned_in_rounded, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Center(
                                child: Text(
                                  "No attendance records found",
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  "Try altering search queries or date filters",
                                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _filteredLogs.length,
                            itemBuilder: (context, index) {
                              final log = _filteredLogs[index];
                              final profile = log['profiles'] ?? {};
                              final display = profile['display_name'] ?? 'Student';
                              final regNo = profile['registration_no'] ?? 'N/A';
                              final activity = log['activity_type'] ?? 'Field Work';
                              final status = log['status'] ?? 'Present';
                              final semester = log['semester'] ?? 'N/A';
                              
                              final checkIn = log['check_in_time'] != null
                                  ? DateTime.parse(log['check_in_time']).toLocal()
                                  : null;
                              final checkOut = log['check_out_time'] != null
                                  ? DateTime.parse(log['check_out_time']).toLocal()
                                  : null;

                              final checkInDateStr = checkIn != null
                                  ? DateFormat('EEEE, dd MMM yyyy').format(checkIn)
                                  : 'N/A';
                              final checkInTimeStr = checkIn != null
                                  ? DateFormat('hh:mm a').format(checkIn)
                                  : '--:--';
                              final checkOutTimeStr = checkOut != null
                                  ? DateFormat('hh:mm a').format(checkOut)
                                  : 'Active Session';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey[100]!, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.01),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _editLog(log),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Student Info & Badges
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: Colors.grey[100],
                                              child: Text(
                                                display.isNotEmpty ? display[0].toUpperCase() : 'S',
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
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
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    "Reg No: $regNo",
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color: Colors.grey[500],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(status).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                status,
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getStatusColor(status),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 12.0),
                                          child: Divider(height: 1, thickness: 1),
                                        ),

                                        // Times details
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "CHECK IN",
                                                    style: GoogleFonts.inter(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey[500],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    checkInTimeStr,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    checkInDateStr,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              height: 32,
                                              width: 1,
                                              color: Colors.grey[200],
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "CHECK OUT",
                                                    style: GoogleFonts.inter(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey[500],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    checkOutTimeStr,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: checkOut == null
                                                          ? Colors.teal
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    checkOut != null
                                                        ? DateFormat('EEEE, dd MMM yyyy').format(checkOut)
                                                        : "Ongoing",
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      color: checkOut == null
                                                          ? Colors.teal.withValues(alpha: 0.8)
                                                          : Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),

                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 12.0),
                                          child: Divider(height: 1, thickness: 1),
                                        ),

                                        // Footer Details: Semester & Activity
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.school_outlined, size: 14, color: Colors.grey[600]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  semester,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _getActivityColor(activity).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                activity,
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getActivityColor(activity),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _EditLogBottomSheet extends StatefulWidget {
  final Map<String, dynamic> log;
  final List<String> semesters;
  final List<String> statusOptions;
  final List<String> activityOptions;
  final List<String> fieldWorkTypeOptions;
  final Future<DateTime?> Function(DateTime) onPickDateTime;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final Future<void> Function() onDelete;

  const _EditLogBottomSheet({
    required this.log,
    required this.semesters,
    required this.statusOptions,
    required this.activityOptions,
    required this.fieldWorkTypeOptions,
    required this.onPickDateTime,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_EditLogBottomSheet> createState() => _EditLogBottomSheetState();
}

class _EditLogBottomSheetState extends State<_EditLogBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  late String _selectedStatus;
  late String _selectedActivity;
  late String _selectedSemester;
  String? _selectedFieldWorkType;

  late DateTime _checkInDateTime;
  DateTime? _checkOutDateTime;
  bool _hasCheckOut = false;

  @override
  void initState() {
    super.initState();
    final log = widget.log;
    _selectedStatus = log['status'] ?? 'Present';
    _selectedActivity = log['activity_type'] ?? 'Field Work';
    _selectedSemester = log['semester'] ?? (widget.semesters.isNotEmpty ? widget.semesters.first : 'Semester I');
    _selectedFieldWorkType = log['field_work_type'];

    final checkInStr = log['check_in_time'];
    _checkInDateTime = checkInStr != null ? DateTime.parse(checkInStr).toLocal() : DateTime.now();

    final checkOutStr = log['check_out_time'];
    if (checkOutStr != null) {
      _checkOutDateTime = DateTime.parse(checkOutStr).toLocal();
      _hasCheckOut = true;
    } else {
      _checkOutDateTime = null;
      _hasCheckOut = false;
    }
  }

  void _saveForm() {
    if (!_formKey.currentState!.validate()) return;

    final Map<String, dynamic> updatedData = {
      'status': _selectedStatus,
      'activity_type': _selectedActivity,
      'semester': _selectedSemester,
      'field_work_type': _selectedActivity == 'Field Work' ? _selectedFieldWorkType : null,
      'check_in_time': _checkInDateTime.toUtc().toIso8601String(),
      'check_out_time': _hasCheckOut && _checkOutDateTime != null
          ? _checkOutDateTime!.toUtc().toIso8601String()
          : null,
      'is_active': !_hasCheckOut,
    };

    widget.onSave(updatedData);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.log['profiles'] ?? {};
    final display = profile['display_name'] ?? 'Student';
    final regNo = profile['registration_no'] ?? 'N/A';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bottom Sheet handle
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Delete Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Edit Attendance Record",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onDelete();
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    tooltip: "Delete Record",
                  )
                ],
              ),
              const SizedBox(height: 8),

              // Student Info Read-Only banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.black,
                      child: Text(
                        display.isNotEmpty ? display[0].toUpperCase() : 'S',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            display,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
                          ),
                          Text(
                            "Registration No: $regNo",
                            style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Check-in Selector
              Text(
                "Check-in Time",
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final dt = await widget.onPickDateTime(_checkInDateTime);
                  if (dt != null) {
                    setState(() => _checkInDateTime = dt);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEEE, dd MMM yyyy, hh:mm a').format(_checkInDateTime),
                        style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                      ),
                      const Icon(Icons.edit_calendar_rounded, size: 20, color: Colors.black54),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Check-out Checkbox / Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Set Check-out Time",
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                  ),
                  Switch(
                    value: _hasCheckOut,
                    activeColor: Colors.black,
                    onChanged: (val) {
                      setState(() {
                        _hasCheckOut = val;
                        if (val && _checkOutDateTime == null) {
                          // Default to check-in time plus 8 hours or now
                          _checkOutDateTime = _checkInDateTime.add(const Duration(hours: 8));
                          if (_checkOutDateTime!.isAfter(DateTime.now())) {
                            _checkOutDateTime = DateTime.now();
                          }
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),

              if (_hasCheckOut && _checkOutDateTime != null) ...[
                InkWell(
                  onTap: () async {
                    final dt = await widget.onPickDateTime(_checkOutDateTime!);
                    if (dt != null) {
                      setState(() => _checkOutDateTime = dt);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('EEEE, dd MMM yyyy, hh:mm a').format(_checkOutDateTime!),
                          style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                        ),
                        const Icon(Icons.edit_calendar_rounded, size: 20, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Dropdown selectors row (Status and Activity)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: widget.statusOptions.contains(_selectedStatus) ? _selectedStatus : widget.statusOptions.first,
                      decoration: InputDecoration(
                        labelText: "Status",
                        labelStyle: GoogleFonts.inter(fontSize: 12),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      items: widget.statusOptions
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e,
                                  style: GoogleFonts.inter(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatus = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: widget.activityOptions.contains(_selectedActivity) ? _selectedActivity : widget.activityOptions.first,
                      decoration: InputDecoration(
                        labelText: "Activity Type",
                        labelStyle: GoogleFonts.inter(fontSize: 12),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      items: widget.activityOptions
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e,
                                  style: GoogleFonts.inter(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedActivity = val;
                            if (val == 'Field Work') {
                              _selectedFieldWorkType = 'Regular';
                            } else {
                              _selectedFieldWorkType = null;
                            }
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Dropdown selectors row (Semester and optional Field Work Type)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: widget.semesters.contains(_selectedSemester) ? _selectedSemester : (widget.semesters.isNotEmpty ? widget.semesters.first : null),
                      decoration: InputDecoration(
                        labelText: "Semester",
                        labelStyle: GoogleFonts.inter(fontSize: 12),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      items: widget.semesters
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e,
                                  style: GoogleFonts.inter(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSemester = val);
                      },
                    ),
                  ),
                  if (_selectedActivity == 'Field Work') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: widget.fieldWorkTypeOptions.contains(_selectedFieldWorkType)
                            ? _selectedFieldWorkType
                            : widget.fieldWorkTypeOptions.first,
                        decoration: InputDecoration(
                          labelText: "Field Work Type",
                          labelStyle: GoogleFonts.inter(fontSize: 12),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        items: widget.fieldWorkTypeOptions
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    e,
                                    style: GoogleFonts.inter(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedFieldWorkType = val);
                        },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 28),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        "Cancel",
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[750]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        "Save Corrections",
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
