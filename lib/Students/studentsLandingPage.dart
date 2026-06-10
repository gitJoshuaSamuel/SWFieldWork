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
  String? _avatarUrl;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadStudentAvatar();
  }

  Future<void> _loadStudentAvatar() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final res = await supabase
            .from('profiles')
            .select('avatar_url')
            .eq('id', userId)
            .maybeSingle();
        if (res != null && res['avatar_url'] != null) {
          if (mounted) {
            setState(() {
              _avatarUrl = res['avatar_url'] as String;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading avatar in landing page: $e");
    }
  }

  void _changePage(String page) {
    setState(() {
      _selectedPage = page;
    });
    _loadStudentAvatar();
  }

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
    final bool isDashboard = _selectedPage == 'Dashboard';

    return Scaffold(
      appBar: AppBar(
        title: isDashboard ? null : Text(_selectedPage),
        backgroundColor: isDashboard ? const Color(0xFF1E88E5) : Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: isDashboard
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPage = 'Profile';
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white24,
                        backgroundImage: _avatarUrl != null
                            ? NetworkImage(_avatarUrl!)
                            : null,
                        child: _avatarUrl == null
                            ? const Icon(Icons.person, color: Colors.white, size: 20)
                            : null,
                      ),
                    ),
                  ),
                ),
              ]
            : null,
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
                _changePage('Dashboard');
                Navigator.pop(context); // Close the drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              selected: _selectedPage == 'Profile',
              onTap: () {
                _changePage('Profile');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_alt_outlined),
              title: const Text('Notes'),
              selected: _selectedPage == 'Notes',
              onTap: () {
                _changePage('Notes');
                Navigator.pop(context);
              },
            ),
            const Divider(), // A visual line separator
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              selected: _selectedPage == 'Settings',
              onTap: () {
                _changePage('Settings');
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
