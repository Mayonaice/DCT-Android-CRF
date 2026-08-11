import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/return_data_model.dart';
import '../models/update_qty_catridge_request.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';

class ReturnApiService {
  // Base URL
  static const String _baseUrl = 'https://dev.advantagescm.com/LocalCRF/api';

  // API timeout duration
  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _approvalTimeout = Duration(seconds: 300);

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
  Future<http.Response> _debugHttp(
      Future<http.Response> Function() request, String description) async {
    try {
      debugPrint('🔄 HTTP REQUEST [$description] - Starting...');
      final stopwatch = Stopwatch()..start();
      final response = await request();
      stopwatch.stop();

      // Log partial response (to avoid huge logs)
      final bodyPreview = response.body.length > 200
          ? '${response.body.substring(0, 200)}... (${response.body.length} chars total)'
          : response.body;

      debugPrint(
          '🔄 HTTP RESPONSE [$description] - Status: ${response.statusCode}, Time: ${stopwatch.elapsedMilliseconds}ms');
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
  Future<List<ReturnData>> getReturnList(
      {String? branchCode, String? typeReturn}) async {
    try {
      final apiHeaders = await headers;

      // Build the URL with optional branchCode parameter
      String url = '$_baseUrl/CRF/kon/return/list';
      bool hasQuery = false;
      if (branchCode != null && branchCode.isNotEmpty) {
        url += '?BranchCode=$branchCode';
        hasQuery = true;
      }
      if (typeReturn != null && typeReturn.isNotEmpty) {
        url +=
            '${hasQuery ? '&' : '?'}typeReturn=${Uri.encodeQueryComponent(typeReturn)}';
      }
      debugPrint('🔍 Return API URL: $url');

      final response = await _debugHttp(
        () => _client
            .get(
              Uri.parse(url),
              headers: apiHeaders,
            )
            .timeout(_timeout),
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
          debugPrint(
              'API returned success=false or no data: ${responseData['message']}');
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
  Future<Map<String, dynamic>> validateTLSupervisor(
      String nik, String password) async {
    try {
      final apiHeaders = await headers;
      const url = '$_baseUrl/CRF/validate/tl-supervisor';

      debugPrint('🔍 Validating TL Supervisor: $nik');

      final response = await _debugHttp(
        () => _client
            .post(
              Uri.parse(url),
              headers: apiHeaders,
              body: json.encode({
                'NIK': nik,
                'Password': password,
              }),
            )
            .timeout(_approvalTimeout),
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
              'message': errorMessage.isNotEmpty
                  ? errorMessage
                  : 'Validasi TL Supervisor berhasil',
              'data': validationData
            };
          } else {
            return {
              'success': false,
              'message': errorMessage.isNotEmpty
                  ? errorMessage
                  : 'Validasi TL Supervisor gagal',
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
  Future<Map<String, dynamic>> updateQtyCatridge(
      UpdateQtyCatridgeRequest request) async {
    try {
      final apiHeaders = await headers;
      const url = '$_baseUrl/CRF/kon/validate-update/qty/catridge';

      debugPrint('🔍 Updating quantity catridge for IdTool: ${request.idTool}');
      debugPrint('🔍 Request body: ${json.encode(request.toJson())}');
      debugPrint(
          '🔍 Request body details: TableCode=${request.tableCode}, User=${request.user}, SpvTLCode=${request.spvTLCode}');

      final response = await _debugHttp(
        () => _client
            .post(
              Uri.parse(url),
              headers: apiHeaders,
              body: json.encode(request.toJson()),
            )
            .timeout(_approvalTimeout),
        'updateQtyCatridge',
      );

      // Log full response details
      debugPrint('🔍 Response status code: ${response.statusCode}');
      debugPrint('🔍 Response body raw: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        // Check for specific validation messages from the SP
        if (responseData['success'] == false &&
            responseData['message'] != null) {
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
          } else if (message.contains(
              'Tidak bisa dilakukan pengeditan ketika bank sudah di EOD')) {
            return {
              'success': false,
              'message':
                  'Tidak bisa dilakukan pengeditan ketika bank sudah di EOD',
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
            'message': errorData['message'] ??
                'Failed to update quantity catridge: ${response.statusCode}',
          };
        } catch (e) {
          debugPrint('🔍 Error parsing 400 response: $e');
          debugPrint('🔍 Raw response body: ${response.body}');
          return {
            'success': false,
            'message':
                'Failed to update quantity catridge: ${response.statusCode}',
          };
        }
      } else {
        debugPrint('API returned error status code: ${response.statusCode}');
        debugPrint('🔍 Response body: ${response.body}');
        return {
          'success': false,
          'message':
              'Failed to update quantity catridge: ${response.statusCode}',
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

  Future<Map<String, dynamic>> approveKonsolReturnEdit({
    required String idTool,
    required int a1,
    required int a2,
    required int a5,
    required int a10,
    required int a20,
    required int a50,
    required int a75,
    required int a100,
    required String user,
    String? tableCode,
  }) async {
    try {
      final apiHeaders = await headers;
      const url = '$_baseUrl/CRF/kon/return-edit/approve';
      final requestBody = {
        'IdTool': idTool,
        'A1': a1.toString(),
        'A2': a2.toString(),
        'A5': a5.toString(),
        'A10': a10.toString(),
        'A20': a20.toString(),
        'A50': a50.toString(),
        'A75': a75.toString(),
        'A100': a100.toString(),
        'User': user,
        'TableCode': tableCode ?? '',
      };

      debugPrint('ðŸ” Approve konsol return edit URL: $url');
      debugPrint(
          'ðŸ” Approve konsol return edit body: ${json.encode(requestBody)}');

      final response = await _debugHttp(
        () => _client
            .post(
              Uri.parse(url),
              headers: apiHeaders,
              body: json.encode(requestBody),
            )
            .timeout(_approvalTimeout),
        'approveKonsolReturnEdit',
      );

      Map<String, dynamic> responseData = {};
      try {
        responseData = json.decode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (response.statusCode == 200) {
        return responseData;
      }

      return {
        'success': false,
        'message': responseData['message']?.toString() ??
            responseData['Message']?.toString() ??
            'Failed to approve return edit: ${response.statusCode}',
      };
    } catch (e) {
      debugPrint('Error approving konsol return edit: $e');
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> checkKonsolApprovalStatus({
    String? idTool,
    String? wsid,
  }) async {
    try {
      final apiHeaders = await headers;
      final cleanIdTool = idTool?.trim() ?? '';
      if (cleanIdTool.isEmpty) {
        return {
          'success': false,
          'approved': false,
          'message': 'IdTool approval kosong, tidak bisa cek status',
        };
      }

      return await _checkKonsolApprovalStatusFromConsoleList(
        apiHeaders: apiHeaders,
        cleanIdTool: cleanIdTool,
      );

      final uri = Uri.parse('$_baseUrl/CRF/kon/approval/status').replace(
        queryParameters: {
          'idTool': cleanIdTool,
          if (wsid != null && wsid.trim().isNotEmpty) 'wsid': wsid.trim(),
        },
      );

      debugPrint('Ã°Å¸â€Â Check konsol approval status URL: $uri');

      final response = await _debugHttp(
        () => _client.get(uri, headers: apiHeaders).timeout(_timeout),
        'checkKonsolApprovalStatus',
      );

      Map<String, dynamic> responseData = {};
      try {
        responseData = json.decode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (response.statusCode == 200) {
        final rows = responseData['data'];
        final approved =
            responseData['approved'] == true || _isApprovalResponseApproved(rows);
        return {
          'success': responseData['success'] == true,
          'approved': approved,
          'message': approved
              ? 'Approval TL sudah berhasil'
              : 'Masih menunggu approval TL',
          'data': rows,
        };
      }

      final fallback = await _checkKonsolApprovalStatusFromConsoleList(
        apiHeaders: apiHeaders,
        cleanIdTool: cleanIdTool,
      );
      if (fallback['success'] == true || fallback['approved'] == true) {
        return fallback;
      }

      return {
        'success': false,
        'approved': false,
        'message': responseData['message']?.toString() ??
            responseData['Message']?.toString() ??
            'Failed to check approval status: ${response.statusCode}',
      };
    } catch (e) {
      debugPrint('Error checking konsol approval status: $e');
      return {
        'success': false,
        'approved': false,
        'message': 'Connection error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _checkKonsolApprovalStatusFromConsoleList({
    required Map<String, String> apiHeaders,
    required String cleanIdTool,
  }) async {
    final uri = Uri.parse('$_baseUrl/CRF/kon/console-android/list')
        .replace(queryParameters: {'idTool': cleanIdTool});
    debugPrint('Check konsol approval status URL: $uri');

    final response = await _debugHttp(
      () => _client.get(uri, headers: apiHeaders).timeout(_timeout),
      'checkKonsolApprovalStatusFallback',
    );

    Map<String, dynamic> responseData = {};
    try {
      responseData = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    if (response.statusCode != 200) {
      return {
        'success': false,
        'approved': false,
        'message': responseData['message']?.toString() ??
            responseData['Message']?.toString() ??
            'Failed to check approval status: ${response.statusCode}',
      };
    }

    final rows = responseData['data'];
    final approved = _isApprovalResponseApproved(rows);
    return {
      'success': responseData['success'] == true,
      'approved': approved,
      'message': approved
          ? 'Approval TL sudah berhasil'
          : 'Masih menunggu approval TL',
      'data': rows,
    };
  }

  bool _isApprovalResponseApproved(dynamic rows) {
    return rows is List && rows.any(_isConsoleRowApproved);
  }

  bool _isConsoleRowApproved(dynamic row) {
    if (row is! Map) return false;
    final isApprovedFlag = row['IsApproved'];
    if (isApprovedFlag == true ||
        isApprovedFlag?.toString().toLowerCase() == 'true' ||
        isApprovedFlag?.toString() == '1') {
      return true;
    }

    final isClosing = row['IsClosing']?.toString().trim().toUpperCase() ?? '';
    if (isClosing == 'Y') {
      return true;
    }

    final validate = row['Validate']?.toString().trim().toUpperCase() ?? '';
    final tlCode = row['TLCode']?.toString().trim() ?? '';
    final timeFinish = row['TimeFinish']?.toString().trim() ?? '';
    return validate == 'Y' &&
        tlCode.isNotEmpty &&
        tlCode.toLowerCase() != 'null' &&
        timeFinish.isNotEmpty &&
        timeFinish.toLowerCase() != 'null';
  }
}
