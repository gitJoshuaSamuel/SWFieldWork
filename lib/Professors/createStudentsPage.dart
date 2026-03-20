import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Createstudentspage extends StatefulWidget {
  const Createstudentspage({super.key});

  @override
  State<Createstudentspage> createState() => _CreatestudentspageState();
}

class _CreatestudentspageState extends State<Createstudentspage> {
  final supabase = Supabase.instance.client;
  bool _showStudentCreationFields = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _collegeCodeController = TextEditingController();
  late final String?
  relatedProfessorName; // To store the professor's name for the student record

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;

    if (user != null) {
      relatedProfessorName = user.userMetadata?['display_name'];
      print('Display Name: $relatedProfessorName');
    }
  }

  Future<void> createStudents() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final displayName = _displayNameController.text.trim();
    final collegeCode = _collegeCodeController.text.trim();

    print("Creating student with name: ${email} and email: ${password}");

    final response = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'display_name': displayName,
        'college_code': collegeCode,
        'role': 'Student',
        'department': 'MSW',
        'college': 'MCC',
        'related_professor': relatedProfessorName,
      },
    );
    print(
      "Creating student with name: ${_emailController.text} and email: ${_passwordController.text}",
    );
    // After creation, you might want to clear the fields or show a success message
    _emailController.clear();
    _passwordController.clear();
    _displayNameController.clear();
    _collegeCodeController.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Student created successfully!")));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 20),
        Align(
          alignment: Alignment.bottomRight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            onPressed: () => {
              setState(() {
                _showStudentCreationFields = true;
              }),
            },
            child: Text("Create Students"),
          ),
        ),
        SizedBox(height: 20),
        if (_showStudentCreationFields)
          Container(
            padding: EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: "Student Email"),
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: "Student Password"),
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _displayNameController,
                  decoration: InputDecoration(labelText: "Display Name"),
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _collegeCodeController,
                  decoration: InputDecoration(labelText: "College Code"),
                ),
                ElevatedButton(
                  onPressed: () {
                    createStudents();
                  },
                  child: Text("Submit"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
