
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileProvider extends ChangeNotifier {
  static const String _cloudName = 'vmi67fhz'; // reuse RPTO cloud, or your own
  static const String _uploadPreset = 'rpto_unsigned'; // change if separate preset

  String? name;
  String? email;
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
        photoUrl = data['photoUrl'] as String?;
      }
    } catch (e) {
      debugPrint('ProfileProvider.loadProfile error: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> uploadProfilePhoto(File imageFile) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = 'profile_photos'
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

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
        debugPrint('Cloudinary upload failed: $resBody');
        return false;
      }
    } catch (e) {
      debugPrint('ProfileProvider.uploadProfilePhoto error: $e');
      return false;
    }
  }
}
