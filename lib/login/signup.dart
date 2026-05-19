import 'package:field_work_2/login/login.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final supabase = Supabase.instance.client;

  final formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _collegecode = TextEditingController();

  bool _isLoading = false;

  Future<void> submitForm() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final displayName = _displayNameController.text.trim();
    final collegeCode = _collegecode.text.trim();

    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'display_name': displayName,
          'college_code': collegeCode,
          'role': 'Professor',
          'department': 'MSW',
          'college': 'MCC',
        },
      );

      if (response.user == null) {
        _showMessage("Signup failed", "Please try again.");
        return;
      }

      _showMessage(
        "Signup successful",
        "Welcome $displayName!",
        onOk: () {
          Navigator.pushReplacementNamed(context, '/landing');
        },
      );
    } catch (e) {
      _showMessage("Sign up Error", e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> navigateAfterLogin() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    final data = await Supabase.instance.client
        .from('users')
        .select('has_seen_onboarding')
        .eq('id', userId!)
        .single();

    final seen = data['has_seen_onboarding'] ?? false;

    if (seen) {
      Navigator.pushReplacementNamed(context, '/landing');
    } else {
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  void _showMessage(String title, String message, {VoidCallback? onOk}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.normal,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              navigateAfterLogin();
              Navigator.of(context).pop();
              if (onOk != null) onOk();
            },
            child: Text(
              "OK",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? emailValidator(String? value) {
    if (value == null || value.isEmpty) return "Email cannot be empty";
    if (!value.contains("@")) return "Enter a valid email";
    return null;
  }

  String? passwordValidator(String? value) {
    if (value == null || value.isEmpty) return "Password cannot be empty";
    if (value.length < 6) return "Password should be more than 6 characters";
    return null;
  }

  String? displayNameValidator(String? value) {
    if (value == null || value.isEmpty) return "Display Name cannot be empty";
    return null;
  }

  InputDecoration _inputDecoration(String labelText, IconData icon) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.black87, size: 20),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.person_add_alt_1_outlined,
                      size: 64,
                      color: Colors.black,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Create Account",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Sign up as a Professor to get started",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 36),
                    TextFormField(
                      controller: _emailController,
                      validator: emailValidator,
                      style: GoogleFonts.inter(fontSize: 15),
                      decoration: _inputDecoration('Email', Icons.email_outlined),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      validator: passwordValidator,
                      obscureText: true,
                      style: GoogleFonts.inter(fontSize: 15),
                      decoration: _inputDecoration('Password', Icons.lock_outline),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _displayNameController,
                      validator: displayNameValidator,
                      style: GoogleFonts.inter(fontSize: 15),
                      decoration: _inputDecoration('Display Name', Icons.person_outline),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _collegecode,
                      style: GoogleFonts.inter(fontSize: 15),
                      decoration: _inputDecoration('College Code', Icons.school_outlined),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: Colors.black54,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Sign Up',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => Login()),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black87,
                      ),
                      child: Text(
                        'Have an account? Login',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
