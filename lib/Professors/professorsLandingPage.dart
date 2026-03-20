import 'package:field_work_2/Professors/createStudentsPage.dart';
import 'package:field_work_2/Professors/professorsDashboard.dart';
import 'package:flutter/material.dart';

class Professorslandingpage extends StatefulWidget {
  const Professorslandingpage({super.key});

  @override
  State<Professorslandingpage> createState() => _ProfessorslandingpageState();
}

class _ProfessorslandingpageState extends State<Professorslandingpage> {
  // Track which page is currently selected
  String _selectedPage = 'Dashboard';

  // Helper to switch the body content
  Widget _buildBody() {
    switch (_selectedPage) {
      case 'Create students':
        // return const Center(child: Text("Form to Create Students goes here"));
        return const Createstudentspage();
      case 'Settings':
        return const Center(child: Text("App Settings goes here"));
      default:
        return ProfessorDashboard();
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
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _selectedPage == 'Dashboard',
              onTap: () {
                setState(() => _selectedPage = 'Dashboard');
                Navigator.pop(context); // Close the drawer
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
