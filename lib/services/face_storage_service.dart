import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class FaceStorageService {
  static const String _referencePhotoIdKey = 'mlkit_reference_photo_id';
  static const String _userNameKey = 'mlkit_user_name';
  static const String _photoStoredDateKey = 'mlkit_photo_stored_date';

  /// Save reference photo ID for the current user
  Future<bool> saveReferencePhotoId(String photoId, String userName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(_referencePhotoIdKey, photoId);
      await prefs.setString(_userNameKey, userName);
      await prefs.setString(_photoStoredDateKey, DateTime.now().toIso8601String());
      
      debugPrint('✅ FaceStorage: Reference photo ID saved: $photoId for user: $userName');
      return success;
    } catch (e) {
      debugPrint('❌ FaceStorage: Error saving reference photo ID: $e');
      return false;
    }
  }

  /// Get stored reference photo ID
  Future<String?> getReferencePhotoId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final photoId = prefs.getString(_referencePhotoIdKey);
      
      if (photoId != null) {
        debugPrint('✅ FaceStorage: Retrieved reference photo ID: $photoId');
      } else {
        debugPrint('ℹ️ FaceStorage: No reference photo ID found');
      }
      
      return photoId;
    } catch (e) {
      debugPrint('❌ FaceStorage: Error getting reference photo ID: $e');
      return null;
    }
  }

  /// Get stored user name associated with reference photo
  Future<String?> getStoredUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userNameKey);
    } catch (e) {
      debugPrint('❌ FaceStorage: Error getting stored user name: $e');
      return null;
    }
  }

  /// Get the date when reference photo was stored
  Future<DateTime?> getPhotoStoredDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateString = prefs.getString(_photoStoredDateKey);
      
      if (dateString != null) {
        return DateTime.tryParse(dateString);
      }
      return null;
    } catch (e) {
      debugPrint('❌ FaceStorage: Error getting photo stored date: $e');
      return null;
    }
  }

  /// Check if user has a stored reference photo
  Future<bool> hasReferencePhoto() async {
    final photoId = await getReferencePhotoId();
    return photoId != null && photoId.isNotEmpty;
  }

  /// Clear stored reference photo data
  Future<bool> clearReferencePhoto() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_referencePhotoIdKey);
      await prefs.remove(_userNameKey);
      await prefs.remove(_photoStoredDateKey);
      
      debugPrint('✅ FaceStorage: Reference photo data cleared');
      return true;
    } catch (e) {
      debugPrint('❌ FaceStorage: Error clearing reference photo data: $e');
      return false;
    }
  }

  /// Get reference photo info summary
  Future<ReferencePhotoInfo?> getReferencePhotoInfo() async {
    try {
      final photoId = await getReferencePhotoId();
      if (photoId == null) return null;

      final userName = await getStoredUserName();
      final storedDate = await getPhotoStoredDate();

      return ReferencePhotoInfo(
        photoId: photoId,
        userName: userName ?? 'Unknown',
        storedDate: storedDate ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ FaceStorage: Error getting reference photo info: $e');
      return null;
    }
  }
}

/// Reference photo information
class ReferencePhotoInfo {
  final String photoId;
  final String userName;
  final DateTime storedDate;

  ReferencePhotoInfo({
    required this.photoId,
    required this.userName,
    required this.storedDate,
  });

  /// Check if the reference photo is older than specified days
  bool isOlderThan(int days) {
    final now = DateTime.now();
    final difference = now.difference(storedDate);
    return difference.inDays > days;
  }

  @override
  String toString() {
    return 'ReferencePhotoInfo(photoId: $photoId, userName: $userName, storedDate: $storedDate)';
  }
}