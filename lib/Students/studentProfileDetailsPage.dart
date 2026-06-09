import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StudentProfileDetailsPage extends StatelessWidget {
  final Map<String, dynamic> profile;

  const StudentProfileDetailsPage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final displayName = profile['display_name'] ?? 'N/A';
    final regNo = profile['registration_no'] ?? 'N/A';
    final department = profile['department'] ?? 'N/A';
    final college = profile['college'] ?? 'N/A';
    final secretCode = profile['secret_code'] ?? profile['college_code'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Profile Details",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey[200],
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card with Avatar & Primary Details
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF232526), Color(0xFF414345)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 44),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Registration No: $regNo",
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Academic Information
              _buildSectionHeader("Academic Information"),
              const SizedBox(height: 8),
              _buildCard([
                _buildDetailTile(
                  icon: Icons.class_outlined,
                  label: "Class",
                  value: profile['class'],
                  color: Colors.blueAccent,
                ),
                _buildDivider(),
                _buildDetailTile(
                  icon: Icons.calendar_today_outlined,
                  label: "Batch",
                  value: profile['batch'],
                  color: Colors.teal,
                ),
                _buildDivider(),
                _buildDetailTile(
                  icon: Icons.dns_outlined,
                  label: "Current Semester",
                  value: profile['semester'],
                  color: Colors.orangeAccent,
                ),
                _buildDivider(),
                _buildDetailTile(
                  icon: Icons.star_outline_rounded,
                  label: "Specialisation",
                  value: profile['specialisation'],
                  color: Colors.purpleAccent,
                ),
              ]),
              const SizedBox(height: 24),

              // Placement Information
              _buildSectionHeader("Placement Information"),
              const SizedBox(height: 8),
              _buildCard([
                _buildDetailTile(
                  icon: Icons.business_outlined,
                  label: "Organisation Placed",
                  value: profile['organisation_placed'],
                  color: Colors.indigoAccent,
                ),
              ]),
              const SizedBox(height: 24),

              // Supervision & Mentors
              _buildSectionHeader("Supervision & Mentoring"),
              const SizedBox(height: 8),
              _buildCard([
                _buildDetailTile(
                  icon: Icons.face_retouching_natural_rounded,
                  label: "Faculty Supervisor",
                  value: profile['faculty_supervisor'],
                  color: Colors.pinkAccent,
                ),
                _buildDivider(),
                _buildDetailTile(
                  icon: Icons.assignment_ind_outlined,
                  label: "Agency Supervisor",
                  value: profile['agency_supervisor'],
                  color: Colors.teal,
                ),
                _buildDivider(),
                _buildDetailTile(
                  icon: Icons.person_pin_rounded,
                  label: "Related Professor",
                  value: profile['related_professor'],
                  color: Colors.deepPurpleAccent,
                ),
              ]),
              const SizedBox(height: 24),

              // Institutional Information
              _buildSectionHeader("Institution Details"),
              const SizedBox(height: 8),
              _buildCard([
                _buildDetailTile(
                  icon: Icons.school_outlined,
                  label: "College / University",
                  value: college,
                  color: Colors.redAccent,
                ),
                _buildDivider(),
                _buildDetailTile(
                  icon: Icons.domain_outlined,
                  label: "Department",
                  value: department,
                  color: Colors.blueAccent,
                ),
                _buildDivider(),
                _buildDetailTile(
                  icon: Icons.vpn_key_outlined,
                  label: "College Secret Code",
                  value: secretCode.toString(),
                  color: Colors.amber,
                ),
              ]),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey[200]!, width: 1.5),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: Colors.grey[100],
      height: 1,
      thickness: 1,
      indent: 56,
      endIndent: 16,
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required dynamic value,
    required Color color,
  }) {
    final displayValue = (value == null || value.toString().trim().isEmpty) ? 'Not Assigned' : value.toString().trim();
    final isNotAssigned = displayValue == 'Not Assigned';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayValue,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isNotAssigned ? Colors.grey[400] : Colors.black87,
                    fontStyle: isNotAssigned ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
