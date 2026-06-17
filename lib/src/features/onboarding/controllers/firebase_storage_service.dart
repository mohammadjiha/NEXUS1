import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Fetch image URL from Firebase Storage to keep app size small
  /// Usage: Image.network(await getImageUrl('assets/gym_logo.png'))
  Future<String?> getImageUrl(String path) async {
    try {
      final ref = _storage.ref().child(path);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error fetching image URL from storage: $e');
      return null;
    }
  }

  /// Upload user files securely (e.g., Profile Picture)
  /// Regulated by Firebase Security Rules to max 5MB and image types.
  Future<String?> uploadProfileImage(String userId, Uint8List fileBytes, String fileName) async {
    try {
      final ref = _storage.ref().child('users/$userId/profile_images/$fileName');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      
      final uploadTask = await ref.putData(fileBytes, metadata);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image to storage: $e');
      return null;
    }
  }
}
