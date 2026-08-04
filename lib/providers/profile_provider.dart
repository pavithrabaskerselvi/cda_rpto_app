import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class ProfileProvider extends ChangeNotifier {
  static const String _cloudName = 'vmi67fhz'; // reuse RPTO cloud, or your own
  static const String _uploadPreset = 'rpto_unsigned'; // change if separate preset

  String? name;
  String? email;
  String? phone;
  String? photoUrl;
  bool isLoading = false;

  Future<void> loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    isLoading = true;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        name = data['name'] as String?;
        email = data['email'] as String? ?? FirebaseAuth.instance.currentUser?.email;
        phone = data['phone'] as String?;
        photoUrl = data['photoUrl'] as String?;
      }
    } catch (e) {
      debugPrint('ProfileProvider.loadProfile error: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  /// Updates the editable personal-info fields (name, phone) in Firestore.
  /// Email is intentionally not editable here since it's tied to the
  /// Firebase Auth account. Returns true on success.
  Future<bool> updatePersonalInfo({required String name, required String phone}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': name,
        'phone': phone,
      });
      this.name = name;
      this.phone = phone;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('ProfileProvider.updatePersonalInfo error: $e');
      return false;
    }
  }

  /// Takes an [XFile] (from image_picker) instead of dart:io File —
  /// dart:io.File.path is a blob: URL on Flutter Web and can't be read,
  /// so we read raw bytes from the XFile instead. This works identically
  /// on web, Android, and iOS.
  Future<bool> uploadProfilePhoto(XFile imageFile) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      final bytes = await imageFile.readAsBytes();
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = 'profile_photos'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: imageFile.name,
        ));

      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(resBody);
        final uploadedUrl = data['secure_url'] as String;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'photoUrl': uploadedUrl});

        photoUrl = uploadedUrl;
        notifyListeners();
        return true;
      } else {
        debugPrint('Cloudinary upload failed (${response.statusCode}): $resBody');
        return false;
      }
    } catch (e) {
      debugPrint('ProfileProvider.uploadProfilePhoto error: $e');
      return false;
    }
  }
}