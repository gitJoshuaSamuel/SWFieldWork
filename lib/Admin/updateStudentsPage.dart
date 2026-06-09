import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class UpdateStudentsPage extends StatefulWidget {
  const UpdateStudentsPage({super.key});

  @override
  State<UpdateStudentsPage> createState() => _UpdateStudentsPageState();
}

class _UpdateStudentsPageState extends State<UpdateStudentsPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;
  int? _collegeCode;

  // Loaded students list
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];

  // Currently selected student to edit (null means list view)
  Map<String, dynamic>? _selectedStudent;

  // Controllers for editing
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _regNoController = TextEditingController();

  // Dynamic dropdown lists fetched from public.college_options
  List<String> _classes = [];
  List<String> _batches = [];
  List<String> _semesters = [];
  List<String> _specialisations = [];
  List<String> _organisations = [];
  List<String> _agencySupervisors = [];
  List<String> _facultySupervisors = [];
  List<String> _professors = [];

  // Dropdown selected values
  String? _selectedClass;
  String? _selectedBatch;
  String? _selectedSemester;
  String? _selectedSpecialisation;
  String? _selectedOrgPlaced;
  String? _selectedFacultySupervisor;
  String? _selectedAgencySupervisor;
  String? _selectedRelatedProfessor;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _regNoController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // 1. Get professor college code
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

          // 2. Fetch College Options
          final options = await supabase
              .from('college_options')
              .select()
              .eq('college_code', code);

          final List<Map<String, dynamic>> optRows = List<Map<String, dynamic>>.from(options);
          
          final List<String> classes = [];
          final List<String> batches = [];
          final List<String> semesters = [];
          final List<String> specialisations = [];
          final List<String> organisations = [];
          final List<String> agencySupervisors = [];
          final List<String> facultySupervisors = [];
          final List<String> professors = [];

          for (var row in optRows) {
            final cat = row['category']?.toString().toLowerCase().trim();
            final val = row['value']?.toString().trim() ?? '';
            if (val.isEmpty) continue;

            switch (cat) {
              case 'class':
                classes.add(val);
                break;
              case 'batch':
                batches.add(val);
                break;
              case 'semester':
                semesters.add(val);
                break;
              case 'specialisation':
                specialisations.add(val);
                break;
              case 'organisation':
                organisations.add(val);
                break;
              case 'agency_supervisor':
                agencySupervisors.add(val);
                break;
              case 'faculty_supervisor':
                facultySupervisors.add(val);
                break;
              case 'professor':
                professors.add(val);
                break;
            }
          }

          // 3. Fetch Students of this college
          final studentsData = await supabase
              .from('profiles')
              .select()
              .eq('role', 'Student');

          final List<Map<String, dynamic>> allProfiles = List<Map<String, dynamic>>.from(studentsData);
          final filteredStudents = allProfiles.where((p) {
            final pCode = p['college_code'] ?? p['secret_code'];
            return pCode?.toString() == code.toString();
          }).toList();

          // Sort alphabetically by name
          filteredStudents.sort((a, b) => (a['display_name']?.toString() ?? '')
              .toLowerCase()
              .compareTo((b['display_name']?.toString() ?? '').toLowerCase()));

          setState(() {
            _classes = classes;
            _batches = batches;
            _semesters = semesters;
            _specialisations = specialisations;
            _organisations = organisations;
            _agencySupervisors = agencySupervisors;
            _facultySupervisors = facultySupervisors;
            _professors = professors;

            _students = filteredStudents;
            _filteredStudents = filteredStudents;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading data in updateStudentsPage: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterStudents(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredStudents = _students;
      } else {
        _filteredStudents = _students.where((student) {
          final name = (student['display_name'] ?? '').toString().toLowerCase();
          final regNo = (student['registration_no'] ?? '').toString().toLowerCase();
          final q = query.toLowerCase();
          return name.contains(q) || regNo.contains(q);
        }).toList();
      }
    });
  }

  void _selectStudent(Map<String, dynamic> student) {
    setState(() {
      _selectedStudent = student;
      _displayNameController.text = student['display_name']?.toString() ?? '';
      _regNoController.text = student['registration_no']?.toString() ?? '';

      // Initialize dropdown selections
      _selectedClass = _classes.contains(student['class']) ? student['class'] : null;
      _selectedBatch = _batches.contains(student['batch']) ? student['batch'] : null;
      _selectedSemester = _semesters.contains(student['semester']) ? student['semester'] : null;
      _selectedSpecialisation = _specialisations.contains(student['specialisation']) ? student['specialisation'] : null;
      _selectedOrgPlaced = _organisations.contains(student['organisation_placed']) ? student['organisation_placed'] : null;
      _selectedFacultySupervisor = _facultySupervisors.contains(student['faculty_supervisor']) ? student['faculty_supervisor'] : null;
      _selectedAgencySupervisor = _agencySupervisors.contains(student['agency_supervisor']) ? student['agency_supervisor'] : null;
      _selectedRelatedProfessor = _professors.contains(student['related_professor']) ? student['related_professor'] : null;
    });
  }

  Future<void> _updateStudentProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudent == null) return;

    setState(() => _isSaving = true);
    final studentId = _selectedStudent!['id'];

    try {
      final updatedData = {
        'display_name': _displayNameController.text.trim(),
        'registration_no': _regNoController.text.trim().isEmpty ? null : _regNoController.text.trim(),
        'class': _selectedClass,
        'batch': _selectedBatch,
        'semester': _selectedSemester,
        'specialisation': _selectedSpecialisation,
        'organisation_placed': _selectedOrgPlaced,
        'faculty_supervisor': _selectedFacultySupervisor,
        'agency_supervisor': _selectedAgencySupervisor,
        'related_professor': _selectedRelatedProfessor,
      };

      await supabase
          .from('profiles')
          .update(updatedData)
          .eq('id', studentId);

      // Show success indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Student profile updated successfully!",
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      // Deselect student and refresh list
      setState(() {
        _selectedStudent = null;
      });
      await _loadData();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating profile: $e"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDecoration(String labelText, IconData icon) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.black54, size: 18),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }

  Widget _buildDropdown({
    required String labelText,
    required IconData icon,
    required String? currentValue,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool required = false,
  }) {
    final displayItems = items.where((e) => e.trim().isNotEmpty).toList();

    return DropdownButtonFormField<String>(
      value: displayItems.contains(currentValue) ? currentValue : null,
      decoration: _inputDecoration(labelText, icon),
      hint: Text(
        "Select $labelText",
        style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
      ),
      disabledHint: Text(
        "No $labelText options configured",
        style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13),
      ),
      dropdownColor: Colors.white,
      style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
      items: displayItems.isEmpty
          ? null
          : displayItems
              .map((e) => DropdownMenuItem<String>(
                    value: e,
                    child: Text(e),
                  ))
              .toList(),
      onChanged: displayItems.isEmpty ? null : onChanged,
      validator: required
          ? (v) => (v == null || v.isEmpty) ? "$labelText is required" : null
          : null,
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
            "Profile error: College code missing",
            style: GoogleFonts.inter(),
          ),
        ),
      );
    }

    return _selectedStudent == null ? _buildStudentList() : _buildEditForm();
  }

  Widget _buildStudentList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search box
          TextField(
            onChanged: _filterStudents,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: "Search student by name or registration number...",
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 22),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.black, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Total Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              "Students Count: ${_filteredStudents.length}",
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Student cards list
          Expanded(
            child: _filteredStudents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off_rounded, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          "No students found matching search",
                          style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filteredStudents.length,
                    itemBuilder: (context, index) {
                      final student = _filteredStudents[index];
                      final name = student['display_name'] ?? 'Student';
                      final regNo = student['registration_no'] ?? 'N/A';
                      final classVal = student['class'] ?? 'N/A';
                      final semVal = student['semester'] ?? 'N/A';
                      final specVal = student['specialisation'] ?? 'N/A';

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey[150] ?? Colors.grey[200]!, width: 1.5),
                        ),
                        color: Colors.white,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _selectStudent(student),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.indigo[50],
                                  child: Icon(Icons.person_rounded, color: Colors.indigo[800], size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Reg: $regNo",
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              classVal,
                                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.indigo[50],
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              semVal,
                                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.indigo[700]),
                                            ),
                                          ),
                                          if (specVal != 'N/A' && specVal != null && specVal.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                specVal,
                                                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500]),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 28),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    final studentName = _selectedStudent?['display_name'] ?? 'Student';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.grey[100]!, width: 1.5),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row with Back button
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _selectedStudent = null),
                    icon: const Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      padding: const EdgeInsets.all(8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Edit Profile",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo[800],
                          ),
                        ),
                        Text(
                          studentName,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Student Display Name
              TextFormField(
                controller: _displayNameController,
                decoration: _inputDecoration("Display Name *", Icons.person_outline_rounded),
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.inter(fontSize: 14),
                validator: (v) => (v == null || v.isEmpty) ? "Display Name is required" : null,
              ),
              const SizedBox(height: 16),

              // Registration Number
              TextFormField(
                controller: _regNoController,
                decoration: _inputDecoration("Registration Number", Icons.badge_outlined),
                style: GoogleFonts.inter(fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Class Dropdown
              _buildDropdown(
                labelText: "Class",
                icon: Icons.class_outlined,
                currentValue: _selectedClass,
                items: _classes,
                onChanged: (val) => setState(() => _selectedClass = val),
              ),
              const SizedBox(height: 16),

              // Batch Dropdown
              _buildDropdown(
                labelText: "Batch",
                icon: Icons.date_range_rounded,
                currentValue: _selectedBatch,
                items: _batches,
                onChanged: (val) => setState(() => _selectedBatch = val),
              ),
              const SizedBox(height: 16),

              // Semester Dropdown
              _buildDropdown(
                labelText: "Semester",
                icon: Icons.dns_outlined,
                currentValue: _selectedSemester,
                items: _semesters,
                onChanged: (val) => setState(() => _selectedSemester = val),
              ),
              const SizedBox(height: 16),

              // Specialisation Dropdown
              _buildDropdown(
                labelText: "Specialisation",
                icon: Icons.star_outline_rounded,
                currentValue: _selectedSpecialisation,
                items: _specialisations,
                onChanged: (val) => setState(() => _selectedSpecialisation = val),
              ),
              const SizedBox(height: 16),

              // Organisation Placed Dropdown
              _buildDropdown(
                labelText: "Organisation Placed",
                icon: Icons.business_outlined,
                currentValue: _selectedOrgPlaced,
                items: _organisations,
                onChanged: (val) => setState(() => _selectedOrgPlaced = val),
              ),
              const SizedBox(height: 16),

              // Faculty Supervisor Dropdown
              _buildDropdown(
                labelText: "Faculty Supervisor",
                icon: Icons.face_retouching_natural_rounded,
                currentValue: _selectedFacultySupervisor,
                items: _facultySupervisors,
                onChanged: (val) => setState(() => _selectedFacultySupervisor = val),
              ),
              const SizedBox(height: 16),

              // Agency Supervisor Dropdown
              _buildDropdown(
                labelText: "Agency Supervisor",
                icon: Icons.assignment_ind_outlined,
                currentValue: _selectedAgencySupervisor,
                items: _agencySupervisors,
                onChanged: (val) => setState(() => _selectedAgencySupervisor = val),
              ),
              const SizedBox(height: 16),

              // Related Professor Dropdown
              _buildDropdown(
                labelText: "Related Professor",
                icon: Icons.person_pin_rounded,
                currentValue: _selectedRelatedProfessor,
                items: _professors,
                onChanged: (val) => setState(() => _selectedRelatedProfessor = val),
              ),
              const SizedBox(height: 36),

              // Save Changes Button
              ElevatedButton(
                onPressed: _isSaving ? null : _updateStudentProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey[400],
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        "Save Changes",
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
