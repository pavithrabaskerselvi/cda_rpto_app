import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // NEW
import '../../models/student_model.dart';
import '../../providers/theme_provider.dart'; // NEW
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

  // ---- Theme-aware colors: flip between dark/light based on current
  // Theme brightness instead of hardcoded dark-only constants. ----
  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _pBackground(BuildContext c) =>
      _isDark(c) ? const Color(0xFF05070D) : const Color(0xFFF5F7FA);
  Color _pSurface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF10141F) : const Color(0xFFFFFFFF);
  Color _pAccent(BuildContext c) =>
      _isDark(c) ? const Color(0xFF2DD4BF) : const Color(0xFF0E9488);
  Color _pGold(BuildContext c) =>
      _isDark(c) ? const Color(0xFFC9A24B) : const Color(0xFFA9822F);
  Color _pTextPrimary(BuildContext c) =>
      _isDark(c) ? const Color(0xFFF5F6FA) : const Color(0xFF0B1220);
  Color _pTextSecondary(BuildContext c) =>
      _isDark(c) ? const Color(0xFF8A93A6) : const Color(0xFF5B6472);
  Color _pTextMuted(BuildContext c) =>
      _isDark(c) ? const Color(0xFF6B7280) : const Color(0xFF9AA3B2);
  Color _pDanger(BuildContext c) =>
      _isDark(c) ? const Color(0xFFE0685A) : const Color(0xFFC94A3B);
  Color _pSuccess(BuildContext c) =>
      _isDark(c) ? const Color(0xFF3FCE8E) : const Color(0xFF1F9D63);
  Color _pAmber(BuildContext c) =>
      _isDark(c) ? const Color(0xFFFFB020) : const Color(0xFFB77400);

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'Active':
        return _pSuccess(context);
      case 'Completed':
        return _pAccent(context);
      case 'Dropped':
        return _pDanger(context);
      default:
        return _pAmber(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>(); // NEW

    return Scaffold(
      backgroundColor: _pBackground(context),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _pAccent(context),
        foregroundColor: _pBackground(context),
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
            backgroundColor: _pBackground(context),
            pinned: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: _pTextPrimary(context)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'StudentList',
              style: GoogleFonts.plusJakartaSans(
                  color: _pTextPrimary(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 22),
            ),
            // NEW: dark/light mode toggle
            actions: [
              Row(
                children: [
                  Icon(Icons.light_mode,
                      size: 18,
                      color: themeProvider.isDarkMode
                          ? _pTextMuted(context)
                          : _pAmber(context)),
                  Switch(
                    value: themeProvider.isDarkMode,
                    activeColor: _pAccent(context),
                    onChanged: (val) => themeProvider.toggleTheme(val),
                  ),
                  Icon(Icons.dark_mode,
                      size: 18,
                      color: themeProvider.isDarkMode
                          ? _pAccent(context)
                          : _pTextMuted(context)),
                  const SizedBox(width: 8),
                ],
              ),
            ],
            flexibleSpace: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _pGold(context).withValues(alpha: 0.18),
                    _pAccent(context).withValues(alpha: 0.12),
                    _pBackground(context),
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
                      style: GoogleFonts.plusJakartaSans(
                          color: _pTextPrimary(context)),
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.toLowerCase()),
                      decoration: InputDecoration(
                        hintText:
                        'Search roll no / name / email / phone / aadhaar...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                            color: _pTextMuted(context)),
                        prefixIcon:
                        Icon(Icons.search, color: _pAccent(context)),
                        filled: true,
                        fillColor: _pSurface(context),
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
                            selectedColor: _pAccent(context),
                            backgroundColor: _pSurface(context),
                            labelStyle: GoogleFonts.plusJakartaSans(
                              color: selected
                                  ? _pBackground(context)
                                  : _pTextSecondary(context),
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide.none,
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
                        style: GoogleFonts.plusJakartaSans(
                            color: _pTextPrimary(context))),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return SliverFillRemaining(
                  child: Center(
                      child:
                      CircularProgressIndicator(color: _pAccent(context))),
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
                            color: _pTextSecondary(context), fontSize: 16)),
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
                          color: _pSurface(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: _statusColor(context, student.status)
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
                                  _pGold(context).withValues(alpha: 0.7),
                                  _pAccent(context).withValues(alpha: 0.6),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: _pBackground(context),
                              child: Text(
                                student.name.isNotEmpty
                                    ? student.name[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.plusJakartaSans(
                                    color: _pAccent(context),
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          title: Text(
                            student.rollNo.isNotEmpty
                                ? '${student.rollNo} • ${student.name}'
                                : student.name,
                            style: GoogleFonts.plusJakartaSans(
                                color: _pTextPrimary(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 16),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              [
                                student.batchName,
                                student.phone,
                              ].join(' • '),
                              style: GoogleFonts.plusJakartaSans(
                                  color: _pTextSecondary(context),
                                  fontSize: 13),
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _statusColor(context, student.status)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              student.status,
                              style: GoogleFonts.plusJakartaSans(
                                color: _statusColor(context, student.status),
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