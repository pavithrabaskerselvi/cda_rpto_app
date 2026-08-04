import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/batch/batch_list_screen.dart';
import '../screens/batch/batch_add_screen.dart';
import '../screens/batch/batch_detail_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';

  // Company
  static const String companyDetails = '/company-details';

  // Instructor
  static const String instructorList = '/instructor-list';
  static const String instructorAdd = '/instructor-add';

  // Drone
  static const String droneList = '/drone-list';
  static const String droneAdd = '/drone-add';

  // Simulator
  static const String simList = '/sim-list';
  static const String simAdd = '/sim-add';

  // Student
  static const String studentList = '/student-list';
  static const String studentAdd = '/student-add';

  // Batch
  static const String batchList = '/batch-list';
  static const String batchAdd = '/batch-add';
  static const String batchDetail = '/batch-detail';

  static Map<String, WidgetBuilder> get routes {
    return {
      login: (context) => const LoginScreen(),
      register: (context) => const RegisterScreen(),
      dashboard: (context) => const DashboardScreen(),
      batchList: (context) => const BatchListScreen(),
      batchAdd: (context) => const AddBatchScreen(),
      // Remaining routes added as we build each module
    };
  }

  /// Handles routes that need arguments passed in (e.g. batch-detail needs
  /// a batchId). These can't go in the plain `routes` map above because
  /// WidgetBuilder there has no access to RouteSettings.arguments.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case batchDetail:
        final batchId = settings.arguments as String?;
        if (batchId == null) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('Missing batchId for batch detail')),
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => BatchDetailScreen(batchId: batchId),
        );
      default:
        return null; // fall back to `routes` map above
    }
  }
}