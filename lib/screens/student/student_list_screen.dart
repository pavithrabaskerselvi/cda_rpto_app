import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import '../../models/student_model.dart';
import 'student_detail_screen.dart';
import 'student_add_screen.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  String _searchQuery = '';
  String _selectedStatus = 'All';

  final List<String> _statuses = ['All', 'Active', 'Completed', 'Dropped'];

  @override
  void dispose() {
    super.dispose();
  }

  Color _statusColor(CompanyColors c, String status) {
    switch (status) {
      case 'Active':
        return c.success;
      case 'Completed':
        return c.accent;
      case 'Dropped':
        return c.danger;
      default:
        return c.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final c = CompanyColors.of(isDark);

    return Scaffold(
      backgroundColor: c.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: c.accent,
        foregroundColor: c.background,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentAddScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: c.background,
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: c.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'StudentList',
              style: GoogleFonts.plusJakartaSans(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 22),
            ),
            actions: const [],
            flexibleSpace: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    c.gold.withValues(alpha: 0.18),
                    c.accent.withValues(alpha: 0.12),
                    c.background,
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(110),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    TextField(
                      style: GoogleFonts.plusJakartaSans(color: c.textPrimary),
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.toLowerCase()),
                      decoration: InputDecoration(
                        hintText:
                        'Search roll no / name / email / phone / aadhaar...',
                        hintStyle: GoogleFonts.plusJakartaSans(color: c.textSecondary),
                        prefixIcon: Icon(Icons.search, color: c.accent),
                        filled: true,
                        fillColor: c.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // ---- Status chip row ----
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _statuses.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final s = _statuses[index];
                          final selected = s == _selectedStatus;
                          return ChoiceChip(
                            label: Text(s),
                            selected: selected,
                            onSelected: (_) => setState(() {
                              _selectedStatus = s;
                            }),
                            selectedColor: c.accent,
                            backgroundColor: c.surface,
                            labelStyle: GoogleFonts.plusJakartaSans(
                              color: selected ? c.background : c.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: selected ? c.accent : c.borderSubtle.withValues(alpha: 0.08),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('students')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text('Error: ${snapshot.error}',
                        style: GoogleFonts.plusJakartaSans(color: c.textPrimary)),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: c.accent)),
                );
              }

              final allStudents = snapshot.data!.docs
                  .map((doc) => StudentModel.fromDocument(doc))
                  .toList();

              final students = allStudents.where((s) {
                final matchesStatus =
                    _selectedStatus == 'All' || s.status == _selectedStatus;
                final matchesSearch = _searchQuery.isEmpty ||
                    s.rollNo.toLowerCase().contains(_searchQuery) ||
                    s.name.toLowerCase().contains(_searchQuery) ||
                    s.email.toLowerCase().contains(_searchQuery) ||
                    s.phone.toLowerCase().contains(_searchQuery) ||
                    s.aadhaar.toLowerCase().contains(_searchQuery);
                return matchesStatus && matchesSearch;
              }).toList()
              // Roll No ascending (numeric-aware; blanks sort last)
                ..sort(StudentModel.compareRollNo);

              if (students.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text('No students found',
                        style: GoogleFonts.plusJakartaSans(
                            color: c.textSecondary, fontSize: 16)),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final student = students[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: _statusColor(c, student.status)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    StudentDetailScreen(student: student),
                              ),
                            );
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  c.gold.withValues(alpha: 0.7),
                                  c.accent.withValues(alpha: 0.6),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: c.background,
                              child: Text(
                                student.name.isNotEmpty
                                    ? student.name[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.plusJakartaSans(
                                    color: c.accent, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          title: Text(
                            student.rollNo.isNotEmpty
                                ? '${student.rollNo} • ${student.name}'
                                : student.name,
                            style: GoogleFonts.plusJakartaSans(
                                color: c.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              [
                                student.batchName,
                                student.phone,
                              ].join(' • '),
                              style: GoogleFonts.plusJakartaSans(
                                  color: c.textSecondary, fontSize: 13),
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _statusColor(c, student.status)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              student.status,
                              style: GoogleFonts.plusJakartaSans(
                                color: _statusColor(c, student.status),
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: students.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}