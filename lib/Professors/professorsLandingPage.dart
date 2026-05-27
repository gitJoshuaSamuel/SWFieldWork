import 'package:field_work_2/Professors/createStudentsPage.dart';
import 'package:field_work_2/Professors/collegeOptionsPage.dart';
import 'package:field_work_2/Professors/collegeSchedulePage.dart';
import 'package:field_work_2/Professors/professorsAnalyticsDashboard.dart';
import 'package:field_work_2/Professors/attendanceLogsPage.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Professorslandingpage extends StatefulWidget {
  const Professorslandingpage({super.key});

  @override
  State<Professorslandingpage> createState() => _ProfessorslandingpageState();
}

class _ProfessorslandingpageState extends State<Professorslandingpage> {
  // Track which page is currently selected
  String _selectedPage = 'Analytics Dashboard';

  // Helper to switch the body content
  Widget _buildBody() {
    switch (_selectedPage) {
      case 'Create students':
        return const Createstudentspage();
      case 'Dropdown options':
        return const CollegeOptionsPage();
      case 'Analytics Dashboard':
        return const ProfessorAnalyticsDashboard();
      case 'Attendance Logs':
        return const AttendanceLogsPage();
      case 'Schedule & Settings':
        return const CollegeSchedulePage();
      case 'Settings':
        return const Center(child: Text("App Settings goes here"));
      default:
        return const ProfessorAnalyticsDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedPage),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      // This adds the "hamburger" icon automatically
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.black),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.indigo),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Professor Portal',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),

            ListTile(
              leading: const Icon(Icons.analytics_rounded),
              title: const Text('Analytics Dashboard'),
              selected: _selectedPage == 'Analytics Dashboard',
              onTap: () {
                setState(() => _selectedPage = 'Analytics Dashboard');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_rounded),
              title: const Text('Attendance Logs'),
              selected: _selectedPage == 'Attendance Logs',
              onTap: () {
                setState(() => _selectedPage = 'Attendance Logs');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_rounded),
              title: const Text('Schedule & Settings'),
              selected: _selectedPage == 'Schedule & Settings',
              onTap: () {
                setState(() => _selectedPage = 'Schedule & Settings');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Create students'),
              selected: _selectedPage == 'Create students',
              onTap: () {
                setState(() => _selectedPage = 'Create students');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_suggest_rounded),
              title: const Text('Dropdown Options'),
              selected: _selectedPage == 'Dropdown options',
              onTap: () {
                setState(() => _selectedPage = 'Dropdown options');
                Navigator.pop(context);
              },
            ),
            const Divider(), // A visual line separator
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              selected: _selectedPage == 'Settings',
              onTap: () {
                setState(() => _selectedPage = 'Settings');
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/Login',
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }
}
