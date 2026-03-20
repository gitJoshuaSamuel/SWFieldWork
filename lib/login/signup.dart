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
      // final response = await supabase.auth.signUp(
      //   email: email,
      //   password: password,
      //   data: {
      //     'display_name': displayName,
      //     'college_code': collegeCode,
      //     'role': 'Professor',
      //     'department': 'MSW',
      //     'college': 'MCC',
      //   },
      // );

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

      // await supabase.from('users').insert({
      //   'real_uuid': response.user!.id,
      //   'display_name': displayName,
      //   'email': email,
      //   'password': password,
      // });

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
        backgroundColor: Colors.black,
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              navigateAfterLogin();
              Navigator.of(context).pop();
              if (onOk != null) onOk(); //
            },
            child: Text(
              "OK",
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text("Sign up"),
      ),
      body: Center(
        child: Form(
          key: formKey,
          child: Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.only(left: 20, right: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Email
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: TextFormField(
                    controller: _emailController,
                    validator: emailValidator,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Password
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: TextFormField(
                    controller: _passwordController,
                    validator: passwordValidator,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Username
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: TextFormField(
                    controller: _displayNameController,
                    validator: displayNameValidator,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: TextFormField(
                    controller: _collegecode,
                    decoration: const InputDecoration(
                      labelText: 'College Code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(400, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
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
                      : const Text('Sign Up'),
                ),

                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => Login()),
                    ),
                    child: const Text('Have an account? Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
