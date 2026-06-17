import 'package:field_work_2/Students/studentsDashboardPage.dart';
import 'package:field_work_2/Students/studentProfilePage.dart';
import 'package:field_work_2/Students/studentNotesPage.dart';
import 'package:field_work_2/Students/studentFilteredLogsPage.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

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
    _loadStudentProfile();
  }

  Future<void> _loadStudentProfile() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final res = await supabase
            .from('profiles')
            .select('avatar_url')
            .eq('id', userId)
            .maybeSingle();
        if (res != null) {
          if (mounted) {
            setState(() {
              _avatarUrl = res['avatar_url'] as String?;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading profile in landing page: $e");
    }
  }

  void _changePage(String page) {
    setState(() {
      _selectedPage = page;
    });
    _loadStudentProfile();
  }

  // Helper to switch the body contents
  Widget _buildBody() {
    switch (_selectedPage) {
      case 'Profile':
        return const StudentProfilePage();
      case 'Notes':
        return const StudentNotesPage();
      case 'Logs':
        return const StudentFilteredLogsPage(
          filterActivity: 'All',
          hideAppBar: true,
        );
      default:
        return const AttendanceMainPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDashboard = _selectedPage == 'Dashboard';

    return Scaffold(
      appBar: AppBar(
        title: isDashboard
            ? null
            : Text(
                _selectedPage,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
        backgroundColor: const Color(0xFF1E88E5),
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
                            ? const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 120,
              decoration: const BoxDecoration(
                color: Color(0xFF1E88E5),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 16.0,
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Field Work',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.dashboard_rounded,
                color: Color(0xFF1E88E5),
              ),
              title: Text(
                'Dashboard',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              selected: _selectedPage == 'Dashboard',
              selectedTileColor: const Color(
                0xFF1E88E5,
              ).withValues(alpha: 0.08),
              onTap: () {
                _changePage('Dashboard');
                Navigator.pop(context); // Close the drawer
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.person_rounded,
                color: Color(0xFF1E88E5),
              ),
              title: Text(
                'Profile',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              selected: _selectedPage == 'Profile',
              selectedTileColor: const Color(
                0xFF1E88E5,
              ).withValues(alpha: 0.08),
              onTap: () {
                _changePage('Profile');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.note_alt_rounded,
                color: Color(0xFF1E88E5),
              ),
              title: Text(
                'Notes',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              selected: _selectedPage == 'Notes',
              selectedTileColor: const Color(
                0xFF1E88E5,
              ).withValues(alpha: 0.08),
              onTap: () {
                _changePage('Notes');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.history_rounded,
                color: Color(0xFF1E88E5),
              ),
              title: Text(
                'Logs',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              selected: _selectedPage == 'Logs',
              selectedTileColor: const Color(
                0xFF1E88E5,
              ).withValues(alpha: 0.08),
              onTap: () {
                _changePage('Logs');
                Navigator.pop(context);
              },
            ),
            const Divider(height: 32, color: Color(0xFFEEEEEE)),
            ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
              ),
              title: Text(
                'Logout',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.redAccent,
                ),
              ),
              onTap: () async {
                final navigator = Navigator.of(context);
                await Supabase.instance.client.auth.signOut();
                navigator.pushNamedAndRemoveUntil('/Login', (route) => false);
              },
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }
}
