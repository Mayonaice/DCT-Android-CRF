import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/history_model.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';

class HistoryApiService {
  // Base URL
  static const String _baseUrl = 'http://10.10.0.223/LocalCRF/api/CRF';
  
  // API timeout duration
  static const Duration _timeout = Duration(seconds: 15);

  // Singleton pattern
  static final HistoryApiService _instance = HistoryApiService._internal();
  factory HistoryApiService() => _instance;
  
  // Auth service
  final AuthService _authService = AuthService();
  
  // Http client
  final http.Client _client = http.Client();

  HistoryApiService._internal();

  // Dispose method to clean up resources
  void dispose() {
    _client.close();
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

  // Get history prepare data
  Future<HistoryResponse> getHistoryPrepare({
    required String branchCode,
    required String userId,
  }) async {
    try {
      final requestHeaders = await headers;
      
      final requestBody = {
        "branchCode": branchCode,
        "userId": userId,
      };
      
      debugPrint('History Prepare request: ${json.encode(requestBody)}');
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/history/prepare'),
        headers: requestHeaders,
        body: json.encode(requestBody),
      ).timeout(_timeout);

      debugPrint('History Prepare response status: ${response.statusCode}');
      debugPrint('History Prepare response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          return HistoryResponse.fromJson(jsonData);
        } catch (e) {
          debugPrint('Error parsing History Prepare JSON: $e');
          return HistoryResponse(
            success: false,
            message: 'Invalid data format from server',
            data: [],
          );
        }
      } else if (response.statusCode == 401) {
        await _authService.logout();
        return HistoryResponse(
          success: false,
          message: 'Session expired: Please login again',
          data: [],
        );
      } else {
        return HistoryResponse(
          success: false,
          message: 'Server error (${response.statusCode}): ${response.body}',
          data: [],
        );
      }
    } catch (e) {
      debugPrint('History Prepare API error: $e');
      
      String errorMessage = 'Network error: ${e.toString()}';
      if (e is TimeoutException) {
        errorMessage = 'Connection timeout: Please check your internet connection';
      }
      
      return HistoryResponse(
        success: false,
        message: errorMessage,
        data: [],
      );
    }
  }

  // Get history return data
  Future<HistoryResponse> getHistoryReturn({
    required String branchCode,
    required String userId,
  }) async {
    try {
      final requestHeaders = await headers;
      
      final requestBody = {
        "branchCode": branchCode,
        "userId": userId,
      };
      
      debugPrint('History Return request: ${json.encode(requestBody)}');
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/history/return'),
        headers: requestHeaders,
        body: json.encode(requestBody),
      ).timeout(_timeout);

      debugPrint('History Return response status: ${response.statusCode}');
      debugPrint('History Return response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          return HistoryResponse.fromJson(jsonData);
        } catch (e) {
          debugPrint('Error parsing History Return JSON: $e');
          return HistoryResponse(
            success: false,
            message: 'Invalid data format from server',
            data: [],
          );
        }
      } else if (response.statusCode == 401) {
        await _authService.logout();
        return HistoryResponse(
          success: false,
          message: 'Session expired: Please login again',
          data: [],
        );
      } else {
        return HistoryResponse(
          success: false,
          message: 'Server error (${response.statusCode}): ${response.body}',
          data: [],
        );
      }
    } catch (e) {
      debugPrint('History Return API error: $e');
      
      String errorMessage = 'Network error: ${e.toString()}';
      if (e is TimeoutException) {
        errorMessage = 'Connection timeout: Please check your internet connection';
      }
      
      return HistoryResponse(
        success: false,
        message: errorMessage,
        data: [],
      );
    }
  }
}