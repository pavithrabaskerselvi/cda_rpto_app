import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import '../overall/overall_list_home_screen.dart';
import 'aerial_fpv_student_list_screen.dart';

/// Aerial / FPV entry screen: one "Years" option. Tap it to open all the
/// years (2022 and continuing up to the current year automatically).
/// Choosing a year shows that year's students + Add Student / Bulk Add.
class AerialFpvYearScreen extends StatefulWidget {
  final String category; // 'aerial' | 'fpv'

  /// true when opened from Overall List: a year opens the spreadsheet-style
  /// table instead of the student cards.
  final bool overall;
  const AerialFpvYearScreen(
      {super.key, required this.category, this.overall = false});

  @override
  State<AerialFpvYearScreen> createState() => _AerialFpvYearScreenState();
}

class _AerialFpvYearScreenState extends State<AerialFpvYearScreen> {
  bool _open = false;
  int _more = 0; // extra years added with "+ Add year"

  @override
  Widget build(BuildContext context) {
    final c = CompanyColors.of(context.watch<ThemeProvider>().isDarkMode);
    final category = widget.category;
    final accent = aerialFpvColor(category);
    final label = aerialFpvLabel(category);

    return aerialFpvThemed(
      context,
      Scaffold(
        backgroundColor: c.background,
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(kAerialFpvCollection)
              .where('category', isEqualTo: category)
              .snapshots(),
          builder: (context, snap) {
            final students = <int, int>{};
            final files = <int, int>{};
            for (final d in snap.data?.docs ?? const []) {
              final data = d.data();
              final y = aerialFpvYearOf(data);
              students[y] = (students[y] ?? 0) + 1;
              files[y] =
                  (files[y] ?? 0) + ((data['documents'] as List?) ?? []).length;
            }

            final base = aerialFpvYearOptions(
              extra: students.keys.where((y) => y > 0).fold<int?>(
                  null, (m, y) => (m == null || y > m) ? y : m),
            );
            final years = [
              for (var y = base.first; y <= base.last + _more; y++) y
            ];
            final legacyCount = students[0] ?? 0;
            final total = students.values.fold<int>(0, (a, b) => a + b);

            String sub(int y) {
              final s = students[y] ?? 0;
              final f = files[y] ?? 0;
              return '$s student${s == 1 ? '' : 's'}  •  $f file${f == 1 ? '' : 's'}';
            }

            void openYear(int y) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => widget.overall
                    ? OverallAerialFpvTableScreen(
                    category: category, year: y)
                    : AerialFpvStudentListScreen(
                    category: category, year: y),
              ),
            );

            Widget yearTile(String title, String subtitle, VoidCallback onTap) {
              return SizedBox(
                width: 170,
                height: 96,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(title,
                            style: GoogleFonts.plusJakartaSans(
                                color: accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 20)),
                        const SizedBox(height: 4),
                        Text(subtitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                                color: c.textSecondary, fontSize: 10.5)),
                      ],
                    ),
                  ),
                ),
              );
            }

            return CustomScrollView(
              slivers: [
                aerialFpvSliverAppBar(c: c, title: label),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(12),
                        border:
                        Border.all(color: accent.withValues(alpha: 0.25)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _open = !_open),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.calendar_month,
                                        color: accent, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text('Years',
                                            style: GoogleFonts.plusJakartaSans(
                                                color: c.textPrimary,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15)),
                                        const SizedBox(height: 2),
                                        Text(
                                            '${years.first} - ${years.last}  •  $total student${total == 1 ? '' : 's'}',
                                            style: GoogleFonts.plusJakartaSans(
                                                color: c.textSecondary,
                                                fontSize: 11.5)),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                      _open
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: accent),
                                ],
                              ),
                            ),
                          ),
                          if (_open)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    for (final y in years)
                                      yearTile('$y', sub(y), () => openYear(y)),
                                    if (legacyCount > 0)
                                      yearTile('No year', sub(0),
                                              () => openYear(0)),
                                    yearTile(
                                        '+ ${years.last + 1}',
                                        'Add next year',
                                            () => setState(() => _more++)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
