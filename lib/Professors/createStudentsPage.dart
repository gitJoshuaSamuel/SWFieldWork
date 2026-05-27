import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class Createstudentspage extends StatefulWidget {
  const Createstudentspage({super.key});

  @override
  State<Createstudentspage> createState() => _CreatestudentspageState();
}

class _CreatestudentspageState extends State<Createstudentspage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isLoadingOptions = false;

  // Primary controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _collegeCodeController = TextEditingController();
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

  String? relatedProfessorName; 
  String? professorDept;
  String? professorCollege;

  @override
  void initState() {
    super.initState();
    _loadProfessorProfile();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _collegeCodeController.dispose();
    _regNoController.dispose();
    super.dispose();
  }

  Future<void> _loadProfessorProfile() async {
    setState(() => _isLoadingOptions = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        debugPrint("Loading profile for user id: ${user.id}");
        final profileResponse = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        debugPrint("Profile response: $profileResponse");
        int? code;
        if (profileResponse != null) {
          relatedProfessorName = profileResponse['display_name']?.toString() ?? 'Professor';
          professorDept = profileResponse['department']?.toString() ?? 'MSW';
          professorCollege = profileResponse['college']?.toString() ?? 'MCC';
          
          final rawCode = profileResponse['secret_code'] ?? profileResponse['college_code'];
          debugPrint("Raw code from database: $rawCode");
          if (rawCode != null) {
            code = int.tryParse(rawCode.toString());
          }
        }

        // Fallback to user metadata
        if (code == null) {
          relatedProfessorName = user.userMetadata?['display_name'] ?? relatedProfessorName;
          professorDept = user.userMetadata?['department'] ?? professorDept;
          professorCollege = user.userMetadata?['college'] ?? professorCollege;
          final rawCode = user.userMetadata?['secret_code'] ?? user.userMetadata?['college_code'];
          debugPrint("Raw code from metadata fallback: $rawCode");
          if (rawCode != null) {
            code = int.tryParse(rawCode.toString());
          }
        }

        if (code != null) {
          _collegeCodeController.text = code.toString();
          debugPrint("Prefilling college code $code and fetching options");
          await _fetchCollegeOptions(code);
        } else {
          debugPrint("No college code/secret code found for professor profile");
          setState(() => _isLoadingOptions = false);
        }
      } else {
        debugPrint("No current user signed in");
        setState(() => _isLoadingOptions = false);
      }
    } catch (e) {
      debugPrint("Error loading professor profile: $e");
      setState(() => _isLoadingOptions = false);
    }
  }

  Future<void> _fetchCollegeOptions(int collegeCode) async {
    setState(() => _isLoadingOptions = true);
    try {
      debugPrint("Querying college_options for code: $collegeCode");
      final response = await supabase
          .from('college_options')
          .select()
          .eq('college_code', collegeCode);

      final List<Map<String, dynamic>> rows = List<Map<String, dynamic>>.from(response);
      debugPrint("Fetched ${rows.length} rows from college_options");

      final List<String> classes = [];
      final List<String> batches = [];
      final List<String> semesters = [];
      final List<String> specialisations = [];
      final List<String> organisations = [];
      final List<String> agencySupervisors = [];
      final List<String> facultySupervisors = [];
      final List<String> professors = [];

      for (var row in rows) {
        final category = row['category']?.toString().trim().toLowerCase();
        final value = row['value']?.toString().trim() ?? '';
        if (value.isEmpty) continue;

        switch (category) {
          case 'class':
            classes.add(value);
            break;
          case 'batch':
            batches.add(value);
            break;
          case 'semester':
            semesters.add(value);
            break;
          case 'specialisation':
            specialisations.add(value);
            break;
          case 'organisation':
            organisations.add(value);
            break;
          case 'agency_supervisor':
            agencySupervisors.add(value);
            break;
          case 'faculty_supervisor':
            facultySupervisors.add(value);
            break;
          case 'professor':
            professors.add(value);
            break;
        }
      }

      setState(() {
        _classes = classes;
        _batches = batches;
        _semesters = semesters;
        _specialisations = specialisations;
        _organisations = organisations;
        _agencySupervisors = agencySupervisors;
        _facultySupervisors = facultySupervisors;
        _professors = professors;

        // Auto-select matchings where possible
        if (_professors.contains(relatedProfessorName)) {
          _selectedRelatedProfessor = relatedProfessorName;
        } else if (_professors.isNotEmpty) {
          _selectedRelatedProfessor = _professors.first;
        } else {
          _selectedRelatedProfessor = null;
        }

        // Reset other values if their lists no longer contain them
        if (!_classes.contains(_selectedClass)) _selectedClass = null;
        if (!_batches.contains(_selectedBatch)) _selectedBatch = null;
        if (!_semesters.contains(_selectedSemester)) _selectedSemester = null;
        if (!_specialisations.contains(_selectedSpecialisation)) _selectedSpecialisation = null;
        if (!_organisations.contains(_selectedOrgPlaced)) _selectedOrgPlaced = null;
        if (!_facultySupervisors.contains(_selectedFacultySupervisor)) _selectedFacultySupervisor = null;
        if (!_agencySupervisors.contains(_selectedAgencySupervisor)) _selectedAgencySupervisor = null;

        _isLoadingOptions = false;
      });
    } catch (e) {
      debugPrint("Error fetching options: $e");
      setState(() => _isLoadingOptions = false);
    }
  }

  Future<void> createStudents() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final displayName = _displayNameController.text.trim();
    final collegeCode = _collegeCodeController.text.trim();

    try {
      final parsedSecretCode = int.tryParse(collegeCode);

      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'display_name': displayName,
          'college_code': collegeCode,
          'role': 'Student',
          'department': professorDept,
          'college': professorCollege,
          'related_professor': _selectedRelatedProfessor ?? relatedProfessorName,
          'secret_code': parsedSecretCode,
          'registration_no': _regNoController.text.trim().isEmpty ? null : _regNoController.text.trim(),
          'class': _selectedClass,
          'batch': _selectedBatch,
          'semester': _selectedSemester,
          'specialisation': _selectedSpecialisation,
          'organisation_placed': _selectedOrgPlaced,
          'faculty_supervisor': _selectedFacultySupervisor,
          'agency_supervisor': _selectedAgencySupervisor,
        },
      );

      // Clear all fields on success
      _emailController.clear();
      _passwordController.clear();
      _displayNameController.clear();
      _regNoController.clear();

      setState(() {
        _selectedClass = null;
        _selectedBatch = null;
        _selectedSemester = null;
        _selectedSpecialisation = null;
        _selectedOrgPlaced = null;
        _selectedFacultySupervisor = null;
        _selectedAgencySupervisor = null;
        _selectedRelatedProfessor = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Student account created successfully!",
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
          content: Text("Error creating student: $e"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
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
        "No $labelText options set in DB",
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
              // Form Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_add_rounded, color: Colors.teal, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        "Create Student Profile",
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  if (_isLoadingOptions)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.teal, strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 28),

              // Student Email
              TextFormField(
                controller: _emailController,
                decoration: _inputDecoration("Student Email *", Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.inter(fontSize: 14),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Email is required";
                  if (!v.contains('@')) return "Enter a valid email";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Student Password
              TextFormField(
                controller: _passwordController,
                decoration: _inputDecoration("Student Password *", Icons.lock_outline_rounded),
                obscureText: true,
                style: GoogleFonts.inter(fontSize: 14),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Password is required";
                  if (v.length < 6) return "Password must be >= 6 chars";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Display Name
              TextFormField(
                controller: _displayNameController,
                decoration: _inputDecoration("Display Name *", Icons.person_outline_rounded),
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.inter(fontSize: 14),
                validator: (v) => (v == null || v.isEmpty) ? "Display Name is required" : null,
              ),
              const SizedBox(height: 16),

              // College Secret Code (Triggers options fetching on change)
              TextFormField(
                controller: _collegeCodeController,
                decoration: _inputDecoration("College Secret Code *", Icons.vpn_key_outlined),
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(fontSize: 14),
                onChanged: (value) {
                  final parsed = int.tryParse(value.trim());
                  if (parsed != null && value.trim().length == 5) {
                    _fetchCollegeOptions(parsed);
                  }
                },
                validator: (v) {
                  if (v == null || v.isEmpty) return "Code is required";
                  final val = int.tryParse(v.trim());
                  if (val == null || val < 10000 || val > 99999) {
                    return "Must be a 5-digit number";
                  }
                  return null;
                },
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

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : createStudents,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey[400],
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        "Submit",
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
