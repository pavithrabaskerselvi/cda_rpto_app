import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/instructor_model.dart';
import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import 'instructor_add_screen.dart';
import 'instructor_detail_screen.dart';

class InstructorListScreen extends StatefulWidget {
  const InstructorListScreen({super.key});

  @override
  State<InstructorListScreen> createState() => _InstructorListScreenState();
}

class _InstructorListScreenState extends State<InstructorListScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Active', 'Inactive'];

  Stream<QuerySnapshot> _instructorStream() {
    return FirebaseFirestore.instance
        .collection('instructors')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final c = CompanyColors.of(isDark);

    return Scaffold(
      backgroundColor: c.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: c.background,
            pinned: true,
            expandedHeight: 130,
            elevation: 0,
            iconTheme: IconThemeData(color: c.textPrimary),
            actions: const [],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                'Instructors',
                style: GoogleFonts.plusJakartaSans(
                  color: c.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              background: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.accent.withValues(alpha: 0.35), c.background],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.plusJakartaSans(color: c.textPrimary),
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search instructor name...',
                  hintStyle: GoogleFonts.plusJakartaSans(color: c.textSecondary),
                  prefixIcon: Icon(Icons.search, color: c.textSecondary),
                  filled: true,
                  fillColor: c.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedFilter = filter),
                      selectedColor: c.accent,
                      backgroundColor: c.surface,
                      labelStyle: GoogleFonts.plusJakartaSans(
                        color: isSelected ? c.background : c.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? c.accent : c.borderSubtle.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          StreamBuilder<QuerySnapshot>(
            stream: _instructorStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: c.accent)),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text('No instructors found',
                        style: GoogleFonts.plusJakartaSans(color: c.textSecondary)),
                  ),
                );
              }

              var instructors = snapshot.data!.docs
                  .map((d) => InstructorModel.fromDocument(d))
                  .where((i) => _selectedFilter == 'All' || i.status == _selectedFilter)
                  .where((i) => _searchQuery.isEmpty || i.name.toLowerCase().contains(_searchQuery))
                  .toList();

              if (instructors.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text('No matching instructors',
                        style: GoogleFonts.plusJakartaSans(color: c.textSecondary)),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildInstructorCard(instructors[index], c),
                  childCount: instructors.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accent,
        icon: Icon(Icons.add, color: c.background),
        label: Text(
          'Add Instructor',
          style: GoogleFonts.plusJakartaSans(color: c.background, fontWeight: FontWeight.w700),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InstructorAddScreen()),
          );
        },
      ),
    );
  }

  Widget _buildInstructorCard(InstructorModel instructor, CompanyColors c) {
    final isActive = instructor.status == 'Active';
    final statusColor = isActive ? c.success : c.danger;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstructorDetailScreen(instructor: instructor),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [c.gold.withValues(alpha: 0.7), c.accent.withValues(alpha: 0.5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: c.background,
                backgroundImage: instructor.profileImageUrl != null
                    ? NetworkImage(instructor.profileImageUrl!)
                    : null,
                child: instructor.profileImageUrl == null
                    ? Text(
                  instructor.name.isNotEmpty ? instructor.name[0].toUpperCase() : '?',
                  style: GoogleFonts.plusJakartaSans(
                    color: c.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                )
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          instructor.name,
                          style: GoogleFonts.plusJakartaSans(
                            color: c.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withValues(alpha: 0.45)),
                        ),
                        child: Text(
                          instructor.status,
                          style: GoogleFonts.plusJakartaSans(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    instructor.specialization,
                    style: GoogleFonts.plusJakartaSans(color: c.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.badge_outlined, color: c.textSecondary.withValues(alpha: 0.7), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        instructor.licenseNumber,
                        style: GoogleFonts.plusJakartaSans(color: c.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.work_outline, color: c.textSecondary.withValues(alpha: 0.7), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${instructor.experienceYears} yrs',
                        style: GoogleFonts.plusJakartaSans(color: c.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.textSecondary.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
