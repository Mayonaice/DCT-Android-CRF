import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'device_service.dart';
import 'package:crypto/crypto.dart'; // Tambahkan import untuk enkripsi
// Removed flutter_secure_storage import to avoid crashes

class AuthService {
  // Make base URL more flexible - allow for fallback
  static const String _primaryBaseUrl = 'http://10.10.0.223/LocalCRF/api';
  static const String _fallbackBaseUrl = 'http://10.10.0.223:8080/LocalCRF/api'; // Fallback URL if primary fails
  static const String tokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String baseUrlKey = 'base_url';
  static const String tlspvCredentialsKey = 'tlspv_credentials'; // Key untuk menyimpan kredensial TLSPV
  static const String encryptionKey = 'CRF_SECURE_KEY_2025'; // Key untuk enkripsi data
  
  // Cache untuk data user
  String? _cachedUserData;
  
  // API timeout duration
  static const Duration _timeout = Duration(seconds: 15);

  // Track which base URL is working
  String _currentBaseUrl = _primaryBaseUrl;

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    // Initialize by loading saved base URL or using primary
    _loadBaseUrl();
  }

  // Platform detection helper
  String _getClientType() {
    // Always return 'Android' for Flutter app, regardless of platform
    // This ensures we always use CRFAndroid_SP_Login with full validation
    return 'Android';
  }

  // Load saved base URL if available
  Future<void> _loadBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentBaseUrl = prefs.getString(baseUrlKey) ?? _primaryBaseUrl;
    } catch (e) {
      debugPrint('Failed to load base URL: $e');
      _currentBaseUrl = _primaryBaseUrl;
    }
  }

  // Save working base URL
  Future<void> _saveBaseUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(baseUrlKey, url);
      _currentBaseUrl = url;
    } catch (e) {
      debugPrint('Failed to save base URL: $e');
    }
  }

  // Try request with fallback if primary fails - optimized version
  Future<http.Response> _tryRequestWithFallback({
    required Future<http.Response> Function(String baseUrl) requestFn,
  }) async {
    try {
      // Use full timeout for login - don't rush it
      debugPrint('🔄 Attempting login with URL: $_currentBaseUrl');
      final response = await requestFn(_currentBaseUrl).timeout(_timeout);
      debugPrint('✅ Login request successful with $_currentBaseUrl');
      return response;
    } catch (e) {
      debugPrint('❌ Login request failed with $_currentBaseUrl: $e');
      
      // For login, don't try fallback - just fail fast
      // Fallback URLs might not be configured for login
      rethrow;
    }
  }

  // Get available branches for user (Step 1 of 2-step login)
  // No AndroidID validation here - only basic credential check
  Future<Map<String, dynamic>> getUserBranches(String username, String password, String noMeja, {String? androidId}) async {
    try {
      // Get client type but don't send AndroidID for branches check
      final clientType = _getClientType();
      
      final response = await _tryRequestWithFallback(
        requestFn: (baseUrl) => http.post(
          Uri.parse('$baseUrl/CRF/get-user-branches'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'Username': username,
            'Password': password,
            'NoMeja': noMeja,
            'ClientType': clientType,
            // No AndroidId parameter - skip AndroidID validation for branches
          }),
        ),
      );

      Map<String, dynamic> responseData;
      try {
        responseData = json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Error parsing JSON: $e');
        return {
          'success': false,
          'message': 'Server returned invalid data: ${response.body.substring(0, min(100, response.body.length))}',
        };
      }
      
      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Branches retrieved successfully',
          'data': responseData['data']
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to get branches (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('Get branches error: $e');
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  // Enhanced login method with role-based authentication
  Future<Map<String, dynamic>> login(String username, String password, String noMeja, {String? selectedBranch, String? androidId}) async {
    try {
      // Get device ID for validation (use custom androidId if provided)
      final deviceId = androidId ?? await DeviceService.getDeviceId();
      
      // Get client type
      final clientType = _getClientType();
      
      debugPrint('Login attempt for user: $username, deviceId: $deviceId, selectedBranch: $selectedBranch');
      debugPrint('🔍 DETAILED REQUEST ANALYSIS:');
      debugPrint('  - Username: $username');
      debugPrint('  - NoMeja: $noMeja');
      debugPrint('  - AndroidId: $deviceId (Length: ${deviceId.length})');
      debugPrint('  - ClientType: $clientType');
      debugPrint('  - SelectedBranch: $selectedBranch');
      
      final requestBody = {
        'username': username,
        'password': password,
        'noMeja': noMeja,
        'AndroidId': deviceId,
        'clientType': clientType,
        'selectedBranch': selectedBranch
      };
      
      debugPrint('🔍 FULL REQUEST BODY (JSON):');
      debugPrint(json.encode(requestBody));
      
      debugPrint('🔍 REQUEST BODY FIELDS CHECK:');
      requestBody.forEach((key, value) {
        debugPrint('  - Field "$key": ${value.runtimeType} = "${key == 'password' ? '***HIDDEN***' : value}"');
      });
      
      debugPrint('🔍 POWERSHELL COMPARISON:');
      debugPrint('PowerShell worked with: {"username":"w-888","password":"Kepo@123","noMeja":"010101","AndroidId":"c74499a2bd1dec10","clientType":"Android","selectedBranch":"Cideng"}');
      debugPrint('Flutter sending: ${json.encode(requestBody)}');
      debugPrint('Are they identical? ${json.encode(requestBody) == '{"username":"w-888","password":"Kepo@123","noMeja":"010101","AndroidId":"c74499a2bd1dec10","clientType":"Android","selectedBranch":"Cideng"}'}');
      
      final response = await _tryRequestWithFallback(
        requestFn: (baseUrl) {
          final url = '$baseUrl/CRF/login';
          debugPrint('🔍 MAKING REQUEST TO: $url');
          debugPrint('🔍 REQUEST HEADERS: Content-Type: application/json');
          
          return http.post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json'
            },
            body: json.encode(requestBody),
          );
        },
      );
      
      debugPrint('🔍 HTTP RESPONSE STATUS: ${response.statusCode}');
      debugPrint('🔍 HTTP RESPONSE HEADERS: ${response.headers}');
      debugPrint('🔍 HTTP RESPONSE BODY (Raw): ${response.body}');
      
      // Parse JSON response first to get API error message
      late Map<String, dynamic> responseData;
      try {
        responseData = json.decode(response.body);
      } catch (e) {
        debugPrint('❌ JSON PARSE ERROR: $e');
        debugPrint('Raw response: ${response.body}');
        return {
          'success': false,
          'message': 'Invalid server response format',
          'errorType': 'JSON_PARSE_ERROR'
        };
      }
      debugPrint('🔍 PARSED RESPONSE DATA: ${json.encode(responseData)}');
      
      // Check HTTP status code and handle API error messages properly
      if (response.statusCode != 200) {
        debugPrint('❌ HTTP ERROR: Status ${response.statusCode}');
        
        // Try to get error message from API response first
        final apiErrorMessage = responseData['message'];
        final errorType = responseData['errorType'];
        
        if (apiErrorMessage != null && apiErrorMessage.toString().isNotEmpty) {
          // Use API error message
          debugPrint('🔍 Using API error message: $apiErrorMessage');
          return {
            'success': false,
            'message': apiErrorMessage,
            'errorType': errorType ?? (apiErrorMessage.toString().toLowerCase().contains('androidid') ? 'ANDROID_ID_ERROR' : 'HTTP_ERROR')
          };
        } else {
          // Fallback to generic HTTP error
          return {
            'success': false,
            'message': 'HTTP Error ${response.statusCode}: ${response.reasonPhrase}',
            'errorType': 'HTTP_ERROR'
          };
        }
      }
      
      // Check for API error - Handle both boolean and string success values
      final successValue = responseData['success'];
      final isSuccess = successValue == true || successValue == 'true' || successValue == 1 || successValue == '1';
      
      debugPrint('🔍 SUCCESS VALUE ANALYSIS:');
      debugPrint('  - Raw success value: $successValue (${successValue.runtimeType})');
      debugPrint('  - Parsed as success: $isSuccess');
      
      if (!isSuccess) {
        debugPrint('❌ LOGIN FAILED - DETAILED ANALYSIS:');
        debugPrint('  - Success: ${responseData['success']}');
        debugPrint('  - Message: ${responseData['message']}');
        debugPrint('  - Full Response: ${json.encode(responseData)}');
        
        final errorMessage = responseData['message'] ?? 'Unknown error';
        final isAndroidIdError = errorMessage.toString().toLowerCase().contains('androidid');
        
        debugPrint('  - Error Type: ${isAndroidIdError ? 'ANDROID_ID_ERROR' : 'LOGIN_ERROR'}');
        
        return {
          'success': false,
          'message': errorMessage,
          'errorType': isAndroidIdError ? 'ANDROID_ID_ERROR' : 'LOGIN_ERROR'
        };
      }
      
      // Store token - Check if token exists in response
      if (responseData['data'] == null || responseData['data']['token'] == null) {
        debugPrint('ERROR: Login response missing token data!');
        debugPrint('Response data: ${json.encode(responseData)}');
        return {
          'success': false,
          'message': 'Server error: Login response missing token',
          'errorType': 'TOKEN_MISSING'
        };
      }
      
      final token = responseData['data']['token'];
      if (token == null || token.isEmpty) {
        debugPrint('ERROR: Token is null or empty!');
        return {
          'success': false,
          'message': 'Server error: Token is empty',
          'errorType': 'TOKEN_EMPTY'
        };
      }
      
      // Print token for debugging (partial for security)
      final displayToken = token.length > 10 ? "${token.substring(0, 5)}...${token.substring(token.length - 5)}" : token;
      debugPrint('Token received: $displayToken (length: ${token.length})');
      
      // Store token with verification
      final tokenStored = await saveToken(token);
      if (!tokenStored) {
        debugPrint('ERROR: Failed to store token!');
        return {
          'success': false,
          'message': 'Error storing token',
          'errorType': 'TOKEN_STORAGE_ERROR'
        };
      }
      
      // Store user data
      Map<String, dynamic> userData = responseData['data'];
      // Ensure branchCode is included
      if (selectedBranch != null && !userData.containsKey('branchCode')) {
        userData['branchCode'] = selectedBranch;
      }
      
      // Ensure noMeja is included in userData
      if (!userData.containsKey('noMeja') && noMeja.isNotEmpty) {
        userData['noMeja'] = noMeja;
        debugPrint('🔍 Added noMeja to userData: $noMeja');
      } else {
        debugPrint('🔍 noMeja already in userData: ${userData['noMeja']}');
      }
      
      // Tambahkan username dan password untuk QR code jika role adalah CRF_TL
      final userRole = userData['role']?.toString().toUpperCase() ?? 
                      userData['roleID']?.toString().toUpperCase();
      
      debugPrint('USER ROLE: $userRole');
      
      if (userRole == 'CRF_TL') {
        // Simpan kredensial untuk QR code
        userData['username'] = username;
        userData['password'] = password;
        
        // Simpan kredensial secara terpisah untuk QR code
        final credentialsSaved = await saveTLSPVCredentials(username, password);
        debugPrint('Storing TLSPV credentials for QR code generation: ${credentialsSaved ? "SUCCESS" : "FAILED"}');
        
        // Verifikasi kredensial tersimpan
        final savedCreds = await getTLSPVCredentials();
        if (savedCreds != null) {
          debugPrint('Verified saved TLSPV credentials: username=${savedCreds['username']}, hasPassword=${savedCreds['password'] != null}');
        } else {
          debugPrint('WARNING: Failed to verify saved TLSPV credentials!');
        }
      }
      
      await saveUserData(userData);
      
      // Double-check token storage by reading it back immediately
      final storedToken = await getToken();
      if (storedToken == null || storedToken.isEmpty) {
        debugPrint('WARNING: Token storage verification failed! Stored token is null or empty.');
        
        // Try one more time with a slight delay
        await Future.delayed(const Duration(milliseconds: 100));
        final retryToken = await getToken();
        if (retryToken == null || retryToken.isEmpty) {
          debugPrint('ERROR: Token storage retry failed! Token still null or empty.');
          return {
            'success': false,
            'message': 'Error retrieving stored token',
            'errorType': 'TOKEN_RETRIEVAL_ERROR'
          };
        }
      } else {
        debugPrint('Token storage verification successful');
      }
      
      return {
        'success': true,
        'message': 'Login successful',
        'role': responseData['data']['role']
      };
    } catch (e) {
      debugPrint('Login error: $e');
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
        'errorType': 'CONNECTION_ERROR'
      };
    }
  }

  // Login directly with token for test mode
  Future<Map<String, dynamic>> loginWithToken(String token) async {
    try {
      // Verify token by making a test request
      final response = await _tryRequestWithFallback(
        requestFn: (baseUrl) => http.get(
          Uri.parse('$baseUrl/CRF/check-session'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json'
          },
        ),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // Save the token
          await saveToken(token);
          
          // Extract user data from token
          final parts = token.split('.');
          if (parts.length == 3) {
            final payload = json.decode(
              utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
            );
            
            // Create user data from token claims
            final userData = {
              'token': token,
              'userId': payload['userId'] ?? '',
              'userName': payload['sub'] ?? '',
              'role': payload['role'] ?? '',
              'isTestMode': true,
            };
            
            await saveUserData(userData);
            
            return {
              'success': true,
              'message': 'Login berhasil (Test Mode)',
              'data': userData
            };
          }
        }
      }
      
      return {
        'success': false,
        'message': 'Token tidak valid',
      };
    } catch (e) {
      debugPrint('Error logging in with token: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Helper to get min value (for string substring)
  int min(int a, int b) {
    return (a < b) ? a : b;
  }

  // Save token to shared preferences
  Future<bool> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Validate token
      if (token.isEmpty) {
        debugPrint('WARNING: Attempting to save empty token!');
        return false;
      }
      
      // Clear token first to ensure clean state
      await prefs.remove(tokenKey);
      
      // Store token
      final success = await prefs.setString(tokenKey, token);
      
      if (!success) {
        debugPrint('WARNING: Failed to save token to SharedPreferences!');
        return false;
      } else {
        debugPrint('Token saved successfully (length: ${token.length})');
        return true;
      }
    } catch (e) {
      debugPrint('Error saving token: $e');
      return false;
    }
  }
  
  // Get token from shared preferences
  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(tokenKey);
      
      // Log token details for debugging (partial token for security)
      if (token != null && token.isNotEmpty) {
        final parts = token.split('.');
        final displayPart = token.length > 10 ? "${token.substring(0, 5)}...${token.substring(token.length - 5)}" : token;
        debugPrint('Retrieved token: $displayPart (length: ${token.length}, parts: ${parts.length})');
      } else {
        debugPrint('Retrieved token is null or empty');
      }
      
      return token;
    } catch (e) {
      debugPrint('Error getting token: $e');
      return null;
    }
  }
  
  // Forcefully reset token (for testing)
  Future<void> resetToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenKey);
      debugPrint('Token forcefully reset');
    } catch (e) {
      debugPrint('Error resetting token: $e');
    }
  }

  // Save user data to shared preferences
  Future<bool> saveUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = json.encode(userData);
      
      // Update cache
      _cachedUserData = userDataString;
      
      // Jika role adalah CRF_TL, simpan kredensial untuk QR code
      if (userData['role']?.toString().toUpperCase() == 'CRF_TL' || 
          userData['roleID']?.toString().toUpperCase() == 'CRF_TL') {
        // Simpan username dan password jika tersedia
        if (userData['username'] != null && userData['password'] != null) {
          await saveTLSPVCredentials(userData['username'], userData['password']);
          debugPrint('TLSPV credentials saved for QR code usage');
        }
      }
      
      return await prefs.setString(userDataKey, userDataString);
    } catch (e) {
      debugPrint('Failed to save user data: $e');
      return false;
    }
  }
  
  // Get user data - optimized version
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      // Try cache first
      if (_cachedUserData != null && _cachedUserData!.isNotEmpty) {
        try {
          return json.decode(_cachedUserData!) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('Error parsing cached user data: $e');
          // Continue to read from SharedPreferences
        }
      }
      
      // If not in cache, read from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(userDataKey);
      
      if (userDataString != null && userDataString.isNotEmpty) {
        // Update cache
        _cachedUserData = userDataString;
        return json.decode(userDataString) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Failed to get user data: $e');
    }
    return null;
  }

  // Get user data (synchronous version)
  Map<String, dynamic>? getUserDataSync() {
    try {
      // Gunakan data yang sudah di-cache
      final userDataString = _cachedUserData;
      if (userDataString != null && userDataString.isNotEmpty) {
        return json.decode(userDataString) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting user data sync: $e');
    }
    return null;
  }

  // Logout method
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenKey);
      await prefs.remove(userDataKey);
    } catch (e) {
      debugPrint('Failed to logout: $e');
    }
  }

  // Check if user is logged in - optimized version
  Future<bool> isLoggedIn() async {
    try {
      // Try to get token from SharedPreferences directly for performance
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(tokenKey);
      return token != null && token.isNotEmpty;
    } catch (e) {
      debugPrint('Failed to check login status: $e');
      return false;
    }
  }

  // Add token expiration check
  Future<bool> shouldRefreshToken() async {
    try {
      final token = await getToken();
      if (token == null) return false;
      
      // Parse JWT token
      final parts = token.split('.');
      if (parts.length != 3) return false;

      try {
        // Decode payload
        final payload = json.decode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
        );
        
        // Get expiration timestamp
        if (!payload.containsKey('exp')) {
          debugPrint('Token does not contain expiration claim');
          return false; // Don't refresh if no expiration found - API will handle it
        }
        
        final expiration = DateTime.fromMillisecondsSinceEpoch((payload['exp'] as int) * 1000);
        
        // Only refresh if token is actually expired
        final isExpired = DateTime.now().isAfter(expiration);
        debugPrint('Token expires at: $expiration, isExpired: $isExpired');
        return isExpired;
      } catch (parseError) {
        debugPrint('Error parsing token payload: $parseError');
        return false; // Don't refresh if parsing fails - API will handle it
      }
    } catch (e) {
      debugPrint('Error checking token expiration: $e');
      return false; // Don't refresh if any error occurs - API will handle it
    }
  }

  // Refresh token
  Future<bool> refreshToken() async {
    try {
      final token = await getToken();
      if (token == null) return false;

      debugPrint('Attempting to refresh token');
      
      // Try primary URL first
      try {
        final response = await http.post(
          Uri.parse('$_primaryBaseUrl/CRF/refresh-token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          debugPrint('Refresh token response: ${response.body}');
          
          if (responseData['success'] == true && responseData['data'] != null && 
              responseData['data']['token'] != null) {
            final newToken = responseData['data']['token'];
            await saveToken(newToken);
            debugPrint('Token refreshed successfully');
            return true;
          }
        } else {
          debugPrint('Failed to refresh token with primary URL: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Error refreshing token with primary URL: $e');
      }
      
      // Try fallback URL if primary fails
      try {
        final response = await http.post(
          Uri.parse('$_fallbackBaseUrl/CRF/refresh-token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          debugPrint('Refresh token response (fallback): ${response.body}');
          
          if (responseData['success'] == true && responseData['data'] != null && 
              responseData['data']['token'] != null) {
            final newToken = responseData['data']['token'];
            await saveToken(newToken);
            debugPrint('Token refreshed successfully with fallback URL');
            return true;
          }
        }
      } catch (e) {
        debugPrint('Error refreshing token with fallback URL: $e');
      }
      
      // If we get here, both attempts failed
      debugPrint('Failed to refresh token with both URLs');
      return false;
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      return false;
    }
  }

  // Check if user is in test mode
  Future<bool> isTestMode() async {
    try {
      final userData = await getUserData();
      if (userData == null) return false;
      
      final username = userData['userName'] as String?;
      if (username == null) return false;
      
      return username.toLowerCase().startsWith('test_') || 
             username.toLowerCase().endsWith('_test');
    } catch (e) {
      debugPrint('Error checking test mode: $e');
      return false;
    }
  }

  // Get user role from stored data with priority to roleID
  Future<String?> getUserRole() async {
    try {
      final userData = await getUserData();
      if (userData == null) return null;
      
      // Print all possible role fields for debugging
      print('DEBUG getUserRole: roleID=${userData['roleID']}, role=${userData['role']}');
      
      // Prioritize roleID field as it's the field name from API
      String? userRole = (userData['roleID'] ?? 
                        userData['RoleID'] ?? 
                        userData['role'] ?? 
                        userData['Role'] ?? 
                        userData['userRole'] ?? 
                        userData['UserRole'] ?? 
                        userData['position'] ?? 
                        userData['Position'])?.toString();
                        
      print('DEBUG getUserRole: normalized userRole=$userRole');
      return userRole?.toUpperCase();
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return null;
    }
  }

  // Check if user has specific role (using uppercase for consistency)
  Future<bool> hasRole(String requiredRole) async {
    try {
      final userRole = await getUserRole();
      if (userRole == null) return false;
      
      // Normalize role comparison using uppercase
      print('DEBUG hasRole: comparing userRole=$userRole with requiredRole=$requiredRole');
      return userRole.toUpperCase() == requiredRole.toUpperCase();
    } catch (e) {
      debugPrint('Error checking user role: $e');
      return false;
    }
  }

  // Check if user has any of the specified roles (using uppercase for consistency)
  Future<bool> hasAnyRole(List<String> requiredRoles) async {
    try {
      final userRole = await getUserRole();
      if (userRole == null) return false;
      
      // Normalize and check against all required roles using uppercase
      final normalizedUserRole = userRole.toUpperCase();
      print('DEBUG hasAnyRole: checking userRole=$normalizedUserRole against requiredRoles=$requiredRoles');
      return requiredRoles.any((role) => role.toUpperCase() == normalizedUserRole);
    } catch (e) {
      debugPrint('Error checking user roles: $e');
      return false;
    }
  }

  // Get available menu items based on user role (using uppercase for consistency)
  Future<List<String>> getAvailableMenus() async {
    try {
      final userRole = await getUserRole();
      print('DEBUG getAvailableMenus: userRole=$userRole');
      if (userRole == null) return [];
      
      switch (userRole.toUpperCase()) {
        case 'CRF_KONSOL':
          return [
            'prepare_mode',
            'return_mode',
            'device_info',
            'settings_opr',
            'konsol_mode', // Added Konsol Mode menu
          ];
        case 'CRF_TL':
          print('DEBUG: Returning menus for CRF_TL role');
          return [
            'dashboard_tl',
            'team_management',
            'approvals',
            'reports_tl',
            'settings_tl',
          ];
        case 'CRF_OPR':
        default:
          return [
            'prepare_mode',
            'return_mode',
            'device_info',
            'settings_opr',
          ];
      }
    } catch (e) {
      debugPrint('Error getting available menus: $e');
      return [];
    }
  }

  // Menyimpan kredensial TLSPV untuk digunakan dalam QR code
  Future<bool> saveTLSPVCredentials(String username, String password) async {
    try {
      if (username.isEmpty || password.isEmpty) {
        debugPrint('Cannot save TLSPV credentials: username or password is empty');
        return false;
      }
      
      debugPrint('Saving TLSPV credentials: username=$username, passwordLength=${password.length}');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Create a safer credentials object with encryption
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final salt = 'CRF_SECURE_SALT_$timestamp';
      final passwordHash = sha256.convert(utf8.encode(password + salt)).toString().substring(0, 32);
      
      final credentials = {
        'username': username,
        'password_hash': passwordHash, // Store hash instead of plain password
        'password': password, // Still need the password for QR code
        'salt': salt,
        'timestamp': timestamp
      };
      
      final jsonStr = json.encode(credentials);
      debugPrint('Credentials JSON length: ${jsonStr.length}');
      
      // Clear previous credentials first
      await prefs.remove(tlspvCredentialsKey);
      
      // Save new credentials
      final success = await prefs.setString(tlspvCredentialsKey, jsonStr);
      
      if (!success) {
        debugPrint('ERROR: Failed to save TLSPV credentials to SharedPreferences!');
        return false;
      }
      
      // Verify saved
      final saved = prefs.getString(tlspvCredentialsKey);
      if (saved == null || saved.isEmpty) {
        debugPrint('ERROR: Failed to verify TLSPV credentials in SharedPreferences!');
        return false;
      }
      
      debugPrint('TLSPV credentials saved successfully');
      return true;
    } catch (e) {
      debugPrint('Failed to save TLSPV credentials: $e');
      return false;
    }
  }
  
  // Mengambil kredensial TLSPV yang tersimpan
  Future<Map<String, dynamic>?> getTLSPVCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Use a try-catch specifically for the getString operation
      String? credentialsString;
      try {
        credentialsString = prefs.getString(tlspvCredentialsKey);
      } catch (e) {
        debugPrint('Error accessing SharedPreferences for TLSPV credentials: $e');
        return null;
      }
      
      if (credentialsString == null) {
        debugPrint('No TLSPV credentials found in SharedPreferences');
        return null;
      }
      
      if (credentialsString.isEmpty) {
        debugPrint('TLSPV credentials string is empty');
        return null;
      }
      
      debugPrint('Retrieved TLSPV credentials string length: ${credentialsString.length}');
      
      Map<String, dynamic> credentials;
      try {
        credentials = json.decode(credentialsString) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Error parsing TLSPV credentials JSON: $e');
        return null;
      }
      
      // Validate credentials
      final username = credentials['username'];
      final password = credentials['password'];
      
      if (username == null || username.toString().isEmpty) {
        debugPrint('Retrieved TLSPV credentials have empty username');
        return null;
      }
      
      if (password == null || password.toString().isEmpty) {
        debugPrint('Retrieved TLSPV credentials have empty password');
        return null;
      }
      
      debugPrint('Successfully retrieved TLSPV credentials: username=$username, hasPassword=${password != null}');
      return credentials;
    } catch (e) {
      debugPrint('Failed to get TLSPV credentials: $e');
      return null;
    }
  }
  
  // Enkripsi data untuk QR code
  String encryptDataForQR(Map<String, dynamic> data) {
    try {
      // Konversi data ke JSON string
      final jsonString = json.encode(data);
      
      // Tambahkan timestamp untuk keamanan
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Buat signature dengan HMAC
      final key = utf8.encode(encryptionKey + timestamp);
      final bytes = utf8.encode(jsonString);
      final hmacSha256 = Hmac(sha256, key);
      final digest = hmacSha256.convert(bytes);
      final signature = digest.toString();
      
      // Gabungkan data dengan timestamp dan signature
      final secureData = {
        'data': base64Encode(utf8.encode(jsonString)),
        'timestamp': timestamp,
        'signature': signature
      };
      
      // Encode final data untuk QR
      return base64Encode(utf8.encode(json.encode(secureData)));
    } catch (e) {
      debugPrint('Error encrypting data for QR: $e');
      return '';
    }
  }
  
  // Dekripsi data dari QR code
  Map<String, dynamic>? decryptDataFromQR(String encryptedData) {
    try {
      debugPrint('Decrypting QR data, length: ${encryptedData.length}');
      
      // Decode base64 string
      final decodedString = utf8.decode(base64Decode(encryptedData));
      final secureData = json.decode(decodedString) as Map<String, dynamic>;
      
      // Ambil komponen
      if (!secureData.containsKey('data') || !secureData.containsKey('timestamp') || !secureData.containsKey('signature')) {
        debugPrint('QR data missing required fields: data=${secureData.containsKey('data')}, timestamp=${secureData.containsKey('timestamp')}, signature=${secureData.containsKey('signature')}');
        return null;
      }
      
      final encodedData = secureData['data'] as String;
      final timestamp = secureData['timestamp'] as String;
      final receivedSignature = secureData['signature'] as String;
      
      // Decode data asli
      final jsonString = utf8.decode(base64Decode(encodedData));
      debugPrint('Decoded JSON string: ${jsonString.length > 100 ? "${jsonString.substring(0, 100)}..." : jsonString}');
      
      // Verifikasi signature
      final key = utf8.encode(encryptionKey + timestamp);
      final bytes = utf8.encode(jsonString);
      final hmacSha256 = Hmac(sha256, key);
      final digest = hmacSha256.convert(bytes);
      final calculatedSignature = digest.toString();
      
      // Periksa signature dan timestamp (maksimal 5 menit)
      final now = DateTime.now().millisecondsSinceEpoch;
      final msgTime = int.parse(timestamp);
      final validTime = (now - msgTime) < 5 * 60 * 1000; // 5 menit
      final validSignature = calculatedSignature == receivedSignature;
      
      debugPrint('Signature validation: ${validSignature ? "VALID" : "INVALID"}');
      debugPrint('Time validation: ${validTime ? "VALID" : "EXPIRED"} (${(now - msgTime) / (60 * 1000)} minutes old)');
      
      if (validSignature && validTime) {
        Map<String, dynamic> decodedData;
        try {
          decodedData = json.decode(jsonString) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('Error parsing JSON from QR: $e');
          return null;
        }
        
        // Debug log untuk memeriksa data yang didekripsi
        debugPrint('Decrypted QR data keys: ${decodedData.keys.toList()}');
        
        // Pastikan username dan password ada dan tidak kosong
        if (!decodedData.containsKey('username')) {
          debugPrint('QR data missing username key');
        } else if (decodedData['username'] == null || decodedData['username'].toString().isEmpty) {
          debugPrint('QR data username is null or empty: ${decodedData['username']}');
        } else {
          debugPrint('QR data username is present: ${decodedData['username']}');
        }
        
        if (!decodedData.containsKey('password')) {
          debugPrint('QR data missing password key');
        } else if (decodedData['password'] == null || decodedData['password'].toString().isEmpty) {
          debugPrint('QR data password is null or empty');
        } else {
          debugPrint('QR data password is present and not empty');
        }
        
        // Pastikan data yang dikembalikan tidak null
        return decodedData;
      } else {
        if (!validSignature) {
          debugPrint('QR data signature invalid: expected=$calculatedSignature, received=$receivedSignature');
        }
        if (!validTime) {
          debugPrint('QR data expired: ${(now - msgTime) / (60 * 1000)} minutes old');
        }
        return null;
      }
    } catch (e) {
      debugPrint('Error decrypting QR data: $e');
      return null;
    }
  }
}