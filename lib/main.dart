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