import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _scrollController = ScrollController();
  final _featuresKey = GlobalKey();
  final _whyUsKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  // Controller for the phone simulator state to trigger from the CTA button
  final GlobalKey<_PhoneSimulatorState> _phoneSimulatorKey = GlobalKey();

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
      body: Stack(
        children: [
          // Background soft gradient blobs for premium visual flair
          Positioned(
            top: -150,
            left: -150,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 400,
            right: -100,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.04),
                    blurRadius: 120,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          ),
          
          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Navbar
                _buildNavbar(context, isDesktop),
                
                // Content scroll area
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      children: [
                        // Hero Section
                        _buildHero(context, isDesktop),
                        
                        // Problem Section
                        _buildProblemSection(isDesktop),
                        
                        // Features Section
                        Container(
                          key: _featuresKey,
                          child: _buildFeaturesGrid(isDesktop),
                        ),
                        
                        // Why Choose Us Section
                        Container(
                          key: _whyUsKey,
                          child: _buildWhyChooseUs(isDesktop),
                        ),
                        
                        // Bottom CTA Section
                        _buildBottomCTA(),
                        
                        // Footer Section
                        _buildFooter(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Navbar ---
  Widget _buildNavbar(BuildContext context, bool isDesktop) {
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
          // Logo
          Row(
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
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          
          // Desktop Nav links
          if (isDesktop)
            Row(
              children: [
                _buildNavLink("Features", () => _scrollTo(_featuresKey)),
                const SizedBox(width: 32),
                _buildNavLink("Why FieldLogix", () => _scrollTo(_whyUsKey)),
                const SizedBox(width: 32),
                _buildNavLink("Privacy Policy", () {
                  Navigator.pushNamed(context, '/privacy');
                }),
              ],
            ),
          
          // Action Buttons
          Row(
            children: [
              if (isDesktop) ...[
                OutlinedButton(
                  onPressed: () => _showDemoDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    "Request a Demo",
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/Login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  "Login",
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavLink(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // --- Hero Section ---
  Widget _buildHero(BuildContext context, bool isDesktop) {
    final textContent = Column(
      crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE0E7FF)),
          ),
          child: Text(
            "Designed for MSW & BSW Programs",
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4F46E5),
            ),
          ),
        ),
        const SizedBox(height: 20),
        
        // Headline
        Text(
          "Streamline Social Work\nFieldwork Tracking.\nNo Paperwork. No Guesswork.",
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: isDesktop ? 48 : 32,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            height: 1.15,
          ),
        ),
        const SizedBox(height: 20),
        
        // Subheadline
        Text(
          "FieldLogix helps social work colleges track student check-ins, verify locations with photo proof, and calculate total hours automatically. Available on Android and Web.",
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xFF475569),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 36),
        
        // CTAs
        Row(
          mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _showDemoDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Row(
                children: [
                  Text(
                    "Request a Demo",
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () {
                // Scroll or trigger phone simulator animation
                _phoneSimulatorKey.currentState?.triggerDemoAnimation();
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_outline_rounded, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    "Watch How It Works",
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );

    if (isDesktop) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
        constraints: const BoxConstraints(minHeight: 650),
        child: Row(
          children: [
            Expanded(flex: 6, child: textContent),
            const SizedBox(width: 60),
            Expanded(
              flex: 5,
              child: Center(
                child: PhoneSimulator(key: _phoneSimulatorKey),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          children: [
            textContent,
            const SizedBox(height: 48),
            Center(
              child: PhoneSimulator(key: _phoneSimulatorKey),
            ),
          ],
        ),
      );
    }
  }

  // --- Problem Section ---
  Widget _buildProblemSection(bool isDesktop) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 80 : 24, vertical: 64),
      child: Column(
        children: [
          Text(
            "Managing fieldwork shouldn't feel like a second job.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: isDesktop ? 36 : 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Text(
              "As a field coordinator or professor, you shouldn't have to chase down paper logs, doubt if a student actually visited their assigned NGO, or manually calculate hundreds of field hours at the end of the semester.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFF475569),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 36),
          
          // Highlights
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFEEF2FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            constraints: const BoxConstraints(maxWidth: 850),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF2563EB), size: 36),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    "Traditional attendance systems aren't built for the dynamic nature of social work field placement. FieldLogix is.",
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E3A8A),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Features Grid ---
  Widget _buildFeaturesGrid(bool isDesktop) {
    final features = [
      _FeatureData(
        icon: Icons.my_location_rounded,
        color: const Color(0xFF3B82F6),
        title: "Fraud-Proof Check-In & Check-Out",
        desc: "Students open the FieldLogix app on their Android device when they arrive at their assigned field agency. The app captures their exact live coordinates, ensuring they are exactly where they need to be.",
      ),
      _FeatureData(
        icon: Icons.add_a_photo_rounded,
        color: const Color(0xFF10B981),
        title: "Real-Time Photo Verification",
        desc: "No more proxy attendance. To complete a check-in or check-out, students snap a quick photo at the site. It adds an unalterable layer of accountability to every single field visit.",
      ),
      _FeatureData(
        icon: Icons.timer_rounded,
        color: const Color(0xFFF59E0B),
        title: "Automatic Time Calculation",
        desc: "The moment a student checks out, FieldLogix calculates the exact time spent on-site down to the minute. No manual data entry, no math errors, and no inflated hours.",
      ),
      _FeatureData(
        icon: Icons.dashboard_rounded,
        color: const Color(0xFF8B5CF6),
        title: "Centralized Web Dashboard",
        desc: "College administrators and professors can log in via any web browser to see real-time student locations, review uploaded photos, and export clean, audit-ready attendance sheets with a single click.",
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 80 : 24, vertical: 64),
      child: Column(
        children: [
          Text(
            "Core Features Designed for Accountability",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: isDesktop ? 36 : 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 48),
          if (isDesktop)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 32,
                mainAxisSpacing: 32,
                mainAxisExtent: 220,
              ),
              itemCount: 4,
              itemBuilder: (context, idx) => _FeatureCard(data: features[idx]),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(height: 24),
              itemBuilder: (context, idx) => _FeatureCard(data: features[idx]),
            ),
        ],
      ),
    );
  }

  // --- Why Choose Us Section ---
  Widget _buildWhyChooseUs(bool isDesktop) {
    final reasons = [
      _WhyUsData(
        icon: Icons.verified_user_rounded,
        title: "100% Accountability",
        desc: "Geolocation combined with photo proof means total peace of mind for university audits and certification records.",
      ),
      _WhyUsData(
        icon: Icons.bolt_rounded,
        title: "Massive Time Savings",
        desc: "Eliminate hours of manual Excel entry or reviewing messy paper log books at the end of every term.",
      ),
      _WhyUsData(
        icon: Icons.sync_rounded,
        title: "Cross-Platform Syncing",
        desc: "Seamless, immediate data synchronization between the student Android app and the admin Web portal dashboard.",
      ),
      _WhyUsData(
        icon: Icons.school_rounded,
        title: "Tailored for MSW/BSW",
        desc: "Built specifically to handle the unique compliance, safety, and hour-tracking requirements of social work field education.",
      ),
    ];

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 80 : 24, vertical: 64),
      width: double.infinity,
      child: Column(
        children: [
          Text(
            "Why Social Work Colleges Choose FieldLogix",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: isDesktop ? 36 : 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 48),
          
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: reasons.map((r) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFEEF2FF),
                        child: Icon(r.icon, color: const Color(0xFF2563EB), size: 28),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        r.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        r.desc,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reasons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 36),
              itemBuilder: (context, index) {
                final r = reasons[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFEEF2FF),
                      child: Icon(r.icon, color: const Color(0xFF2563EB), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.title,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            r.desc,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF64748B),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // --- Bottom CTA ---
  Widget _buildBottomCTA() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Text(
            "Ready to modernize your field work tracking?",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Join the forward-thinking social work departments using FieldLogix to eliminate manual paperwork.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF93C5FD),
            ),
          ),
          const SizedBox(height: 36),
          ElevatedButton(
            onPressed: () => _showDemoDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              "Schedule a Demo Today",
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // --- Footer ---
  Widget _buildFooter(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0F19),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      width: double.infinity,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "FieldLogix",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.pushNamed(context, '/privacy');
                },
                child: Text(
                  "Privacy Policy",
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF1E293B), height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "© 2026 FieldLogix. All rights reserved.",
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              Text(
                "Compliance & Assurance",
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Request Demo Dialog ---
  void _showDemoDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final collegeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Text(
              "Schedule a Demo",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Let us show you how FieldLogix can transform your social work fieldwork tracking.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  validator: (v) => v == null || v.trim().isEmpty ? "Please enter your name" : null,
                  decoration: _dialogInputDecoration("Your Full Name", Icons.person_outline),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Please enter your email";
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                      return "Please enter a valid email";
                    }
                    return null;
                  },
                  decoration: _dialogInputDecoration("Work Email Address", Icons.email_outlined),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: collegeController,
                  validator: (v) => v == null || v.trim().isEmpty ? "Please enter your college name" : null,
                  decoration: _dialogInputDecoration("University / Organization Name", Icons.school_outlined),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              "Cancel",
              style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop();
                _showSuccessDialog(context, nameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              "Submit Request",
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF10B981),
              size: 72,
            ),
            const SizedBox(height: 20),
            Text(
              "Thank you, $name!",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "We have received your demo request. One of our team members will contact you within 24 hours to schedule your personalized session.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF475569),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Great!"),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dialogInputDecoration(String labelText, IconData icon) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
      labelStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}

// --- Dynamic Feature Card Helper ---
class _FeatureCard extends StatefulWidget {
  final _FeatureData data;
  const _FeatureCard({required this.data});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? widget.data.color.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
              width: _isHovered ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered ? widget.data.color.withValues(alpha: 0.1) : const Color(0x050F172A),
                offset: const Offset(0, 10),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.data.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.data.icon, color: widget.data.color, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                widget.data.title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  widget.data.desc,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF475569),
                    height: 1.5,
                  ),
                  overflow: TextOverflow.fade,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Data structures
class _FeatureData {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  _FeatureData({required this.icon, required this.color, required this.title, required this.desc});
}

class _WhyUsData {
  final IconData icon;
  final String title;
  final String desc;
  _WhyUsData({required this.icon, required this.title, required this.desc});
}

// --- Interactive Phone Simulator ---
class PhoneSimulator extends StatefulWidget {
  const PhoneSimulator({super.key});

  @override
  State<PhoneSimulator> createState() => _PhoneSimulatorState();
}

class _PhoneSimulatorState extends State<PhoneSimulator> {
  // Steps: 0 = Idle, 1 = Locate (GPS Pulse), 2 = Camera snap, 3 = Checked In & Active Timer
  int _simStep = 0;
  String _simStatus = "Awaiting Placement Arrival";
  int _timerSeconds = 0;

  void triggerDemoAnimation() {
    if (_simStep != 0) return;
    _startDemoFlow();
  }

  void _startDemoFlow() async {
    setState(() {
      _simStep = 1;
      _simStatus = "Fetching Geolocation...";
    });

    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    setState(() {
      _simStep = 2;
      _simStatus = "Taking Photo Proof...";
    });

    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    setState(() {
      _simStep = 3;
      _simStatus = "Checked In Successfully!";
      _timerSeconds = 0;
    });

    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || _simStep != 3) return false;
      setState(() {
        _timerSeconds++;
      });
      return _timerSeconds < 5; // Simulates 5 seconds of time logging
    }).then((_) {
      if (mounted && _simStep == 3) {
        setState(() {
          _simStep = 4; // Check-out screen
          _simStatus = "Check-Out Logged!";
        });
      }
    });
  }

  void _resetDemo() {
    setState(() {
      _simStep = 0;
      _simStatus = "Awaiting Placement Arrival";
      _timerSeconds = 0;
    });
  }

  String _formatTime(int totalSecs) {
    // scale seconds to mock hours/minutes
    int minutes = totalSecs * 27;
    int hours = minutes ~/ 60;
    int remainingMins = minutes % 60;
    return "${hours.toString().padLeft(2, '0')}:${remainingMins.toString().padLeft(2, '0')}:${(totalSecs % 60).toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 600,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark slate Phone shell
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: const Color(0xFF1E293B), width: 12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 24),
            blurRadius: 38,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              // Screen Notch
              Container(
                height: 24,
                color: const Color(0xFF1E88E5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // App Bar Simulator
              Container(
                color: const Color(0xFF1E88E5),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.menu_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      "FieldLogix App",
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Body Simulator
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildPhoneBody(),
                ),
              ),
              
              // Status Banner
              Container(
                color: const Color(0xFFF1F5F9),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _simStep == 4
                          ? Icons.check_circle_rounded
                          : _simStep == 3
                              ? Icons.alarm_on_rounded
                              : _simStep > 0
                                  ? Icons.sync_rounded
                                  : Icons.hourglass_empty_rounded,
                      color: _simStep == 4
                          ? Colors.green
                          : _simStep == 3
                              ? const Color(0xFF1E88E5)
                              : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _simStatus,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF334155),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneBody() {
    switch (_simStep) {
      case 1:
        // GPS Locating Pulse
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: Color(0xFF1E88E5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Verifying coordinates via GPS...",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            Text(
              "Lat: 40.7128° N\nLng: 74.0060° W",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

      case 2:
        // Photo Snap Simulation
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.person_rounded, size: 64, color: Color(0xFF94A3B8)),
                  Positioned(
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "CAMERA PREVIEW",
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // Flash effect
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1.0, end: 0.0),
                    duration: const Duration(milliseconds: 600),
                    builder: (context, val, child) {
                      return Opacity(
                        opacity: val,
                        child: Container(color: Colors.white),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Uploading secure selfie proof...",
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
            ),
          ],
        );

      case 3:
        // Checked In timer sequence
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Active Placement",
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF065F46)),
                        ),
                        Text(
                          "St. Mary's Shelter",
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF047857)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "Logged Duration",
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Text(
              _formatTime(_timerSeconds),
              style: GoogleFonts.outfit(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: null, // Disabled to show automatic demo sequence
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Check Out"),
            ),
          ],
        );

      case 4:
        // Finished / checkout screen summary
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_rounded, color: Colors.green, size: 56),
            const SizedBox(height: 16),
            Text(
              "Session Summary",
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _summaryRow("Agency", "St. Mary's Shelter"),
                  const Divider(height: 20),
                  _summaryRow("Date", "June 19, 2026"),
                  const Divider(height: 20),
                  _summaryRow("Hours Logged", "2 hrs 15 mins"),
                  const Divider(height: 20),
                  _summaryRow("GPS Match", "100% Accurate"),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _resetDemo,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Run Demo Again"),
            ),
          ],
        );

      default:
        // Idle screen
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pin_drop_rounded, size: 64, color: Color(0xFF94A3B8)),
            const SizedBox(height: 20),
            Text(
              "Ready to Check-In",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Select assigned field agency to start your shift tracking.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            ElevatedButton(
              onPressed: _startDemoFlow,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                "Check In",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
    }
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
        ),
      ],
    );
  }
}
