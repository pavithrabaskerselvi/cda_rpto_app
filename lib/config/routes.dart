import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/batch/batch_list_screen.dart';
import '../screens/batch/batch_add_screen.dart';
import '../screens/batch/batch_detail_screen.dart';
import '../screens/batch/bulk_batch_setup_screen.dart';
import '../screens/import/bulk_import_screen.dart';
import '../controllers/bulk_import_controller.dart';
import '../screens/import/drone_bulk_import_screen.dart';
import '../controllers/drone_bulk_import_controller.dart';
import '../screens/vault/vault_home_screen.dart';

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
  static const String bulkBatchSetup = '/bulk-batch-setup';

  // RPTO Vault
  // Home screen only needs a plain route — the category screen needs a
  // VaultCategory argument, so it's pushed directly with
  // Navigator.push(MaterialPageRoute(...)) from vault_home_screen.dart
  // instead of going through named routes.
  static const String vaultHome = '/vault-home';

  // Bulk Import (student documents)
  // NOTE: intentionally NOT in the `routes` map below — it needs an
  // optional argument (batchName) to support "import for this batch
  // only", and the plain `routes` map has no access to
  // RouteSettings.arguments. Always navigate to it with pushNamed,
  // passing a String batchName if you want it scoped, or null/omitted
  // to import across all batches.
  static const String bulkImport = '/bulk-import';

  // Bulk Import (drone documents)
  // Same reasoning as above — needs arguments, so it's handled in
  // onGenerateRoute. Navigate with:
  //   Navigator.pushNamed(context, AppRoutes.droneBulkImport,
  //     arguments: {'droneId': drone.id, 'droneName': drone.droneName});
  // for a single-drone import scoped to that drone, or with no
  // arguments (or null) for a multi-drone import across a picked root
  // folder.
  static const String droneBulkImport = '/drone-bulk-import';

  static Map<String, WidgetBuilder> get routes {
    return {
      login: (context) => const LoginScreen(),
      register: (context) => const RegisterScreen(),
      dashboard: (context) => const DashboardScreen(),
      batchList: (context) => const BatchListScreen(),
      batchAdd: (context) => const AddBatchScreen(),
      bulkBatchSetup: (context) => const BulkBatchSetupScreen(),
      vaultHome: (context) => const VaultHomeScreen(),
      // Remaining routes added as we build each module
    };
  }

  /// Handles routes that need arguments passed in (e.g. batch-detail needs
  /// a batchId, bulk-import needs an optional batchName). These can't go
  /// in the plain `routes` map above because WidgetBuilder there has no
  /// access to RouteSettings.arguments.
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

      case bulkImport:
      // Optional: pass a batch name (e.g. "BATCH 1") to scope the
      // import to just that batch's folder. Pass nothing / null to
      // import across every batch folder under the picked root.
        final batchName = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => Provider<BulkImportController>(
            create: (_) => BulkImportController(batchNameFilter: batchName),
            dispose: (_, controller) => controller.dispose(),
            child: BulkImportScreen(batchName: batchName),
          ),
        );

      case droneBulkImport:
      // Optional Map<String, String> {'droneId', 'droneName'} to scope
      // the import to one drone (single-drone mode). Pass nothing /
      // null for a multi-drone import across every drone folder under
      // the picked root.
        final args = settings.arguments as Map?;
        final droneId = args?['droneId'] as String?;
        final droneName = args?['droneName'] as String?;
        return MaterialPageRoute(
          builder: (_) => Provider<DroneBulkImportController>(
            create: (_) => DroneBulkImportController(
              singleDroneId: droneId,
              singleDroneName: droneName,
            ),
            dispose: (_, controller) => controller.dispose(),
            child: DroneBulkImportScreen(droneName: droneName),
          ),
        );

      default:
        return null; // fall back to `routes` map above
    }
  }
}
