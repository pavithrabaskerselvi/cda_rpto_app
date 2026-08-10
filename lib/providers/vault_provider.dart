import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/vault_categories.dart';
import '../models/vault_document_model.dart';
import '../models/vault_folder_model.dart';

/// Firestore collection holding every RPTO Vault file, flat, filtered by
/// [VaultDocument.categoryKey]. Kept flat (rather than one subcollection
/// per category) so the search screen can query across every category
/// in a single call.
const String kVaultCollection = 'vault_documents';

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

  /// Renames a document's display name in place — the Cloudinary URL and
  /// underlying file are untouched, only the Firestore `fileName` field
  /// updates. watchCategory's stream picks up the change automatically.
  Future<void> renameDocument(String documentId, String newFileName) async {
    final trimmed = newFileName.trim();
    if (trimmed.isEmpty) return;
    await _firestore
        .collection(kVaultCollection)
        .doc(documentId)
        .update({'fileName': trimmed});
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
}