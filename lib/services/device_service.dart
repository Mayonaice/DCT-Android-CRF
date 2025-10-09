import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  
  // Keys for storing device ID
  static const String DEVICE_ID_KEY = 'persistent_device_id';
  static const String DEVICE_ID_CREATED_AT = 'device_id_created_at';
  static const String DEVICE_ID_HASH_KEY = 'device_id_hash'; // New key for hash-based verification
  static const String SECURE_DEVICE_ID_KEY = 'secure_device_id'; // New key for secure storage
  
  // Test device ID constant (exactly 16 characters for AndroidId format)
  static const String TEST_DEVICE_ID = '1234567890abcdef';
  
  // Cached device ID for faster access
  static String? _cachedDeviceId;
  
  // Secure storage for more permanent storage (survives app reinstalls)
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'CRF_SecurePrefs',
      preferencesKeyPrefix: 'CRF_',
    ),
    iOptions: IOSOptions(
      groupId: 'com.advantage.crf_android.secureStorage',
    ),
  );
  
  /// Validate AndroidId format (must be exactly 16 hexadecimal characters)
  static bool isValidAndroidId(String androidId) {
    if (androidId.length != 16) {
      print('❌ AndroidId validation failed: Invalid length ${androidId.length} (should be 16)');
      return false;
    }
    
    // Check if all characters are valid hexadecimal
    final hexRegex = RegExp(r'^[0-9a-fA-F]+$');
    if (!hexRegex.hasMatch(androidId)) {
      print('❌ AndroidId validation failed: Contains non-hexadecimal characters');
      return false;
    }
    
    print('✅ AndroidId validation passed: $androidId');
    return true;
  }

  /// Get Android ID - Real device AndroidID for production
  /// Returns 16-character AndroidID for registration validation
  static Future<String> getDeviceId() async {
    try {
      print('🔍 Getting device ID with persistence (SECURE STORAGE PRIORITY)');
      
      // Use cached ID if available for better performance
      if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
        print('📱 Using cached device ID: $_cachedDeviceId');
        return _cachedDeviceId!;
      }
      
      // First check secure storage (most reliable across reinstalls)
      final String? secureId = await _getSecureDeviceId();
      if (secureId != null && secureId.isNotEmpty) {
        print('✅ Using secure stored device ID: $secureId');
        _cachedDeviceId = secureId; // Cache for future use
        return secureId;
      }
      
      try {
        // Then check shared preferences as fallback
        final String? storedId = await _getStoredDeviceId();
        if (storedId != null && storedId.isNotEmpty) {
          // Verify the stored ID with hash if available
          final bool isValid = await _verifyDeviceIdHash(storedId);
          if (isValid) {
            print('✅ Using verified stored device ID: $storedId');
            // Also save to secure storage for future use
            await _storeSecureDeviceId(storedId);
            _cachedDeviceId = storedId; // Cache for future use
            return storedId;
          } else {
            print('⚠️ Stored device ID failed verification');
          }
        }
      } catch (e) {
        print('⚠️ Error accessing shared preferences: $e');
      }
      
      // If no valid stored ID, generate a new one
      print('⚠️ No valid stored device ID found, generating new one');
      String newId;
      
      try {
        // Generate device ID using device info only
        newId = await _generateDeviceId();
        print('✅ Using generated device ID: $newId');
      } catch (e) {
        print('⚠️ Error generating device ID: $e');
        newId = TEST_DEVICE_ID;
        print('✅ Using test device ID after error: $newId');
      }
      
      // Store the new ID in both SharedPreferences and Secure Storage
      try {
        // Store in background for better performance
        await _storeDeviceId(newId);
        await _storeDeviceIdHash(newId);
        await _storeSecureDeviceId(newId); // Also store in secure storage
        print('✅ New device ID stored in both SharedPreferences and Secure Storage: $newId');
      } catch (e) {
        print('⚠️ Could not store device ID: $e');
      }
      
      // Cache the ID for future use
      _cachedDeviceId = newId;
      return newId;
    } catch (e) {
      print('❌ Error in getDeviceId: $e');
      // Last resort fallback - generate a new ID
      return await _generateDeviceId();
    }
  }
  
  /// Get stored device ID from SharedPreferences
  static Future<String?> _getStoredDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(DEVICE_ID_KEY);
    } catch (e) {
      print('❌ Error getting stored device ID: $e');
      return null;
    }
  }
  
  /// Store device ID in SharedPreferences
  static Future<bool> _storeDeviceId(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(DEVICE_ID_KEY, deviceId);
      await prefs.setString(DEVICE_ID_CREATED_AT, DateTime.now().toIso8601String());
      print('✅ Device ID stored successfully: $deviceId');
      return true;
    } catch (e) {
      print('❌ Error storing device ID: $e');
      return false;
    }
  }
  
  /// Get device ID from secure storage (survives app reinstalls)
  static Future<String?> _getSecureDeviceId() async {
    try {
      print('🔍 Attempting to read from secure storage with key: $SECURE_DEVICE_ID_KEY');
      final result = await _secureStorage.read(key: SECURE_DEVICE_ID_KEY);
      if (result != null) {
        print('✅ Successfully read from secure storage: $result');
      } else {
        print('ℹ️ No data found in secure storage for key: $SECURE_DEVICE_ID_KEY');
      }
      return result;
    } catch (e) {
      print('❌ Error getting secure device ID: $e');
      print('❌ Error type: ${e.runtimeType}');
      return null;
    }
  }
  
  /// Store device ID in secure storage
  static Future<void> _storeSecureDeviceId(String deviceId) async {
    try {
      print('🔍 Attempting to write to secure storage with key: $SECURE_DEVICE_ID_KEY, value: $deviceId');
      await _secureStorage.write(key: SECURE_DEVICE_ID_KEY, value: deviceId);
      print('✅ Device ID stored securely: $deviceId');
      
      // Verify the write operation
      final verifyRead = await _secureStorage.read(key: SECURE_DEVICE_ID_KEY);
      if (verifyRead == deviceId) {
        print('✅ Secure storage write verification successful');
      } else {
        print('❌ Secure storage write verification failed. Expected: $deviceId, Got: $verifyRead');
      }
    } catch (e) {
      print('❌ Error storing secure device ID: $e');
      print('❌ Error type: ${e.runtimeType}');
    }
  }
  
  /// Create a hash of the device ID for verification
  static String _createDeviceIdHash(String deviceId) {
    final bytes = utf8.encode(deviceId + 'CRF_SALT_2023');
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
  
  /// Store a hash of the device ID for verification
  static Future<bool> _storeDeviceIdHash(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hash = _createDeviceIdHash(deviceId);
      await prefs.setString(DEVICE_ID_HASH_KEY, hash);
      print('✅ Device ID hash stored: $hash');
      return true;
    } catch (e) {
      print('❌ Error storing device ID hash: $e');
      return false;
    }
  }
  
  /// Verify a device ID against its stored hash
  static Future<bool> _verifyDeviceIdHash(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedHash = prefs.getString(DEVICE_ID_HASH_KEY);
      
      // If no hash is stored, assume it's valid (first run)
      if (storedHash == null) {
        print('ℹ️ No device ID hash found, storing new hash');
        await _storeDeviceIdHash(deviceId);
        return true;
      }
      
      // Compare the calculated hash with the stored hash
      final calculatedHash = _createDeviceIdHash(deviceId);
      final isValid = calculatedHash == storedHash;
      
      print(isValid ? '✅ Device ID hash verified' : '⚠️ Device ID hash verification failed');
      return isValid;
    } catch (e) {
      print('❌ Error verifying device ID hash: $e');
      return true; // Default to true on error to avoid blocking the app
    }
  }
  
  /// Generate a device ID based on hardware information
  static Future<String> _generateDeviceId() async {
    try {
      print('🔍 Generating device ID from hardware info');
      
      // Web platform detection
      if (kIsWeb) {
        print('🔍 Web platform detected - using browser-based ID');
        // For web, generate a proper 16-character hex ID like Android
        try {
          // Use browser-specific information for uniqueness (stable, no timestamp)
          final String userAgent = 'web_browser';
          final String language = 'en_US'; // Default language for web
          final String platformVersion = Platform.operatingSystemVersion;
          
          // Create web-specific identifiers (stable, no timestamp)
          final List<String> webIdentifiers = [
            'web',
            userAgent,
            language,
            platformVersion,
            'CRF_WEB_STABLE_SALT_2024', // Static salt for consistency
          ];
          
          // Create a stable identifier by hashing web properties
          final String webData = webIdentifiers.join('|');
          final String fullHash = sha256.convert(utf8.encode(webData)).toString();
          
          // Extract exactly 16 characters for AndroidId format (standard hex format)
          final String webHash = fullHash.substring(0, 16);
          
          print('✅ Generated stable web hash (16 chars): $webHash (from browser info)');
          print('📏 AndroidId length validation: ${webHash.length} characters (should be 16)');
          print('🔧 Web identifiers used: ${webIdentifiers.join(", ")}');
          
          // Validate the generated AndroidId
          if (isValidAndroidId(webHash)) {
            return webHash;
          } else {
            print('❌ Generated web AndroidId validation failed, using TEST_DEVICE_ID');
            return TEST_DEVICE_ID;
          }
        } catch (e) {
          print('⚠️ Error generating web device ID: $e');
          return TEST_DEVICE_ID;
        }
      }
      
      if (Platform.isAndroid) {
        print('🔍 Android platform detected');
        
        // Use device info only (android_id plugin removed for compatibility)
        print('🔍 Using device info for ID generation');
        try {
          AndroidDeviceInfo androidInfo = await _deviceInfoPlugin.androidInfo;
          
          // Create a stable identifier from device hardware info (no timestamp!)
          final List<String> deviceIdentifiers = [
            'android',
            androidInfo.brand ?? 'unknown',
            androidInfo.model ?? 'unknown', 
            androidInfo.manufacturer ?? 'unknown',
            androidInfo.device ?? 'unknown',
            androidInfo.board ?? 'unknown',
            androidInfo.hardware ?? 'unknown',
            'CRF_STABLE_SALT_2024', // Static salt for consistency
          ];
          
          // Create a stable identifier by hashing device properties
          final String deviceData = deviceIdentifiers.join('|');
          final String fullHash = sha256.convert(utf8.encode(deviceData)).toString();
          
          // Extract exactly 16 characters for AndroidId format (standard hex format)
          final String deviceHash = fullHash.substring(0, 16);
          
          print('✅ Generated stable device hash (16 chars): $deviceHash (from hardware info)');
          print('📏 AndroidId length validation: ${deviceHash.length} characters (should be 16)');
          print('🔧 Device identifiers used: ${deviceIdentifiers.join(", ")}');
          
          // Validate the generated AndroidId
          if (isValidAndroidId(deviceHash)) {
            return deviceHash;
          } else {
            print('❌ Generated AndroidId validation failed, using TEST_DEVICE_ID');
            return TEST_DEVICE_ID;
          }
        } catch (e) {
          print('⚠️ Error generating device ID: $e');
          // Return test device ID if all methods fail
          return TEST_DEVICE_ID;
        }
      } else if (Platform.isIOS) {
        print('🔍 iOS platform detected');
        try {
          IosDeviceInfo iosInfo = await _deviceInfoPlugin.iosInfo;
          
          // Create a stable identifier from iOS device info (no timestamp!)
          final List<String> iosIdentifiers = [
            'ios',
            iosInfo.name ?? 'unknown',
            iosInfo.model ?? 'unknown',
            iosInfo.systemName ?? 'unknown',
            iosInfo.systemVersion ?? 'unknown',
            iosInfo.localizedModel ?? 'unknown',
            'CRF_IOS_STABLE_SALT_2024', // Static salt for consistency
          ];
          
          final String iosData = iosIdentifiers.join('|');
          final String iosHash = sha256.convert(utf8.encode(iosData)).toString().substring(0, 16);
          
          print('✅ Generated stable iOS ID: $iosHash');
          print('🔧 iOS identifiers used: ${iosIdentifiers.join(", ")}');
          return iosHash;
        } catch (e) {
          print('⚠️ Error generating iOS device ID: $e');
          return TEST_DEVICE_ID;
        }
      } else {
        print('🔍 Desktop platform detected');
        return TEST_DEVICE_ID;
      }
    } catch (e) {
      print('❌ Error generating device ID: $e');
      return TEST_DEVICE_ID;
    }
  }
  
  /// Get detailed device information
  static Future<Map<String, String>> getDeviceInfo() async {
    try {
      String persistentDeviceId = await getDeviceId();
      
      // Web platform
      if (kIsWeb) {
        return {
          'deviceId': persistentDeviceId,
          'nativeAndroidId': 'web_browser_id',
          'originalId': 'web_session',
          'brand': 'Browser',
          'model': 'Web Browser',
          'manufacturer': 'Web',
          'androidVersion': 'N/A',
          'platform': 'Web',
          'isPersistent': 'session_based',
        };
      }
      
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfoPlugin.androidInfo;
        
        return {
          'deviceId': persistentDeviceId,
          'nativeAndroidId': androidInfo.id ?? 'unknown',
          'originalId': androidInfo.id ?? 'unknown',
          'brand': androidInfo.brand ?? 'Unknown',
          'model': androidInfo.model ?? 'Unknown',
          'manufacturer': androidInfo.manufacturer ?? 'Unknown',
          'androidVersion': androidInfo.version.release ?? 'Unknown',
          'buildNumber': androidInfo.version.incremental ?? 'Unknown',
          'buildId': androidInfo.display ?? 'Unknown',
          'osVersion': androidInfo.version.codename ?? androidInfo.version.release ?? 'Unknown',
          'platform': 'Android',
          'isPersistent': 'true',
        };
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfoPlugin.iosInfo;
        return {
          'deviceId': persistentDeviceId,
          'originalId': iosInfo.identifierForVendor ?? 'unknown',
          'name': iosInfo.name ?? 'Unknown',
          'model': iosInfo.model ?? 'Unknown',
          'systemName': iosInfo.systemName ?? 'Unknown',
          'systemVersion': iosInfo.systemVersion ?? 'Unknown',
          'platform': 'iOS',
          'isPersistent': 'true',
        };
      } else {
        return {
          'deviceId': persistentDeviceId,
          'platform': Platform.operatingSystem,
          'isPersistent': 'true',
        };
      }
    } catch (e) {
      print('❌ Error getting device info: $e');
      return {
        'deviceId': 'error_fallback_id',
        'error': e.toString(),
        'platform': kIsWeb ? 'Web' : 'Unknown',
        'isPersistent': 'false',
      };
    }
  }
  
  /// Check if device has a stored ID
  static Future<bool> hasStoredDeviceId() async {
    try {
      final storedId = await _getStoredDeviceId();
      return storedId != null && storedId.isNotEmpty;
    } catch (e) {
      print('❌ Error checking stored device ID: $e');
      return false;
    }
  }
  
  /// Reset stored device ID (for testing only)
  static Future<bool> resetDeviceId() async {
    try {
      print('🔄 Starting device ID reset...');
      
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(DEVICE_ID_KEY);
      await prefs.remove(DEVICE_ID_CREATED_AT);
      await prefs.remove(DEVICE_ID_HASH_KEY);
      print('✅ SharedPreferences cleared');
      
      // Clear secure storage
      await _secureStorage.delete(key: SECURE_DEVICE_ID_KEY);
      print('✅ Secure storage cleared');
      
      // Clear cache
      _cachedDeviceId = null;
      print('✅ Cache cleared');
      
      print('✅ Device ID reset successfully from all storage locations');
      return true;
    } catch (e) {
      print('❌ Error resetting device ID: $e');
      print('❌ Error type: ${e.runtimeType}');
      return false;
    }
  }
  
  /// Debug function to check all stored keys
  static Future<void> debugStorageStatus() async {
    try {
      print('🔍 === STORAGE DEBUG STATUS ===');
      
      // Check SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString(DEVICE_ID_KEY);
      final createdAt = prefs.getString(DEVICE_ID_CREATED_AT);
      final hash = prefs.getString(DEVICE_ID_HASH_KEY);
      
      print('📱 SharedPreferences:');
      print('  - Device ID: $deviceId');
      print('  - Created At: $createdAt');
      print('  - Hash: $hash');
      
      // Check Secure Storage
      final secureId = await _secureStorage.read(key: SECURE_DEVICE_ID_KEY);
      print('🔒 Secure Storage:');
      print('  - Device ID: $secureId');
      
      // Check Cache
      print('💾 Cache:');
      print('  - Cached ID: $_cachedDeviceId');
      
      print('🔍 === END DEBUG STATUS ===');
    } catch (e) {
      print('❌ Error in debug storage status: $e');
    }
  }
}