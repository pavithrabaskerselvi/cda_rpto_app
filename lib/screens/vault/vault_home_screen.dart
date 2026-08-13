import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import '../../providers/vault_provider.dart';
import '../../models/vault_folder_model.dart';
import 'vault_category_screen.dart';
import 'vault_folder_browser_screen.dart';
import 'vault_search_screen.dart';

class VaultHomeScreen extends StatefulWidget {
  const VaultHomeScreen({super.key});

  @override
  State<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends State<VaultHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VaultProvider>().loadFolders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final c = CompanyColors.of(isDark);

    // Plus Jakarta Sans applied page-wide, matching the Company Details
    // screen — every Text widget here (app bar title, folder labels, file
    // counts, error/retry states) inherits it automatically.
    final jakartaTheme = GoogleFonts.plusJakartaSansTextTheme(Theme.of(context).textTheme);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: jakartaTheme,
        primaryTextTheme: jakartaTheme,
      ),
      child: Scaffold(
        backgroundColor: c.background,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: c.background,
              pinned: true,
              expandedHeight: 130,
              elevation: 0,
              iconTheme: IconThemeData(color: c.textPrimary),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Search Vault',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VaultSearchScreen()),
                    );
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                title: Text(
                  'RPTO Vault',
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
              child: Consumer<VaultProvider>(
                builder: (context, vault, _) {
                  if (vault.isLoadingFolders && vault.folders.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (vault.foldersError != null && vault.folders.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, color: c.danger, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            vault.foldersError!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(color: c.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.accent,
                              foregroundColor: c.background,
                            ),
                            onPressed: () => vault.loadFolders(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: c.accent,
                    onRefresh: () => vault.loadFolders(),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: _buildFolderRows(context, vault.folders, c),
                      ),
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

  // Lays folders out 3-per-row with each card sized to fit its own content
  // (icon + label) rather than stretching to fill a fixed aspect-ratio grid
  // cell — keeps cards compact even on wide desktop/web windows.
  List<Widget> _buildFolderRows(
      BuildContext context, List<VaultFolder> folders, CompanyColors c) {
    final rows = <Widget>[];
    for (var i = 0; i < folders.length; i += 3) {
      final chunk = folders.sublist(i, i + 3 > folders.length ? folders.length : i + 3);
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < chunk.length; j++) ...[
              if (j > 0) const SizedBox(width: 10),
              Expanded(
                child: _VaultFolderTile(
                  folder: chunk[j],
                  colors: c,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => chunk[j].category.supportsSubfolders
                            ? VaultFolderBrowserScreen(category: chunk[j].category)
                            : VaultCategoryScreen(category: chunk[j].category),
                      ),
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

/// Compact folder tile: icon centered in a small colored chip near the
/// top, label + file count stacked underneath, all vertically centered
/// in a smaller square-ish box rather than a tall stretched card.
class _VaultFolderTile extends StatelessWidget {
  final VaultFolder folder;
  final CompanyColors colors;
  final VoidCallback onTap;

  const _VaultFolderTile({required this.folder, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: folder.color.withValues(alpha: 0.25)),
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
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ---- Small centered icon chip ----
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: folder.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(folder.icon, color: folder.color, size: 17),
            ),
            const SizedBox(height: 8),
            // ---- Label ----
            Text(
              folder.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 3),
            // ---- File count ----
            Text(
              '${folder.docCount} file${folder.docCount == 1 ? '' : 's'}',
              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}