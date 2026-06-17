import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class UpdateProfessorsPage extends StatefulWidget {
  const UpdateProfessorsPage({super.key});

  @override
  State<UpdateProfessorsPage> createState() => _UpdateProfessorsPageState();
}

class _UpdateProfessorsPageState extends State<UpdateProfessorsPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;
  int? _collegeCode;

  // Lists
  List<Map<String, dynamic>> _professors = [];
  List<Map<String, dynamic>> _filteredProfessors = [];
  List<Map<String, dynamic>> _collegesData = [];
  List<String> _colleges = [];
  List<String> _departments = [];

  // Currently selected professor to edit (null means list view)
  Map<String, dynamic>? _selectedProfessor;

  // Controllers for editing
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _secretCodeController = TextEditingController();

  // Dropdown selected values
  String? _selectedCollege;
  String? _selectedDepartment;
  String? _selectedRole;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _secretCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // 1. Get current user profile code
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

          // 2. Fetch Colleges list for dropdown
          final collegesResp = await supabase.from('colleges').select();
          _collegesData = List<Map<String, dynamic>>.from(collegesResp);
          _colleges = _collegesData
              .map((e) => e['college_name']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList();

          // 3. Fetch all professors/admins from profiles
          final profsData = await supabase
              .from('profiles')
              .select()
              .or('role.eq.Professor,role.eq.Admin');

          final List<Map<String, dynamic>> allProfiles = List<Map<String, dynamic>>.from(profsData);
          final filteredProfessors = allProfiles.where((p) {
            final pCode = p['college_code'] ?? p['secret_code'];
            return pCode?.toString() == code.toString();
          }).toList();

          // Sort alphabetically by name
          filteredProfessors.sort((a, b) => (a['display_name']?.toString() ?? '')
              .toLowerCase()
              .compareTo((b['display_name']?.toString() ?? '').toLowerCase()));

          setState(() {
            _professors = filteredProfessors;
            _filteredProfessors = filteredProfessors;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading data in updateProfessorsPage: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterProfessors(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredProfessors = _professors;
      } else {
        _filteredProfessors = _professors.where((p) {
          final name = (p['display_name'] ?? '').toString().toLowerCase();
          final email = (p['email'] ?? p['id'] ?? '').toString().toLowerCase();
          final q = query.toLowerCase();
          return name.contains(q) || email.contains(q);
        }).toList();
      }
    });
  }

  String _getDepartmentColumn(Map<String, dynamic> row) {
    if (row.containsKey('department_name')) return 'department_name';
    if (row.containsKey('department_names')) return 'department_names';
    if (row.containsKey('department')) return 'department';
    for (var key in row.keys) {
      if (key.toLowerCase().contains('dept') ||
          key.toLowerCase().contains('department')) {
        return key;
      }
    }
    return 'department_name';
  }

  String _getSecretCodeColumn(Map<String, dynamic> row) {
    if (row.containsKey('secret_code')) return 'secret_code';
    if (row.containsKey('college_code')) return 'college_code';
    if (row.containsKey('code')) return 'code';
    if (row.containsKey('secret')) return 'secret';
    for (var key in row.keys) {
      if (key.toLowerCase().contains('secret') ||
          key.toLowerCase().contains('code')) {
        return key;
      }
    }
    return 'secret_code';
  }

  void _onCollegeOrDepartmentChanged() {
    if (_selectedCollege == null || _selectedDepartment == null || _collegesData.isEmpty) {
      return;
    }

    final deptCol = _getDepartmentColumn(_collegesData.first);
    final secretCol = _getSecretCodeColumn(_collegesData.first);

    final matchingRow = _collegesData.firstWhere(
      (row) =>
          row['college_name']?.toString() == _selectedCollege &&
          row[deptCol]?.toString() == _selectedDepartment,
      orElse: () => {},
    );

    if (matchingRow.isNotEmpty) {
      final secretVal = matchingRow[secretCol]?.toString() ?? '';
      _secretCodeController.text = secretVal;
    }
  }

  void _selectProfessor(Map<String, dynamic> professor) {
    setState(() {
      _selectedProfessor = professor;
      _displayNameController.text = professor['display_name']?.toString() ?? '';
      _secretCodeController.text = (professor['secret_code'] ?? professor['college_code'] ?? '').toString();

      _selectedRole = professor['role']?.toString();
      _selectedCollege = professor['college']?.toString();

      if (_selectedCollege != null && _collegesData.isNotEmpty) {
        final deptCol = _getDepartmentColumn(_collegesData.first);
        _departments = _collegesData
            .where((row) => row['college_name']?.toString() == _selectedCollege)
            .map((row) => row[deptCol]?.toString() ?? '')
            .where((dept) => dept.isNotEmpty)
            .toSet()
            .toList();
      } else {
        _departments = [];
      }

      _selectedDepartment = _departments.contains(professor['department']) ? professor['department']?.toString() : null;
    });
  }

  Future<void> _updateProfessorProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProfessor == null) return;

    if (_selectedCollege == null || _selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a College and Department."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final profId = _selectedProfessor!['id'];
    final secretVal = _secretCodeController.text.trim();
    final parsedSecretCode = int.tryParse(secretVal);

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final updatedData = {
        'display_name': _displayNameController.text.trim(),
        'role': _selectedRole,
        'college': _selectedCollege,
        'department': _selectedDepartment,
        'secret_code': parsedSecretCode,
        'college_code': secretVal,
      };

      await supabase
          .from('profiles')
          .update(updatedData)
          .eq('id', profId);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            "Professor profile updated successfully!",
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      setState(() {
        _selectedProfessor = null;
      });
      await _loadData();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text("Error updating profile: $e"),
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

    return _selectedProfessor == null ? _buildProfessorsList() : _buildEditForm();
  }

  Widget _buildProfessorsList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search box
          TextField(
            onChanged: _filterProfessors,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: "Search faculty by name...",
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
              "Faculty Count: ${_filteredProfessors.length}",
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Professors cards list
          Expanded(
            child: _filteredProfessors.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_alt_outlined, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          "No faculty members found matching search",
                          style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filteredProfessors.length,
                    itemBuilder: (context, index) {
                      final prof = _filteredProfessors[index];
                      final name = prof['display_name'] ?? 'Faculty Member';
                      final deptVal = prof['department'] ?? 'N/A';
                      final roleVal = prof['role'] ?? 'Professor';

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey[200]!, width: 1.5),
                        ),
                        color: Colors.white,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _selectProfessor(prof),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.indigo[50],
                                  child: Icon(
                                    roleVal == 'Admin' ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                                    color: Colors.indigo[800],
                                    size: 24,
                                  ),
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
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              deptVal,
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
                                              roleVal,
                                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.indigo[700]),
                                            ),
                                          ),
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
    final profName = _selectedProfessor?['display_name'] ?? 'Faculty Member';

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
                    onPressed: () => setState(() => _selectedProfessor = null),
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
                          "Edit Faculty Profile",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo[800],
                          ),
                        ),
                        Text(
                          profName,
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

              // Name
              TextFormField(
                controller: _displayNameController,
                decoration: _inputDecoration("Full Name *", Icons.person_outline_rounded),
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.inter(fontSize: 14),
                validator: (v) => (v == null || v.isEmpty) ? "Full Name is required" : null,
              ),
              const SizedBox(height: 16),

              // Role Dropdown
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: _inputDecoration("Role *", Icons.badge_outlined),
                dropdownColor: Colors.white,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                items: const [
                  DropdownMenuItem(value: 'Professor', child: Text("Professor")),
                  DropdownMenuItem(value: 'Admin', child: Text("Admin")),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedRole = val);
                  }
                },
              ),
              const SizedBox(height: 16),

              // College Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCollege,
                decoration: _inputDecoration("College *", Icons.school_outlined),
                dropdownColor: Colors.white,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                hint: Text("Select College", style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
                items: _colleges.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCollege = val;
                    _selectedDepartment = null;
                    _secretCodeController.clear();
                    if (val != null && _collegesData.isNotEmpty) {
                      final deptCol = _getDepartmentColumn(_collegesData.first);
                      _departments = _collegesData
                          .where((row) => row['college_name']?.toString() == val)
                          .map((row) => row[deptCol]?.toString() ?? '')
                          .where((dept) => dept.isNotEmpty)
                          .toSet()
                          .toList();
                    } else {
                      _departments = [];
                    }
                  });
                },
                validator: (v) => v == null ? "College is required" : null,
              ),
              const SizedBox(height: 16),

              // Department Dropdown
              DropdownButtonFormField<String>(
                value: _selectedDepartment,
                decoration: _inputDecoration("Department *", Icons.lan_outlined),
                dropdownColor: Colors.white,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                disabledHint: Text("Select College first", style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13)),
                hint: Text("Select Department", style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
                items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: _selectedCollege == null
                    ? null
                    : (val) {
                        setState(() {
                          _selectedDepartment = val;
                        });
                        _onCollegeOrDepartmentChanged();
                      },
                validator: (v) => v == null ? "Department is required" : null,
              ),
              const SizedBox(height: 16),

              // Secret Code
              TextFormField(
                controller: _secretCodeController,
                decoration: _inputDecoration("College Secret Code *", Icons.vpn_key_outlined),
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(fontSize: 14),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Secret Code is required";
                  final parsed = int.tryParse(v.trim());
                  if (parsed == null || parsed < 10000 || parsed > 99999) {
                    return "Must be a 5-digit number";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 36),

              // Save Changes Button
              ElevatedButton(
                onPressed: _isSaving ? null : _updateProfessorProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
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
