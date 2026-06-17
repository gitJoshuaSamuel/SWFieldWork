import 'createStudentsPage.dart';
import 'updateStudentsPage.dart';
import 'createAdminPage.dart';
import 'updateProfessorsPage.dart';
import 'collegeOptionsPage.dart';
import 'collegeSchedulePage.dart';
import 'AdminAnalyticsDashboard.dart';
import 'attendanceLogsPage.dart';
import 'attendanceExportPage.dart';
import 'attendanceReportsPage.dart';
import 'attendanceLogsManagerPage.dart';
import 'attendanceExceptionsPage.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminLandingPage extends StatefulWidget {
  const AdminLandingPage({super.key});

  @override
  State<AdminLandingPage> createState() => _AdminLandingPageState();
}

class _AdminLandingPageState extends State<AdminLandingPage> {
  final supabase = Supabase.instance.client;
  String _selectedPage = 'Daily Report';
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
            _collegeCodeStr =
                (profile['secret_code'] ?? profile['college_code'] ?? '')
                    .toString();
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
      case 'Create professors':
        return const CreateProfessorsPage();
      case 'Update professors':
        return const UpdateProfessorsPage();
      case 'Dropdown options':
        return const CollegeOptionsPage();
      case 'Daily Report':
        return const AdminAnalyticsDashboard();
      case 'Attendance Logs':
        return const AttendanceLogsPage();
      case 'Manage Attendance':
        return const AttendanceLogsManagerPage();
      case 'Export Attendance':
        return const AttendanceExportPage();
      case 'Table View':
        return const AttendanceReportsPage();
      case 'Defaulters View':
        return const AttendanceExceptionsPage();
      case 'Schedule & Settings':
        return const CollegeSchedulePage();
      default:
        return const AdminAnalyticsDashboard();
    }
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String pageKey,
    Color? color,
  }) {
    final isSelected = _selectedPage == pageKey;
    final activeColor = color ?? const Color(0xFF1E88E5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
      child: ListTile(
        leading: Icon(
          icon,
          color: activeColor,
          size: 22,
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        selected: isSelected,
        selectedTileColor: activeColor.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _selectedPage,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
            // Header with matching background and Live Profile
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                top: 60,
                left: 20,
                right: 20,
                bottom: 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1E88E5),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _collegeCodeStr.isEmpty
                                ? "Faculty Account"
                                : "Code: $_collegeCodeStr",
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
                    title: 'Daily Report',
                    pageKey: 'Daily Report',
                  ),
                  _buildDrawerItem(
                    icon: Icons.assignment_late_rounded,
                    title: 'Defaulters View',
                    pageKey: 'Defaulters View',
                  ),
                  _buildDrawerItem(
                    icon: Icons.table_chart_rounded,
                    title: 'Table View',
                    pageKey: 'Table View',
                  ),
                  _buildDrawerItem(
                    icon: Icons.assignment_rounded,
                    title: 'Attendance Logs',
                    pageKey: 'Attendance Logs',
                  ),
                  _buildDrawerItem(
                    icon: Icons.edit_note_rounded,
                    title: 'Manage Attendance',
                    pageKey: 'Manage Attendance',
                  ),
                  _buildDrawerItem(
                    icon: Icons.download_rounded,
                    title: 'Export Attendance',
                    pageKey: 'Export Attendance',
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
                    icon: Icons.group_add_rounded,
                    title: 'Create Professors',
                    pageKey: 'Create professors',
                  ),
                  _buildDrawerItem(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'Update Professors',
                    pageKey: 'Update professors',
                  ),
                  _buildDrawerItem(
                    icon: Icons.calendar_month_rounded,
                    title: 'Schedule & Settings',
                    pageKey: 'Schedule & Settings',
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings_suggest_rounded,
                    title: 'Dropdown Options',
                    pageKey: 'Dropdown options',
                  ),
                ],
              ),
            ),

            // Logout Footer
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 12.0,
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Colors.redAccent,
                  size: 22,
                ),
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
                  navigator.pushNamedAndRemoveUntil('/Login', (route) => false);
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
