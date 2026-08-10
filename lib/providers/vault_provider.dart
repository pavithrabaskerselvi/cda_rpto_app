import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/vault_categories.dart';
import '../models/vault_document_model.dart';
import '../models/vault_folder_model.dart';
import '../models/vault_subfolder_model.dart';

/// Firestore collection holding every RPTO Vault file, flat, filtered by
/// [VaultDocument.categoryKey]. Kept flat (rather than one subcollection
/// per category) so the search screen can query across every category
/// in a single call.
const String kVaultCollection = 'vault_documents';

/// Firestore collection holding user-created subfolders for categories
/// with VaultCategory.supportsSubfolders (currently only 'audit_files').
const String kVaultSubfoldersCollection = 'vault_subfolders';

/// Loads category tile counts for the Vault home screen, fetches the
/// file list for a single category, and runs the cross-category search.
class VaultProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;

  VaultProvider({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  List<VaultFolder> _folders = [];
  bool _isLoadingFolders = false;
  String? _foldersError;

  List<VaultFolder> get folders => _folders;
  bool get isLoadingFolders => _isLoadingFolders;
  String? get foldersError => _foldersError;

  List<VaultDocument> _searchResults = [];
  bool _isSearching = false;

  List<VaultDocument> get searchResults => _searchResults;
  bool get isSearching => _isSearching;

  /// Loads every category tile with its live doc count from Firestore.
  /// Call once when VaultHomeScreen opens (and on pull-to-refresh).
  Future<void> loadFolders() async {
    _isLoadingFolders = true;
    _foldersError = null;
    notifyListeners();

    try {
      final snapshot = await _firestore.collection(kVaultCollection).get();
      final docs = snapshot.docs
          .map((d) => VaultDocument.fromDocument(d))
          .toList();

      _folders = VaultCategories.all.map((category) {
        final inCategory =
        docs.where((d) => d.categoryKey == category.key).toList();
        DateTime? lastUpdated;
        for (final d in inCategory) {
          if (lastUpdated == null || d.uploadedAt.isAfter(lastUpdated)) {
            lastUpdated = d.uploadedAt;
          }
        }
        return VaultFolder(
          category: category,
          docCount: inCategory.length,
          lastUpdated: lastUpdated,
        );
      }).toList();
    } catch (e) {
      _foldersError = 'Could not load RPTO Vault: $e';
    }

    _isLoadingFolders = false;
    notifyListeners();
  }

  /// Files for one category, newest first. Used by VaultCategoryScreen.
  Stream<List<VaultDocument>> watchCategory(String categoryKey) {
    return _firestore
        .collection(kVaultCollection)
        .where('categoryKey', isEqualTo: categoryKey)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => VaultDocument.fromDocument(d)).toList());
  }

  /// Saves a Firestore record for a file already uploaded to Cloudinary
  /// (upload it first with your existing CloudinaryUploadService, same
  /// one DroneBulkImportController uses, then call this with the
  /// returned secure URL).
  Future<void> addDocument({
    required String categoryKey,
    required String fileName,
    required String url,
    required String extension,
    required int size,
    required String uploadedBy,
    String folderPath = '',
  }) async {
    await _firestore.collection(kVaultCollection).add(
      VaultDocument(
        id: '',
        categoryKey: categoryKey,
        fileName: fileName,
        url: url,
        extension: extension,
        size: size,
        uploadedBy: uploadedBy,
        uploadedAt: DateTime.now(),
        folderPath: folderPath,
      ).toMap(),
    );

    // Keep the home-screen tile counts in sync without forcing the user
    // to pull-to-refresh.
    final idx = _folders.indexWhere((f) => f.key == categoryKey);
    if (idx != -1) {
      final old = _folders[idx];
      _folders[idx] = VaultFolder(
        category: old.category,
        docCount: old.docCount + 1,
        lastUpdated: DateTime.now(),
      );
      notifyListeners();
    }
  }

  Future<void> deleteDocument(String documentId, String categoryKey) async {
    await _firestore.collection(kVaultCollection).doc(documentId).delete();

    final idx = _folders.indexWhere((f) => f.key == categoryKey);
    if (idx != -1 && _folders[idx].docCount > 0) {
      final old = _folders[idx];
      _folders[idx] = VaultFolder(
        category: old.category,
        docCount: old.docCount - 1,
        lastUpdated: old.lastUpdated,
      );
      notifyListeners();
    }
  }

  /// Client-side filename search across every category. Firestore has no
  /// native "contains" query, so this pulls the (typically small)
  /// collection and filters in memory — fine for a few hundred docs; if
  /// the Vault grows into the thousands, swap this for Algolia/Typesense.
  Future<void> search(String query) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final snapshot = await _firestore.collection(kVaultCollection).get();
      _searchResults = snapshot.docs
          .map((d) => VaultDocument.fromDocument(d))
          .where((d) => d.fileName.toLowerCase().contains(trimmed))
          .toList();
    } catch (_) {
      _searchResults = [];
    }

    _isSearching = false;
    notifyListeners();
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  // ── Nested folders (categories with supportsSubfolders: true) ─────────

  /// Files at one exact folder level within a category — e.g. category
  /// 'audit_files', folderPath '03-02-2026/CHECKLIST' returns only the
  /// files uploaded directly into that folder, not files in sibling or
  /// child folders.
  Stream<List<VaultDocument>> watchCategoryPath(String categoryKey, String folderPath) {
    return _firestore
        .collection(kVaultCollection)
        .where('categoryKey', isEqualTo: categoryKey)
        .where('folderPath', isEqualTo: folderPath)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => VaultDocument.fromDocument(d)).toList());
  }

  /// Subfolders sitting directly under [parentPath] within [categoryKey].
  /// Pass '' for parentPath to get the top-level folders shown right
  /// under the category (e.g. the date folders under Audit Files).
  Stream<List<VaultSubfolder>> watchSubfolders(String categoryKey, String parentPath) {
    return _firestore
        .collection(kVaultSubfoldersCollection)
        .where('categoryKey', isEqualTo: categoryKey)
        .where('parentPath', isEqualTo: parentPath)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) => VaultSubfolder.fromDocument(d)).toList());
  }

  /// Creates a new subfolder. Returns false (without writing) if a
  /// sibling folder with the same name already exists at this level.
  Future<bool> createSubfolder({
    required String categoryKey,
    required String parentPath,
    required String name,
    required String createdBy,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    final existing = await _firestore
        .collection(kVaultSubfoldersCollection)
        .where('categoryKey', isEqualTo: categoryKey)
        .where('parentPath', isEqualTo: parentPath)
        .where('name', isEqualTo: trimmed)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return false;

    await _firestore.collection(kVaultSubfoldersCollection).add(
      VaultSubfolder(
        id: '',
        categoryKey: categoryKey,
        name: trimmed,
        parentPath: parentPath,
        createdAt: DateTime.now(),
        createdBy: createdBy,
      ).toMap(),
    );
    return true;
  }

  /// Deletes a subfolder record. Does NOT recursively delete files or
  /// child folders inside it — by design, so an accidental tap can't
  /// silently wipe out nested content. The UI should only offer this
  /// once the folder (and its subtree) is confirmed empty.
  Future<void> deleteSubfolder(String subfolderId) async {
    await _firestore.collection(kVaultSubfoldersCollection).doc(subfolderId).delete();
  }
}
