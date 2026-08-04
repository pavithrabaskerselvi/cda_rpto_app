import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'providers/profile_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const CdaRptoApp());
}

// Below this width we treat the window as a phone and keep the locked
// 430px "phone frame" look (matches CDA Inventory). At or above it — i.e.
// laptop/desktop browser windows — the app uses the real available width
// instead of being boxed into a tiny phone-shaped column.
const double _kMobileBreakpoint = 600.0;

// On very wide desktop monitors we still cap the content so it doesn't
// stretch into an unreadable single line of cards edge-to-edge. Screens
// between the mobile breakpoint and this cap get the FULL window width.
const double _kDesktopMaxWidth = 1200.0;

class CdaRptoApp extends StatelessWidget {
  const CdaRptoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        // your other providers (auth_provider, batch_provider etc.)
        // can be added here too if you want them app-wide
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'CDA RPTO',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          routes: AppRoutes.routes,
          // Handles routes that need arguments (e.g. /batch-detail needs a
          // batchId). Routes not found here fall back to the `routes` map above.
          onGenerateRoute: AppRoutes.onGenerateRoute,
          // Responsive shell:
          //  • width < 600  (phone / narrow mobile web) -> locked 430px
          //    phone frame with the starfield letterbox either side, same
          //    as CDA Inventory.
          //  • 600 <= width <= 1200 (tablet / laptop) -> uses the FULL
          //    available width, no letterbox, no lock.
          //  • width > 1200 (large desktop monitor) -> content capped at
          //    1200px and centered so cards/text don't stretch edge-to-edge.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final windowWidth = mq.size.width;
            final isMobile = windowWidth < _kMobileBreakpoint;

            double contentWidth;
            if (isMobile) {
              contentWidth = windowWidth > 430.0 ? 430.0 : windowWidth;
            } else if (windowWidth > _kDesktopMaxWidth) {
              contentWidth = _kDesktopMaxWidth;
            } else {
              contentWidth = windowWidth; // laptop/tablet: use full width
            }

            // Only show the decorative blue starfield letterbox when we're
            // actually boxing the content in (mobile-locked or capped
            // desktop) — on laptop/tablet widths in between, the app fills
            // the window so there's no letterbox to draw.
            final showLetterbox = contentWidth < windowWidth;

            final sizedChild = Center(
              child: SizedBox(
                width: contentWidth,
                height: mq.size.height,
                child: MediaQuery(
                  data: mq.copyWith(size: Size(contentWidth, mq.size.height)),
                  child: ClipRect(child: child!),
                ),
              ),
            );

            if (!showLetterbox) {
              // Full-bleed: no frame, no gradient background needed.
              return sizedChild;
            }

            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1442C4), Color(0xFF0B2A8A), Color(0xFF1442C4)],
                ),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(child: _FrameStarfield()),
                  sizedChild,
                ],
              ),
            );
          },
          // `home` is wrapped in a Builder so the `context` used inside
          // onFinished belongs to a widget that's already a descendant of the
          // Navigator MaterialApp creates. Using the outer `context` from
          // CdaRptoApp.build() directly would fail with "Navigator operation
          // requested with a context that does not include a Navigator."
          home: Builder(
            builder: (context) {
              return SplashScreen(
                onFinished: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const AuthGate()),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Listens to auth state and shows Login or Dashboard accordingly.
/// This avoids the login-screen-flash issue by not popping/pushing manually.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const DashboardScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

/// Gently twinkling stars scattered across the blue letterbox background
/// behind the phone frame — matches the reference mock's speckled blue
/// side panels. Purely decorative; doesn't affect the app content itself.
class _FrameStarfield extends StatefulWidget {
  const _FrameStarfield();

  @override
  State<_FrameStarfield> createState() => _FrameStarfieldState();
}

class _FrameStarfieldState extends State<_FrameStarfield> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _FrameStarfieldPainter(twinkle: _ctrl.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _FrameStarfieldPainter extends CustomPainter {
  final double twinkle;
  _FrameStarfieldPainter({required this.twinkle});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(11); // fixed seed = stable star layout
    for (var i = 0; i < 140; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final baseR = rnd.nextDouble() * 1.4 + 0.4;
      // Each star drifts opacity slightly out of phase for a subtle twinkle.
      final phase = (i % 7) / 7;
      final alpha = 0.25 + 0.35 * (0.5 + 0.5 * math.sin((twinkle + phase) * 2 * math.pi));
      final paint = Paint()..color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(dx, dy), baseR, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FrameStarfieldPainter oldDelegate) => oldDelegate.twinkle != twinkle;
}