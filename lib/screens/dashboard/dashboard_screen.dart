import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../company/company_list_screen.dart';
import '../drone/drone_list_screen.dart';
import '../simulator/sim_list_screen.dart';
import '../student/student_list_screen.dart';
import '../batch/batch_list_screen.dart';
import '../instructor/instructor_list_screen.dart';
import '../profile/profile_screen.dart';

/// Dashboard restyled as a flight-instrument / HUD panel: corner-bracket
/// "targeting" frames, a radar sweep behind the crest, monospace readouts,
/// and signal-strength ticks on the fleet counters. Every recurring device
/// (brackets, ticks, tabular clock) is drawn from the same aviation-console
/// vocabulary so the page reads as one instrument, not a stack of cards.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();
  String? _userName;

  // Drives the radar sweep behind the crest.
  late AnimationController _radarController;
  // Drives the shimmer callsign text and the status-dot pulse.
  late AnimationController _pulseController;
  // Drives the drone that periodically flies across the header.
  late AnimationController _droneController;

  int _navIndex = 0;

  @override
  void initState() {
    super.initState();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // One flight every 7s, with a pause between passes so it reads as a
    // recurring event rather than constant noise.
    _droneController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();

    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _userName = doc.data()?['name'] ?? doc.data()?['email'] ?? 'User';
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _radarController.dispose();
    _pulseController.dispose();
    _droneController.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = _now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _todayLabel() {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${_now.day} ${months[_now.month - 1]} ${_now.year}';
  }

  String _timeLabel() {
    int hour = _now.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final minute = _now.minute.toString().padLeft(2, '0');
    final second = _now.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second $period';
  }

  void _onNavTap(int index) {
    if (index == _navIndex) return;

    if (index == 2) {
      // Profile tab tapped — open the real Profile screen.
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ).then((_) {
        // Reset nav highlight back to Home after returning from Profile.
        if (mounted) setState(() => _navIndex = 0);
      });
      return;
    }

    setState(() => _navIndex = index);

    if (index == 1) {
      // Search screen not built yet — keep the "coming soon" placeholder.
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: AppColors.blue.withValues(alpha: 0.3)),
          ),
          content: const Text('Search — coming soon', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
      setState(() => _navIndex = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nunito applied page-wide: every Text/​_ShimmerText on this screen
    // inherits it, including the clock and readouts.
    final nunitoTheme = GoogleFonts.nunitoTextTheme(Theme.of(context).textTheme);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: nunitoTheme,
        primaryTextTheme: nunitoTheme,
      ),
      child: Scaffold(
        // ---------- Left side navigation drawer: all modules + logout ----------
        drawer: _HudDrawer(userName: _userName),
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColors.blue,
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 400));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------- Header: status strip, radar crest, callsign, flying drone ----------
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.blue.withValues(alpha: 0.22),
                          AppColors.blue.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Flying drone: sweeps left-to-right across the header,
                        // banking slightly, fading in/out at the edges, then
                        // pauses before the next pass.
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _droneController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: _FlyingDronePainter(
                                  progress: _droneController.value,
                                  color: AppColors.teal,
                                ),
                              );
                            },
                          ),
                        ),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status strip: hamburger menu + pulsing ONLINE tag + logout
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    // Hamburger icon opens the left drawer.
                                    Builder(
                                      builder: (context) => InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => Scaffold.of(context).openDrawer(),
                                        child: const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(Icons.menu_rounded,
                                              color: AppColors.textSecondary, size: 22),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (context, child) {
                                        final pulse = 0.5 +
                                            0.5 * math.sin(_pulseController.value * 2 * math.pi);
                                        return Row(
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppColors.green,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.green
                                                        .withValues(alpha: 0.25 + 0.45 * pulse),
                                                    blurRadius: 7,
                                                    spreadRadius: 1.5,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 7),
                                            _ShimmerText(
                                              text: 'SYSTEM ONLINE',
                                              controller: _pulseController,
                                              highlightColor: AppColors.green,
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1.4,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.logout, color: AppColors.textSecondary, size: 20),
                                  onPressed: () => AuthService.logout(),
                                ),
                              ],
                            ),

                            // Center branding: radar-swept crest
                            Center(
                              child: Column(
                                children: [
                                  SizedBox(
                                    width: 96,
                                    height: 96,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        AnimatedBuilder(
                                          animation: _radarController,
                                          builder: (context, child) => CustomPaint(
                                            size: const Size(96, 96),
                                            painter: _RadarSweepPainter(
                                              progress: _radarController.value,
                                              ringColor: AppColors.blue,
                                              sweepColor: AppColors.teal,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 82,
                                          height: 82,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                            border: Border.all(
                                              color: AppColors.blue.withValues(alpha: 0.5),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.blue.withValues(alpha: 0.25),
                                                blurRadius: 14,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          // ClipOval + cover + slight upscale so the logo
                                          // fills the circle edge-to-edge with no white
                                          // ring showing around it.
                                          child: ClipOval(
                                            child: Transform.scale(
                                              scale: 1.25,
                                              child: Image.asset(
                                                'lib/assets/images/logo.webp',
                                                fit: BoxFit.cover,
                                                filterQuality: FilterQuality.high,
                                                isAntiAlias: true,
                                                errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.flight_takeoff,
                                                    color: AppColors.blue, size: 32),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _ShimmerText(
                                    text: 'CHENNAI DRONE ACADEMY',
                                    controller: _pulseController,
                                    highlightColor: AppColors.blue,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  _ShimmerText(
                                    text: 'SKYLYNC UNMANNED SYSTEMS pvt.ltd',
                                    controller: _pulseController,
                                    highlightColor: AppColors.blue,
                                    phase: 0.15,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _ShimmerText(
                                  text: _userName != null ? '${_greeting()}, $_userName' : _greeting(),
                                  controller: _pulseController,
                                  phase: 0.3,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 9),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                _ShimmerText(
                                  text: _todayLabel(),
                                  controller: _pulseController,
                                  phase: 0.45,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                _ShimmerText(
                                  text: _timeLabel(),
                                  controller: _pulseController,
                                  phase: 0.6,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionEyebrow('FLEET STATUS', AppColors.blue),
                        const SizedBox(height: 14),

                        StreamBuilder<Map<String, int>>(
                          stream: DashboardService.categoryTotalsStream(),
                          builder: (context, snapshot) {
                            final totals = snapshot.data ?? {'RPTO': 0, 'FPV': 0, 'Aerial': 0};
                            return Row(
                              children: [
                                Expanded(
                                  child: _InstrumentCard(
                                    label: 'RPTO',
                                    count: totals['RPTO'] ?? 0,
                                    color: AppColors.blue,
                                    icon: Icons.flight_takeoff,
                                    controller: _pulseController,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _InstrumentCard(
                                    label: 'FPV',
                                    count: totals['FPV'] ?? 0,
                                    color: AppColors.purple,
                                    icon: Icons.videogame_asset,
                                    controller: _pulseController,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _InstrumentCard(
                                    label: 'AERIAL',
                                    count: totals['Aerial'] ?? 0,
                                    color: AppColors.teal,
                                    icon: Icons.terrain,
                                    controller: _pulseController,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 32),
                        _sectionEyebrow('CONTROL MODULES', AppColors.teal),
                        const SizedBox(height: 14),

                        // ---- Control Modules grid (3 columns, matches reference screenshot) ----
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                          children: [
                            _TapColorCard(
                              title: 'Company Details',
                              imagePath: 'lib/assets/images/company_details.jpeg',
                              color: AppColors.blue,
                              controller: _pulseController,
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const CompanyListScreen())),
                            ),
                            _TapColorCard(
                              title: 'Instructors',
                              imagePath: 'lib/assets/images/instructor.jpeg',
                              color: AppColors.teal,
                              controller: _pulseController,
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const InstructorListScreen())),
                            ),
                            _TapColorCard(
                              title: 'Drones',
                              imagePath: 'lib/assets/images/drone.jpeg',
                              color: AppColors.amber,
                              controller: _pulseController,
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const DroneListScreen())),
                            ),
                            _TapColorCard(
                              title: 'Simulators',
                              imagePath: 'lib/assets/images/simulator.jpeg',
                              color: AppColors.purple,
                              controller: _pulseController,
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const SimListScreen())),
                            ),
                            _TapColorCard(
                              title: 'Students',
                              imagePath: 'lib/assets/images/student.jpeg',
                              color: AppColors.green,
                              controller: _pulseController,
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const StudentListScreen())),
                            ),
                            _TapColorCard(
                              title: 'Batches',
                              imagePath: 'lib/assets/images/batch_list.jpeg',
                              color: AppColors.coral,
                              controller: _pulseController,
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const BatchListScreen())),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),
                        _BrandFooter(controller: _pulseController),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: _HudBottomNav(
          currentIndex: _navIndex,
          onTap: _onNavTap,
        ),
      ),
    );
  }

  Widget _sectionEyebrow(String label, Color accent) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        _ShimmerText(
          text: label,
          controller: _pulseController,
          highlightColor: accent,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

// ---------------- Left drawer: full module list + logout ----------------

/// Slide-out navigation drawer opened from the header hamburger icon.
/// Mirrors the header crest at the top, lists every control module in the
/// same order as the dashboard grid, and ends with a dedicated Logout row.
class _HudDrawer extends StatelessWidget {
  final String? userName;

  const _HudDrawer({required this.userName});

  @override
  Widget build(BuildContext context) {
    final modules = <({IconData icon, String title, Color color, Widget Function() builder})>[
      (icon: Icons.apartment,title: 'Company Details', color: AppColors.blue,
      builder: () => const CompanyListScreen()),
      (icon: Icons.badge, title: 'Instructors', color: AppColors.teal,
      builder: () => const InstructorListScreen()),
      (icon: Icons.flight, title: 'Drones', color: AppColors.amber,
      builder: () => const DroneListScreen()),
      (icon: Icons.sports_esports, title: 'Simulators', color: AppColors.purple,
      builder: () => const SimListScreen()),
      (icon: Icons.school, title: 'Students', color: AppColors.green,
      builder: () => const StudentListScreen()),
      (icon: Icons.groups, title: 'Batches', color: AppColors.coral,
      builder: () => const BatchListScreen()),
      (icon: Icons.person, title: 'Profile', color: AppColors.blue,
      builder: () => const ProfileScreen()),
    ];

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Drawer header: crest + brand + signed-in user ----
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: AppColors.blue.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: ClipOval(
                      child: Transform.scale(
                        scale: 1.25,
                        child: Image.asset(
                          'lib/assets/images/logo.webp',
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          isAntiAlias: true,
                          errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.flight_takeoff, color: AppColors.blue, size: 26),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CHENNAI DRONE ACADEMY',
                          maxLines: 2,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userName != null ? 'Signed in as $userName' : 'Not signed in',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),

            // ---- All control modules ----
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: modules.length,
                itemBuilder: (context, i) {
                  final m = modules[i];
                  return ListTile(
                    leading: Icon(m.icon, color: m.color, size: 22),
                    title: Text(
                      m.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context); // close the drawer first
                      Navigator.push(context, MaterialPageRoute(builder: (_) => m.builder()));
                    },
                  );
                },
              ),
            ),

            const Divider(color: AppColors.border, height: 1),

            // ---- Logout: always last, visually separated ----
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.logout, color: AppColors.coral, size: 22),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: AppColors.coral,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  AuthService.logout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Shimmer text (callsign) ----------------

class _ShimmerText extends StatelessWidget {
  final String text;
  final AnimationController controller;
  final TextStyle style;
  final Color? highlightColor;
  final TextAlign textAlign;
  // Staggers the shimmer sweep slightly per-instance so a screen full of
  // shimmering labels doesn't all flash in perfect unison.
  final double phase;

  const _ShimmerText({
    required this.text,
    required this.controller,
    required this.style,
    this.highlightColor,
    this.textAlign = TextAlign.start,
    this.phase = 0,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = style.color ?? AppColors.textPrimary;
    final glow = highlightColor ?? Colors.white;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final slide = (controller.value + phase) % 1.0;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [baseColor, glow, baseColor],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment(-1.5 + slide * 3, 0),
              end: Alignment(-0.5 + slide * 3, 0),
            ).createShader(bounds);
          },
          child: Text(text, style: style, textAlign: textAlign),
        );
      },
    );
  }
}

// ---------------- Radar sweep painter (crest signature element) ----------------

class _RadarSweepPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color sweepColor;

  _RadarSweepPainter({
    required this.progress,
    required this.ringColor,
    required this.sweepColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, radius * 0.74, ringPaint..color = ringColor.withValues(alpha: 0.28));
    canvas.drawCircle(center, radius * 0.94, ringPaint..color = ringColor.withValues(alpha: 0.16));

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          sweepColor.withValues(alpha: 0.0),
          sweepColor.withValues(alpha: 0.0),
          sweepColor.withValues(alpha: 0.55),
        ],
        stops: const [0.0, 0.75, 1.0],
        transform: GradientRotation(progress * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.94));

    canvas.drawCircle(center, radius * 0.94, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) => oldDelegate.progress != progress;
}

// ---------------- Flying drone painter (header signature animation) ----------------

/// Draws a small drone silhouette that sweeps left-to-right across the
/// header on a gentle arc, spinning rotor blurs as it goes, then fades out
/// before looping. `progress` runs 0→1 across the whole cycle; the drone is
/// only visible for the first ~55% of it, giving a pause before the next pass.
class _FlyingDronePainter extends CustomPainter {
  final double progress;
  final Color color;

  _FlyingDronePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const flightSpan = 0.55;
    if (progress > flightSpan) return;

    final t = progress / flightSpan; // 0..1 across the visible flight

    // Fade in over the first 12%, hold, fade out over the last 15%.
    double opacity = 1.0;
    if (t < 0.12) {
      opacity = t / 0.12;
    } else if (t > 0.85) {
      opacity = (1.0 - t) / 0.15;
    }
    opacity = opacity.clamp(0.0, 1.0);
    if (opacity <= 0) return;

    // Gentle arc: left edge to right edge, dipping slightly in the middle.
    final dx = -0.15 + t * 1.3;
    final dy = 0.18 + 0.10 * math.sin(t * math.pi);
    final center = Offset(size.width * dx, size.height * dy);

    // Slight banking tilt as it "flies".
    final tilt = math.sin(t * math.pi) * 0.12;

    final bodyPaint = Paint()..color = color.withValues(alpha: 0.85 * opacity);
    final armPaint = Paint()
      ..color = color.withValues(alpha: 0.6 * opacity)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final rotorPaint = Paint()
      ..color = color.withValues(alpha: 0.28 * opacity)
      ..style = PaintingStyle.fill;
    final trailPaint = Paint()
      ..color = color.withValues(alpha: 0.18 * opacity)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);

    // Motion trail behind the drone.
    canvas.drawLine(const Offset(-22, 0), const Offset(-8, 0), trailPaint);
    canvas.drawLine(const Offset(-18, -3), const Offset(-8, -1), trailPaint);
    canvas.drawLine(const Offset(-18, 3), const Offset(-8, 1), trailPaint);

    const armLen = 8.0;
    final armOffsets = [
      const Offset(-armLen, -armLen * 0.6),
      const Offset(armLen, -armLen * 0.6),
      const Offset(-armLen, armLen * 0.6),
      const Offset(armLen, armLen * 0.6),
    ];
    for (final o in armOffsets) {
      canvas.drawLine(Offset.zero, o, armPaint);
      // Rotor blur disc, size pulses with progress to suggest spin.
      final rotorRadius = 3.0 + 0.6 * math.sin(t * 40);
      canvas.drawCircle(o, rotorRadius.abs() + 2.5, rotorPaint);
    }

    // Body.
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 12, height: 6),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FlyingDronePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ---------------- Corner-bracket HUD frame ----------------

class _CornerBracketPainter extends CustomPainter {
  final Color color;
  final double length;
  final double strokeWidth;

  _CornerBracketPainter({
    required this.color,
    this.length = 9,
    this.strokeWidth = 1.6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(0, 0), Offset(length, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, length), paint);

    canvas.drawLine(Offset(size.width, 0), Offset(size.width - length, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, length), paint);

    canvas.drawLine(Offset(0, size.height), Offset(length, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - length), paint);

    canvas.drawLine(
        Offset(size.width, size.height), Offset(size.width - length, size.height), paint);
    canvas.drawLine(
        Offset(size.width, size.height), Offset(size.width, size.height - length), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.length != length;
}

class _HudFrame extends StatelessWidget {
  final Widget child;
  final Color color;

  const _HudFrame({required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CornerBracketPainter(color: color),
      child: child,
    );
  }
}

// ---------------- Fleet status instrument card ----------------

class _InstrumentCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final AnimationController controller;

  const _InstrumentCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final litTicks = count.clamp(0, 5);
    return _HudFrame(
      color: color.withValues(alpha: 0.55),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 17),
                _ShimmerText(
                  text: label,
                  controller: controller,
                  highlightColor: Colors.white,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ShimmerText(
              text: count.toString().padLeft(2, '0'),
              controller: controller,
              highlightColor: color,
              phase: 0.2,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final lit = i < litTicks;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: 9,
                  height: 3,
                  decoration: BoxDecoration(
                    color: lit ? color : AppColors.border,
                    borderRadius: BorderRadius.circular(1),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Module card: HUD frame + full-bleed image + tap feedback ----------------
// The module image now fills the ENTIRE card edge-to-edge (BoxFit.cover),
// same as the "Stock Management" style reference. Title sits in a bottom
// gradient scrim on top of the image so it stays readable regardless of
// what the artwork looks like underneath. On tap, a color tint washes over
// the image for feedback instead of a background-color swap.
//
// NOTE: if a module's source PNG has a lot of built-in transparent padding
// (e.g. company_details.png), BoxFit.cover may crop into the artwork more
// aggressively than expected. If that looks wrong for a given icon, the fix
// is to tight-crop the source PNG (remove the transparent margins) rather
// than changing the fit here — changing the fit would break the "same box,
// fully covered" look for every other card.
//
// Title text: plain Text (no shimmer) — module card titles were switched
// off the shimmer effect per request; every other _ShimmerText usage on
// this screen (header, fleet counters, footer) is unchanged.

class _TapColorCard extends StatefulWidget {
  final String title;
  final String imagePath;
  final Color color;
  final VoidCallback onTap;
  final AnimationController controller;
  // Kept for API compatibility with existing call sites; no longer used
  // now that the image is full-bleed via BoxFit.cover instead of a fixed
  // centered icon size.
  final double iconSize;

  const _TapColorCard({
    required this.title,
    required this.imagePath,
    required this.color,
    required this.onTap,
    required this.controller,
    this.iconSize = 44,
  });

  @override
  State<_TapColorCard> createState() => _TapColorCardState();
}

class _TapColorCardState extends State<_TapColorCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: _HudFrame(
        color: widget.color.withValues(alpha: _isPressed ? 0.9 : 0.4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isPressed
                  ? widget.color.withValues(alpha: 0.9)
                  : widget.color.withValues(alpha: 0.25),
              width: _isPressed ? 1.4 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ---- Image fills the entire card, edge-to-edge ----
              Positioned.fill(
                child: Image.asset(
                  widget.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: widget.color.withValues(alpha: 0.15),
                    child: Icon(Icons.image_not_supported, color: widget.color, size: 28),
                  ),
                ),
              ),

              // ---- Pressed-state color wash on top of the image ----
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _isPressed ? 1 : 0,
                child: Positioned.fill(
                  child: Container(color: widget.color.withValues(alpha: 0.22)),
                ),
              ),

              // ---- Bottom gradient scrim so the title stays readable ----
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.only(top: 22, bottom: 9, left: 6, right: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

              // ---- Status dot, top-right ----
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.7),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Brand footer ----------------

/// Small watermark-style footer echoing the header crest: brand name, a
/// pulsing separator dot, and the parent company name — the last thing you
/// see before the bottom nav.
class _BrandFooter extends StatelessWidget {
  final AnimationController controller;

  const _BrandFooter({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 17,
              height: 17,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              // ClipOval + cover keeps this mini crest logo edge-to-edge too.
              child: ClipOval(
                child: Transform.scale(
                  scale: 1.25,
                  child: Image.asset(
                    'lib/assets/images/logo.webp',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(Icons.flight_takeoff, size: 11, color: AppColors.blue.withValues(alpha: 0.7)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
            _ShimmerText(
              text: 'Chennai Drone Academy',
              controller: controller,
              highlightColor: AppColors.blue,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  final pulse = 0.5 + 0.5 * math.sin(controller.value * 2 * math.pi);
                  return Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.teal.withValues(alpha: 0.5 + 0.5 * pulse),
                    ),
                  );
                },
              ),
            ),
            _ShimmerText(
              text: 'SkyLync Unmanned Pvt. Ltd.',
              controller: controller,
              highlightColor: AppColors.teal,
              phase: 0.2,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Bottom navigation (Home / Search / Profile) ----------------

class _HudBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _HudBottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.search_rounded, label: 'Search'),
    (icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            final isSelected = i == currentIndex;
            return _NavItem(
              icon: item.icon,
              label: item.label,
              isSelected: isSelected,
              onTap: () => onTap(i),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.blue : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}