import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        title: const Text(
          'RPTO Vault',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
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
      ),
      body: Consumer<VaultProvider>(
        builder: (context, vault, _) {
          if (vault.isLoadingFolders && vault.folders.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vault.foldersError != null && vault.folders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.coral, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      vault.foldersError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => vault.loadFolders(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.blue,
            onRefresh: () => vault.loadFolders(),
            child: ListView(
              padding: const EdgeInsets.all(12),
              physics: const AlwaysScrollableScrollPhysics(),
              children: _buildFolderRows(context, vault.folders),
            ),
          );
        },
      ),
    );
  }

  // Lays folders out 3-per-row with each card sized to fit its own content
  // (icon + label) rather than stretching to fill a fixed aspect-ratio grid
  // cell — keeps cards compact even on wide desktop/web windows.
  List<Widget> _buildFolderRows(BuildContext context, List<VaultFolder> folders) {
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
  final VoidCallback onTap;

  const _VaultFolderTile({required this.folder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
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
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 3),
            // ---- File count ----
            Text(
              '${folder.docCount} file${folder.docCount == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}