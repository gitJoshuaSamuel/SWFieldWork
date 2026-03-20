import 'package:field_work_2/login/signup.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Login extends StatefulWidget {
  Login({super.key});

  final String title = "Login Page";

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final supabase = Supabase.instance.client;

  final formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? emailValidator(String? value) {
    if (_emailController.text.isEmpty) {
      return "Email cannot be empty";
    }
    return null;
  }

  String? passwordValidator(String? value) {
    if (_passwordController.text.isEmpty) {
      return "Password cannot be empty";
    }
    if (_passwordController.text.length < 6) {
      return "Password should be more than 6 characters";
    }
    return null;
  }

  Future<void> submitForm() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    print("Email and password is: $email, $password");

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (mounted) Navigator.pop(context); // remove loading dialog

      if (response.user != null &&
          response.session != null &&
          response.user!.userMetadata?['role'] == 'Professor') {
        Navigator.pushReplacementNamed(context, '/professors-landing');
      } else if (response.user != null &&
          response.session != null &&
          response.user!.userMetadata?['role'] == 'Student') {
        Navigator.pushReplacementNamed(context, '/students-landing');
      } else {
        _showErrorDialog("Login failed. Please try again.");
      }
    } on AuthException catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorDialog(e.message); // Supabase auth error
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorDialog("Something went wrong. Please try again.");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          "Login Error",
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
            SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: TextFormField(
                controller: _passwordController,
                validator: passwordValidator,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(height: 20),
            Align(
              child: ElevatedButton(
                onPressed: submitForm,
                child: const Text('Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: Size(400, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      30,
                    ), // Adjust width as needed
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Align(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => Signup()),
                ),
                child: Text('Are you a Professor? Signup here'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
