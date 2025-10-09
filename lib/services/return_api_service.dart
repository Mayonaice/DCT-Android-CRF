import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/return_data_model.dart';
import '../models/update_qty_catridge_request.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';

class ReturnApiService {
  // Base URL
  static const String _baseUrl = 'http://10.10.0.223/LocalCRF/api';
  
  // API timeout duration
  static const Duration _timeout = Duration(seconds: 15);

  // Singleton pattern
  static final ReturnApiService _instance = ReturnApiService._internal();
  factory ReturnApiService() => _instance;
  
  // Auth service
  final AuthService _authService = AuthService();
  
  // Http client
  final http.Client _client = http.Client();
  
  // Constructor
  ReturnApiService._internal();
  
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

  // Get data return list from API
  Future<List<ReturnData>> getReturnList({String? branchCode}) async {
    try {
      final apiHeaders = await headers;
      
      // Build the URL with optional branchCode parameter
      String url = '$_baseUrl/CRF/kon/return/list';
      if (branchCode != null && branchCode.isNotEmpty) {
        url += '?BranchCode=$branchCode';
      }
      debugPrint('🔍 Return API URL: $url');
      
      final response = await _debugHttp(
        () => _client.get(
          Uri.parse(url),
          headers: apiHeaders,
        ).timeout(_timeout),
        'getReturnList',
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> returnDataList = responseData['data'];
          
          return returnDataList
              .map((item) => ReturnData.fromJson(item))
              .toList();
        } else {
          debugPrint('API returned success=false or no data: ${responseData['message']}');
          return [];
        }
      } else {
        debugPrint('API returned error status code: ${response.statusCode}');
        throw Exception('Failed to load return data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting return list: $e');
      throw Exception('Failed to load return data: $e');
    }
  }
  
  // Validate TL Supervisor credentials
  Future<Map<String, dynamic>> validateTLSupervisor(String nik, String password) async {
    try {
      final apiHeaders = await headers;
      const url = '$_baseUrl/CRF/validate/tl-supervisor';
      
      debugPrint('🔍 Validating TL Supervisor: $nik');
      
      final response = await _debugHttp(
        () => _client.post(
          Uri.parse(url),
          headers: apiHeaders,
          body: json.encode({
            'NIK': nik,
            'Password': password,
          }),
        ).timeout(_timeout),
        'validateTLSupervisor',
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        // Check if the validation has data and extract the validation status
        if (responseData['data'] != null) {
          final validationData = responseData['data'];
          final validationStatus = validationData['validationStatus'] ?? '';
          final errorMessage = validationData['errorMessage'] ?? '';
          
          // Return appropriate response based on validation status
          if (validationStatus.toString().toUpperCase() == 'SUCCESS') {
            return {
              'success': true,
              'message': errorMessage.isNotEmpty ? errorMessage : 'Validasi TL Supervisor berhasil',
              'data': validationData
            };
          } else {
            return {
              'success': false,
              'message': errorMessage.isNotEmpty ? errorMessage : 'Validasi TL Supervisor gagal',
              'data': validationData
            };
          }
        }
        
        // If we get here, use the standard response format
        return responseData;
      } else {
        debugPrint('API returned error status code: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to validate TL Supervisor: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error validating TL Supervisor: $e');
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }
  
  // Update quantity catridge
  Future<Map<String, dynamic>> updateQtyCatridge(UpdateQtyCatridgeRequest request) async {
    try {
      final apiHeaders = await headers;
      const url = '$_baseUrl/CRF/kon/validate-update/qty/catridge';
      
      debugPrint('🔍 Updating quantity catridge for IdTool: ${request.idTool}');
      debugPrint('🔍 Request body: ${json.encode(request.toJson())}');
      debugPrint('🔍 Request body details: TableCode=${request.tableCode}, User=${request.user}, SpvTLCode=${request.spvTLCode}');
      
      final response = await _debugHttp(
        () => _client.post(
          Uri.parse(url),
          headers: apiHeaders,
          body: json.encode(request.toJson()),
        ).timeout(_timeout),
        'updateQtyCatridge',
      );
      
      // Log full response details
      debugPrint('🔍 Response status code: ${response.statusCode}');
      debugPrint('🔍 Response body raw: ${response.body}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        // Check for specific validation messages from the SP
        if (responseData['success'] == false && responseData['message'] != null) {
          final message = responseData['message'].toString();
          debugPrint('🔍 Error message from API: $message');
          
          // Map specific error messages from SP
          if (message.contains('Perlu validasi dari spvtl terlebih dahulu')) {
            return {
              'success': false,
              'message': 'Perlu validasi dari spvtl terlebih dahulu',
              'errorCode': 'SPVTL_REQUIRED',
            };
          } else if (message.contains('ID Return tidak valid')) {
            return {
              'success': false,
              'message': 'ID Return tidak valid',
              'errorCode': 'INVALID_RETURN_ID',
            };
          } else if (message.contains('Tidak bisa dilakukan pengeditan ketika bank sudah di EOD')) {
            return {
              'success': false,
              'message': 'Tidak bisa dilakukan pengeditan ketika bank sudah di EOD',
              'errorCode': 'EOD_RESTRICTION',
            };
          }
        }
        
        return responseData;
      } else if (response.statusCode == 400) {
        // Handle Bad Request errors
        try {
          final Map<String, dynamic> errorData = json.decode(response.body);
          debugPrint('🔍 Error 400 details: ${errorData.toString()}');
          return {
            'success': false,
            'message': errorData['message'] ?? 'Failed to update quantity catridge: ${response.statusCode}',
          };
        } catch (e) {
          debugPrint('🔍 Error parsing 400 response: $e');
          debugPrint('🔍 Raw response body: ${response.body}');
          return {
            'success': false,
            'message': 'Failed to update quantity catridge: ${response.statusCode}',
          };
        }
      } else {
        debugPrint('API returned error status code: ${response.statusCode}');
        debugPrint('🔍 Response body: ${response.body}');
        return {
          'success': false,
          'message': 'Failed to update quantity catridge: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error updating quantity catridge: $e');
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }
}