import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class CreateProfessorsPage extends StatefulWidget {
  const CreateProfessorsPage({super.key});

  @override
  State<CreateProfessorsPage> createState() => _CreateProfessorsPageState();
}

class _CreateProfessorsPageState extends State<CreateProfessorsPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isLoadingColleges = true;

  // Form Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _secretCodeController = TextEditingController();

  // Colleges/Departments lists
  List<Map<String, dynamic>> _collegesData = [];
  List<String> _colleges = [];
  List<String> _departments = [];

  // Dropdown selected values
  String? _selectedCollege;
  String? _selectedDepartment;
  String _selectedRole = 'Professor';

  @override
  void initState() {
    super.initState();
    _fetchColleges();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _secretCodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchColleges() async {
    try {
      final response = await supabase.from('colleges').select();
      setState(() {
        _collegesData = List<Map<String, dynamic>>.from(response);
        _colleges = _collegesData
            .map((e) => e['college_name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList();
        _isLoadingColleges = false;
      });
    } catch (e) {
      debugPrint("Error fetching colleges in CreateProfessorsPage: $e");
      setState(() => _isLoadingColleges = false);
    }
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

  Future<void> _registerProfessor() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCollege == null || _selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a College and Department."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final displayName = _displayNameController.text.trim();
    final secretCodeStr = _secretCodeController.text.trim();
    final parsedSecretCode = int.tryParse(secretCodeStr);

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Create user in Supabase auth
      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'display_name': displayName,
          'college_code': secretCodeStr,
          'role': _selectedRole,
          'department': _selectedDepartment,
          'college': _selectedCollege,
          'secret_code': parsedSecretCode,
        },
      );

      // Reset fields on success
      _emailController.clear();
      _passwordController.clear();
      _displayNameController.clear();
      _secretCodeController.clear();
      setState(() {
        _selectedCollege = null;
        _selectedDepartment = null;
        _selectedRole = 'Professor';
        _departments = [];
      });

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            "Account created successfully!",
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text("Error creating account: $e"),
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_add_rounded, color: Colors.indigo, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        "Create Faculty Account",
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  if (_isLoadingColleges)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.indigo, strokeWidth: 2),
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

              // Email
              TextFormField(
                controller: _emailController,
                decoration: _inputDecoration("Email Address *", Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.inter(fontSize: 14),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Email is required";
                  if (!v.contains('@')) return "Enter a valid email";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: _passwordController,
                decoration: _inputDecoration("Password *", Icons.lock_outline_rounded),
                obscureText: true,
                style: GoogleFonts.inter(fontSize: 14),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Password is required";
                  if (v.length < 6) return "Password must be >= 6 characters";
                  return null;
                },
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
              _isLoadingColleges
                  ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
                  : DropdownButtonFormField<String>(
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

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _registerProfessor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
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
                        "Register Account",
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
