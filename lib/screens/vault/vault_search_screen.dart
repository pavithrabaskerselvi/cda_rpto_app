import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../config/vault_categories.dart';
import '../../models/vault_document_model.dart';
import '../../providers/vault_provider.dart';

/// Cross-category search across every file in RPTO Vault. Also fills
/// the previously-empty `screens/search/` slot if you want the bottom
/// nav "Search" tab to open here specifically for Vault content — or
/// keep this as a Vault-only search reached from the Vault app bar.
class VaultSearchScreen extends StatefulWidget {
  const VaultSearchScreen({super.key});

  @override
  State<VaultSearchScreen> createState() => _VaultSearchScreenState();
}

class _VaultSearchScreenState extends State<VaultSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      context.read<VaultProvider>().search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search RPTO Vault…',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                context.read<VaultProvider>().clearSearch();
              },
            ),
        ],
      ),
      body: Consumer<VaultProvider>(
        builder: (context, vault, _) {
          if (vault.isSearching) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_controller.text.trim().isEmpty) {
            return const Center(
              child: Text(
                'Type to search across every Vault category.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          if (vault.searchResults.isEmpty) {
            return const Center(
              child: Text(
                'No files match that search.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: vault.searchResults.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final VaultDocument doc = vault.searchResults[index];
              final category = VaultCategories.byKey(doc.categoryKey);
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  leading: Icon(category.icon, color: category.color),
                  title: Text(
                    doc.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  subtitle: Text(
                    category.label,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  onTap: () async {
                    final uri = Uri.tryParse(doc.url);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}