import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';

/// Shown when the user taps the "Batches" tile. Instead of dumping every
/// batch (RPC, FPV, Agri, ...) into one flat list, this shows one card per
/// course category. Tapping a card opens BatchListScreen scoped to just
/// that category's batches.
class BatchCategoryScreen extends StatelessWidget {
  const BatchCategoryScreen({super.key});

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  Color _kNavy(BuildContext c) =>
      _isDark(c) ? const Color(0xFF05070D) : const Color(0xFFF7F8FA);
  Color _kSurface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF10141F) : const Color(0xFFFFFFFF);
  Color _kSurfaceElevated(BuildContext c) =>
      _isDark(c) ? const Color(0xFF161B29) : const Color(0xFFF1F3F6);
  Color _kTextPrimary(BuildContext c) =>
      _isDark(c) ? const Color(0xFFF5F6FA) : const Color(0xFF0F172A);
  Color _kTextSecondary(BuildContext c) =>
      _isDark(c) ? const Color(0xFF8A93A6) : const Color(0xFF5B6472);
  Color _kBorder(BuildContext c) =>
      _isDark(c) ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E5EA);

  @override
  Widget build(BuildContext context) {
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
              'Batches',
              style: TextStyle(
                color: _kTextPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: 24,
                letterSpacing: 0.2,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Choose a course to view its batches',
                style: TextStyle(
                  color: _kTextSecondary(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: _buildCategoryRows(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Lays category cards out 3-per-row with each card sized to fit its own
  // content (icon + label + count) instead of stretching to fill a tall
  // fixed-aspect-ratio grid cell — matches the compact RPTO Vault look.
  List<Widget> _buildCategoryRows(BuildContext context) {
    final items = kBatchCategoryInfo;
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 3) {
      final chunk = items.sublist(i, i + 3 > items.length ? items.length : i + 3);
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < chunk.length; j++) ...[
              if (j > 0) const SizedBox(width: 10),
              Expanded(
                child: _CategoryCard(
                  info: chunk[j],
                  isDark: _isDark(context),
                  surface: _kSurfaceElevated(context),
                  surfaceBase: _kSurface(context),
                  border: _kBorder(context),
                  textPrimary: _kTextPrimary(context),
                  textSecondary: _kTextSecondary(context),
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.batchList,
                      arguments: chunk[j].key,
                    );
                  },
                ),
              ),
            ],
            // Pad the last row so cards stay a consistent width even when
            // it has fewer than 3 items.
            if (chunk.length < 3) ...[
              for (var k = 0; k < 3 - chunk.length; k++) ...[
                const SizedBox(width: 10),
                const Expanded(child: SizedBox()),
              ],
            ],
          ],
        ),
      );
      rows.add(const SizedBox(height: 10));
    }
    if (rows.isNotEmpty) rows.removeLast();
    return rows;
  }
}

class _CategoryCard extends StatelessWidget {
  final BatchCategoryInfo info;
  final bool isDark;
  final Color surface;
  final Color surfaceBase;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.info,
    required this.isDark,
    required this.surface,
    required this.surfaceBase,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  /// Counts batches under this category. Batches saved before the
  /// category field existed have no `category` value at all — those are
  /// counted under RPC (see normalizeBatchCategory).
  Stream<int> _countStream() {
    return FirebaseFirestore.instance
        .collection('batches')
        .snapshots()
        .map((snap) => snap.docs.where((doc) {
      final data = doc.data();
      return normalizeBatchCategory(data['category'] as String?) ==
          info.key;
    }).length);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [surface, surfaceBase],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor: info.color.withValues(alpha: 0.08),
          highlightColor: info.color.withValues(alpha: 0.04),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: info.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(info.icon, color: info.color, size: 19),
                ),
                const SizedBox(height: 9),
                Text(
                  info.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                StreamBuilder<int>(
                  stream: _countStream(),
                  builder: (context, snapshot) {
                    final count = snapshot.data;
                    return Text(
                      count == null
                          ? '…'
                          : '$count batch${count == 1 ? '' : 'es'}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
