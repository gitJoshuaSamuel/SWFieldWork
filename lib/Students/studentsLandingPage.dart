import 'package:field_work_2/Professors/createStudentsPage.dart';
import 'package:field_work_2/Students/studentsDashboardPage.dart';
import 'package:flutter/material.dart';

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
      case 'Settings':
        return const Center(child: Text("App Settings goes here"));
      default:
        return AttendanceMainPage();
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
          ],
        ),
      ),
      body: _buildBody(),
    );
  }
}
