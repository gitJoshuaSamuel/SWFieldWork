import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  final _scrollController = ScrollController();
  final List<GlobalKey> _sectionKeys = List.generate(6, (_) => GlobalKey());
  int _activeSection = 0;

  final List<String> _sections = [
    "1. Introduction",
    "2. Information We Collect",
    "3. How We Use Information",
    "4. Data Sharing & Privacy",
    "5. Access & Security",
    "6. Contact Us",
  ];

  void _scrollToSection(int index) {
    setState(() => _activeSection = index);
    final context = _sectionKeys[index].currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Modern slate-light background
      body: Column(
        children: [
          // Header
          _buildHeader(context),
          
          // Body content
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sidebar index (Desktop only)
                if (isDesktop) _buildSidebar(),
                
                // Privacy text content
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 60 : 20,
                      vertical: 40,
                    ),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTitleSection(),
                            const SizedBox(height: 32),
                            _buildSection(0, "1. Introduction", 
                              "Welcome to FieldLogix. We are committed to protecting the privacy of our users, specifically social work student candidates, professors, field coordinators, and university administrators. This Privacy Policy details how FieldLogix collects, uses, protects, and discloses personal information when using our Android student application and administrative Web dashboard interface.\n\n"
                              "By accessing or using FieldLogix, you agree to the collection and use of information in accordance with this policy. This application is tailored for MSW (Master of Social Work) and BSW (Bachelor of Social Work) program compliance requirements."
                            ),
                            _buildGPSHighlightCard(),
                            _buildSection(1, "2. Information We Collect", 
                              "To provide accurate fieldwork time logging and audit verification, FieldLogix collects several data types:\n\n"
                              "• Real-Time Location Coordinates: We collect your exact GPS latitude and longitude ONLY at the precise moment you tap the 'Check In' or 'Check Out' buttons inside the student Android app. The app does NOT perform background tracking of your location during your shift or while closed.\n\n"
                              "• Photo Verification: Students are required to take a live photo of themselves or their site location upon Check-In and Check-Out. This photo is securely uploaded directly to our cloud servers as visual audit verification of attendance.\n\n"
                              "• User Account Information: We store your name, email address, password hash, university placement coordinates, and system roles (Admin, Professor, Student) created by your college administration.\n\n"
                              "• Usage Metadata: Basic device diagnostics, connection timestamps, and export logs generated via the administration panel."
                            ),
                            _buildSection(2, "3. How We Use Information", 
                              "The collected information is used solely for university course compliance and academic audit assurance:\n\n"
                              "• Attendance logs verification (determining presence at assigned agency placements).\n\n"
                              "• Calculating student fieldwork hours spent on-site (down to the minute) automatically, eliminating manual timecard arithmetic errors.\n\n"
                              "• Displaying live log records to authorized college supervisors and professors via the Web Dashboard.\n\n"
                              "• Exporting official CSV or Excel placement logs for university certification and external academic board audits."
                            ),
                            _buildSection(3, "4. Data Sharing & Privacy", 
                              "Your personal data is private. FieldLogix does NOT rent, sell, share, or trade your collected personal coordinates, photo uploads, or profile data with any third-party marketing networks or external companies.\n\n"
                              "Data is accessible only to:\n"
                              "1. Authorized professors and administrative coordinators from your specific university.\n"
                              "2. Cloud infrastructure provider (Supabase storage and database APIs) under strict privacy terms."
                            ),
                            _buildSection(4, "5. Access & Security", 
                              "FieldLogix uses industry-standard measures to protect all data:\n\n"
                              "• Encryption: All uploads, including location details and verification photos, are transmitted using secure HTTPS/TLS encryption and stored in secure cloud systems managed by Supabase.\n\n"
                              "• Role-Based Policies: Database tables use Row Level Security (RLS) policies, ensuring that student users cannot modify attendance logs after creation, and students can view only their own records, while professors/admins can manage details for their specific cohorts."
                            ),
                            _buildSection(5, "6. Contact Us", 
                              "If you have any questions about this Privacy Policy, your geolocation tracking, photo privacy, or if you need to request database updates or account deletion, please contact your University Social Work Department Field Coordinator or email us directly at support@fieldlogix.edu.\n\n"
                              "Last Updated: June 19, 2026."
                            ),
                            const SizedBox(height: 60),
                            _buildBackToTopButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Simple footer
          _buildMiniFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x050F172A),
            offset: Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => Navigator.pushReplacementNamed(context, '/'),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "FieldLogix",
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text("Back to Home"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              "Table of Contents",
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _sections.length,
              itemBuilder: (context, idx) {
                final isSelected = _activeSection == idx;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ListTile(
                    onTap: () => _scrollToSection(idx),
                    selected: isSelected,
                    selectedTileColor: const Color(0xFFEFF6FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    title: Text(
                      _sections[idx],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "Legal & Compliance",
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF4F46E5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Privacy Policy",
          style: GoogleFonts.outfit(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Learn how we prioritize security and transparency in tracking placements.",
          style: GoogleFonts.inter(
            fontSize: 15,
            color: const Color(0xFF64748B),
          ),
        ),
        const Divider(color: Color(0xFFE2E8F0), height: 40),
      ],
    );
  }

  Widget _buildSection(int index, String title, String body) {
    return Container(
      key: _sectionKeys[index],
      padding: const EdgeInsets.only(bottom: 40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: const Color(0xFF334155),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGPSHighlightCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 40.0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.security_rounded, color: Color(0xFF059669), size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Zero Background Tracking Guarantee",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "FieldLogix only reads coordinates and requests location verification during the check-in and check-out taps. We value your privacy and never track your movements in the background.",
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: const Color(0xFF047857),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackToTopButton() {
    return Center(
      child: OutlinedButton.icon(
        onPressed: () {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
          );
        },
        icon: const Icon(Icons.arrow_upward_rounded, size: 16),
        label: const Text("Back to Top"),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF64748B),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildMiniFooter() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "© 2026 FieldLogix. All rights reserved.",
            style: GoogleFonts.inter(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
          Text(
            "Privacy Compliance Standard v1.2",
            style: GoogleFonts.inter(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
