import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../models/prepare_model.dart';
import '../models/return_model.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class ApiService {
  // Gunakan base URL yang benar sesuai backend
  static const String _primaryBaseUrl = 'https://dev.advantagescm.com/LocalCRF/api';
  // Hapus fallback ke port 8080 karena backend hanya di /LocalCRF/
  static const String _fallbackBaseUrl = 'https://dev.advantagescm.com/LocalCRF/api';
  
  // API timeout duration
  static const Duration _timeout = Duration(seconds: 15);

  // Track which base URL is working
  String _currentBaseUrl = _primaryBaseUrl;

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  
  // Auth service
  final AuthService _authService = AuthService();
  
  // Http client with logging
  final http.Client _client = http.Client();
  
  // Dio instance for better logging
  late final Dio _dio;
  
  // Initialize with logging
  ApiService._internal() {
    _dio = Dio(BaseOptions(
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      baseUrl: _currentBaseUrl,
    ))
      ..interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
        logPrint: (obj) => debugPrint('🔄 DIO: ${obj.toString()}'),
      ));
  }
  
  // Debug helper method for HTTP requests
  Future<http.Response> _debugHttp(Future<http.Response> Function() request, String description) async {
    try {
      debugPrint('🔄 HTTP REQUEST [$description] - Starting...');
      final stopwatch = Stopwatch()..start();
      final response = await request();
      stopwatch.stop();
      
      // Log partial response (to avoid huge logs)
      final bodyPreview = response.body.length > 200 
          ? '${response.body.substring(0, 200)}... (${response.body.length} chars total)'
          : response.body;
          
      debugPrint('🔄 HTTP RESPONSE [$description] - Status: ${response.statusCode}, Time: ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('🔄 HTTP RESPONSE BODY: $bodyPreview');
      
      return response;
    } catch (e) {
      debugPrint('🔄 HTTP ERROR [$description]: $e');
      rethrow;
    }
  }

  // Get headers for API requests with authorization token
  Future<Map<String, String>> get headers async {
    try {
      final token = await _authService.getToken();
      
      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': token != null ? 'Bearer $token' : '',
      };
    } catch (e) {
      debugPrint('Error getting headers: $e');
      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
    }
  }

  // Private method to get headers (alias for the public getter)
  Future<Map<String, String>> _getHeaders() async {
    return await headers;
  }

  // Execute request with retry logic
  Future<http.Response> _executeWithRetry(
    Future<http.Response> Function() request,
    String description,
  ) async {
    return await _debugHttp(request, description);
  }
  
  // Save working base URL
  Future<void> _saveBaseUrl(String url) async {
    try {
      _currentBaseUrl = url;
      debugPrint('Switching to base URL: $url');
    } catch (e) {
      debugPrint('Failed to save base URL: $e');
    }
  }

  // Try request with fallback
  Future<http.Response> _tryRequestWithFallback({
    required Future<http.Response> Function(String baseUrl) requestFn,
  }) async {
    // Track the current attempt for detailed error reporting
    String currentAttemptUrl = _currentBaseUrl;
    String errorDetails = '';
    
    try {
      // Try with current URL
      debugPrint('Attempting request with primary URL: $currentAttemptUrl');
      final response = await requestFn(_currentBaseUrl).timeout(_timeout);
      
      // Check for auth errors
      if (response.statusCode == 401) {
        debugPrint('Authentication error (401) with URL: $currentAttemptUrl');
        throw Exception('Session expired: Please login again');
      }
      
      debugPrint('Request successful with URL: $currentAttemptUrl, Status: ${response.statusCode}');
      return response;
    } catch (e) {
      // Skip token refresh retry for fallback if it's a session expired exception
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      
      errorDetails = 'Request failed with $currentAttemptUrl: $e';
      debugPrint(errorDetails);
      
      // Try with fallback URL
      final fallbackUrl = (_currentBaseUrl == _primaryBaseUrl) 
          ? _fallbackBaseUrl 
          : _primaryBaseUrl;
      
      currentAttemptUrl = fallbackUrl; // Update for error reporting
      
      try {
        debugPrint('Attempting request with fallback URL: $fallbackUrl');
        final response = await requestFn(fallbackUrl).timeout(_timeout);
        
        // Check for auth errors on fallback
        if (response.statusCode == 401) {
          debugPrint('Authentication error (401) with fallback URL: $fallbackUrl');
          throw Exception('Session expired: Please login again');
        }
        
        // If fallback worked, save it as current
        if (response.statusCode >= 200 && response.statusCode < 300) {
          await _saveBaseUrl(fallbackUrl);
          debugPrint('Fallback request successful, switching to URL: $fallbackUrl');
        } else {
          debugPrint('Fallback request completed with status: ${response.statusCode}');
        }
        return response;
      } catch (e2) {
        final fallbackErrorDetails = 'Fallback request also failed with $fallbackUrl: $e2';
        debugPrint(fallbackErrorDetails);
        
        // If the second error is about session expiration, prioritize that
        if (e2.toString().contains('Session expired')) {
          rethrow;
        }
        
        // Provide detailed error message combining both attempts
        throw Exception('Kedua URL server tidak dapat diakses.\n\nURL Utama: $_primaryBaseUrl\nKesalahan: $e\n\nURL Cadangan: $_fallbackBaseUrl\nKesalahan: $e2\n\nMohon periksa koneksi internet dan konfigurasi server.');
      }
    }
  }

  Future<String> _resolveBranchCode(String? branchCode) async {
    String value = (branchCode ?? '').trim();
    if (value.isNotEmpty && value != '0') {
      return RegExp(r'^\d+$').hasMatch(value) ? value : '1';
    }
    final userData = await _authService.getUserData();
    final fromUser = (userData?['groupId'] ??
            userData?['GroupId'] ??
            userData?['GroupID'] ??
            userData?['groupid'] ??
            userData?['groupID'] ??
            userData?['branchCode'] ??
            userData?['BranchCode'])
        ?.toString()
        .trim();
    if (fromUser != null && fromUser.isNotEmpty && RegExp(r'^\d+$').hasMatch(fromUser)) {
      return fromUser;
    }
    return '1';
  }

  // Get ATM Prepare Replenish data by ID with better error handling
  Future<PrepareReplenishResponse> getATMPrepareReplenish(int id, {String? branchCode}) async {
    try {
      final requestHeaders = await headers;
      final resolvedBranchCode = await _resolveBranchCode(branchCode);
      
      // Check if token is missing
      if (!requestHeaders.containsKey('Authorization') || 
          requestHeaders['Authorization'] == null || 
          requestHeaders['Authorization']!.isEmpty ||
          requestHeaders['Authorization'] == 'Bearer ') {
        debugPrint('🚨 CRITICAL ERROR: Missing or empty Authorization header!');
        await _authService.logout();
        throw Exception('Session invalid: Please login again');
      }
      
      // First attempt
      try {
        debugPrint('🔍 Preparing to fetch ATM data for ID: $id');
        debugPrint('🔍 Using URL: $_currentBaseUrl/CRF/atm/prepare-replenish/$id?branchCode=$resolvedBranchCode');
        debugPrint('🔍 Headers: ${requestHeaders.toString()}');
        
        final response = await _debugHttp(
          () => http.get(
            Uri.parse('$_currentBaseUrl/CRF/atm/prepare-replenish/$id')
                .replace(queryParameters: {'branchCode': resolvedBranchCode}),
            headers: requestHeaders,
          ).timeout(_timeout),
          'GET ATM Prepare $id'
        );

        if (response.statusCode == 200) {
          try {
            final jsonData = json.decode(response.body);
            return PrepareReplenishResponse.fromJson(jsonData);
          } catch (e) {
            debugPrint('Error parsing JSON: $e');
            throw Exception('Invalid data format from server');
          }
        } else if (response.statusCode == 401) {
          // On 401, force logout and throw exception
          debugPrint('🚨 401 Unauthorized! Forcing logout...');
          await _authService.logout();
          throw Exception('Session expired: Please login again');
        } else {
          throw Exception('Server error (${response.statusCode}): ${response.body}');
        }
      } catch (firstAttemptError) {
        // If first attempt fails with anything except session expired, try fallback URL
        if (firstAttemptError.toString().contains('Session expired') || 
            firstAttemptError.toString().contains('Session invalid')) {
          rethrow;
        }
        
        debugPrint('First attempt failed: $firstAttemptError, trying fallback URL');
        
        // Fallback attempt
        final fallbackUrl = (_currentBaseUrl == _primaryBaseUrl) 
            ? _fallbackBaseUrl 
            : _primaryBaseUrl;
            
        final response = await _debugHttp(
          () => http.get(
            Uri.parse('$fallbackUrl/CRF/atm/prepare-replenish/$id')
                .replace(queryParameters: {'branchCode': resolvedBranchCode}),
            headers: requestHeaders,
          ).timeout(_timeout),
          'GET ATM Prepare $id (Fallback)'
        );
        
        if (response.statusCode == 200) {
          try {
            // Save fallback URL if successful
            await _saveBaseUrl(fallbackUrl);
            
            final jsonData = json.decode(response.body);
            return PrepareReplenishResponse.fromJson(jsonData);
          } catch (e) {
            debugPrint('Error parsing JSON: $e');
            throw Exception('Invalid data format from server');
          }
        } else if (response.statusCode == 401) {
          // On 401, force logout and throw exception
          debugPrint('🚨 401 Unauthorized on fallback! Forcing logout...');
          await _authService.logout();
          throw Exception('Session expired: Please login again');
        } else {
          throw Exception('Server error (${response.statusCode}): ${response.body}');
        }
      }
    } catch (e) {
      debugPrint('API error: $e');
      if (e is TimeoutException) {
        throw Exception('Connection timeout: Please check your internet connection');
      }
      rethrow; // Return original error message
    }
  }

  // Get Return Catridge data by ID
  Future<ReturnCatridgeResponse> getReturnCatridge(String idTool, {String branchCode = "0"}) async {
    try {
      final requestHeaders = await headers;
      
      // Check if token is missing
      if (!requestHeaders.containsKey('Authorization') || 
          requestHeaders['Authorization'] == null || 
          requestHeaders['Authorization']!.isEmpty ||
          requestHeaders['Authorization'] == 'Bearer ') {
        debugPrint('🚨 CRITICAL ERROR: Missing or empty Authorization header!');
        await _authService.logout();
        throw Exception('Session invalid: Please login again');
      }
      
      // First attempt
      try {
        debugPrint('🔍 Preparing to fetch Return data for ID: $idTool, Branch: $branchCode');
        debugPrint('🔍 Using URL: $_currentBaseUrl/CRF/atm/return-catridge/$idTool?branchCode=$branchCode');
        debugPrint('🔍 Headers: ${requestHeaders.toString()}');
        
        final response = await _debugHttp(
          () => http.get(
            Uri.parse('$_currentBaseUrl/CRF/atm/return-catridge/$idTool?branchCode=$branchCode'),
            headers: requestHeaders,
          ).timeout(_timeout),
          'GET Return Catridge $idTool'
        );

        if (response.statusCode == 200) {
          try {
            final jsonData = json.decode(response.body);
            return ReturnCatridgeResponse.fromJson(jsonData);
          } catch (e) {
            debugPrint('Error parsing JSON: $e');
            throw Exception('Invalid data format from server');
          }
        } else if (response.statusCode == 401) {
          // On 401, force logout and throw exception
          debugPrint('🚨 401 Unauthorized! Forcing logout...');
          await _authService.logout();
          throw Exception('Session expired: Please login again');
        } else {
          throw Exception('Server error (${response.statusCode}): ${response.body}');
        }
      } catch (firstAttemptError) {
        // If first attempt fails with anything except session expired, try fallback URL
        if (firstAttemptError.toString().contains('Session expired') || 
            firstAttemptError.toString().contains('Session invalid')) {
          rethrow;
        }
        
        debugPrint('First attempt failed: $firstAttemptError, trying fallback URL');
        
        // Fallback attempt
        final fallbackUrl = (_currentBaseUrl == _primaryBaseUrl) 
            ? _fallbackBaseUrl 
            : _primaryBaseUrl;
            
        final response = await _debugHttp(
          () => http.get(
            Uri.parse('$fallbackUrl/CRF/atm/return-catridge/$idTool?branchCode=$branchCode'),
            headers: requestHeaders,
          ).timeout(_timeout),
          'GET Return Catridge $idTool (Fallback)'
        );
        
        if (response.statusCode == 200) {
          try {
            // Save fallback URL if successful
            await _saveBaseUrl(fallbackUrl);
            
            final jsonData = json.decode(response.body);
            return ReturnCatridgeResponse.fromJson(jsonData);
          } catch (e) {
            debugPrint('Error parsing JSON: $e');
            throw Exception('Invalid data format from server');
          }
        } else if (response.statusCode == 401) {
          // On 401, force logout and throw exception
          debugPrint('🚨 401 Unauthorized on fallback! Forcing logout...');
          await _authService.logout();
          throw Exception('Session expired: Please login again');
        } else {
          throw Exception('Server error (${response.statusCode}): ${response.body}');
        }
      }
    } catch (e) {
      debugPrint('API error: $e');
      if (e is TimeoutException) {
        throw Exception('Connection timeout: Please check your internet connection');
      }
      rethrow; // Return original error message
    }
  }

  // Insert Return ATM Catridge
  Future<ApiResponse> insertReturnAtmCatridge({
    required String idTool,
    required String bagCode,
    required String catridgeCode,
    required String sealCode,
    required String catridgeSeal,
    required String denomCode,
    required String qty,
    required String userInput,
    String isBalikKaset = "N",
    String catridgeCodeOld = "",
    String scanCatStatus = "",
    String scanCatStatusRemark = "",
    String scanSealStatus = "",
    String scanSealStatusRemark = "",
  }) async {
    try {
      final requestHeaders = await headers;
      
      // Convert idTool to integer if possible
      int? idToolNum;
      try {
        idToolNum = int.parse(idTool);
      } catch (e) {
        debugPrint('Error converting idTool to int: $e');
        idToolNum = 0;
      }
      
      final requestBody = {
        "IdTool": idToolNum > 0 ? idToolNum : idTool,
        "BagCode": bagCode,
        "CatridgeCode": catridgeCode,
        "SealCode": sealCode,
        "CatridgeSeal": catridgeSeal,
        "DenomCode": denomCode,
        "Qty": qty,
        "UserInput": userInput,
        "IsBalikKaset": isBalikKaset,
        "CatridgeCodeOld": catridgeCodeOld,
        "ScanCatStatus": scanCatStatus,
        "ScanCatStatusRemark": scanCatStatusRemark,
        "ScanSealStatus": scanSealStatus,
        "ScanSealStatusRemark": scanSealStatusRemark
      };
      
      debugPrint('🔍 Return ATM Catridge insert request: ${json.encode(requestBody)}');
      debugPrint('🔍 Headers: $requestHeaders');
      
      final response = await _debugHttp(
        () => _tryRequestWithFallback(
          requestFn: (baseUrl) => http.post(
            Uri.parse('$baseUrl/CRF/rtn/atm/catridge'),
            headers: requestHeaders,
            body: json.encode(requestBody),
          ),
        ),
        'Return ATM Catridge Insert'
      );

      if (response.statusCode == 200) {
        try {
          debugPrint('🔍 Raw return ATM catridge insert response: ${response.body.substring(0, math.min(300, response.body.length))}...');
          
          final jsonData = json.decode(response.body);
          
          // Normalize keys to handle case insensitivity
          Map<String, dynamic> normalizedJson = {};
          if (jsonData is Map<String, dynamic>) {
            jsonData.forEach((key, value) {
              normalizedJson[key.toLowerCase()] = value;
            });
          } else {
            debugPrint('❌ Unexpected response format: $jsonData');
            return ApiResponse(
              success: false,
              message: 'Invalid response format',
              status: 'error'
            );
          }
          
          // Check if the response contains direct success/status fields from SP
          bool isSuccess = false;
          String message = 'Operation completed';
          
          if (normalizedJson.containsKey('success')) {
            isSuccess = normalizedJson['success'] == true;
          }
          
          if (normalizedJson.containsKey('message')) {
            message = normalizedJson['message'].toString();
          }
          
          if (normalizedJson.containsKey('data')) {
            try {
              var dataValue = normalizedJson['data'];
              debugPrint('🔍 Data value type: ${dataValue.runtimeType}');
              
              if (dataValue is String) {
                // Try to parse data if it's a JSON string
                try {
                  final dataJson = json.decode(dataValue);
                  debugPrint('🔍 Parsed data JSON: $dataJson');
                  
                  if (dataJson is List && dataJson.isNotEmpty) {
                    // Normalize first item's keys
                    Map<String, dynamic> normalizedDataItem = {};
                    if (dataJson[0] is Map<String, dynamic>) {
                      (dataJson[0] as Map<String, dynamic>).forEach((key, value) {
                        normalizedDataItem[key.toLowerCase()] = value;
                      });
                      
                      debugPrint('🔍 Normalized data item: $normalizedDataItem');
                      
                      // Extract status and message
                      final status = normalizedDataItem['status']?.toString().toLowerCase();
                      final dataMessage = normalizedDataItem['message']?.toString();
                      
                      if (status != null) {
                        isSuccess = status == 'success';
                        if (dataMessage != null && dataMessage.isNotEmpty) {
                          message = dataMessage;
                        }
                      }
                    }
                  }
                } catch (parseError) {
                  debugPrint('❌ Error parsing data JSON string: $parseError');
                }
              } else if (dataValue is List && dataValue.isNotEmpty) {
                // Handle direct list response
                debugPrint('🔍 Data is a direct list with ${dataValue.length} items');
                
                if (dataValue[0] is Map<String, dynamic>) {
                  // Normalize first item's keys
                  Map<String, dynamic> normalizedDataItem = {};
                  (dataValue[0] as Map<String, dynamic>).forEach((key, value) {
                    normalizedDataItem[key.toLowerCase()] = value;
                  });
                  
                  debugPrint('🔍 Normalized data item: $normalizedDataItem');
                  
                  // Extract status and message
                  final status = normalizedDataItem['status']?.toString().toLowerCase();
                  final dataMessage = normalizedDataItem['message']?.toString();
                  
                  if (status != null) {
                    isSuccess = status == 'success';
                    if (dataMessage != null && dataMessage.isNotEmpty) {
                      message = dataMessage;
                    }
                  }
                }
              } else if (dataValue is Map<String, dynamic>) {
                // Handle direct map response
                debugPrint('🔍 Data is a direct map');
                
                // Normalize data map keys
                Map<String, dynamic> normalizedDataMap = {};
                dataValue.forEach((key, value) {
                  normalizedDataMap[key.toLowerCase()] = value;
                });
                
                debugPrint('🔍 Normalized data map: $normalizedDataMap');
                
                // Extract status and message
                final status = normalizedDataMap['status']?.toString().toLowerCase();
                final dataMessage = normalizedDataMap['message']?.toString();
                
                if (status != null) {
                  isSuccess = status == 'success';
                  if (dataMessage != null && dataMessage.isNotEmpty) {
                    message = dataMessage;
                  }
                }
              }
            } catch (e) {
              debugPrint('❌ Error processing data field: $e');
            }
          }
          
          debugPrint('🔍 Final result: success=$isSuccess, message=$message');
          
          return ApiResponse(
            success: isSuccess,
            message: message,
            status: isSuccess ? 'success' : 'error',
            data: normalizedJson['data']
          );
        } catch (e) {
          debugPrint('❌ Error parsing Return ATM catridge insert JSON: $e');
          return ApiResponse(
            success: false,
            message: 'Invalid Return ATM catridge insert data format from server',
            status: 'error'
          );
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ 401 Unauthorized on return ATM catridge insert!');
        await _authService.logout();
        return ApiResponse(
          success: false,
          message: 'Session expired: Please login again',
          status: 'error'
        );
      } else {
        debugPrint('❌ HTTP error on return ATM catridge insert: ${response.statusCode}, body: ${response.body}');
        return ApiResponse(
          success: false,
          message: 'Server error (${response.statusCode}): ${response.body}',
          status: 'error'
        );
      }
    } catch (e) {
      debugPrint('❌ Return ATM catridge insert API error: $e');
      
      String errorMessage = 'Network error: ${e.toString()}';
      if (e is TimeoutException) {
        errorMessage = 'Connection timeout: Please check your internet connection';
      }
      
      return ApiResponse(
        success: false,
        message: errorMessage,
        status: 'error'
      );
    }
  }

  // Insert Return ATM Catridge TEMP (RTN_SP_InsertAtmCatridgeTemporary)
  Future<ApiResponse> insertReturnAtmCatridgeTemp({
    required String idTool,
    required String bagCode,
    required String catridgeCode,
    required String sealCode,
    required String catridgeSeal,
    required String denomCode,
    required String qty,
    required String userInput,
    String isBalikKaset = "N",
    String catridgeCodeOld = "",
    String scanCatStatus = "",
    String scanCatStatusRemark = "",
    String scanSealStatus = "",
    String scanSealStatusRemark = "",
  }) async {
    try {
      final requestHeaders = await headers;
      int? idToolNum;
      try {
        idToolNum = int.parse(idTool);
      } catch (e) {
        debugPrint('Error converting idTool to int: $e');
        idToolNum = 0;
      }

      final requestBody = {
        "IdTool": idToolNum > 0 ? idToolNum : idTool,
        "BagCode": bagCode,
        "CatridgeCode": catridgeCode,
        "SealCode": sealCode,
        "CatridgeSeal": catridgeSeal,
        "DenomCode": denomCode,
        "Qty": qty,
        "UserInput": userInput,
        "IsBalikKaset": isBalikKaset,
        "CatridgeCodeOld": catridgeCodeOld,
        "ScanCatStatus": scanCatStatus.isEmpty ? null : scanCatStatus,
        "ScanCatStatusRemark": scanCatStatusRemark.isEmpty ? null : scanCatStatusRemark,
        "ScanSealStatus": scanSealStatus.isEmpty ? null : scanSealStatus,
        "ScanSealStatusRemark": scanSealStatusRemark.isEmpty ? null : scanSealStatusRemark
      };

      debugPrint('🔍 Return ATM Catridge TEMP insert request: ${json.encode(requestBody)}');
      debugPrint('🔍 Headers: $requestHeaders');

      final response = await _debugHttp(
        () => _tryRequestWithFallback(
          requestFn: (baseUrl) => http.post(
            Uri.parse('$baseUrl/CRF/rtn/atm/catridge/temp'),
            headers: requestHeaders,
            body: json.encode(requestBody),
          ),
        ),
        'Return ATM Catridge TEMP Insert'
      );

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          Map<String, dynamic> normalizedJson = {};
          if (jsonData is Map<String, dynamic>) {
            jsonData.forEach((key, value) {
              normalizedJson[key.toLowerCase()] = value;
            });
          }

          bool isSuccess = false;
          String message = 'Operation completed';
          if (normalizedJson.containsKey('success')) {
            isSuccess = normalizedJson['success'] == true;
          }
          if (normalizedJson.containsKey('message')) {
            message = normalizedJson['message'].toString();
          }

          // Optional: handle 'data' field shape like SP output
          return ApiResponse(
            success: isSuccess,
            message: message,
            status: isSuccess ? 'success' : 'error',
            data: normalizedJson['data']
          );
        } catch (e) {
          debugPrint('❌ Error parsing Return ATM catridge TEMP insert JSON: $e');
          return ApiResponse(
            success: false,
            message: 'Invalid Return ATM catridge TEMP insert data format from server',
            status: 'error'
          );
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ 401 Unauthorized on return ATM catridge TEMP insert!');
        await _authService.logout();
        return ApiResponse(
          success: false,
          message: 'Session expired: Please login again',
          status: 'error'
        );
      } else if (response.statusCode == 400) {
        bool isValidationError = false;
        final bodyLower = response.body.toLowerCase();
        if (bodyLower.contains('one or more validation') ||
            bodyLower.contains('validation errors occurred')) {
          isValidationError = true;
        } else {
          try {
            final decoded = json.decode(response.body);
            if (decoded is Map) {
              final title = (decoded['title'] ?? '').toString().toLowerCase();
              final message = (decoded['message'] ?? '').toString().toLowerCase();
              if (title.contains('one or more validation') ||
                  message.contains('one or more validation') ||
                  title.contains('validation errors occurred') ||
                  message.contains('validation errors occurred')) {
                isValidationError = true;
              }
            }
          } catch (_) {}
        }

        if (isValidationError) {
          return ApiResponse(
            success: false,
            message: 'Inputan Return masih ada yang kosong!',
            status: 'error',
          );
        }

        debugPrint('❌ HTTP 400 on return ATM catridge TEMP insert: ${response.body}');
        return ApiResponse(
          success: false,
          message: 'Server error (400): ${response.body}',
          status: 'error',
        );
      } else {
        debugPrint('❌ HTTP error on return ATM catridge TEMP insert: ${response.statusCode}, body: ${response.body}');
        return ApiResponse(
          success: false,
          message: 'Server error (${response.statusCode}): ${response.body}',
          status: 'error'
        );
      }
    } catch (e) {
      debugPrint('❌ Return ATM catridge TEMP insert API error: $e');
      String errorMessage = 'Network error: ${e.toString()}';
      if (e is TimeoutException) {
        errorMessage = 'Connection timeout: Please check your internet connection';
      }
      return ApiResponse(
        success: false,
        message: errorMessage,
        status: 'error'
      );
    }
  }

  // Execute Return ATM Catridge by IdTool (RTN_SP_InsertAtmCatridge)
  Future<ApiResponse> executeReturnAtmCatridgeByIdTool({
    required int idTool,
    required String userApproveReturn,
  }) async {
    final requestHeaders = await headers;
    final requestBody = {
      "IdTool": idTool,
      "UserApproveReturn": userApproveReturn,
    };

    final response = await _tryRequestWithFallback(
      requestFn: (baseUrl) => http.post(
        Uri.parse('$baseUrl/CRF/rtn/atm/catridge/execute'),
        headers: requestHeaders,
        body: json.encode(requestBody),
      ),
    );

    if (response.statusCode == 200) {
      try {
        final jsonData = json.decode(response.body);
        bool success = jsonData is Map<String, dynamic> && (jsonData['success'] == true);
        String message = (jsonData is Map<String, dynamic> && jsonData['message'] != null)
            ? jsonData['message'].toString()
            : '';
        final data = (jsonData is Map<String, dynamic>) ? jsonData['data'] : null;
        String status = '';
        if (data is Map<String, dynamic> && data['status'] != null) {
          status = data['status'].toString();
        }
        return ApiResponse(success: success, message: message, data: data, status: status);
      } catch (e) {
        debugPrint('Error parsing execute return catridge JSON: $e');
        throw Exception('Invalid data format from server');
      }
    } else if (response.statusCode == 401) {
      await _authService.logout();
      throw Exception('Session expired: Please login again');
    } else {
      throw Exception('Server error (${response.statusCode}): ${response.body}');
    }
  }

  Future<ApiResponse> checkIsDone({
    required int idTool,
  }) async {
    try {
      final requestHeaders = await headers;
      final response = await _debugHttp(
        () => _tryRequestWithFallback(
          requestFn: (baseUrl) => http.get(
            Uri.parse('$baseUrl/CRF/rtn/check-is-done/$idTool'),
            headers: requestHeaders,
          ),
        ),
        'RTN Check Is Done $idTool',
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        Map<String, dynamic>? asLowerMap(dynamic value) {
          if (value is! Map) return null;
          final out = <String, dynamic>{};
          value.forEach((k, v) {
            out[k.toString().toLowerCase()] = v;
          });
          return out;
        }

        String extractStatus(dynamic value) {
          if (value == null) return '';
          if (value is String) return value;

          final map = asLowerMap(value);
          if (map != null) {
            final statusVal = map['status'];
            if (statusVal != null) return statusVal.toString();

            final dataVal = map['data'];
            if (dataVal != null) return extractStatus(dataVal);
          }

          if (value is List && value.isNotEmpty) {
            return extractStatus(value.first);
          }

          return '';
        }

        String message = 'OK';
        String status = extractStatus(decoded);

        final top = asLowerMap(decoded);
        if (top != null) {
          final msgVal = top['message'] ?? top['msg'];
          if (msgVal != null && msgVal.toString().trim().isNotEmpty) {
            message = msgVal.toString();
          }
        }

        return ApiResponse(success: true, message: message, status: status, data: decoded);
      } else if (response.statusCode == 401) {
        await _authService.logout();
        return ApiResponse(success: false, message: 'Session expired: Please login again', status: 'error');
      } else {
        return ApiResponse(success: false, message: 'Server error (${response.statusCode})', status: 'error');
      }
    } catch (e) {
      return ApiResponse(success: false, message: e.toString(), status: 'error');
    }
  }

  // Get catridge details with retry for different formats
  Future<ApiResponse> getCatridgeDetails(
    String branchCode, 
    String catridgeCode, {
    int? requiredStandValue,
    String? requiredType,
    List<String>? existingCatridges,
    String? idTool, // Add IdTool parameter
  }) async {
    try {
      final requestHeaders = await headers;
      ApiResponse? firstErrorResponse; // Store first error response
      
      // Try with original format first
      final originalResponse = await _tryCatridgeFormat(
        branchCode, 
        catridgeCode.trim(), 
        requestHeaders,
        requiredStandValue: requiredStandValue,
        requiredType: requiredType,
        existingCatridges: existingCatridges,
        idTool: idTool, // Pass IdTool parameter
      );
      
      if (originalResponse.success) {
        return originalResponse;
      } else {
        firstErrorResponse = originalResponse; // Store first error
      }
      
      // If original format fails, try without spaces
      final noSpacesCode = catridgeCode.replaceAll(' ', '');
      if (noSpacesCode != catridgeCode) {
        final noSpacesResponse = await _tryCatridgeFormat(
          branchCode, 
          noSpacesCode, 
          requestHeaders,
          requiredStandValue: requiredStandValue,
          requiredType: requiredType,
          existingCatridges: existingCatridges,
          idTool: idTool, // Pass IdTool parameter
        );
        
        if (noSpacesResponse.success) {
          return noSpacesResponse;
        }
      }
      
      // If no spaces fails, try with "ATM " prefix if not already present
      if (!catridgeCode.toUpperCase().startsWith('ATM ')) {
        final withAtmResponse = await _tryCatridgeFormat(
          branchCode, 
          'ATM ${catridgeCode.trim()}', 
          requestHeaders,
          requiredStandValue: requiredStandValue,
          requiredType: requiredType,
          existingCatridges: existingCatridges,
          idTool: idTool, // Pass IdTool parameter
        );
        
        if (withAtmResponse.success) {
          return withAtmResponse;
        }
      }
      
      // If all formats fail, return the first error response (most relevant)
      if (firstErrorResponse != null) {
        return firstErrorResponse;
      }
      
      // Fallback generic error
      return ApiResponse(
        success: false,
        message: 'Catridge tidak ditemukan. Periksa kembali nomor catridge.',
        status: 'error',
      );
    } catch (e) {
      debugPrint('Catridge details API error: $e');
      return ApiResponse(
        success: false,
        message: 'Error validating catridge: ${e.toString()}',
        status: 'error'
      );
    }
  }
  
  // Helper method to try different catridge formats
  Future<ApiResponse> _tryCatridgeFormat(
    String branchCode, 
    String catridgeCode, 
    Map<String, String> headers, {
    int? requiredStandValue,
    String? requiredType,
    List<String>? existingCatridges,
    String? idTool, // Add IdTool parameter
  }) async {
    try {
      final encodedCatridgeCode = Uri.encodeComponent(catridgeCode);
      
      // 
      String url = '$_currentBaseUrl/CRF/catridge/list?branchCode=$branchCode&catridgeCode=$encodedCatridgeCode';
      
      // Add optional parameters if provided
      if (requiredStandValue != null) {
        url += '&requiredStandValue=$requiredStandValue';
      }
      
      if (requiredType != null) {
        url += '&requiredType=$requiredType';
      }
      
      // Add IdTool parameter if provided
      if (idTool != null && idTool.isNotEmpty) {
        url += '&IdTool=$idTool';
      }
      
      // Debug log the request
      debugPrint('🔍 Catridge lookup URL: $url');
      debugPrint('🔍 Headers: $headers');
      
      final response = await _debugHttp(
        () => http.get(
          Uri.parse(url),
          headers: headers,
        ).timeout(_timeout),
        'Catridge Lookup: $catridgeCode'
      );
      
      if (response.statusCode == 200) {
        // lalu
        debugPrint('🔍 Raw response: ${response.body.substring(0, math.min(200, response.body.length))}...');
        
        final jsonData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(jsonData);
        
        // Debug log the parsed response lalu tolong untuk bagian,
        debugPrint('🔍 Parsed response: success=${apiResponse.success}, message=${apiResponse.message}');
        
        if (apiResponse.data is List) {
          debugPrint('🔍 Data is List with ${(apiResponse.data as List).length} items');
        } else {
          debugPrint('🔍 Data type: ${apiResponse.data.runtimeType}');
        }
        
        return apiResponse;
      } else {
        debugPrint('🔍 HTTP error: ${response.statusCode}, body: ${response.body}');
        return ApiResponse(
          success: false,
          message: 'Server error (${response.statusCode})',
          status: 'error'
        );
      }
    } catch (e) {
      debugPrint('🔍 Exception: $e');
      return ApiResponse(
        success: false,
        message: 'Error: ${e.toString()}',
        status: 'error'
      );
    }
  }
  
  // Helper to extract code from catridge data item
  String _extractCodeFromItem(dynamic item) {
    if (item is Map<String, dynamic>) {
      // Try both upper and lowercase keys
      if (item.containsKey('Code')) {
        return item['Code'].toString();
      } else if (item.containsKey('code')) {
        return item['code'].toString();
      } else {
        // If no direct code key, try to normalize keys
        Map<String, dynamic> normalized = {};
        item.forEach((key, value) {
          normalized[key.toLowerCase()] = value;
        });
        
        if (normalized.containsKey('code')) {
          return normalized['code'].toString();
        }
      }
    }
    return '';
  }

  // Validate Seal Code
  Future<ApiResponse> validateSeal(String sealCode) async {
    try {
      final requestHeaders = await headers;
      
      debugPrint('🔍 Validating seal: $sealCode');
      debugPrint('🔍 Headers: $requestHeaders');
      
      final response = await _debugHttp(
        () => _tryRequestWithFallback(
          requestFn: (baseUrl) => http.get(
            Uri.parse('$baseUrl/CRF/validate/seal/$sealCode'),
            headers: requestHeaders,
          ),
        ),
        'Validate Seal: $sealCode'
      );

      if (response.statusCode == 200) {
        try {
          debugPrint('🔍 Raw seal validation response: ${response.body.substring(0, math.min(200, response.body.length))}...');
          
          final jsonData = json.decode(response.body);
          final apiResponse = ApiResponse.fromJson(jsonData);
          
          // Debug log the parsed response
          debugPrint('🔍 Parsed seal response: success=${apiResponse.success}, message=${apiResponse.message}');
          if (apiResponse.data != null) {
            debugPrint('🔍 Data type: ${apiResponse.data.runtimeType}');
            if (apiResponse.data is Map) {
              debugPrint('🔍 Data as Map: ${apiResponse.data.toString().substring(0, math.min(100, apiResponse.data.toString().length))}...');
            } else if (apiResponse.data is List) {
              debugPrint('🔍 Data is List with ${(apiResponse.data as List).length} items');
            }
          }
          
          return apiResponse;
        } catch (e) {
          debugPrint('❌ Error parsing seal validation JSON: $e');
          return ApiResponse(
            success: false,
            message: 'Invalid data format from server',
            status: 'error'
          );
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ 401 Unauthorized on seal validation!');
        await _authService.logout();
        return ApiResponse(
          success: false,
          message: 'Session expired: Please login again',
          status: 'error'
        );
      } else {
        debugPrint('❌ HTTP error on seal validation: ${response.statusCode}, body: ${response.body}');
        return ApiResponse(
          success: false,
          message: 'Server error (${response.statusCode}): ${response.body}',
          status: 'error'
        );
      }
    } catch (e) {
      debugPrint('❌ Seal validation API error: $e');
      
      String errorMessage = 'Network error: ${e.toString()}';
      if (e is TimeoutException) {
        errorMessage = 'Connection timeout: Please check your internet connection';
      }
      
      return ApiResponse(
        success: false,
        message: errorMessage,
        status: 'error'
      );
    }
  }

  // Update Planning API for TL Supervisor approval
  Future<ApiResponse> updatePlanning({
    required int idTool,
    required String cashierCode,
    required String spvTLCode,
    required String tableCode,
    String? dateStart,
    String warehouseCode = "Cideng",
  }) async {
    try {
      final requestHeaders = await headers;
      
      // Make sure idTool is properly formatted as integer
      int idToolAsInt;
      try {
        if (idTool is String) {
          idToolAsInt = int.parse(idTool.toString());
        } else {
          idToolAsInt = idTool;
        }
      } catch (e) {
        debugPrint('❌ Error converting idTool to int: $e');
        idToolAsInt = 0;
      }
      
      final requestBody = {
        "IdTool": idToolAsInt,
        "CashierCode": cashierCode,
        "CashierCode2": "", // Kosongkan sesuai requirement
        "TableCode": tableCode,
        "DateStart": dateStart ?? DateTime.now().toIso8601String(),
        "WarehouseCode": warehouseCode,
        "SpvTLCode": spvTLCode,
        "IsManual": "N"
      };
      
      debugPrint('🔍 Planning update request: ${json.encode(requestBody)}');
      debugPrint('🔍 Headers: $requestHeaders');
      
      final response = await _debugHttp(
        () => _tryRequestWithFallback(
          requestFn: (baseUrl) => http.post(
            Uri.parse('$baseUrl/CRF/planning/update'),
            headers: requestHeaders,
            body: json.encode(requestBody),
          ),
        ),
        'Update Planning: $idTool'
      );

      if (response.statusCode == 200) {
        try {
          debugPrint('🔍 Raw planning update response: ${response.body.substring(0, math.min(300, response.body.length))}...');
          
          final jsonData = json.decode(response.body);
          
          // Normalize response for consistent access
          Map<String, dynamic> normalizedJson = {};
          if (jsonData is Map<String, dynamic>) {
            jsonData.forEach((key, value) {
              normalizedJson[key.toLowerCase()] = value;
            });
          } else {
            debugPrint('❌ Unexpected response format: ${jsonData.runtimeType}');
            return ApiResponse(
              success: false,
              message: 'Format respons server tidak valid',
              status: 'error'
            );
          }
          
          // Process response
          bool isSuccess = false;
          String message = '';
          
          if (normalizedJson.containsKey('success')) {
            isSuccess = normalizedJson['success'] == true;
          } else if (normalizedJson.containsKey('status')) {
            isSuccess = normalizedJson['status'].toString().toLowerCase() == 'success';
          }
          
          if (normalizedJson.containsKey('message')) {
            message = normalizedJson['message'].toString();
          }
          
          // Check for data field containing nested responses
          if (normalizedJson.containsKey('data')) {
            var dataValue = normalizedJson['data'];
            debugPrint('🔍 Data value type: ${dataValue.runtimeType}');
            
            // Handle string representation of data
            if (dataValue is String) {
              try {
                final dataJson = json.decode(dataValue);
                debugPrint('🔍 Parsed data JSON: $dataJson');
                
                if (dataJson is List && dataJson.isNotEmpty) {
                  final firstItem = dataJson[0];
                  if (firstItem is Map<String, dynamic>) {
                    // Normalize keys
                    Map<String, dynamic> normalizedData = {};
                    firstItem.forEach((key, value) {
                      normalizedData[key.toLowerCase()] = value;
                    });
                    
                    // Check for status and message in the nested data
                    if (normalizedData.containsKey('status')) {
                      isSuccess = normalizedData['status'].toString().toLowerCase() == 'success';
                      
                      if (normalizedData.containsKey('message')) {
                        message = normalizedData['message'].toString();
                      }
                    }
                  }
                }
              } catch (e) {
                debugPrint('❌ Error parsing data JSON: $e');
              }
            } else if (dataValue is List && dataValue.isNotEmpty) {
              final firstItem = dataValue[0];
              if (firstItem is Map<String, dynamic>) {
                // Normalize keys
                Map<String, dynamic> normalizedData = {};
                firstItem.forEach((key, value) {
                  normalizedData[key.toLowerCase()] = value;
                });
                
                // Check for status and message in the nested data
                if (normalizedData.containsKey('status')) {
                  isSuccess = normalizedData['status'].toString().toLowerCase() == 'success';
                  
                  if (normalizedData.containsKey('message')) {
                    message = normalizedData['message'].toString();
                  }
                }
              }
            }
          }
          
          debugPrint('🔍 Final result: success=$isSuccess, message=$message');
          
          // Construct final response
          ApiResponse finalResponse = ApiResponse(
            success: isSuccess,
            message: message.isNotEmpty ? message : (isSuccess ? 'Planning berhasil diupdate' : 'Planning gagal diupdate'),
            status: isSuccess ? 'success' : 'error',
            data: normalizedJson['data']
          );
          
          debugPrint('🔍 API Response: success=${finalResponse.success}, message=${finalResponse.message}');
          
          return finalResponse;
        } catch (e) {
          debugPrint('❌ Error parsing planning update JSON: $e');
          return ApiResponse(
            success: false,
            message: 'Format data dari server tidak valid: ${e.toString()}',
            status: 'error'
          );
        }
      } else if (response.statusCode == 500) {
        debugPrint('❌ Server error (500): ${response.body}');
        
        // Try to extract the error message from the response
        String errorMessage = 'Server error (500)';
        try {
          final errorJson = json.decode(response.body);
          if (errorJson is Map<String, dynamic> && errorJson.containsKey('message')) {
            errorMessage = errorJson['message'].toString();
          } else if (errorJson is Map<String, dynamic> && errorJson.containsKey('error')) {
            errorMessage = errorJson['error'].toString();
          }
        } catch (e) {
          // If parsing fails, use a generic message with the response body
          errorMessage = 'Server error (500): ${response.body.length > 100 ? response.body.substring(0, 100) : response.body}';
        }
        
        return ApiResponse(
          success: false,
          message: errorMessage,
          status: 'error'
        );
      } else if (response.statusCode == 401) {
        debugPrint('❌ 401 Unauthorized! Forcing logout...');
        await _authService.logout();
        return ApiResponse(
          success: false,
          message: 'Session expired: Please login again',
          status: 'error'
        );
      } else {
        debugPrint('❌ HTTP error: ${response.statusCode}, body: ${response.body}');
        return ApiResponse(
          success: false,
          message: 'Server error (${response.statusCode}): ${response.body}',
          status: 'error'
        );
      }
    } catch (e) {
      debugPrint('❌ Planning update API error: $e');
      
      String errorMessage = 'Network error: ${e.toString()}';
      if (e is TimeoutException) {
        errorMessage = 'Connection timeout: Please check your internet connection';
      }
      
      return ApiResponse(
        success: false,
        message: errorMessage,
        status: 'error'
      );
    }
  }

  Future<PrepareConfirmationResponse> getPrepareConfirmation(int idTool) async {
    try {
      final requestHeaders = await headers;
      final response = await _tryRequestWithFallback(
        requestFn: (baseUrl) => http.get(
          Uri.parse('$baseUrl/CRF/prepare/confirmation/$idTool'),
          headers: requestHeaders,
        ),
      );
      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          return PrepareConfirmationResponse.fromJson(jsonData);
        } catch (e) {
          return PrepareConfirmationResponse(success: false, message: 'Invalid data', data: null);
        }
      } else if (response.statusCode == 401) {
        await _authService.logout();
        return PrepareConfirmationResponse(success: false, message: 'Session expired', data: null);
      } else {
        return PrepareConfirmationResponse(success: false, message: 'Server error (${response.statusCode})', data: null);
      }
    } catch (e) {
      return PrepareConfirmationResponse(success: false, message: e.toString(), data: null);
    }
  }

  // Insert ATM Catridge API
  Future<ApiResponse> insertAtmCatridge({
    required int idTool,
    required String bagCode,
    required String catridgeCode,
    required String sealCode,
    required String catridgeSeal,
    required String denomCode,
    required String qty,
    required String userInput,
    required String sealReturn,
    String scanCatStatus = "",
    String scanCatStatusRemark = "",
    String scanSealStatus = "",
    String scanSealStatusRemark = "",
    String difCatAlasan = "",
    String difCatRemark = "",
    String typeCatridgeTrx = "C", // Default to 'C' for backward compatibility
  }) async {
    try {
      final requestHeaders = await headers;

      String normalizeDenomCode(String input) {
        final trimmed = input.trim();
        if (trimmed.isEmpty) return '0';

        final upper = trimmed.toUpperCase();
        if (RegExp(r'^A\d+$').hasMatch(upper)) return upper;

        final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isEmpty) return trimmed;

        final numeric = int.tryParse(digits);
        if (numeric == null) return trimmed;
        if (numeric <= 0) return '0';
        if (numeric >= 1000 && numeric % 1000 == 0) {
          return 'A${numeric ~/ 1000}';
        }
        return 'A$numeric';
      }
      
      // Make sure idTool is properly formatted as integer
      int idToolAsInt;
      try {
        if (idTool is String) {
          idToolAsInt = int.parse(idTool.toString());
        } else {
          idToolAsInt = idTool;
        }
      } catch (e) {
        debugPrint('❌ Error converting idTool to int: $e');
        idToolAsInt = 0;
      }

      final normalizedDenomCode = normalizeDenomCode(denomCode);
      
      // IMPORTANT: Create request body WITHOUT the InsertedId field
      // This is to prevent the "Column 'InsertedId' does not belong to table" error
      final requestBody = {
        "IdTool": idToolAsInt,
        "BagCode": bagCode.isEmpty ? "0" : bagCode,
        "CatridgeCode": catridgeCode.isEmpty ? "0" : catridgeCode,
        "SealCode": sealCode.isEmpty ? "0" : sealCode,
        "CatridgeSeal": catridgeSeal.isEmpty ? "0" : catridgeSeal,
        "DenomCode": normalizedDenomCode,
        "Qty": qty,
        "UserInput": userInput,
        "SealReturn": sealReturn.isEmpty ? "0" : sealReturn,
        "ScanCatStatus": scanCatStatus.isEmpty ? null : scanCatStatus,
        "ScanCatStatusRemark": scanCatStatusRemark.isEmpty ? null : scanCatStatusRemark,
        "ScanSealStatus": scanSealStatus.isEmpty ? null : scanSealStatus,
        "ScanSealStatusRemark": scanSealStatusRemark.isEmpty ? null : scanSealStatusRemark,
        "DifCatAlasan": difCatAlasan,
        "DifCatRemark": difCatRemark,
        "TypeCatridgeTrx": typeCatridgeTrx,
      };
      
      debugPrint('🔍 ATM Catridge insert request: ${json.encode(requestBody)}');
      debugPrint('🔍 Headers: $requestHeaders');
      
      // Langsung gunakan endpoint utama (tidak perlu alternate endpoint)
      debugPrint('🔍 Menggunakan endpoint utama untuk insert catridge');
      final response = await _debugHttp(
        () => _tryRequestWithFallback(
          requestFn: (baseUrl) => http.post(
            Uri.parse('$baseUrl/CRF/atm/catridge/temp'),
            headers: requestHeaders,
            body: json.encode(requestBody),
          ),
        ),
        'Insert ATM Catridge: $catridgeCode'
      );

      if (response.statusCode == 200) {
        try {
          debugPrint('🔍 Raw response: ${response.body.substring(0, math.min(300, response.body.length))}...');
          
          final jsonData = json.decode(response.body);
          
          // Check for server-side errors returned with status 200
          if (jsonData is Map<String, dynamic>) {
            Map<String, dynamic> normalizedJson = {};
            jsonData.forEach((key, value) {
              normalizedJson[key.toLowerCase()] = value;
            });
            
            // Tidak perlu lagi menangani error InsertedId karena sudah ditangani di SP dan API
            
            // Process normal response
            bool isSuccess = false;
            String message = '';
            
            if (normalizedJson.containsKey('success')) {
              isSuccess = normalizedJson['success'] == true;
            } else if (normalizedJson.containsKey('status')) {
              isSuccess = normalizedJson['status'].toString().toLowerCase() == 'success';
            }
            
            if (normalizedJson.containsKey('message')) {
              message = normalizedJson['message'].toString();
            }
            
            // Check for data field containing nested responses
            if (normalizedJson.containsKey('data')) {
              var dataValue = normalizedJson['data'];
              debugPrint('🔍 Data value type: ${dataValue.runtimeType}');
              
              // Handle string representation of data
              if (dataValue is String) {
                try {
                  final dataJson = json.decode(dataValue);
                  debugPrint('🔍 Parsed data JSON: $dataJson');
                  
                  if (dataJson is List && dataJson.isNotEmpty) {
                    final firstItem = dataJson[0];
                    if (firstItem is Map<String, dynamic>) {
                      // Normalize keys
                      Map<String, dynamic> normalizedData = {};
                      firstItem.forEach((key, value) {
                        normalizedData[key.toLowerCase()] = value;
                      });
                      
                      // Check for status and message in the nested data
                      if (normalizedData.containsKey('status')) {
                        isSuccess = normalizedData['status'].toString().toLowerCase() == 'success';
                        
                        if (normalizedData.containsKey('message')) {
                          message = normalizedData['message'].toString();
                        }
                      }
                    }
                  }
                } catch (e) {
                  debugPrint('❌ Error parsing data JSON: $e');
                }
              } else if (dataValue is List && dataValue.isNotEmpty) {
                final firstItem = dataValue[0];
                if (firstItem is Map<String, dynamic>) {
                  // Normalize keys
                  Map<String, dynamic> normalizedData = {};
                  firstItem.forEach((key, value) {
                    normalizedData[key.toLowerCase()] = value;
                  });
                  
                  // Check for status and message in the nested data
                  if (normalizedData.containsKey('status')) {
                    isSuccess = normalizedData['status'].toString().toLowerCase() == 'success';
                    
                    if (normalizedData.containsKey('message')) {
                      message = normalizedData['message'].toString();
                    }
                  }
                }
              }
            }
            
            debugPrint('🔍 Final result: success=$isSuccess, message=$message');
            
            // Construct final response (WITHOUT insertedId to avoid the issue)
            ApiResponse finalResponse = ApiResponse(
              success: isSuccess,
              message: message.isNotEmpty ? message : (isSuccess ? 'Catridge berhasil disimpan' : 'Catridge gagal disimpan'),
              status: isSuccess ? 'success' : 'error',
              data: normalizedJson['data']
              // Explicitly NOT including insertedId field here
            );
            
            debugPrint('🔍 API Response: success=${finalResponse.success}, message=${finalResponse.message}');
            
            return finalResponse;
          } else {
            debugPrint('❌ Unexpected response format: ${jsonData.runtimeType}');
            return ApiResponse(
              success: false,
              message: 'Format respons server tidak valid',
              status: 'error'
            );
          }
        } catch (e) {
          debugPrint('❌ Error parsing ATM catridge insert JSON: $e');
          return ApiResponse(
            success: false,
            message: 'Format data dari server tidak valid: ${e.toString()}',
            status: 'error'
          );
        }
      } else if (response.statusCode == 500) {
        debugPrint('❌ Server error (500): ${response.body}');
        
        // Try to extract the error message from the response
        String errorMessage = 'Server error (500)';
        try {
          final errorJson = json.decode(response.body);
          if (errorJson is Map<String, dynamic> && errorJson.containsKey('message')) {
            errorMessage = errorJson['message'].toString();
          } else if (errorJson is Map<String, dynamic> && errorJson.containsKey('error')) {
            errorMessage = errorJson['error'].toString();
          }
        } catch (e) {
          // yang 
          errorMessage = 'Server error (500): ${response.body.length > 100 ? response.body.substring(0, 100) : response.body}';
        }
        
        return ApiResponse(
          success: false,
          message: errorMessage,
          status: 'error'
        );
      } else if (response.statusCode == 401) {
        debugPrint('❌ 401 Unauthorized! Forcing logout...');
        await _authService.logout();
        return ApiResponse(
          success: false,
          message: 'Session expired: Please login again',
          status: 'error'
        );
      } else {
        debugPrint('❌ HTTP error: ${response.statusCode}, body: ${response.body}');
        return ApiResponse(
          success: false,
          message: 'Server error (${response.statusCode}): ${response.body}',
          status: 'error'
        );
      }
    } catch (e) {
      debugPrint('❌ ATM Catridge insert API error: $e');
      
      String errorMessage = 'Network error: ${e.toString()}';
      if (e is TimeoutException) {
        errorMessage = 'Connection timeout: Please check your internet connection';
      }
      
      return ApiResponse(
        success: false,
        message: errorMessage,
        status: 'error'
      );
    }
  }

  Future<ApiResponse> insertAtmCatridgeByIdTool({
    required int idTool,
  }) async {
    final requestHeaders = await headers;
    final requestBody = { "IdTool": idTool };

    final response = await _tryRequestWithFallback(
      requestFn: (baseUrl) => http.post(
        Uri.parse('$baseUrl/CRF/atm/catridge/execute'),
        headers: requestHeaders,
        body: json.encode(requestBody),
      ),
    );

    if (response.statusCode == 200) {
      try {
        final jsonData = json.decode(response.body);
        bool success = jsonData is Map<String, dynamic> && (jsonData['success'] == true);
        String message = (jsonData is Map<String, dynamic> && jsonData['message'] != null)
            ? jsonData['message'].toString()
            : '';
        final data = (jsonData is Map<String, dynamic>) ? jsonData['data'] : null;
        String status = '';
        if (data is Map<String, dynamic> && data['status'] != null) {
          status = data['status'].toString();
        }
        return ApiResponse(success: success, message: message, data: data, status: status);
      } catch (e) {
        debugPrint('Error parsing execute catridge JSON: $e');
        throw Exception('Invalid data format from server');
      }
    } else if (response.statusCode == 401) {
      await _authService.logout();
      throw Exception('Session expired: Please login again');
    } else {
      throw Exception('Server error (${response.statusCode}): ${response.body}');
    }
  }

  // Validate TL Supervisor for approval
  Future<TLSupervisorValidationResponse> validateTLSupervisor({
    required String nik,
    required String password,
  }) async {
    try {
      final requestHeaders = await headers;
      
      final requestBody = {
        "NIK": nik,
        "Password": password,
      };
      
      print('TL Supervisor validation request: ${json.encode(requestBody)}');
      
      final response = await _tryRequestWithFallback(
        requestFn: (baseUrl) => http.post(
          Uri.parse('$baseUrl/CRF/validate/tl-supervisor'),
          headers: requestHeaders,
          body: json.encode(requestBody),
        ),
      );

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          print('TL Supervisor validation response: ${response.body}');
          return TLSupervisorValidationResponse.fromJson(jsonData);
        } catch (e) {
          debugPrint('Error parsing TL supervisor validation JSON: $e');
          throw Exception('Invalid TL supervisor validation data format from server');
        }
      } else if (response.statusCode == 401) {
        await _authService.logout();
        throw Exception('Session expired: Please login again');
      } else {
        throw Exception('Server error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('TL Supervisor validation API error: $e');
      if (e is TimeoutException) {
        throw Exception('Connection timeout: Please check your internet connection');
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Get Return Header and Catridge data by ID
  Future<ReturnHeaderResponse> getReturnHeaderAndCatridge(String idTool, {String branchCode = "0"}) async {
    try {
      final requestHeaders = await headers;
      
      final response = await _tryRequestWithFallback(
        requestFn: (baseUrl) => http.get(
          Uri.parse('$baseUrl/CRF/return/header-and-catridge/$idTool?branchCode=$branchCode'),
          headers: requestHeaders,
        ),
      );

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          print('Return header response: ${response.body}');
          
          // Debug: Log the structure of the response
          print('DEBUG API Response Structure:');
          print('- success: ${jsonData['success']}');
          print('- message: ${jsonData['message']}');
          print('- data type: ${jsonData['data'].runtimeType}');
          
          if (jsonData['data'] != null) {
            if (jsonData['data'] is Map) {
              print('- data is Map with keys: ${(jsonData['data'] as Map).keys.toList()}');
              if (jsonData['data']['catridges'] != null) {
                print('- catridges type: ${jsonData['data']['catridges'].runtimeType}');
                if (jsonData['data']['catridges'] is List) {
                  final catridges = jsonData['data']['catridges'] as List;
                  print('- catridges length: ${catridges.length}');
                  for (int i = 0; i < catridges.length && i < 2; i++) {
                    print('- catridge[$i]: ${catridges[i]}');
                    if (catridges[i] is Map) {
                      final catridge = catridges[i] as Map;
                      print('  - typeCatridgeTrx: ${catridge['typeCatridgeTrx']} (type: ${catridge['typeCatridgeTrx'].runtimeType})');
                    }
                  }
                }
              }
            } else if (jsonData['data'] is List) {
              print('- data is List with length: ${(jsonData['data'] as List).length}');
            }
          }
          
          // Handle business validation errors that come with 200 status
          if (jsonData['success'] == false) {
            return ReturnHeaderResponse(
              success: false,
              message: jsonData['message'] ?? 'Terjadi kesalahan',
              header: null,
              data: [],
            );
          }
          
          return ReturnHeaderResponse.fromJson(jsonData);
        } catch (e) {
          debugPrint('Error parsing return header JSON: $e');
          return ReturnHeaderResponse(
            success: false,
            message: 'Format data tidak valid: ${e.toString()}',
            header: null,
            data: [],
          );
        }
      } else if (response.statusCode == 401) {
        await _authService.logout();
        return ReturnHeaderResponse(
          success: false,
          message: 'Sesi telah berakhir. Silakan login kembali.',
          header: null,
          data: [],
        );
      } else {
        String errorMessage = 'Terjadi kesalahan server';
        try {
          final errorJson = json.decode(response.body);
          errorMessage = errorJson['message'] ?? errorMessage;
        } catch (_) {}
        
        return ReturnHeaderResponse(
          success: false,
          message: '$errorMessage (${response.statusCode})',
          header: null,
          data: [],
        );
      }
    } catch (e) {
      debugPrint('Return header API error: $e');
      String errorMessage = 'Terjadi kesalahan jaringan';
      
      if (e.toString().contains('serah terima pulang')) {
        errorMessage = 'Trip ini belum melakukan serah terima pulang. Silakan selesaikan proses serah terima di menu CPC terlebih dahulu.';
      } else if (e is TimeoutException) {
        errorMessage = 'Koneksi timeout. Silakan periksa koneksi internet Anda.';
      }
      
      return ReturnHeaderResponse(
        success: false,
        message: errorMessage,
        header: null,
        data: [],
      );
    }
  }
  
  // Update Planning RTN for TL approval
  Future<ApiResponse> updatePlanningRTN(Map<String, dynamic> parameters) async {
    try {
      final requestHeaders = await headers;
      
      // Format date parameters properly
      if (parameters.containsKey('DateStartReturn') && parameters['DateStartReturn'] is String) {
        // Make sure it's in a format the API can understand
        final dateStr = parameters['DateStartReturn'];
        try {
          final date = DateTime.parse(dateStr);
          parameters['DateStartReturn'] = date.toIso8601String();
        } catch (e) {
          // Keep original if parsing fails
        }
      }
      
      // Ensure idTool is numeric
      if (parameters.containsKey('idTool')) {
        try {
          final idTool = int.tryParse(parameters['idTool'].toString());
          if (idTool != null) {
            parameters['idTool'] = idTool;
          }
        } catch (e) {
          // Keep as is if parsing fails
        }
      }
      
      print('Update Planning RTN request: ${json.encode(parameters)}');
      
      final response = await _tryRequestWithFallback(
        requestFn: (baseUrl) => http.post(
          Uri.parse('$baseUrl/CRF/rtn/planning/update'),
          headers: requestHeaders,
          body: json.encode(parameters),
        ),
      );

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          print('Update Planning RTN response: ${response.body}');
          return ApiResponse.fromJson(jsonData);
        } catch (e) {
          debugPrint('Error parsing update planning RTN JSON: $e');
          return ApiResponse(
            success: false,
            message: 'Invalid update planning RTN data format from server',
            status: 'error'
          );
        }
      } else if (response.statusCode == 401) {
        await _authService.logout();
        return ApiResponse(
          success: false,
          message: 'Session expired: Please login again',
          status: 'error'
        );
      } else {
        String errorMessage = 'Server error (${response.statusCode})';
        try {
          final errorJson = json.decode(response.body);
          errorMessage = errorJson['message'] ?? errorMessage;
        } catch (_) {}
        
        return ApiResponse(
          success: false,
          message: errorMessage,
          status: 'error'
        );
      }
    } catch (e) {
      debugPrint('Update Planning RTN API error: $e');
      return ApiResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
        status: 'error'
      );
    }
  }

  // Validate Return Catridge using RTN_SP_ReturnCatridge
  Future<ReturnCatridgeValidationResponse> validateReturnCatridge({
    required String idTool,
    String branchCode = "0",
  }) async {
    try {
      final requestHeaders = await headers;
      
      // Build query parameters
      final queryParams = <String, String>{
        'idTool': idTool,
        'branchCode': branchCode,
      };
      
      final response = await _tryRequestWithFallback(
        requestFn: (baseUrl) => http.get(
          Uri.parse('$baseUrl/CRF/rtn/return/catridge').replace(queryParameters: queryParams),
          headers: requestHeaders,
        ),
      );

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          return ReturnCatridgeValidationResponse.fromJson(jsonData);
        } catch (e) {
          debugPrint('Error parsing Return Catridge validation JSON: $e');
          return ReturnCatridgeValidationResponse(
            success: false,
            message: 'Invalid data format from server',
            data: null,
          );
        }
      } else if (response.statusCode == 401) {
        await _authService.logout();
        return ReturnCatridgeValidationResponse(
          success: false,
          message: 'Session expired: Please login again',
          data: null,
        );
      } else {
        return ReturnCatridgeValidationResponse(
          success: false,
          message: 'Server error (${response.statusCode}): ${response.body}',
          data: null,
        );
      }
    } catch (e) {
      debugPrint('Return Catridge validation API error: $e');
      
      String errorMessage = 'Network error: ${e.toString()}';
      if (e is TimeoutException) {
        errorMessage = 'Connection timeout: Please check your internet connection';
      }
      
      return ReturnCatridgeValidationResponse(
        success: false,
        message: errorMessage,
        data: null,
      );
    }
  }
  
  // Get Catridge Replenish data using RTN_SP_CatridgeReplenish
  Future<CatridgeReplenishResponse> getCatridgeReplenish(String catridge) async {
    try {
      final requestHeaders = await headers;
      
      final response = await _tryRequestWithFallback(
        requestFn: (baseUrl) => http.get(
          Uri.parse('$baseUrl/CRF/rtn/catridge/replenish/$catridge'),
          headers: requestHeaders,
        ),
      );

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          return CatridgeReplenishResponse.fromJson(jsonData);
        } catch (e) {
          debugPrint('Error parsing Catridge Replenish JSON: $e');
          return CatridgeReplenishResponse(
            success: false,
            message: 'Invalid data format from server',
            data: [],
          );
        }
      } else if (response.statusCode == 401) {
        await _authService.logout();
        return CatridgeReplenishResponse(
          success: false,
          message: 'Session expired: Please login again',
          data: [],
        );
      } else {
        return CatridgeReplenishResponse(
          success: false,
          message: 'Server error (${response.statusCode}): ${response.body}',
          data: [],
        );
      }
    } catch (e) {
      debugPrint('Catridge Replenish API error: $e');
      
      String errorMessage = 'Network error: ${e.toString()}';
      if (e is TimeoutException) {
        errorMessage = 'Connection timeout: Please check your internet connection';
      }
      
      return CatridgeReplenishResponse(
        success: false,
        message: errorMessage,
        data: [],
      );
    }
  }
  
  // Validate and Get Replenish in one call
  Future<ValidateAndGetReplenishResponse> validateAndGetReplenish({
    required String idTool,
    String catridgeCode = "",
    String branchCode = "0",
  }) async {
    try {
      final numericBranchCode = await _resolveBranchCode(branchCode);
      print('validateAndGetReplenish: Using numeric branch code: $numericBranchCode');
      
      final requestHeaders = await headers;
      
      // Build query parameters with proper URI encoding
      final uri = Uri.parse('$_currentBaseUrl/CRF/rtn/validate-and-get-replenish');
      
      // Prepare query parameters
      final queryParams = <String, String>{
        'idtool': idTool,
        'branchCode': numericBranchCode,
      };
      
      if (catridgeCode.isNotEmpty) {
        queryParams['catridgeCode'] = catridgeCode;
      }
      
      // Log request for debugging
      debugPrint('validateAndGetReplenish: $queryParams');
      
      final response = await _tryRequestWithFallback(
        requestFn: (baseUrl) {
          final baseUri = Uri.parse('$baseUrl/CRF/rtn/validate-and-get-replenish')
              .replace(queryParameters: queryParams);
          return http.get(baseUri, headers: requestHeaders);
        },
      );

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          
          // Debug: Log the response structure for validateAndGetReplenish
          print('DEBUG validateAndGetReplenish Response:');
          print('- success: ${jsonData['success']}');
          print('- message: ${jsonData['message']}');
          if (jsonData['data'] != null && jsonData['data']['catridges'] != null) {
            final catridges = jsonData['data']['catridges'] as List;
            print('- catridges length: ${catridges.length}');
            for (int i = 0; i < catridges.length && i < 2; i++) {
              print('- catridge[$i]: ${catridges[i]}');
              if (catridges[i] is Map) {
                final catridge = catridges[i] as Map;
                print('  - typeCatridgeTrx: "${catridge['typeCatridgeTrx']}" (type: ${catridge['typeCatridgeTrx'].runtimeType})');
              }
            }
          }
          
          return ValidateAndGetReplenishResponse.fromJson(jsonData);
        } catch (e) {
          debugPrint('Error parsing ValidateAndGetReplenish JSON: $e');
          return ValidateAndGetReplenishResponse(
            success: false,
            message: 'Invalid data format from server',
            data: null,
          );
        }
      } else if (response.statusCode == 401) {
        await _authService.logout();
        return ValidateAndGetReplenishResponse(
          success: false,
          message: 'Session expired: Please login again',
          data: null,
        );
      } else {
        return ValidateAndGetReplenishResponse(
          success: false,
          message: 'Server error (${response.statusCode}): ${response.body}',
          data: null,
        );
      }
    } catch (e) {
      debugPrint('ValidateAndGetReplenish API error: $e');
      
      String errorMessage = 'Network error: ${e.toString()}';
      if (e is TimeoutException) {
        errorMessage = 'Connection timeout: Please check your internet connection';
      }
      
      return ValidateAndGetReplenishResponse(
        success: false,
        message: errorMessage,
        data: null,
      );
    }
  }

  // Validate and get replenish data in one call
  Future<Map<String, dynamic>> validateAndGetReplenishRaw(String idTool, String branchCode, {String? catridgeCode}) async {
    try {
      // Ensure branchCode is numeric
      String numericBranchCode = branchCode;
      if (branchCode.isEmpty || !RegExp(r'^\d+$').hasMatch(branchCode)) {
        numericBranchCode = '1'; // Default to '1' if not numeric
        debugPrint('🔍 WARNING: Branch code is not numeric: "$branchCode", using default: $numericBranchCode');
      } else {
        debugPrint('🔍 Using numeric branch code: $numericBranchCode');
      }
      
      // Check authentication status first
      await checkAndRefreshAuth();
      
      // APPROACH 5: Original implementation with auth
      debugPrint('🔍 Trying implementation with auth...');
      final requestHeaders = await headers;
      
      // Use Uri class properly for query parameters instead of manual URL construction
      final uri = Uri.parse('$_currentBaseUrl/CRF/rtn/validate-and-get-replenish');
      
      // Construct the query parameters with proper encoding
      final queryParams = {
        'idtool': idTool,
        'branchCode': numericBranchCode,
      };
      
      // Add catridgeCode parameter only if it's not null and not empty
      if (catridgeCode != null && catridgeCode.trim().isNotEmpty) {
        queryParams['catridgeCode'] = catridgeCode;
        debugPrint('🔍 Including catridgeCode in request: $catridgeCode');
      } else {
        debugPrint('🔍 catridgeCode is empty or null, excluding from request');
      }
      
      // Log the request details for debugging
      debugPrint('🔍 Request: GET ${uri.path}');
      debugPrint('🔍 Parameters: $queryParams');
      debugPrint('🔍 Headers: ${requestHeaders.toString()}');
      
      // Create URI with query parameters
      final requestUri = uri.replace(queryParameters: queryParams);
      debugPrint('🔍 Full URL: ${requestUri.toString()}');
      
      final response = await _debugHttp(
        () => _tryRequestWithFallback(
          requestFn: (baseUrl) {
            final uri = Uri.parse('$baseUrl/CRF/rtn/validate-and-get-replenish')
                .replace(queryParameters: queryParams);
            return http.get(uri, headers: requestHeaders);
          },
        ),
        'Validate and Get Replenish: $idTool'
      );
      
      if (response.statusCode == 200) {
        try {
          debugPrint('🔍 Raw response: ${response.body.substring(0, math.min(300, response.body.length))}...');
          
          final jsonData = json.decode(response.body);
          
          // Normalize response for consistent access
          if (jsonData is Map<String, dynamic>) {
            Map<String, dynamic> normalizedJson = {};
            jsonData.forEach((key, value) {
              normalizedJson[key.toLowerCase()] = value;
            });
            
            // Extract success and message for easier debugging
            bool isSuccess = false;
            String message = '';
            
            if (normalizedJson.containsKey('success')) {
              isSuccess = normalizedJson['success'] == true;
            }
            
            if (normalizedJson.containsKey('message')) {
              message = normalizedJson['message'].toString();
            }
            
            debugPrint('🔍 Parsed response: success=$isSuccess, message=$message');
            
            // Always return the original JSON for backward compatibility
            return jsonData;
          } else {
            debugPrint('❌ Unexpected response format: ${jsonData.runtimeType}');
            return {
              'success': false,
              'message': 'Unexpected response format',
              'data': null
            };
          }
        } catch (e) {
          debugPrint('❌ Error parsing response: $e');
          return {
            'success': false,
            'message': 'Error parsing response: ${e.toString()}',
            'data': null
          };
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ 401 Unauthorized!');
        await _authService.logout();
        return {
          'success': false,
          'message': 'Session expired: Please login again',
          'data': null
        };
      } else {
        debugPrint('❌ Error response: ${response.statusCode}, ${response.body}');
        return {
          'success': false,
          'message': 'Server error (${response.statusCode}): ${response.body}',
          'data': null
        };
      }
    } catch (e) {
      debugPrint('❌ API error: $e');
      if (e is TimeoutException) {
        return {
          'success': false,
          'message': 'Connection timeout: Please check your internet connection',
          'data': null
        };
      }
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': null
      };
    }
  }

  // Try API call using Dio instead of http
  Future<Map<String, dynamic>> tryWithDio(String idTool, String branchCode, {String? catridgeCode}) async {
    try {
      // Ensure branchCode is numeric
      String numericBranchCode = branchCode;
      if (branchCode.isEmpty || !RegExp(r'^\d+$').hasMatch(branchCode)) {
        numericBranchCode = '1'; // Default to '1' if not numeric
        print('Dio: Branch code is not numeric: "$branchCode", using default: $numericBranchCode');
      }
      
      final dio = Dio();
      
      // Set timeout
      dio.options.connectTimeout = const Duration(seconds: 10);
      dio.options.receiveTimeout = const Duration(seconds: 10);
      
      // Get auth token
      final token = await _authService.getToken();
      
      // Set headers
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      // Add auth token if available
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      // Prepare query parameters
      final queryParams = {
        'idtool': idTool,
        'branchCode': numericBranchCode,
      };
      
      if (catridgeCode != null && catridgeCode.trim().isNotEmpty) {
        queryParams['catridgeCode'] = catridgeCode;
      }
      
      // Log request details
      debugPrint('Dio request to: $_currentBaseUrl/CRF/rtn/validate-and-get-replenish');
      debugPrint('Dio params: $queryParams');
      
      // Make request
      final response = await dio.get(
        '$_currentBaseUrl/CRF/rtn/validate-and-get-replenish',
        queryParameters: queryParams,
        options: Options(headers: headers),
      );
      
      // Log response
      debugPrint('Dio response status: ${response.statusCode}');
      
      // Parse response
      if (response.statusCode == 200) {
        return response.data;
      } else {
        return {
          'success': false,
          'message': 'Server error (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('Dio error: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Try API call with parameters in URL path
  Future<Map<String, dynamic>> tryWithPathParams(String idTool, String branchCode, {String? catridgeCode}) async {
    try {
      // Ensure branchCode is numeric
      String numericBranchCode = branchCode;
      if (branchCode.isEmpty || !RegExp(r'^\d+$').hasMatch(branchCode)) {
        numericBranchCode = '1'; // Default to '1' if not numeric
        print('PathParams: Branch code is not numeric: "$branchCode", using default: $numericBranchCode');
      }
      
      // Build URL with parameters in path
      String url = 'https://dev.advantagescm.com/LocalCRF/api/CRF/rtn/validate-and-get-replenish/$idTool/$numericBranchCode';
      if (catridgeCode != null && catridgeCode.trim().isNotEmpty) {
        url += '/$catridgeCode';
      }
      
      debugPrint('Trying with path parameters: $url');
      
      // Make request
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      // Log response
      debugPrint('Path params response status: ${response.statusCode}');
      
      // Parse response
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData;
      } else {
        return {
          'success': false,
          'message': 'Server error (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('Path params error: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Try API call with POST instead of GET
  Future<Map<String, dynamic>> tryWithPost(String idTool, String branchCode, {String? catridgeCode}) async {
    try {
      // Ensure branchCode is numeric
      String numericBranchCode = branchCode;
      if (branchCode.isEmpty || !RegExp(r'^\d+$').hasMatch(branchCode)) {
        numericBranchCode = '1'; // Default to '1' if not numeric
        print('POST: Branch code is not numeric: "$branchCode", using default: $numericBranchCode');
      }
      
      // Get auth token
      final token = await _authService.getToken();
      
      // Set headers
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      // Add auth token if available
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      // Prepare request body
      final body = {
        'idtool': idTool,
        'branchCode': numericBranchCode,
      };
      
      if (catridgeCode != null && catridgeCode.trim().isNotEmpty) {
        body['catridgeCode'] = catridgeCode;
      }
      
      // Log request details
      debugPrint('POST request to: $_currentBaseUrl/CRF/rtn/validate-and-get-replenish');
      debugPrint('POST body: $body');
      
      // Make request
      final response = await http.post(
        Uri.parse('$_currentBaseUrl/CRF/rtn/validate-and-get-replenish'),
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));
      
      // Log response
      debugPrint('POST response status: ${response.statusCode}');
      
      // Parse response
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData;
      } else {
        return {
          'success': false,
          'message': 'Server error (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('POST error: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Enhanced method to check token expiry and handle auto-logout
  Future<bool> checkTokenExpiryAndLogout() async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('🚨 No token found - triggering logout');
        await _handleSessionExpired();
        return false;
      }
      
      // Check if token is expired by trying to decode it
      try {
        final parts = token.split('.');
        if (parts.length != 3) {
          debugPrint('🚨 Invalid token format - triggering logout');
          await _handleSessionExpired();
          return false;
        }
        
        // Decode payload
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final Map<String, dynamic> data = json.decode(decoded);
        
        // Check exp claim
        if (data.containsKey('exp')) {
          final exp = data['exp'];
          final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
          final now = DateTime.now();
          
          if (expDate.isBefore(now)) {
            debugPrint('🚨 Token expired - triggering logout');
            await _handleSessionExpired();
            return false;
          }
        }
        
        debugPrint('✅ Token is valid');
        return true;
      } catch (e) {
        debugPrint('🚨 Error checking token - triggering logout: $e');
        await _handleSessionExpired();
        return false;
      }
    } catch (e) {
      debugPrint('🚨 Error in checkTokenExpiryAndLogout - triggering logout: $e');
      await _handleSessionExpired();
      return false;
    }
  }

  // Check authentication status and refresh token if needed
  Future<bool> checkAndRefreshAuth() async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('No authentication token found');
        return false;
      }
      
      // Check if token is expired by trying to decode it
      try {
        // Simple check - not full JWT validation
        final parts = token.split('.');
        if (parts.length != 3) {
          debugPrint('Invalid token format');
          return false;
        }
        
        // Decode payload
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final Map<String, dynamic> data = json.decode(decoded);
        
        // Check exp claim
        if (data.containsKey('exp')) {
          final exp = data['exp'];
          final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
          final now = DateTime.now();
          
          if (expDate.isBefore(now)) {
            debugPrint('Token expired, attempting refresh');
            // Try to refresh token
            final refreshResult = await _refreshToken();
            return refreshResult;
          }
        }
        
        debugPrint('Token appears valid');
        return true;
      } catch (e) {
        debugPrint('Error checking token: $e');
        return false;
      }
    } catch (e) {
      debugPrint('Error in checkAndRefreshAuth: $e');
      return false;
    }
  }
  
  // Refresh authentication token
  Future<bool> _refreshToken() async {
    try {
      final requestHeaders = await headers;
      final response = await _tryRequestWithFallback(
        requestFn: (baseUrl) => http.post(
          Uri.parse('$baseUrl/CRF/refresh-token'),
          headers: requestHeaders,
        ),
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final newToken = jsonData['data']['token'];
          await _authService.saveToken(newToken);
          debugPrint('Token refreshed successfully');
          return true;
        }
      }
      
      debugPrint('Failed to refresh token: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      return false;
    }
  }

  // Check if an API response contains a session expired message
  bool _isSessionExpiredResponse(http.Response response) {
    try {
      // First check status code
      if (response.statusCode == 401) {
        return true;
      }
      
      // Then check response body for session expired messages
      final Map<String, dynamic> responseData = json.decode(response.body);
      
      // Check for various forms of session expired messages
      final String message = (responseData['message'] ?? '').toString().toLowerCase();
      
      return message.contains('session expired') || 
             message.contains('sesi berakhir') || 
             message.contains('sesi telah berakhir') ||
             message.contains('login kembali') ||
             message.contains('unauthorized') ||
             message.contains('token expired') ||
             message.contains('token invalid') ||
             message.contains('token not valid');
    } catch (e) {
      // If we can't parse the response, it's not a session expired error
      return false;
    }
  }
  
  // Handle a session expired error with navigation context
  Future<void> _handleSessionExpired([BuildContext? context]) async {
    debugPrint('🚨 SESSION EXPIRED: Logging out and redirecting to login');
    await _authService.logout();
    
    // If context is provided, show modal and navigate
    if (context != null && context.mounted) {
      // Import the CustomModals if not already imported
      try {
        // Show error modal
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Sesi Berakhir'),
              content: const Text('Sesi Anda telah berakhir. Silakan login kembali.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Navigate to login
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                      (Route<dynamic> route) => false,
                    );
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      } catch (e) {
        debugPrint('Error showing session expired dialog: $e');
        // Fallback navigation
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (Route<dynamic> route) => false,
          );
        }
      }
    }
    
    throw Exception('Session expired: Please login again');
  }

  // Debug method to check token validity
  Future<bool> checkTokenValidity() async {
    try {
      final requestHeaders = await headers;
      
      // Check if token is missing
      if (!requestHeaders.containsKey('Authorization') || 
          requestHeaders['Authorization'] == null || 
          requestHeaders['Authorization']!.isEmpty ||
          requestHeaders['Authorization'] == 'Bearer ') {
        debugPrint('🚨 Token is missing or empty');
        return false;
      }
      
      debugPrint('🔍 Checking token validity with headers: ${requestHeaders.toString()}');
      
      // First attempt
      try {
        final response = await _debugHttp(
          () => http.get(
            Uri.parse('$_currentBaseUrl/CRF/validate/seal/Dummy'),
            headers: requestHeaders,
          ).timeout(_timeout),
          'DEBUG Token Validity Check'
        );
        
        // Check status code
        if (_isSessionExpiredResponse(response)) {
          debugPrint('🚨 Token validation failed: Session expired');
          return false;
        }
        
        // Any response other than 401 means token is valid (even if request failed for other reasons)
        debugPrint('✅ Token is valid (Status: ${response.statusCode})');
        return true;
      } catch (e) {
        debugPrint('🚨 Error checking token validity: $e');
        // Try fallback URL
        try {
          final fallbackUrl = (_currentBaseUrl == _primaryBaseUrl) 
              ? _fallbackBaseUrl 
              : _primaryBaseUrl;
              
          final response = await _debugHttp(
            () => http.get(
              Uri.parse('$fallbackUrl/CRF/validate/seal/Dummy'),
              headers: requestHeaders,
            ).timeout(_timeout),
            'DEBUG Token Validity Check (Fallback)'
          );
          
          if (_isSessionExpiredResponse(response)) {
            debugPrint('🚨 Token validation failed (fallback): Session expired');
            return false;
          }
          
          // Any response other than 401 means token is valid
          debugPrint('✅ Token is valid on fallback URL (Status: ${response.statusCode})');
          return true;
        } catch (e2) {
          debugPrint('🚨 Error checking token validity on fallback URL: $e2');
          return false;
        }
      }
    } catch (e) {
      debugPrint('🚨 Error in checkTokenValidity: $e');
      return false;
    }
  }

  // Download image for face recognition
  Future<ApiResponse> downloadImage(String imageUrl) async {
    try {
      debugPrint('🖼️ Downloading image from: $imageUrl');
      
      // Ensure the URL is properly formatted
      String fullUrl = imageUrl;
      if (!imageUrl.startsWith('http')) {
        fullUrl = 'http://$imageUrl';
      }
      
      final requestHeaders = await headers;
      
      final response = await _debugHttp(
        () => http.get(
          Uri.parse(fullUrl),
          headers: requestHeaders,
        ),
        'Download Profile Image'
      );
      
      if (response.statusCode == 200) {
        debugPrint('✅ Image downloaded successfully (${response.bodyBytes.length} bytes)');
        return ApiResponse(
          success: true,
          message: 'Image downloaded successfully',
          data: response.bodyBytes,
        );
      } else {
        debugPrint('❌ Failed to download image: ${response.statusCode}');
        return ApiResponse(
          success: false,
          message: 'Failed to download image: ${response.statusCode}',
        );
      }
      
    } catch (e) {
      debugPrint('🚨 Error downloading image: $e');
      return ApiResponse(
        success: false,
        message: 'Error downloading image: ${e.toString()}',
      );
    }
  }

  // Download profile photo for face recognition (returns Uint8List)
  Future<Uint8List?> downloadProfilePhoto(String userId) async {
    try {
      debugPrint('📸 Downloading profile photo for user: $userId');
      
      final requestHeaders = await headers;
      
      // Use the same endpoint as ProfileService
      final url = '$_currentBaseUrl/CRF/photo/direct/$userId';
      
      final response = await _debugHttp(
        () => http.get(
          Uri.parse(url),
          headers: requestHeaders,
        ),
        'Download Profile Photo'
      );
      
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        debugPrint('✅ Profile photo downloaded successfully (${response.bodyBytes.length} bytes)');
        return response.bodyBytes;
      } else {
        debugPrint('❌ Failed to download profile photo: ${response.statusCode}');
        return null;
      }
      
    } catch (e) {
      debugPrint('🚨 Error downloading profile photo: $e');
      return null;
    }
  }

  // Validate Seal Code with new endpoint
  Future<ApiResponse> validateSealCode({
    required String branchCode,
    required String idTool,
    String? sealCode,
    String? sealCodeReturn,
  }) async {
    try {
      final requestHeaders = await headers;
      
      // Prepare request body
      final requestBody = {
        'branchCode': branchCode,
        'idTool': idTool,
        'sealCode': sealCode ?? '',
        'sealCodeReturn': sealCodeReturn ?? '',
      };
      
      debugPrint('🔍 Validating seal code with body: $requestBody');
      debugPrint('🔍 Headers: $requestHeaders');
      
      final response = await _debugHttp(
        () => _tryRequestWithFallback(
          requestFn: (baseUrl) => http.post(
            Uri.parse('$baseUrl/CRF/validate/sealcode'),
            headers: requestHeaders,
            body: json.encode(requestBody),
          ),
        ),
        'Validate Seal Code'
      );

      if (response.statusCode == 200) {
        try {
          debugPrint('🔍 Raw seal code validation response: ${response.body.substring(0, math.min(200, response.body.length))}...');
          
          final jsonData = json.decode(response.body);
          final apiResponse = ApiResponse.fromJson(jsonData);
          
          // Debug log the parsed response
          debugPrint('🔍 Parsed seal code response: success=${apiResponse.success}, message=${apiResponse.message}');
          if (apiResponse.data != null) {
            debugPrint('🔍 Data type: ${apiResponse.data.runtimeType}');
            if (apiResponse.data is Map) {
              debugPrint('🔍 Data as Map: ${apiResponse.data.toString().substring(0, math.min(100, apiResponse.data.toString().length))}...');
            } else if (apiResponse.data is List) {
              debugPrint('🔍 Data is List with ${(apiResponse.data as List).length} items');
            }
          }
          
          return apiResponse;
        } catch (e) {
          debugPrint('❌ Error parsing seal code validation JSON: $e');
          return ApiResponse(
            success: false,
            message: 'Invalid data format from server',
            status: 'error'
          );
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ 401 Unauthorized on seal code validation!');
        await _authService.logout();
        return ApiResponse(
          success: false,
          message: 'Session expired: Please login again',
          status: 'error'
        );
      } else {
        debugPrint('❌ HTTP error on seal code validation: ${response.statusCode}, body: ${response.body}');
        return ApiResponse(
          success: false,
          message: 'Server error (${response.statusCode}): ${response.body}',
          status: 'error'
        );
      }
    } catch (e) {
      debugPrint('❌ Seal code validation API error: $e');
      
      String errorMessage = 'Network error: ${e.toString()}';
      if (e is TimeoutException) {
        errorMessage = 'Connection timeout: Please check your internet connection';
      }
      
      return ApiResponse(
        success: false,
        message: errorMessage,
        status: 'error'
      );
    }
  }

  Future<ApiResponse> validateBagCode({
    required String branchCode,
    required String bagCode,
  }) async {
    try {
      final requestHeaders = await headers;

      final requestBody = {
        'branchCode': branchCode,
        'bagCode': bagCode,
      };

      debugPrint('🔍 Validating bag code with body: $requestBody');
      debugPrint('🔍 Headers: $requestHeaders');

      final response = await _debugHttp(
        () => _tryRequestWithFallback(
          requestFn: (baseUrl) => http.post(
            Uri.parse('$baseUrl/CRF/validate/bag'),
            headers: requestHeaders,
            body: json.encode(requestBody),
          ),
        ),
        'Validate Bag Code'
      );

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          return ApiResponse.fromJson(jsonData);
        } catch (e) {
          debugPrint('❌ Error parsing bag code validation JSON: $e');
          return ApiResponse(
            success: false,
            message: 'Invalid data format from server',
            status: 'error'
          );
        }
      } else if (response.statusCode == 401) {
        await _authService.logout();
        return ApiResponse(
          success: false,
          message: 'Session expired: Please login again',
          status: 'error'
        );
      } else {
        return ApiResponse(
          success: false,
          message: 'Server error (${response.statusCode}): ${response.body}',
          status: 'error'
        );
      }
    } catch (e) {
      debugPrint('❌ Bag code validation API error: $e');

      String errorMessage = 'Network error: ${e.toString()}';
      if (e is TimeoutException) {
        errorMessage = 'Connection timeout: Please check your internet connection';
      }

      return ApiResponse(
        success: false,
        message: errorMessage,
        status: 'error'
      );
    }
  }

  // Method untuk insert return catridge (endpoint /rtn/atm/catridge)
  Future<ApiResponse> insertReturnCatridge({
    required String IdTool,
    required String BagCode,
    required String CatridgeCode,
    required String SealCode,
    required String CatridgeSeal,
    required String DenomCode,
    required String Qty,
    required String UserInput,
    required String IsBalikKaset,
    required String CatridgeCodeOld,
    required String ScanCatStatus,
    required String ScanCatStatusRemark,
    required String ScanSealStatus,
    required String ScanSealStatusRemark,
  }) async {
    debugPrint('🚀 [API] Starting return catridge insert...');
    debugPrint('📤 [API] Return catridge parameters:');
    debugPrint('   - IdTool: $IdTool');
    debugPrint('   - BagCode: $BagCode');
    debugPrint('   - CatridgeCode: $CatridgeCode');
    debugPrint('   - SealCode: $SealCode');
    debugPrint('   - CatridgeSeal: $CatridgeSeal');
    debugPrint('   - DenomCode: $DenomCode');
    debugPrint('   - Qty: $Qty');
    debugPrint('   - UserInput: $UserInput');
    debugPrint('   - IsBalikKaset: $IsBalikKaset');
    debugPrint('   - CatridgeCodeOld: $CatridgeCodeOld');

    try {
      final requestHeaders = await _getHeaders();
      final requestBody = {
        'IdTool': IdTool,
        'BagCode': BagCode,
        'CatridgeCode': CatridgeCode,
        'SealCode': SealCode,
        'CatridgeSeal': CatridgeSeal,
        'DenomCode': DenomCode,
        'Qty': Qty,
        'UserInput': UserInput,
        'IsBalikKaset': IsBalikKaset,
        'CatridgeCodeOld': CatridgeCodeOld,
        'ScanCatStatus': ScanCatStatus.isEmpty ? null : ScanCatStatus,
        'ScanCatStatusRemark': ScanCatStatusRemark.isEmpty ? null : ScanCatStatusRemark,
        'ScanSealStatus': ScanSealStatus.isEmpty ? null : ScanSealStatus,
        'ScanSealStatusRemark': ScanSealStatusRemark.isEmpty ? null : ScanSealStatusRemark,
      };

      debugPrint('📤 [API] Return catridge request body: ${json.encode(requestBody)}');

      final response = await _executeWithRetry(
        () => _tryRequestWithFallback(
          requestFn: (baseUrl) => http.post(
            Uri.parse('$baseUrl/CRF/rtn/atm/catridge'),
            headers: requestHeaders,
            body: json.encode(requestBody),
          ),
        ),
        'Return Catridge Insert'
      );

      if (response.statusCode == 200) {
        try {
          debugPrint('🔍 Raw return catridge insert response: ${response.body.substring(0, math.min(300, response.body.length))}...');
          
          final jsonData = json.decode(response.body);
          final apiResponse = ApiResponse.fromJson(jsonData);
          
          debugPrint('📥 [API] Return catridge insert response: success=${apiResponse.success}, message=${apiResponse.message}');
          return apiResponse;
        } catch (e) {
          debugPrint('❌ Error parsing return catridge insert JSON: $e');
          return ApiResponse(
            success: false,
            message: 'Invalid data format from server',
            status: 'error'
          );
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ 401 Unauthorized on return catridge insert!');
        await _authService.logout();
        return ApiResponse(
          success: false,
          message: 'Session expired: Please login again',
          status: 'error'
        );
      } else {
        debugPrint('❌ HTTP error on return catridge insert: ${response.statusCode}, body: ${response.body}');
        return ApiResponse(
          success: false,
          message: 'Server error (${response.statusCode}): ${response.body}',
          status: 'error'
        );
      }
    } catch (e) {
      debugPrint('❌ Return catridge insert API error: $e');
      
      String errorMessage = 'Network error: ${e.toString()}';
      if (e is TimeoutException) {
        errorMessage = 'Connection timeout: Please check your internet connection';
      }
      
      return ApiResponse(
        success: false,
        message: errorMessage,
        status: 'error'
      );
    }
  }
}
