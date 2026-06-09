import 'package:field_work_2/Professors/createStudentsPage.dart';
import 'package:field_work_2/Professors/updateStudentsPage.dart';
import 'package:field_work_2/Professors/collegeOptionsPage.dart';
import 'package:field_work_2/Professors/collegeSchedulePage.dart';
import 'package:field_work_2/Professors/professorsAnalyticsDashboard.dart';
import 'package:field_work_2/Professors/attendanceLogsPage.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class Professorslandingpage extends StatefulWidget {
  const Professorslandingpage({super.key});

  @override
  State<Professorslandingpage> createState() => _ProfessorslandingpageState();
}

class _ProfessorslandingpageState extends State<Professorslandingpage> {
  final supabase = Supabase.instance.client;
  String _selectedPage = 'Analytics Dashboard';
  String _professorName = 'Professor';
  String _collegeCodeStr = '';

  @override
  void initState() {
    super.initState();
    _loadProfessorProfile();
  }

  Future<void> _loadProfessorProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final profile = await supabase
            .from('profiles')
            .select('display_name, secret_code, college_code')
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null) {
          setState(() {
            _professorName = profile['display_name'] ?? 'Professor';
            _collegeCodeStr = (profile['secret_code'] ?? profile['college_code'] ?? '').toString();
          });
        }
      }
    } catch (_) {}
  }

  Widget _buildBody() {
    switch (_selectedPage) {
      case 'Create students':
        return const Createstudentspage();
      case 'Update students':
        return const UpdateStudentsPage();
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

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String pageKey,
    Color? color,
  }) {
    final isSelected = _selectedPage == pageKey;
    final activeColor = color ?? Colors.indigo[800]!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? activeColor : Colors.grey[600],
          size: 22,
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? activeColor : Colors.grey[700],
          ),
        ),
        selected: isSelected,
        selectedTileColor: activeColor.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: () {
          setState(() => _selectedPage = pageKey);
          Navigator.pop(context); // Close drawer
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        toolbarHeight: 64,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
          child: Builder(
            builder: (context) => IconButton(
              icon: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    )
                  ],
                  border: Border.all(color: Colors.grey[200]!, width: 1),
                ),
                child: const Icon(Icons.menu_rounded, color: Colors.black87, size: 20),
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        title: Text(
          _selectedPage,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            // Header with Gradient and Live Profile
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _professorName,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _collegeCodeStr.isEmpty ? "Faculty Account" : "Code: $_collegeCodeStr",
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Navigation Items
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.analytics_rounded,
                    title: 'Analytics Dashboard',
                    pageKey: 'Analytics Dashboard',
                  ),
                  _buildDrawerItem(
                    icon: Icons.assignment_rounded,
                    title: 'Attendance Logs',
                    pageKey: 'Attendance Logs',
                  ),
                  _buildDrawerItem(
                    icon: Icons.calendar_month_rounded,
                    title: 'Schedule & Settings',
                    pageKey: 'Schedule & Settings',
                  ),
                  _buildDrawerItem(
                    icon: Icons.person_add_rounded,
                    title: 'Create Students',
                    pageKey: 'Create students',
                  ),
                  _buildDrawerItem(
                    icon: Icons.manage_accounts_rounded,
                    title: 'Update Students',
                    pageKey: 'Update students',
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings_suggest_rounded,
                    title: 'Dropdown Options',
                    pageKey: 'Dropdown options',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Divider(),
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    pageKey: 'Settings',
                  ),
                ],
              ),
            ),

            // Logout Footer
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              child: ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
                title: Text(
                  'Logout',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await supabase.auth.signOut();
                  navigator.pushNamedAndRemoveUntil(
                    '/Login',
                    (route) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }
}
