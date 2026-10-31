import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import 'aerial_fpv_student_list_screen.dart';
import 'aerial_fpv_year_screen.dart';

class AerialFpvHomeScreen extends StatelessWidget {
  const AerialFpvHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final c = CompanyColors.of(isDark);

    return aerialFpvThemed(
      context,
      Scaffold(
        backgroundColor: c.background,
        body: CustomScrollView(
          slivers: [
            aerialFpvSliverAppBar(c: c, title: 'Aerial & FPV'),
            SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection(kAerialFpvCollection)
                    .snapshots(),
                builder: (context, snap) {
                  var aerialStudents = 0, fpvStudents = 0;
                  var aerialFiles = 0, fpvFiles = 0;
                  for (final d in snap.data?.docs ?? const []) {
                    final data = d.data();
                    final files = ((data['documents'] as List?) ?? []).length;
                    if (data['category'] == 'aerial') {
                      aerialStudents++;
                      aerialFiles += files;
                    } else if (data['category'] == 'fpv') {
                      fpvStudents++;
                      fpvFiles += files;
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _OptionTile(
                            c: c,
                            label: 'Aerial',
                            icon: Icons.flight,
                            color: aerialFpvColor('aerial'),
                            students: aerialStudents,
                            files: aerialFiles,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                const AerialFpvYearScreen(category: 'aerial'),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _OptionTile(
                            c: c,
                            label: 'FPV',
                            icon: Icons.vrpano_outlined,
                            color: aerialFpvColor('fpv'),
                            students: fpvStudents,
                            files: fpvFiles,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                const AerialFpvYearScreen(category: 'fpv'),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Same compact tile style as the RPTO Vault folder tiles.
class _OptionTile extends StatelessWidget {
  final CompanyColors c;
  final String label;
  final IconData icon;
  final Color color;
  final int students;
  final int files;
  final VoidCallback onTap;

  const _OptionTile({
    required this.c,
    required this.label,
    required this.icon,
    required this.color,
    required this.students,
    required this.files,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$students student${students == 1 ? '' : 's'}  •  $files file${files == 1 ? '' : 's'}',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 10, color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}