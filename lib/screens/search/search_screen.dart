import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../company/company_list_screen.dart';
import '../drone/drone_list_screen.dart';
import '../simulator/sim_list_screen.dart';
import '../student/student_list_screen.dart';
import '../batch/batch_list_screen.dart';
import '../instructor/instructor_list_screen.dart';

/// Simple cross-module search: fetches each module's Firestore collection
/// and filters client-side (case-insensitive "contains") by nameField.
///
/// NOTE: switched from Firestore orderBy/startAt/endAt prefix queries to a
/// client-side filter, because that approach was case-sensitive and
/// returned nothing whenever the typed query's case didn't exactly match
/// the stored data's case (e.g. data stored as "SKYLYNK UNMANNED SYSTEMS
/// PVT LTD" but user types "skylynk"). Client-side filtering works
/// regardless of case and is fine for small-to-medium collections.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _ModuleConfig {
  final String label;
  final String collection;
  final String nameField;
  final IconData icon;
  final Color color;
  final Widget Function() screenBuilder;

  const _ModuleConfig({
    required this.label,
    required this.collection,
    required this.nameField,
    required this.icon,
    required this.color,
    required this.screenBuilder,
  });
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  Map<String, List<Map<String, dynamic>>> _results = {};

  static final _modules = <_ModuleConfig>[
    _ModuleConfig(
      label: 'Company Details',
      collection: 'companies',
      nameField: 'name', // confirmed against live data: top-level "name" field
      icon: Icons.apartment,
      color: AppColors.blue,
      screenBuilder: () => const CompanyListScreen(),
    ),
    _ModuleConfig(
      label: 'Instructors',
      collection: 'instructors',
      nameField: 'name',
      icon: Icons.badge,
      color: AppColors.teal,
      screenBuilder: () => const InstructorListScreen(),
    ),
    _ModuleConfig(
      label: 'Drones',
      collection: 'drones',
      nameField: 'droneName',
      icon: Icons.flight,
      color: AppColors.amber,
      screenBuilder: () => const DroneListScreen(),
    ),
    _ModuleConfig(
      label: 'Simulators',
      collection: 'simulators',
      nameField: 'name',
      icon: Icons.sports_esports,
      color: AppColors.purple,
      screenBuilder: () => const SimListScreen(),
    ),
    _ModuleConfig(
      label: 'Students',
      collection: 'students',
      nameField: 'name',
      icon: Icons.school,
      color: AppColors.green,
      screenBuilder: () => const StudentListScreen(),
    ),
    _ModuleConfig(
      label: 'Batches',
      collection: 'batches',
      nameField: 'batchName',
      icon: Icons.groups,
      color: AppColors.coral,
      screenBuilder: () => const BatchListScreen(),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(value));
  }

  Future<void> _runSearch(String value) async {
    final q = value.trim();
    setState(() {
      _query = q;
      _loading = q.isNotEmpty;
    });
    if (q.isEmpty) {
      setState(() {
        _results = {};
        _loading = false;
      });
      return;
    }

    final lower = q.toLowerCase();
    final grouped = <String, List<Map<String, dynamic>>>{};

    await Future.wait(_modules.map((m) async {
      try {
        // Fetch the collection and filter client-side. This is
        // case-insensitive and doesn't depend on Firestore's
        // orderBy/startAt/endAt prefix-matching behaviour, which was the
        // root cause of the "No results" bug (data was stored in a
        // different case than what users typed).
        final snap = await FirebaseFirestore.instance
            .collection(m.collection)
            .get();

        final docs = snap.docs
            .map((d) => {...d.data(), '_id': d.id, '_module': m.label})
            .where((d) => (d[m.nameField]?.toString().toLowerCase() ?? '')
            .contains(lower))
            .take(10)
            .toList();

        if (docs.isNotEmpty) grouped[m.label] = docs;
      } catch (_) {
        // Collection/field mismatch for this module — skip it silently.
      }
    }));

    if (!mounted) return;
    setState(() {
      _results = grouped;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search Company, Drone, Student...',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            border: InputBorder.none,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
              icon: const Icon(Icons.clear, color: AppColors.textSecondary),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_query.isEmpty) {
      return const Center(
        child: Text(
          'Type to search across all modules',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No results for "$_query"',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: _results.entries.map((entry) {
        final module = _modules.firstWhere((m) => m.label == entry.key);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                entry.key.toUpperCase(),
                style: TextStyle(
                  color: module.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            ...entry.value.map((doc) => ListTile(
              leading: Icon(module.icon, color: module.color),
              title: Text(
                doc[module.nameField]?.toString() ?? 'Untitled',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => module.screenBuilder()),
              ),
            )),
          ],
        );
      }).toList(),
    );
  }
}