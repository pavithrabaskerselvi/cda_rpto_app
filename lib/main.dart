import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'providers/profile_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/vault_provider.dart';
import 'providers/role_provider.dart';
import 'services/access_control_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Web only: guarantees the login session survives a browser refresh
  // or reopening the tab/window, so a user only has to log in once —
  // after that (and after admin approval, for instructors), they land
  // straight on the Dashboard automatically, no login screen. Mobile
  // platforms already persist sessions like this by default.
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }
  runApp(const CdaRptoApp());
}

class CdaRptoApp extends StatelessWidget {
  const CdaRptoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        // ThemeProvider is still registered in case other code reads it,
        // but themeMode below is hardcoded to light so its dark toggle
        // no longer has any visible effect on the app.
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        // RPTO Vault — registered app-wide (not just inside the vault
        // screens) so folder counts loaded on the Vault home screen
        // persist in memory if the user navigates away and back.
        ChangeNotifierProvider(create: (_) => VaultProvider()),
        // Admin facility — holds the signed-in user's access record
        // (admin / instructor, approved / pending / rejected) app-wide.
        ChangeNotifierProvider(create: (_) => RoleProvider()),
        // your other providers (auth_provider, batch_provider etc.)
        // can be added here too if you want them app-wide
      ],
      child: MaterialApp(
        title: 'CDA RPTO',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.lightTheme,
        themeMode: ThemeMode.light,
        routes: AppRoutes.routes,
        // Handles routes that need arguments (e.g. /batch-detail needs a
        // batchId). Routes not found here fall back to the `routes` map above.
        onGenerateRoute: AppRoutes.onGenerateRoute,
        // App fills the full browser window at every size — no
        // phone-frame lock, no width cap, no letterbox.
        builder: (context, child) {
          return child!;
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
    );
  }
}

/// Listens to auth state and shows Login / Waiting-Approval / Dashboard
/// accordingly. This is the ONE place that decides whether a signed-in
/// user is actually allowed into the app — it runs on every app start
/// (not just fresh logins), so a user who was approved, then revoked,
/// gets caught here too. Thanks to Firebase session persistence, once a
/// user has logged in and been approved once, every future app open
/// lands straight on Dashboard — this widget re-runs automatically but
/// the checks all pass instantly, so it's invisible to the user.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Gate on AuthService.isVerifyingLogin FIRST, before even looking at
    // authStateChanges. login_screen flips this true right before it
    // signs in, and only flips it back false once its own post-sign-in
    // checks (isAdminEmail / role-vs-dropdown match) have fully resolved
    // — including any signOut() they trigger.
    //
    // IMPORTANT: while verifying, this must keep rendering LoginScreen
    // itself — NOT a separate spinner widget. Swapping to a different
    // widget here unmounts LoginScreen's State mid-flight (its
    // _handleLogin() is still awaiting Firestore/Firebase calls), which
    // trips every `if (!mounted) return;` guard inside it and skips the
    // isAdminEmail/role checks (and the signOut() they're supposed to
    // trigger) entirely — silently letting a mismatched login through.
    // This was the actual bug behind "picking Admin with any email logs
    // straight into the app, no error."
    return ValueListenableBuilder<bool>(
      valueListenable: AuthService.isVerifyingLogin,
      builder: (context, verifying, _) {
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            // Still verifying (login_screen's post-sign-in checks are in
            // flight) — stay on LoginScreen regardless of what
            // authStateChanges just reported, so its State/checks are
            // never torn down mid-check.
            if (verifying) {
              return const LoginScreen();
            }
            final user = snapshot.data;
            if (user == null) {
              return const LoginScreen();
            }
            return _RoleGate(user: user);
          },
        );
      },
    );
  }
}

/// Loads (or refreshes) the signed-in user's access record via
/// AccessControlService, then routes to Dashboard / PendingApproval /
/// back to Login based on the result.
class _RoleGate extends StatefulWidget {
  final User user;
  const _RoleGate({required this.user});

  @override
  State<_RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<_RoleGate> {
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    // Deferred to a microtask: _load() awaits roleProvider.loadFromFirebaseUser(),
    // which calls notifyListeners() before its first `await`. Calling it directly
    // from initState runs that notifyListeners() synchronously while Flutter is
    // still building this widget's subtree, which throws "setState() or
    // markNeedsBuild() called during build". Future.microtask pushes the call
    // to right after the current build finishes, avoiding that.
    _future = Future.microtask(() => _load());
  }

  @override
  void didUpdateWidget(covariant _RoleGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different user signed in (e.g. sign out -> sign in as someone
    // else without the widget tree fully rebuilding) — reload.
    if (oldWidget.user.uid != widget.user.uid) {
      // Same reasoning as initState above — didUpdateWidget also runs
      // during the build phase, so defer for the same reason.
      _future = Future.microtask(() => _load());
    }
  }

  Future<void> _load() async {
    final roleProvider = context.read<RoleProvider>();
    try {
      await roleProvider.loadFromFirebaseUser(widget.user);
    } on AccountRemovedException catch (_) {
      await FirebaseAuth.instance.signOut();
      roleProvider.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Consumer<RoleProvider>(
          builder: (context, role, _) {
            // Not signed in (e.g. got kicked out above for a removed
            // account) — authStateChanges will fire again shortly and
            // rebuild AuthGate into LoginScreen; show a spinner meanwhile.
            if (!role.isSignedIn) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (role.access!.isRejected) {
              return const PendingApprovalScreen(rejected: true);
            }
            if (role.isPendingApproval) {
              return const PendingApprovalScreen();
            }
            // Admin, or an instructor/student with approved access.
            return const DashboardScreen();
          },
        );
      },
    );
  }
}