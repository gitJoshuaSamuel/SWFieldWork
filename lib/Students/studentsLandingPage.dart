import 'package:field_work_2/Students/studentsDashboardPage.dart';
import 'package:field_work_2/Students/studentProfilePage.dart';
import 'package:field_work_2/Students/studentNotesPage.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Studentslandingpage extends StatefulWidget {
  const Studentslandingpage({super.key});

  @override
  State<Studentslandingpage> createState() => _StudentslandingpageState();
}

class _StudentslandingpageState extends State<Studentslandingpage> {
  // Track which page is currently selected
  String _selectedPage = 'Dashboard';

  // Helper to switch the body contents
  Widget _buildBody() {
    switch (_selectedPage) {
      case 'Profile':
        return const StudentProfilePage();
      case 'Notes':
        return const StudentNotesPage();
      case 'Settings':
        return const Center(child: Text("App Settings goes here"));
      default:
        return const AttendanceMainPage();
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
                    'Students Portal',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _selectedPage == 'Dashboard',
              onTap: () {
                setState(() => _selectedPage = 'Dashboard');
                Navigator.pop(context); // Close the drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              selected: _selectedPage == 'Profile',
              onTap: () {
                setState(() => _selectedPage = 'Profile');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_alt_outlined),
              title: const Text('Notes'),
              selected: _selectedPage == 'Notes',
              onTap: () {
                setState(() => _selectedPage = 'Notes');
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
                final navigator = Navigator.of(context);
                await Supabase.instance.client.auth.signOut();
                navigator.pushNamedAndRemoveUntil(
                  '/Login',
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }
}
