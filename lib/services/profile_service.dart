import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
// TESTING PHASE 1: Comment out problematic imports
// import 'package:flutter_cache_manager/flutter_cache_manager.dart';
// import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'auth_service.dart';

class ProfileService {
  final AuthService _authService = AuthService();
  
  // TESTING PHASE 1: Disable cache manager
  // static final cacheManager = DefaultCacheManager();
  
  // Cache memory untuk menyimpan gambar yang sudah diload
  static final Map<String, ImageProvider> _imageCache = {};
  
  // Maximum image size in bytes (2MB)
  static const int maxImageSize = 2 * 1024 * 1024; // 2MB
  
  // Singleton pattern
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  // TESTING PHASE 1: Remove compression method to eliminate potential conflicts

  // Get cached file path for user profile photo
  String _getCacheKey(String employeeCode) {
    return 'profile_photo_$employeeCode';
  }

  // TESTING PHASE 1: Simplified profile photo without cache manager
  Future<ImageProvider> getProfilePhoto() async {
    try {
      final userData = await _authService.getUserData();
      if (userData == null) {
        return const AssetImage('assets/images/PersonIcon.png');
      }

      // Cek semua kemungkinan field untuk employeeCode/userId
      final employeeCode = userData['userId'] ?? userData['userID'] ?? 
                         userData['UserId'] ?? userData['UserID'] ?? 
                         userData['employeeCode'] ?? userData['EmployeeCode'] ?? 
                         userData['employeeId'] ?? userData['EmployeeId'];
      
      // Debug untuk melihat semua data user
      debugPrint('User data keys: ${userData.keys.toList()}');
      debugPrint('userId: ${userData['userId']}');
      debugPrint('userID: ${userData['userID']}');
      debugPrint('UserId: ${userData['UserId']}');
      debugPrint('UserID: ${userData['UserID']}');
      
      // Check memory cache first (fastest)
      final cacheKey = _getCacheKey(employeeCode);
      if (_imageCache.containsKey(cacheKey)) {
        debugPrint('Found image in memory cache for $employeeCode');
        return _imageCache[cacheKey]!;
      }
      
      // TESTING PHASE 1: Skip disk cache, go directly to network
      if (employeeCode == null) {
        debugPrint('Error: employeeCode not found in user data');
        return const AssetImage('assets/images/PersonIcon.png');
      }

      final token = await _authService.getToken();
      if (token == null) {
        debugPrint('Error: token not found');
        return const AssetImage('assets/images/PersonIcon.png');
      }

      // Debug untuk melihat employeeCode yang digunakan
      debugPrint('Getting profile photo for employeeCode: $employeeCode');

      // URL endpoint yang benar sesuai format yang diberikan
      String baseUrl = 'http://10.10.0.223/LocalCRF/api';
      try {
        final prefs = await _authService.getUserData();
        if (prefs != null && prefs.containsKey('baseUrl')) {
          baseUrl = prefs['baseUrl'];
        }
      } catch (e) {
        debugPrint('Error getting base URL: $e');
      }

      // Gunakan employeeCode asli tanpa menambahkan prefix
      String formattedEmployeeCode = employeeCode;
      debugPrint('Using original employeeCode: $formattedEmployeeCode');

      // Coba dengan URL yang diberikan oleh user terlebih dahulu
      try {
        final directUrl = 'http://10.10.0.223/LocalCRF/api/CRF/photo/direct/$formattedEmployeeCode';
        debugPrint('Trying direct URL: $directUrl');
        
        final directResponse = await http.get(
          Uri.parse(directUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
        
        if (directResponse.statusCode == 200 && directResponse.bodyBytes.isNotEmpty) {
          debugPrint('Direct URL success: ${directResponse.bodyBytes.length} bytes');
          
          // TESTING PHASE 1: Skip compression and disk cache
          // Create memory image and cache it
          final memoryImage = MemoryImage(directResponse.bodyBytes);
          _imageCache[cacheKey] = memoryImage;
          
          return memoryImage;
        } else {
          debugPrint('Direct URL failed: ${directResponse.statusCode}');
        }
      } catch (e) {
        debugPrint('Error with direct URL: $e');
      }
      
      // Fallback ke URL dari baseUrl
      debugPrint('Trying fallback URL with baseUrl');
      final response = await http.get(
        Uri.parse('$baseUrl/CRF/photo/direct/$formattedEmployeeCode'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('Profile photo API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // Check if the response is valid image data
        if (response.bodyBytes.isNotEmpty) {
          debugPrint('Profile photo loaded successfully: ${response.bodyBytes.length} bytes');
          
          // TESTING PHASE 1: Skip compression and disk cache
          // Create memory image and cache it  
          final memoryImage = MemoryImage(response.bodyBytes);
          _imageCache[cacheKey] = memoryImage;
          
          return memoryImage;
        } else {
          debugPrint('Error: Empty response body');
          return const AssetImage('assets/images/PersonIcon.png');
        }
      } else {
        // Log error details untuk debugging
        debugPrint('Error fetching profile photo: ${response.statusCode}');
        debugPrint('Response body: ${response.body.length > 100 ? '${response.body.substring(0, 100)}...' : response.body}');
        return const AssetImage('assets/images/PersonIcon.png');
      }
    } catch (e) {
      debugPrint('Error getting profile photo: $e');
      
      // Tidak perlu mencoba dengan format employeeCode yang berbeda lagi
      // karena kita sudah menggunakan employeeCode asli
      
      return const AssetImage('assets/images/PersonIcon.png');
    }
  }
}