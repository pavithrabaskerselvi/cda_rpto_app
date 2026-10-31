import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../services/auth_service.dart';
import '../../services/access_control_service.dart';
import '../company/company_list_screen.dart';
import '../drone/drone_list_screen.dart';
import '../simulator/sim_list_screen.dart';
import '../student/student_list_screen.dart';
import '../batch/batch_list_screen.dart';
import '../instructor/instructor_list_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';
import '../vault/vault_home_screen.dart';
import '../analytics/analytics_overview_screen.dart';
import '../admin/employee_access_screen.dart';
import '../admin/admin_notifications_screen.dart';
import '../aerial_fpv/aerial_fpv_home_screen.dart'; // NEW
import '../zone/zone_home_screen.dart'; // NEW
import '../overall/overall_list_home_screen.dart'; // NEW
import '../../widgets/role_gated_widget.dart';

/// Dashboard restyled as a flight-instrument / HUD panel: corner-bracket
/// "targeting" frames, a radar sweep behind the crest, monospace readouts,
/// and a squadron of big flying drones sweeping the header.
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

  late AnimationController _radarController;
  late AnimationController _pulseController;
  late AnimationController _droneController;

  int _navIndex = 0;

  static const Color _headerText = Color(0xFF0A2540);
  static const Color _headerOnDark = Colors.white;
  static const Color _headerOnDarkMuted = Color(0xFFC7D2E8);

  static const List<Color> _heroNavy = [
    Color(0xFF0A1628),
    Color(0xFF1B3B7A),
  ];

  static const Color _droneColor = Color(0xFF4FC3F7);

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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ).then((_) {
        if (mounted) setState(() => _navIndex = 0);
      });
      return;
    }

    setState(() => _navIndex = index);

    if (index == 1) {
      setState(() => _navIndex = 0);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nunitoTheme = GoogleFonts.nunitoTextTheme(Theme.of(context).textTheme);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: nunitoTheme,
        primaryTextTheme: nunitoTheme,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
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
                    // ---------- Header ----------
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: _heroNavy,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _droneController,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: _FlyingDronePainter(
                                    progress: _droneController.value,
                                    color: _droneColor,
                                  ),
                                );
                              },
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Builder(
                                        builder: (context) => InkWell(
                                          borderRadius: BorderRadius.circular(8),
                                          onTap: () => Scaffold.of(context).openDrawer(),
                                          child: const Padding(
                                            padding: EdgeInsets.only(right: 4),
                                            child: Icon(Icons.menu_rounded,
                                                color: _headerOnDark, size: 22),
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
                                                  color: _headerOnDark,
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
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AdminOnly(
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: _NotificationBell(
                                            onTap: () => Navigator.pushNamed(
                                                context, AppRoutes.adminNotifications),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.logout, color: _headerOnDark, size: 20),
                                        onPressed: () => AuthService.logout(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
                                                ringColor: Colors.white,
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
                                                  color: Colors.black.withValues(alpha: 0.25),
                                                  blurRadius: 14,
                                                  spreadRadius: 1,
                                                ),
                                              ],
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
                                      highlightColor: AppColors.teal,
                                      style: const TextStyle(
                                        color: _headerOnDark,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    _ShimmerText(
                                      text: 'SKYLYNK UNMANNED SYSTEMS PVT.LTD',
                                      controller: _pulseController,
                                      highlightColor: AppColors.teal,
                                      phase: 0.15,
                                      style: const TextStyle(
                                        color: _headerOnDarkMuted,
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
                                      color: _headerOnDark,
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
                                  const Icon(Icons.calendar_today_outlined, size: 14, color: _headerOnDarkMuted),
                                  const SizedBox(width: 6),
                                  _ShimmerText(
                                    text: _todayLabel(),
                                    controller: _pulseController,
                                    phase: 0.45,
                                    style: const TextStyle(
                                      color: _headerOnDarkMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Icon(Icons.access_time, size: 14, color: _headerOnDarkMuted),
                                  const SizedBox(width: 6),
                                  _ShimmerText(
                                    text: _timeLabel(),
                                    controller: _pulseController,
                                    phase: 0.6,
                                    style: const TextStyle(
                                      color: _headerOnDarkMuted,
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
                          const SizedBox(height: 8),
                          _sectionEyebrow('CONTROL MODULES', AppColors.teal),
                          const SizedBox(height: 14),

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
                                imagePath: 'lib/assets/images/company_details.png',
                                color: AppColors.blue,
                                controller: _pulseController,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const CompanyListScreen())),
                              ),
                              _TapColorCard(
                                title: 'Instructors',
                                imagePath: 'lib/assets/images/instructor.png',
                                color: AppColors.teal,
                                controller: _pulseController,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const InstructorListScreen())),
                              ),
                              _TapColorCard(
                                title: 'Drones',
                                imagePath: 'lib/assets/images/drone.png',
                                color: AppColors.amber,
                                controller: _pulseController,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const DroneListScreen())),
                              ),
                              _TapColorCard(
                                title: 'Simulators',
                                imagePath: 'lib/assets/images/simulator.png',
                                color: AppColors.purple,
                                controller: _pulseController,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const SimListScreen())),
                              ),
                              _TapColorCard(
                                title: 'Students',
                                imagePath: 'lib/assets/images/student.png',
                                color: AppColors.green,
                                controller: _pulseController,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const StudentListScreen())),
                              ),
                              _TapColorCard(
                                title: 'Batches',
                                imagePath: 'lib/assets/images/batch_list.png',
                                color: AppColors.coral,
                                controller: _pulseController,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const BatchListScreen())),
                              ),
                              _TapColorCard(
                                title: 'RPTO Vault',
                                imagePath: 'lib/assets/images/rpto_vault.png',
                                color: AppColors.blue,
                                controller: _pulseController,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const VaultHomeScreen())),
                              ),
                              _TapColorCard(
                                title: 'Analytics dashboard',
                                imagePath: 'lib/assets/images/analytics_dashboard.png',
                                color: AppColors.purple,
                                controller: _pulseController,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const AnalyticsOverviewScreen())),
                              ),
                              // ---- NEW: Aerial & FPV module ----
                              _TapColorCard(
                                title: 'Aerial & FPV',
                                imagePath: 'lib/assets/images/aerial_fpv.png',
                                color: AppColors.teal,
                                controller: _pulseController,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const AerialFpvHomeScreen())),
                              ),
                              // ---- NEW: Overall List module ----
                              _TapColorCard(
                                title: 'Overall List',
                                imagePath: 'lib/assets/images/overall_list.png',
                                color: AppColors.blue,
                                controller: _pulseController,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const OverallListHomeScreen())),
                              ),
                              // ---- NEW: Zone module ----
                              _TapColorCard(
                                title: 'Zone',
                                imagePath: 'lib/assets/images/zone.png',
                                color: AppColors.coral,
                                controller: _pulseController,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const ZoneHomeScreen())),
                              ),
                              // ---- Admin facility tile — admin only ----
                              AdminOnly(
                                child: _TapColorCard(
                                  title: 'Access Hub',
                                  imagePath: 'lib/assets/images/access hub.png',
                                  color: AppColors.teal,
                                  controller: _pulseController,
                                  onTap: () => Navigator.pushNamed(
                                      context, AppRoutes.accessHub),
                                ),
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
            color: _headerText,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

// ---------------- Left drawer: light-blue theme + flying drones ----------------

class _HudDrawer extends StatefulWidget {
  final String? userName;

  const _HudDrawer({required this.userName});

  @override
  State<_HudDrawer> createState() => _HudDrawerState();
}

class _HudDrawerState extends State<_HudDrawer>
    with SingleTickerProviderStateMixin {
  // Light-blue palette
  static const Color _bg = Color(0xFFF4F9FF);
  static const Color _headerTop = Color(0xFFE3F2FD);
  static const Color _headerBottom = Color(0xFF90CAF9);
  static const Color _ink = Color(0xFF0A2540);
  static const Color _inkMuted = Color(0xFF4A6382);
  static const Color _divider = Color(0xFFD0E4F7);
  // Darker blue so drones stay visible on the light header
  static const Color _droneBlue = Color(0xFF1976D2);

  late final AnimationController _droneController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    _droneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modules = <({
    IconData icon,
    String title,
    Color color,
    bool adminOnly,
    void Function(BuildContext) open,
    })>[
      (icon: Icons.apartment, title: 'Company Details', color: AppColors.blue, adminOnly: false,
      open: (c) => Navigator.push(c, MaterialPageRoute(builder: (_) => const CompanyListScreen()))),
      (icon: Icons.badge, title: 'Instructors', color: AppColors.teal, adminOnly: false,
      open: (c) => Navigator.push(c, MaterialPageRoute(builder: (_) => const InstructorListScreen()))),
      (icon: Icons.flight, title: 'Drones', color: AppColors.amber, adminOnly: false,
      open: (c) => Navigator.push(c, MaterialPageRoute(builder: (_) => const DroneListScreen()))),
      (icon: Icons.sports_esports, title: 'Simulators', color: AppColors.purple, adminOnly: false,
      open: (c) => Navigator.push(c, MaterialPageRoute(builder: (_) => const SimListScreen()))),
      (icon: Icons.school, title: 'Students', color: AppColors.green, adminOnly: false,
      open: (c) => Navigator.push(c, MaterialPageRoute(builder: (_) => const StudentListScreen()))),
      (icon: Icons.groups, title: 'Batches', color: AppColors.coral, adminOnly: false,
      open: (c) => Navigator.push(c, MaterialPageRoute(builder: (_) => const BatchListScreen()))),
      (icon: Icons.folder_special, title: 'RPTO Vault', color: AppColors.blue, adminOnly: false,
      open: (c) => Navigator.push(c, MaterialPageRoute(builder: (_) => const VaultHomeScreen()))),
      (icon: Icons.analytics, title: 'Analytics', color: AppColors.purple, adminOnly: false,
      open: (c) => Navigator.push(c, MaterialPageRoute(builder: (_) => const AnalyticsOverviewScreen()))),
      // ---- NEW: Aerial & FPV ----
      (icon: Icons.flight_takeoff, title: 'Aerial & FPV', color: AppColors.teal, adminOnly: false,
      open: (c) => Navigator.push(c, MaterialPageRoute(builder: (_) => const AerialFpvHomeScreen()))),
      // ---- NEW: Overall List ----
      (icon: Icons.format_list_bulleted, title: 'Overall List', color: AppColors.blue, adminOnly: false,
      open: (c) => Navigator.push(c, MaterialPageRoute(builder: (_) => const OverallListHomeScreen()))),
      // ---- NEW: Zone ----
      (icon: Icons.domain, title: 'Zone', color: AppColors.coral, adminOnly: false,
      open: (c) => Navigator.push(c, MaterialPageRoute(builder: (_) => const ZoneHomeScreen()))),
      // ---- Admin-only extras ----
      (icon: Icons.admin_panel_settings, title: 'Access Hub', color: AppColors.teal, adminOnly: true,
      open: (c) => Navigator.pushNamed(c, AppRoutes.accessHub)),
      (icon: Icons.notifications_active, title: 'Access Requests', color: AppColors.coral, adminOnly: true,
      open: (c) => Navigator.push(c, MaterialPageRoute(builder: (_) => const AdminNotificationsScreen()))),
      (icon: Icons.manage_accounts, title: 'Employee Access', color: AppColors.amber, adminOnly: true,
      open: (c) => Navigator.push(c, MaterialPageRoute(builder: (_) => const EmployeeAccessScreen()))),
      (icon: Icons.person, title: 'Profile', color: AppColors.blue, adminOnly: false,
      open: (c) => Navigator.push(c, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
    ];

    return Drawer(
      backgroundColor: _bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- Header with flying drones ----------
          Container(
            width: double.infinity,
            height: 170,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_headerTop, _headerBottom],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _droneController,
                      builder: (context, _) => CustomPaint(
                        painter: _FlyingDronePainter(
                          progress: _droneController.value,
                          color: _droneBlue,
                          bodyColor: _ink,
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                    color: AppColors.blue.withValues(alpha: 0.5),
                                    width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 10,
                                  ),
                                ],
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
                                    const Icon(Icons.flight_takeoff,
                                        color: AppColors.blue, size: 26),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CHENNAI DRONE ACADEMY',
                                    maxLines: 2,
                                    style: TextStyle(
                                      color: _ink,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.userName != null
                                        ? 'Signed in as ${widget.userName}'
                                        : 'Not signed in',
                                    style: const TextStyle(
                                        color: _inkMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---------- Module list ----------
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              itemCount: modules.length,
              itemBuilder: (context, i) {
                final m = modules[i];
                final tile = ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: m.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(m.icon, color: m.color, size: 20),
                  ),
                  title: Text(
                    m.title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    m.open(context);
                  },
                );
                return m.adminOnly ? AdminOnly(child: tile) : tile;
              },
            ),
          ),

          const Divider(color: _divider, height: 1),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              child: ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout,
                      color: AppColors.coral, size: 20),
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: AppColors.coral,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  AuthService.logout();
                },
              ),
            ),
          ),
        ],
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

// ---------------- Pending-approval bell (admin only) ----------------

class _NotificationBell extends StatefulWidget {
  final VoidCallback onTap;
  const _NotificationBell({required this.onTap});

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat();

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: AccessControlService.watchUnreadCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final hasPending = count > 0;

        return GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _shakeController,
            builder: (context, child) {
              final dx = hasPending
                  ? math.sin(_shakeController.value * 2 * math.pi) * 3.2
                  : 0.0;
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: SizedBox(
              width: 30,
              height: 30,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    hasPending
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  if (hasPending)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                        decoration: BoxDecoration(
                          color: AppColors.coral,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF0A1628), width: 1.2),
                        ),
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------- Radar sweep painter ----------------

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

// ---------------- Flying drone painter (shared by header + drawer) ----------------

class _FlyingDronePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bodyColor; // white on dark header, dark ink on light drawer

  _FlyingDronePainter({
    required this.progress,
    required this.color,
    this.bodyColor = Colors.white,
  });

  static const List<_DroneConfig> _drones = [
    _DroneConfig(phaseOffset: 0.00, laneY: 0.18, scale: 2.00, flightSpan: 0.55),
    _DroneConfig(phaseOffset: 0.50, laneY: 0.34, scale: 1.70, flightSpan: 0.50),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final drone in _drones) {
      _paintDrone(canvas, size, drone);
    }
  }

  void _paintDrone(Canvas canvas, Size size, _DroneConfig cfg) {
    final localProgress = (progress + cfg.phaseOffset) % 1.0;
    if (localProgress > cfg.flightSpan) return;

    final t = localProgress / cfg.flightSpan;
    final scale = cfg.scale;

    double opacity = 1.0;
    if (t < 0.12) {
      opacity = t / 0.12;
    } else if (t > 0.85) {
      opacity = (1.0 - t) / 0.15;
    }
    opacity = opacity.clamp(0.0, 1.0);
    if (opacity <= 0) return;

    final dx = -0.15 + t * 1.3;
    final dy = cfg.laneY + 0.08 * math.sin(t * math.pi);
    final center = Offset(size.width * dx, size.height * dy);

    final tilt = math.sin(t * math.pi) * 0.12;

    final armPaint = Paint()
      ..color = color.withValues(alpha: 0.9 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round;
    final rotorGlowPaint = Paint()
      ..color = color.withValues(alpha: 0.25 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * scale
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final rotorRingPaint = Paint()
      ..color = color.withValues(alpha: 0.85 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3 * scale;
    final crosshairPaint = Paint()
      ..color = color.withValues(alpha: 0.6 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9 * scale;
    final bodyGlowPaint = Paint()
      ..color = color.withValues(alpha: 0.5 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final bodyPaint = Paint()..color = bodyColor.withValues(alpha: 0.95 * opacity);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);
    canvas.scale(scale);

    const armLen = 9.0;
    final armOffsets = [
      const Offset(-armLen, -armLen * 0.75),
      const Offset(armLen, -armLen * 0.75),
      const Offset(-armLen, armLen * 0.75),
      const Offset(armLen, armLen * 0.75),
    ];

    for (final o in armOffsets) {
      canvas.drawLine(Offset.zero, o, armPaint);
    }

    const rotorRadius = 5.0;
    for (final o in armOffsets) {
      canvas.drawCircle(o, rotorRadius, rotorGlowPaint);
      canvas.drawCircle(o, rotorRadius, rotorRingPaint);
      canvas.drawLine(o + const Offset(-rotorRadius, 0), o + const Offset(rotorRadius, 0), crosshairPaint);
      canvas.drawLine(o + const Offset(0, -rotorRadius), o + const Offset(0, rotorRadius), crosshairPaint);
    }

    canvas.drawCircle(Offset.zero, 4.5, bodyGlowPaint);
    canvas.drawCircle(Offset.zero, 2.2, bodyPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FlyingDronePainter oldDelegate) =>
      oldDelegate.progress != progress ||
          oldDelegate.color != color ||
          oldDelegate.bodyColor != bodyColor;
}

class _DroneConfig {
  final double phaseOffset;
  final double laneY;
  final double scale;
  final double flightSpan;

  const _DroneConfig({
    required this.phaseOffset,
    required this.laneY,
    required this.scale,
    required this.flightSpan,
  });
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

// ---------------- Module card ----------------

class _TapColorCard extends StatefulWidget {
  final String title;
  final String imagePath;
  final Color color;
  final VoidCallback onTap;
  final AnimationController controller;
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
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _isPressed ? 1 : 0,
                  child: Container(color: widget.color.withValues(alpha: 0.22)),
                ),
              ),
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

class _BrandFooter extends StatelessWidget {
  final AnimationController controller;

  const _BrandFooter({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 7,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 17,
                  height: 17,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
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
              ],
            ),
            AnimatedBuilder(
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
            _ShimmerText(
              text: 'SKYLYNK UNMANNED SYSTEMS PVT.LTD.',
              controller: controller,
              highlightColor: AppColors.teal,
              phase: 0.2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
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