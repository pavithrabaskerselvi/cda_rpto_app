import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns totals for each category card on the dashboard.
  /// Counts students by their `category` field: "RPTO", "FPV", "Aerial"
  static Future<Map<String, int>> getCategoryTotals() async {
    final snapshot = await _firestore.collection('students').get();

    int rptoCount = 0;
    int fpvCount = 0;
    int aerialCount = 0;

    for (final doc in snapshot.docs) {
      final category = (doc.data()['category'] ?? '').toString().toLowerCase();
      switch (category) {
        case 'rpto':
          rptoCount++;
          break;
        case 'fpv':
          fpvCount++;
          break;
        case 'aerial':
          aerialCount++;
          break;
      }
    }

    return {
      'RPTO': rptoCount,
      'FPV': fpvCount,
      'Aerial': aerialCount,
    };
  }

  /// Stream version - live updates on dashboard without manual refresh
  static Stream<Map<String, int>> categoryTotalsStream() {
    return _firestore.collection('students').snapshots().map((snapshot) {
      int rptoCount = 0;
      int fpvCount = 0;
      int aerialCount = 0;

      for (final doc in snapshot.docs) {
        final category = (doc.data()['category'] ?? '').toString().toLowerCase();
        switch (category) {
          case 'rpto':
            rptoCount++;
            break;
          case 'fpv':
            fpvCount++;
            break;
          case 'aerial':
            aerialCount++;
            break;
        }
      }

      return {
        'RPTO': rptoCount,
        'FPV': fpvCount,
        'Aerial': aerialCount,
      };
    });
  }
}