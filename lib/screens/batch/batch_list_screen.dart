import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // NEW
import '../../config/routes.dart';
import '../../providers/theme_provider.dart'; // NEW

class BatchListScreen extends StatefulWidget {
  const BatchListScreen({super.key});

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Active', 'Upcoming', 'Completed', 'Archived'];

  // ---- Theme-aware colors: flip between dark/light based on current
  // Theme brightness instead of hardcoded light-only constants. ----
  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  Color _kNavy(BuildContext c) =>
      _isDark(c) ? const Color(0xFF05070D) : const Color(0xFFF7F8FA);
  Color _kSurface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF10141F) : const Color(0xFFFFFFFF);
  Color _kSurfaceElevated(BuildContext c) =>
      _isDark(c) ? const Color(0xFF161B29) : const Color(0xFFF1F3F6);
  Color _kTeal(BuildContext c) =>
      _isDark(c) ? const Color(0xFF2DD4BF) : const Color(0xFF0F9E93);
  Color _kTealGlow(BuildContext c) =>
      _isDark(c) ? const Color(0xFF5EEAD4) : const Color(0xFF14B8A6);
  Color _kTextPrimary(BuildContext c) =>
      _isDark(c) ? const Color(0xFFF5F6FA) : const Color(0xFF0F172A);
  Color _kTextSecondary(BuildContext c) =>
      _isDark(c) ? const Color(0xFF8A93A6) : const Color(0xFF5B6472);
  Color _kBorder(BuildContext c) =>
      _isDark(c) ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E5EA);
  Color _kAmber(BuildContext c) =>
      _isDark(c) ? const Color(0xFFFFB020) : const Color(0xFFB77400);
  Color _kGreen(BuildContext c) =>
      _isDark(c) ? const Color(0xFF3FCE8E) : const Color(0xFF1F9D63);

  Color _statusColor(BuildContext c, String status) {
    switch (status.toLowerCase()) {
      case 'ongoing':
      case 'active':
        return _kTeal(c);
      case 'completed':
        return _kGreen(c);
      case 'upcoming':
        return _kAmber(c);
      case 'archived':
        return _kTextSecondary(c);
      default:
        return _kTextSecondary(c);
    }
  }

  bool _matchesFilter(String status) {
    if (_selectedFilter == 'All') return true;
    if (_selectedFilter == 'Active') {
      return status.toLowerCase() == 'ongoing' || status.toLowerCase() == 'active';
    }
    return status.toLowerCase() == _selectedFilter.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>(); // NEW

    return Scaffold(
      backgroundColor: _kNavy(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: _kNavy(context),
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: _kTextPrimary(context)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'BatchList',
              style: TextStyle(
                color: _kTextPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: 24,
                letterSpacing: 0.2,
              ),
            ),
            // NEW: dark/light mode toggle
            actions: [
              Row(
                children: [
                  Icon(Icons.light_mode,
                      size: 18,
                      color: themeProvider.isDarkMode
                          ? _kTextSecondary(context)
                          : _kAmber(context)),
                  Switch(
                    value: themeProvider.isDarkMode,
                    activeColor: _kTeal(context),
                    onChanged: (val) => themeProvider.toggleTheme(val),
                  ),
                  Icon(Icons.dark_mode,
                      size: 18,
                      color: themeProvider.isDarkMode
                          ? _kTeal(context)
                          : _kTextSecondary(context)),
                  const SizedBox(width: 4),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: 'Bulk Import Documents',
                  icon: Icon(Icons.upload_file, color: _kTextPrimary(context)),
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.bulkImport);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: 'Bulk Batch Setup (batch + student list at once)',
                  icon: Icon(Icons.playlist_add, color: _kTextPrimary(context)),
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.bulkBatchSetup);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_kTeal(context), _kTealGlow(context)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _kTeal(context).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRoutes.batchAdd);
                    },
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                style: TextStyle(color: _kTextPrimary(context)),
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search batches...',
                  hintStyle: TextStyle(color: _kTextSecondary(context)),
                  prefixIcon: Icon(Icons.search, color: _kTeal(context)),
                  filled: true,
                  fillColor: _kSurface(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _kBorder(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _kBorder(context)),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedFilter = filter),
                      selectedColor: _kTeal(context),
                      backgroundColor: _kSurface(context),
                      labelStyle: TextStyle(
                        color: isSelected ? _kNavy(context) : _kTextSecondary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? _kTeal(context) : _kBorder(context)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('batches')
                .orderBy('startDate', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Error loading batches: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: _kTeal(context)),
                  ),
                );
              }

              final allDocs = snapshot.data?.docs ?? [];
              final docs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final batchName = (data['batchName'] ?? '').toString().toLowerCase();
                final status = (data['status'] ?? 'Upcoming').toString();
                final matchesSearch = _searchQuery.isEmpty || batchName.contains(_searchQuery);
                return matchesSearch && _matchesFilter(status);
              }).toList();

              if (docs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.groups_outlined,
                            color: _kTextSecondary(context), size: 52),
                        const SizedBox(height: 14),
                        Text(
                          allDocs.isEmpty ? 'No batches found' : 'No matching batches',
                          style: TextStyle(
                            color: _kTextPrimary(context),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          allDocs.isEmpty ? 'Tap + to create a new batch' : 'Try a different search or filter',
                          style: TextStyle(color: _kTextSecondary(context), fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final data =
                      docs[index].data() as Map<String, dynamic>;
                      final docId = docs[index].id;

                      final batchName = data['batchName'] ?? 'Unnamed Batch';
                      final instructor = data['instructor'] ?? '-';
                      final studentCount = data['studentCount'] ?? 0;
                      final status = data['status'] ?? 'Upcoming';
                      final startDate = data['startDate'] != null
                          ? (data['startDate'] as Timestamp).toDate()
                          : null;
                      final endDate = data['endDate'] != null
                          ? (data['endDate'] as Timestamp).toDate()
                          : null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_kSurfaceElevated(context), _kSurface(context)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _kBorder(context)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: _isDark(context) ? 0.35 : 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            splashColor: _kTeal(context).withValues(alpha: 0.08),
                            highlightColor: _kTeal(context).withValues(alpha: 0.04),
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                AppRoutes.batchDetail,
                                arguments: docId,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          batchName,
                                          style: TextStyle(
                                            color: _kTextPrimary(context),
                                            fontSize: 19,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _statusColor(context, status)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                          BorderRadius.circular(20),
                                          border: Border.all(
                                            color: _statusColor(context, status)
                                                .withValues(alpha: 0.4),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: _statusColor(context, status),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    height: 1,
                                    color: _kBorder(context),
                                  ),
                                  const SizedBox(height: 14),
                                  _infoRow(context, Icons.person_outline,
                                      'Instructor: $instructor'),
                                  const SizedBox(height: 8),
                                  _infoRow(context, Icons.groups_2_outlined,
                                      'Students: $studentCount'),
                                  if (startDate != null && endDate != null) ...[
                                    const SizedBox(height: 8),
                                    _infoRow(
                                      context,
                                      Icons.calendar_today_outlined,
                                      '${_formatDate(startDate)} - ${_formatDate(endDate)}',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: docs.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: _kTeal(context), size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: _kTextSecondary(context),
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}