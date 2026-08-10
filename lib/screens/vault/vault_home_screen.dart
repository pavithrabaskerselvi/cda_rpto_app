import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/vault_provider.dart';
import '../../models/vault_folder_model.dart';
import 'vault_category_screen.dart';
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
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              physics: const AlwaysScrollableScrollPhysics(),
              // Smaller, more compact tiles: 4 columns per row, near-square
              // boxes instead of tall rectangles.
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: vault.folders.length,
              itemBuilder: (context, index) {
                final folder = vault.folders[index];
                return _VaultFolderTile(
                  folder: folder,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VaultCategoryScreen(category: folder.category),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
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
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ---- Small centered icon chip ----
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: folder.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(folder.icon, color: folder.color, size: 14),
            ),
            const SizedBox(height: 6),
            // ---- Label ----
            Text(
              folder.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 2),
            // ---- File count ----
            Text(
              '${folder.docCount} file${folder.docCount == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}