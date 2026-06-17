import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AttendanceExportPage extends StatefulWidget {
  const AttendanceExportPage({super.key});

  @override
  State<AttendanceExportPage> createState() => _AttendanceExportPageState();
}

class _AttendanceExportPageState extends State<AttendanceExportPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isExporting = false;
  int? _collegeCode;

  // Data lists
  List<Map<String, dynamic>> _allLogs = [];
  List<String> _semesters = ['All'];

  // Filter selections
  String _selectedSemester = 'All';
  String _selectedActivity = 'All';
  String _selectedFieldWorkType = 'All';
  DateTime? _startDate;
  DateTime? _endDate;

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
        // 1. Get college code from profile
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
          final List<String> loadedSems = ['All'];
          for (var row in optRows) {
            final cat = row['category']?.toString().toLowerCase().trim();
            final val = row['value']?.toString().trim() ?? '';
            if (val.isNotEmpty && cat == 'semester') {
              loadedSems.add(val);
            }
          }

          // Fallback to standard semesters if none found
          if (loadedSems.length == 1) {
            loadedSems.addAll([
              'Semester I',
              'Semester II',
              'Semester III',
              'Semester IV',
              'Semester V',
              'Semester VI'
            ]);
          }

          // 3. Fetch all attendance logs for this college
          final logsData = await supabase
              .from('attendance_logs')
              .select('*, profiles(id, display_name, registration_no, college_code, class, batch, semester, faculty_supervisor, agency_supervisor, organisation_placed)')
              .order('check_in_time', ascending: false);

          final List<Map<String, dynamic>> allLogs = List<Map<String, dynamic>>.from(logsData);
          final filteredLogs = allLogs.where((log) {
            if (log['profiles'] == null) return false;
            final lCode = log['profiles']['college_code'];
            return lCode?.toString() == code.toString();
          }).toList();

          setState(() {
            _semesters = loadedSems;
            _allLogs = filteredLogs;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading export initial data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Filter logs locally in Dart based on state
  List<Map<String, dynamic>> _getFilteredLogs() {
    return _allLogs.where((log) {
      final profile = log['profiles'] ?? {};

      // 1. Semester Filter
      // Checking log's semester or student's profile semester
      final logSem = (log['semester'] ?? profile['semester'] ?? '').toString().trim();
      if (_selectedSemester != 'All' && logSem.toLowerCase() != _selectedSemester.toLowerCase()) {
        return false;
      }

      // 2. Activity Type Filter
      final activity = (log['activity_type'] ?? '').toString().trim();
      if (_selectedActivity != 'All' && activity.toLowerCase() != _selectedActivity.toLowerCase()) {
        return false;
      }

      // 3. Field Work Type Filter (Applicable only if Activity is All or Field Work)
      if ((_selectedActivity == 'All' || _selectedActivity == 'Field Work') && _selectedFieldWorkType != 'All') {
        final fwType = log['field_work_type'] ?? 'Standard';
        if (fwType.toString().toLowerCase() != _selectedFieldWorkType.toLowerCase()) {
          return false;
        }
      }

      // 4. Date Range Filter
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

  CellValue? _wrapCell(dynamic val) {
    if (val == null) return null;
    if (val is int) return IntCellValue(val);
    if (val is double) return DoubleCellValue(val);
    if (val is bool) return BoolCellValue(val);
    return TextCellValue(val.toString());
  }

  Future<void> _exportExcel() async {
    final filtered = _getFilteredLogs();
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No records found for the selected filters."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      // Create Workbook
      final excel = Excel.createExcel();
      final sheet = excel['Attendance Logs'];
      
      // Remove default sheet
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Add Headers
      sheet.appendRow([
        _wrapCell('Student Name'),
        _wrapCell('Registration No'),
        _wrapCell('Class'),
        _wrapCell('Batch'),
        _wrapCell('Semester'),
        _wrapCell('Activity Type'),
        _wrapCell('Field Work Type'),
        _wrapCell('Date'),
        _wrapCell('Check In Time'),
        _wrapCell('Check Out Time'),
        _wrapCell('Duration (Hours)'),
        _wrapCell('Status'),
        _wrapCell('Faculty Supervisor'),
        _wrapCell('Agency Supervisor'),
        _wrapCell('Organisation Placed'),
        _wrapCell('Check In Lat'),
        _wrapCell('Check In Lng'),
        _wrapCell('Check Out Lat'),
        _wrapCell('Check Out Lng'),
      ]);

      // Add Data rows
      for (var log in filtered) {
        final profile = log['profiles'] ?? {};
        final checkIn = log['check_in_time'] != null ? DateTime.parse(log['check_in_time']).toLocal() : null;
        final checkOut = log['check_out_time'] != null ? DateTime.parse(log['check_out_time']).toLocal() : null;

        final dateStr = checkIn != null ? DateFormat('yyyy-MM-dd').format(checkIn) : '';
        final checkInStr = checkIn != null ? DateFormat('hh:mm a').format(checkIn) : '';
        final checkOutStr = checkOut != null ? DateFormat('hh:mm a').format(checkOut) : '';

        double duration = 0.0;
        if (log['hours_logged'] != null) {
          duration = double.parse((log['hours_logged'] as num).toDouble().toStringAsFixed(2));
        } else if (checkIn != null && checkOut != null) {
          duration = double.parse((checkOut.difference(checkIn).inMinutes / 60.0).toStringAsFixed(2));
        }

        sheet.appendRow([
          _wrapCell(profile['display_name'] ?? ''),
          _wrapCell(profile['registration_no'] ?? ''),
          _wrapCell(profile['class'] ?? ''),
          _wrapCell(profile['batch'] ?? ''),
          _wrapCell(log['semester'] ?? profile['semester'] ?? ''),
          _wrapCell(log['activity_type'] ?? ''),
          _wrapCell(log['field_work_type'] ?? 'Standard'),
          _wrapCell(dateStr),
          _wrapCell(checkInStr),
          _wrapCell(checkOutStr),
          _wrapCell(duration),
          _wrapCell(log['status'] ?? ''),
          _wrapCell(profile['faculty_supervisor'] ?? ''),
          _wrapCell(profile['agency_supervisor'] ?? ''),
          _wrapCell(profile['organisation_placed'] ?? ''),
          _wrapCell(log['check_in_lat']),
          _wrapCell(log['check_in_lng']),
          _wrapCell(log['check_out_lat']),
          _wrapCell(log['check_out_lng']),
        ]);
      }

      // Save file to temporary storage
      final bytes = excel.save();
      if (bytes != null) {
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final filename = 'Attendance_Export_$timestamp.xlsx';
        final file = File('${tempDir.path}/$filename');
        
        await file.writeAsBytes(bytes);

        if (!mounted) return;

        // Share Excel Sheet
        final box = context.findRenderObject() as RenderBox?;
        try {
          await SharePlus.instance.share(
            ShareParams(
              text: 'Social Work Field Work Attendance Report',
              files: [XFile(file.path)],
              sharePositionOrigin: box != null ? (box.localToGlobal(Offset.zero) & box.size) : null,
            ),
          );
        } catch (e) {
          debugPrint("Failed to share file directly: $e");
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text(
                  "Exported Successfully",
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                content: Text(
                  "The Excel file was generated and saved to your device:\n\n${file.path}\n\nNote: Please rebuild the app (stop the current run and run 'flutter run' again) so the new native sharing plugin is registered.",
                  style: GoogleFonts.inter(color: Colors.black54, fontSize: 13),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      "OK",
                      style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error exporting excel: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to export Excel file: $e"),
            backgroundColor: Colors.redAccent,
          ),
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

    final filteredLogs = _getFilteredLogs();

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
                    "Export Attendance",
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    onPressed: _loadInitialData,
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

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- FILTERS CARD ---
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.grey[200]!, width: 1.5),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.tune_rounded, color: Colors.black87, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "Export Filters",
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Semester Filter
                            _buildFilterDropdown(
                              label: "Semester",
                              value: _selectedSemester,
                              items: _semesters,
                              onChanged: (val) => setState(() => _selectedSemester = val!),
                            ),
                            const SizedBox(height: 12),

                            // Activity Type Filter
                            _buildFilterDropdown(
                              label: "Activity Type",
                              value: _selectedActivity,
                              items: const ['All', 'Field Work', 'Report', 'Conference'],
                              onChanged: (val) {
                                setState(() {
                                  _selectedActivity = val!;
                                  // Reset field work type if not applicable
                                  if (_selectedActivity != 'All' && _selectedActivity != 'Field Work') {
                                    _selectedFieldWorkType = 'All';
                                  }
                                });
                              },
                            ),

                            // Field Work Type Filter (Conditional)
                            if (_selectedActivity == 'All' || _selectedActivity == 'Field Work') ...[
                              const SizedBox(height: 12),
                              _buildFilterDropdown(
                                label: "Field Work Type",
                                value: _selectedFieldWorkType,
                                items: const ['All', 'Standard', 'Additional', 'Compensatory'],
                                onChanged: (val) => setState(() => _selectedFieldWorkType = val!),
                              ),
                            ],
                            const SizedBox(height: 12),

                            // Date Range Picker
                            InkWell(
                              onTap: () => _selectDateRange(context),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_month_rounded, color: Colors.grey[600], size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Date Range Filter",
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _startDate == null || _endDate == null
                                                ? "All Dates (No range limit)"
                                                : "${DateFormat('dd MMMM yyyy').format(_startDate!)} - ${DateFormat('dd MMMM yyyy').format(_endDate!)}",
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_startDate != null)
                                      IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _startDate = null;
                                            _endDate = null;
                                          });
                                        },
                                        icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      )
                                    else
                                      Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[400], size: 14),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- PREVIEW CARD ---
                    Card(
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
                            Text(
                              "Export Preview Summary",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildSummaryStat(
                                  label: "Matching Logs",
                                  value: filteredLogs.length.toString(),
                                  color: Colors.indigo,
                                ),
                                Container(width: 1.5, height: 40, color: Colors.grey[200]),
                                _buildSummaryStat(
                                  label: "Total Logs Loaded",
                                  value: _allLogs.length.toString(),
                                  color: Colors.grey[700]!,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- EXPORT BUTTON ---
                    ElevatedButton.icon(
                      onPressed: _isExporting ? null : _exportExcel,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Icon(Icons.download_rounded, color: Colors.white),
                      label: Text(
                        _isExporting ? "GENERATING EXCEL..." : "EXPORT TO EXCEL",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: Colors.grey[400],
                      ),
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

  Widget _buildSummaryStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey[500],
          ),
        ),
      ],
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
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black),
        ),
      ),
      dropdownColor: Colors.white,
      style: GoogleFonts.inter(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}
