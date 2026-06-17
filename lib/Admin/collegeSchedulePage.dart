import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class CollegeSchedulePage extends StatefulWidget {
  const CollegeSchedulePage({super.key});

  @override
  State<CollegeSchedulePage> createState() => _CollegeSchedulePageState();
}

class _CollegeSchedulePageState extends State<CollegeSchedulePage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;
  int? _collegeCode;

  // Weekdays tracking
  final List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  final Set<String> _fieldWorkDays = {};
  final Set<String> _conferenceDays = {};
  final Set<String> _reportSubmissionDays = {};

  TimeOfDay _reportDeadline = const TimeOfDay(hour: 17, minute: 0);

  // Semesters & targets controllers
  List<String> _semestersList = [];
  final Map<String, Map<String, TextEditingController>> _targetControllers = {};

  // Weekly & Monthly field work hours
  final TextEditingController _weeklyHoursController = TextEditingController();
  final TextEditingController _monthlyHoursController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfileAndSchedule();
  }

  @override
  void dispose() {
    _weeklyHoursController.dispose();
    _monthlyHoursController.dispose();
    for (var maps in _targetControllers.values) {
      for (var ctrl in maps.values) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadProfileAndSchedule() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
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
          await _fetchSchedule(code);
        }
      }
    } catch (e) {
      debugPrint("Error loading profile or schedule: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSchedule(int collegeCode) async {
    try {
      // 1. Fetch main schedule
      final schedule = await supabase
          .from('college_schedule')
          .select()
          .eq('college_code', collegeCode)
          .maybeSingle();

      if (schedule != null) {
        setState(() {
          _fieldWorkDays.clear();
          if (schedule['field_work_days'] != null) {
            for (var day in schedule['field_work_days']) {
              _fieldWorkDays.add(day.toString());
            }
          }

          _conferenceDays.clear();
          if (schedule['conference_days'] != null) {
            for (var day in schedule['conference_days']) {
              _conferenceDays.add(day.toString());
            }
          }

          _reportSubmissionDays.clear();
          if (schedule['report_submission_days'] != null) {
            for (var day in schedule['report_submission_days']) {
              _reportSubmissionDays.add(day.toString());
            }
          }

          final deadlineStr = schedule['report_deadline']?.toString();
          if (deadlineStr != null) {
            final parts = deadlineStr.split(':');
            if (parts.length >= 2) {
              final hr = int.tryParse(parts[0]) ?? 17;
              final min = int.tryParse(parts[1]) ?? 0;
              _reportDeadline = TimeOfDay(hour: hr, minute: min);
            }
          }
        });
      }

      // 2. Fetch semesters from college_options
      final options = await supabase
          .from('college_options')
          .select('value')
          .eq('college_code', collegeCode)
          .eq('category', 'semester');

      final List<String> sems = List<Map<String, dynamic>>.from(options)
          .map((e) => e['value']?.toString().trim() ?? '')
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList();

      if (sems.isEmpty) {
        sems.addAll(['Semester I', 'Semester II', 'Semester III', 'Semester IV']);
      }

      // 3. Fetch existing semester requirements
      final requirements = await supabase
          .from('semester_requirements')
          .select()
          .eq('college_code', collegeCode);

      final List<Map<String, dynamic>> reqRows = List<Map<String, dynamic>>.from(requirements);

      // 4. Fetch Weekly and Monthly FW hours from college_options
      final hoursOptions = await supabase
          .from('college_options')
          .select()
          .eq('college_code', collegeCode)
          .inFilter('category', ['Weekly FW', 'Monthly FW']);

      String weeklyHours = '';
      String monthlyHours = '';
      for (var opt in hoursOptions) {
        if (opt['category'] == 'Weekly FW') {
          weeklyHours = opt['value']?.toString() ?? '';
        } else if (opt['category'] == 'Monthly FW') {
          monthlyHours = opt['value']?.toString() ?? '';
        }
      }

      setState(() {
        _weeklyHoursController.text = weeklyHours;
        _monthlyHoursController.text = monthlyHours;
        _semestersList = sems;
        
        // Dispose existing controllers first
        for (var maps in _targetControllers.values) {
          for (var ctrl in maps.values) {
            ctrl.dispose();
          }
        }
        _targetControllers.clear();

        for (var sem in sems) {
          final matched = reqRows.firstWhere(
            (r) => r['semester']?.toString().trim() == sem,
            orElse: () => {},
          );

          final fwVal = matched['required_field_work']?.toString() ?? '24';
          final repVal = matched['required_reports']?.toString() ?? '24';
          final confVal = matched['required_conferences']?.toString() ?? '5';

          _targetControllers[sem] = {
            'fw': TextEditingController(text: fwVal),
            'rep': TextEditingController(text: repVal),
            'conf': TextEditingController(text: confVal),
          };
        }
      });
    } catch (e) {
      debugPrint("Error fetching schedule detail: $e");
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reportDeadline,
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
    if (picked != null && picked != _reportDeadline) {
      setState(() {
        _reportDeadline = picked;
      });
    }
  }

  Future<void> _saveSchedule() async {
    if (_collegeCode == null) return;
    setState(() => _isSaving = true);

    final deadlineStr = "${_reportDeadline.hour.toString().padLeft(2, '0')}:${_reportDeadline.minute.toString().padLeft(2, '0')}:00";

    try {
      // 1. Upsert college schedule weekdays config
      final existing = await supabase
          .from('college_schedule')
          .select('id')
          .eq('college_code', _collegeCode!)
          .maybeSingle();

      if (existing == null) {
        await supabase.from('college_schedule').insert({
          'college_code': _collegeCode!,
          'field_work_days': _fieldWorkDays.toList(),
          'conference_days': _conferenceDays.toList(),
          'report_submission_days': _reportSubmissionDays.toList(),
          'report_deadline': deadlineStr,
        });
      } else {
        await supabase.from('college_schedule').update({
          'field_work_days': _fieldWorkDays.toList(),
          'conference_days': _conferenceDays.toList(),
          'report_submission_days': _reportSubmissionDays.toList(),
          'report_deadline': deadlineStr,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('college_code', _collegeCode!);
      }

      // 2. Save Weekly and Monthly Field Work Hours
      final weeklyVal = _weeklyHoursController.text.trim();
      final existingWeekly = await supabase
          .from('college_options')
          .select('id')
          .eq('college_code', _collegeCode!)
          .eq('category', 'Weekly FW')
          .maybeSingle();

      if (existingWeekly == null) {
        if (weeklyVal.isNotEmpty) {
          await supabase.from('college_options').insert({
            'college_code': _collegeCode!,
            'category': 'Weekly FW',
            'value': weeklyVal,
          });
        }
      } else {
        await supabase.from('college_options').update({
          'value': weeklyVal,
        }).eq('id', existingWeekly['id']);
      }

      final monthlyVal = _monthlyHoursController.text.trim();
      final existingMonthly = await supabase
          .from('college_options')
          .select('id')
          .eq('college_code', _collegeCode!)
          .eq('category', 'Monthly FW')
          .maybeSingle();

      if (existingMonthly == null) {
        if (monthlyVal.isNotEmpty) {
          await supabase.from('college_options').insert({
            'college_code': _collegeCode!,
            'category': 'Monthly FW',
            'value': monthlyVal,
          });
        }
      } else {
        await supabase.from('college_options').update({
          'value': monthlyVal,
        }).eq('id', existingMonthly['id']);
      }

      // 3. Upsert semester requirements
      for (var sem in _semestersList) {
        final ctrlMap = _targetControllers[sem];
        if (ctrlMap != null) {
          final fw = int.tryParse(ctrlMap['fw']!.text.trim()) ?? 24;
          final rep = int.tryParse(ctrlMap['rep']!.text.trim()) ?? 24;
          final conf = int.tryParse(ctrlMap['conf']!.text.trim()) ?? 5;

          final existingReq = await supabase
              .from('semester_requirements')
              .select('id')
              .eq('college_code', _collegeCode!)
              .eq('semester', sem)
              .maybeSingle();

          if (existingReq == null) {
            await supabase.from('semester_requirements').insert({
              'college_code': _collegeCode!,
              'semester': sem,
              'required_field_work': fw,
              'required_reports': rep,
              'required_conferences': conf,
            });
          } else {
            await supabase.from('semester_requirements').update({
              'required_field_work': fw,
              'required_reports': rep,
              'required_conferences': conf,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('college_code', _collegeCode!).eq('semester', sem);
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Schedule and Semester targets saved!",
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving schedule: $e"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDecoration(String labelText, IconData icon) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11),
      prefixIcon: Icon(icon, color: Colors.black54, size: 14),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black, width: 2),
      ),
    );
  }

  Widget _buildDaysCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Set<String> selectedDays,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _weekdays.map((day) {
                final isSelected = selectedDays.contains(day);
                return ChoiceChip(
                  label: Text(day.substring(0, 3)),
                  selected: isSelected,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                  selectedColor: color,
                  backgroundColor: Colors.grey[100],
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        selectedDays.add(day);
                      } else {
                        selectedDays.remove(day);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldWorkHoursCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_time_rounded, color: Colors.indigo, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Field Work Hours Config",
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        "Configure weekly and monthly field work hours",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weeklyHoursController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration("Weekly Field Work Hours", Icons.calendar_view_week_rounded),
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _monthlyHoursController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration("Monthly Field Work Hours", Icons.calendar_month_rounded),
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSemesterRequirementsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.pink.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.pink, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Semester Targets",
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        "Define log targets for each semester",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ..._semestersList.map((sem) {
              final ctrls = _targetControllers[sem];
              if (ctrls == null) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sem,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: ctrls['fw'],
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration("Field Work Target", Icons.work_history_rounded),
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: ctrls['rep'],
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration("Report Target", Icons.analytics_rounded),
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: ctrls['conf'],
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration("Conference Target", Icons.forum_rounded),
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _collegeCode == null
              ? Center(
                  child: Text(
                    "Profile error: No college code verified",
                    style: GoogleFonts.inter(),
                  ),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Card 1: Field Work Days
                        _buildDaysCard(
                          title: "Field Work Days",
                          subtitle: "Select the weekdays assigned for field work",
                          icon: Icons.work_history_rounded,
                          color: Colors.blueAccent,
                          selectedDays: _fieldWorkDays,
                        ),
                        const SizedBox(height: 16),

                        // Card 2: Conference Days
                        _buildDaysCard(
                          title: "Conference Days",
                          subtitle: "Select the weekdays assigned for conferences",
                          icon: Icons.forum_rounded,
                          color: Colors.purpleAccent,
                          selectedDays: _conferenceDays,
                        ),
                        const SizedBox(height: 16),

                        // Card 3: Report Submission Days
                        _buildDaysCard(
                          title: "Report Submission Days",
                          subtitle: "Select the weekdays assigned for report uploads",
                          icon: Icons.analytics_rounded,
                          color: Colors.teal,
                          selectedDays: _reportSubmissionDays,
                        ),
                        const SizedBox(height: 16),

                        // Card 4: Report Deadline Time
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.grey[100]!, width: 1.5),
                          ),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.timer_rounded, color: Colors.orange, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Report Deadline",
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        "Set submission cutoff time",
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _selectTime(context),
                                  icon: const Icon(Icons.edit_calendar_rounded, size: 16, color: Colors.black87),
                                  label: Text(
                                    _reportDeadline.format(context),
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.grey[100],
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Card 5: Semester targets configuration panel
                        _buildSemesterRequirementsCard(),
                        const SizedBox(height: 16),

                        // Card 6: Field Work Hours targets
                        _buildFieldWorkHoursCard(),
                        const SizedBox(height: 32),

                        // Save Button
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveSchedule,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle_rounded, size: 18),
                          label: Text(
                            _isSaving ? "Saving..." : "Save Schedule Config",
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                            disabledBackgroundColor: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
