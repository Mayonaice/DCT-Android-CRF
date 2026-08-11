import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'package:flutter/foundation.dart';
import '../models/pengurangan_insert_request.dart';
import '../models/bank_model.dart';
import '../models/closing_android_request.dart';
import '../models/pengurangan_data_model.dart';

class KonsolApiService {
  // Base URL
  static const String _baseUrl = 'https://dev.advantagescm.com/LocalCRF/api';

  // API timeout duration
  static const Duration _timeout = Duration(seconds: 15);

  // Singleton pattern
  static final KonsolApiService _instance = KonsolApiService._internal();
  factory KonsolApiService() => _instance;

  // Auth service
  final AuthService _authService = AuthService();

  // Http client
  final http.Client _client = http.Client();

  // Constructor
  KonsolApiService._internal();

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

  // Get konsol android data from API
  Future<List<KonsolData>> getKonsolAndroidList({String? branchCode}) async {
    try {
      final apiHeaders = await headers;

      // Build the URL with optional branchCode parameter
      String url = '$_baseUrl/CRF/kon/konsol-android/list';
      if (branchCode != null && branchCode.isNotEmpty) {
        url += '?BranchCode=$branchCode';
      }
      debugPrint('🔍 Konsol API URL: $url');

      final response = await _debugHttp(
        () => _client
            .get(
              Uri.parse(url),
              headers: apiHeaders,
            )
            .timeout(_timeout),
        'getKonsolAndroidList',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> konsolDataList = responseData['data'];
          debugPrint('🔍 API returned ${konsolDataList.length} items');

          // Debug: Print first item's fields
          if (konsolDataList.isNotEmpty) {
            debugPrint(
                '🔍 First item fields: ${konsolDataList[0].keys.join(', ')}');
          }

          return konsolDataList
              .map((json) => KonsolData.fromJson(json))
              .toList();
        } else {
          debugPrint('🔍 API returned no data or success=false');
          return [];
        }
      } else {
        debugPrint('🔍 API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('🔍 Error fetching konsol data: $e');
      return [];
    }
  }

  // Insert pengurangan data to API
  Future<PenguranganInsertResponse> insertPenguranganData(
      PenguranganInsertRequest request) async {
    try {
      final apiHeaders = await headers;

      const url = '$_baseUrl/CRF/kon/pengurangan/insert';
      debugPrint('🔍 Insert Pengurangan API URL: $url');
      debugPrint('🔍 Request body: ${jsonEncode(request.toJson())}');

      final response = await _debugHttp(
        () => _client
            .post(
              Uri.parse(url),
              headers: apiHeaders,
              body: jsonEncode(request.toJson()),
            )
            .timeout(_timeout),
        'insertPenguranganData',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        debugPrint('🔍 Insert Pengurangan API Response: $responseData');

        return PenguranganInsertResponse.fromJson(responseData);
      } else {
        debugPrint(
            '🔍 Insert Pengurangan API Error: ${response.statusCode} - ${response.body}');

        // Try to parse error response if possible
        try {
          final Map<String, dynamic> errorData = json.decode(response.body);
          return PenguranganInsertResponse(
            success: false,
            message: errorData['message'] ??
                'Failed to insert data. Status: ${response.statusCode}',
          );
        } catch (e) {
          return PenguranganInsertResponse(
            success: false,
            message: 'Failed to insert data. Status: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      debugPrint('🔍 Insert Pengurangan API Exception: $e');
      return PenguranganInsertResponse(
        success: false,
        message: 'Error: ${e.toString()}',
      );
    }
  }

  // Get bank list from API
  Future<List<Bank>> getBankList() async {
    try {
      final apiHeaders = await headers;

      const url = '$_baseUrl/CRF/bank/list';
      debugPrint('🔍 Get Bank List API URL: $url');

      final response = await _debugHttp(
        () => _client
            .get(
              Uri.parse(url),
              headers: apiHeaders,
            )
            .timeout(_timeout),
        'getBankList',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> bankDataList = responseData['data'];
          debugPrint('🔍 API returned ${bankDataList.length} banks');

          return bankDataList.map((json) => Bank.fromJson(json)).toList();
        } else {
          debugPrint('🔍 API returned no data or success=false');
          return [];
        }
      } else {
        debugPrint('🔍 API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('🔍 Error fetching bank data: $e');
      return [];
    }
  }

  // Get closing preview data
  Future<List<ClosingPreviewItem>> getClosingPreview(
      String codeBank, String jnsMesin, String dateReplenish) async {
    try {
      final apiHeaders = await headers;

      final url =
          '$_baseUrl/CRF/kon/closing/preview?codeBank=$codeBank&jnsMesin=$jnsMesin&dateReplenish=$dateReplenish';
      debugPrint('🔍 Get Closing Preview API URL: $url');

      final response = await _debugHttp(
        () => _client
            .get(
              Uri.parse(url),
              headers: apiHeaders,
            )
            .timeout(_timeout),
        'getClosingPreview',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> previewDataList = responseData['data'];
          debugPrint('🔍 API returned ${previewDataList.length} preview items');

          return previewDataList
              .map((json) => ClosingPreviewItem.fromJson(json))
              .toList();
        } else {
          debugPrint('🔍 API returned no data or success=false');
          return [];
        }
      } else {
        debugPrint('🔍 API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('🔍 Error fetching closing preview data: $e');
      return [];
    }
  }

  Future<List<ClosingAndroidListItem>> getClosingAndroidList(
      {String? branchCode, String? fromDate, String? toDate}) async {
    try {
      final apiHeaders = await headers;

      final queryParams = <String>[];
      if (branchCode != null && branchCode.trim().isNotEmpty) {
        queryParams
            .add('branchCode=${Uri.encodeQueryComponent(branchCode.trim())}');
      }
      if (fromDate != null && fromDate.trim().isNotEmpty) {
        queryParams
            .add('fromDate=${Uri.encodeQueryComponent(fromDate.trim())}');
      }
      if (toDate != null && toDate.trim().isNotEmpty) {
        queryParams.add('toDate=${Uri.encodeQueryComponent(toDate.trim())}');
      }

      String url = '$_baseUrl/CRF/kon/closing/list';
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      debugPrint('🔍 Get Closing List API URL: $url');

      final response = await _debugHttp(
        () => _client
            .get(
              Uri.parse(url),
              headers: apiHeaders,
            )
            .timeout(_timeout),
        'getClosingAndroidList',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> list = responseData['data'];
          debugPrint('🔍 Closing list returned ${list.length} items');
          return list
              .map((e) =>
                  ClosingAndroidListItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }

        debugPrint(
            '🔍 Closing list success=false or data null: ${responseData['message']}');
        return [];
      }

      debugPrint(
          '🔍 Closing list API error: ${response.statusCode} - ${response.body}');
      return [];
    } catch (e) {
      debugPrint('🔍 Error fetching closing list: $e');
      return [];
    }
  }

  // Insert closing data
  Future<ClosingAndroidResponse> insertClosingData(
      String codeBank, String jnsMesin, String dateReplenish) async {
    try {
      final apiHeaders = await headers;

      const url = '$_baseUrl/CRF/kon/closing/insert';
      debugPrint('🔍 Insert Closing API URL: $url');

      final request = ClosingAndroidRequest(
          codeBank: codeBank, jnsMesin: jnsMesin, dateReplenish: dateReplenish);
      debugPrint('🔍 Request body: ${jsonEncode(request.toJson())}');

      final response = await _debugHttp(
        () => _client
            .post(
              Uri.parse(url),
              headers: apiHeaders,
              body: jsonEncode(request.toJson()),
            )
            .timeout(_timeout),
        'insertClosingData',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        debugPrint('🔍 Insert Closing API Response: $responseData');

        return ClosingAndroidResponse.fromJson(responseData);
      } else {
        debugPrint(
            '🔍 Insert Closing API Error: ${response.statusCode} - ${response.body}');

        // Try to parse error response if possible
        try {
          final Map<String, dynamic> errorData = json.decode(response.body);
          return ClosingAndroidResponse(
            success: false,
            message: errorData['message'] ??
                'Failed to insert closing data. Status: ${response.statusCode}',
          );
        } catch (e) {
          return ClosingAndroidResponse(
            success: false,
            message:
                'Failed to insert closing data. Status: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      debugPrint('🔍 Insert Closing API Exception: $e');
      return ClosingAndroidResponse(
        success: false,
        message: 'Error: ${e.toString()}',
      );
    }
  }

  Future<ClosingAndroidResponse> approveClosingData({
    required String codeBank,
    required String jnsMesin,
    required String dateReplenish,
    String? cashierCode,
    String? tableCode,
  }) async {
    try {
      final apiHeaders = await headers;

      const url = '$_baseUrl/CRF/kon/closing/approve';
      final requestBody = {
        'CodeBank': codeBank,
        'JnsMesin': jnsMesin,
        'DateReplenish': dateReplenish,
        'CashierCode': cashierCode ?? '',
        'TableCode': tableCode ?? '',
      };
      debugPrint('ðŸ” Approve Closing API URL: $url');
      debugPrint('ðŸ” Approve Closing body: ${jsonEncode(requestBody)}');

      final response = await _debugHttp(
        () => _client
            .post(
              Uri.parse(url),
              headers: apiHeaders,
              body: jsonEncode(requestBody),
            )
            .timeout(_timeout),
        'approveClosingData',
      );

      final Map<String, dynamic> responseData = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ClosingAndroidResponse.fromJson(responseData);
      }

      return ClosingAndroidResponse(
        success: false,
        message: responseData['message']?.toString() ??
            responseData['Message']?.toString() ??
            'Failed to approve closing. Status: ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('ðŸ” Approve Closing API Exception: $e');
      return ClosingAndroidResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  Future<Map<String, dynamic>> checkKonsolApprovalStatus({
    String? idTool,
    String? idTools,
    String? wsid,
    String? codeBank,
    String? jnsMesin,
    String? dateReplenish,
  }) async {
    try {
      final apiHeaders = await headers;
      final approvalIds = <String>{
        if (idTool != null && idTool.trim().isNotEmpty) idTool.trim(),
        if (idTools != null && idTools.trim().isNotEmpty)
          ...idTools
              .split(',')
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty),
      }.toList();

      if (approvalIds.isEmpty) {
        return {
          'success': false,
          'approved': false,
          'message': 'IdTool approval kosong, tidak bisa cek status',
        };
      }

      return await _checkKonsolApprovalStatusFromConsoleList(
        apiHeaders: apiHeaders,
        approvalIds: approvalIds,
      );

      final statusQuery = <String, String>{
        if (approvalIds.length == 1) 'idTool': approvalIds.first,
        if (approvalIds.length > 1) 'idTools': approvalIds.join(','),
        if (wsid != null && wsid.trim().isNotEmpty) 'wsid': wsid.trim(),
        if (codeBank != null && codeBank.trim().isNotEmpty)
          'codeBank': codeBank.trim(),
        if (jnsMesin != null && jnsMesin.trim().isNotEmpty)
          'jnsMesin': jnsMesin.trim(),
        if (dateReplenish != null && dateReplenish.trim().isNotEmpty)
          'dateReplenish': dateReplenish.trim(),
      };

      final uri = Uri.parse('$_baseUrl/CRF/kon/approval/status')
          .replace(queryParameters: statusQuery);

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
        approvalIds: approvalIds,
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
    required List<String> approvalIds,
  }) async {
    final allRows = <dynamic>[];
    var allApproved = true;

    for (final approvalId in approvalIds) {
      final uri = Uri.parse('$_baseUrl/CRF/kon/console-android/list')
          .replace(queryParameters: {'idTool': approvalId});
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
      if (rows is List) {
        allRows.addAll(rows);
        allApproved = allApproved && _isApprovalResponseApproved(rows);
      } else {
        allApproved = false;
      }
    }

    return {
      'success': true,
      'approved': allApproved,
      'message': allApproved
          ? 'Approval TL sudah berhasil'
          : 'Masih menunggu approval TL',
      'data': allRows,
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

  // Get pengurangan android data from API
  Future<List<PenguranganData>> getPenguranganAndroidList(
      {String? branchCode, String? fromDate, String? toDate}) async {
    try {
      final apiHeaders = await headers;

      // Debug token
      final token = await _authService.getToken();
      debugPrint(
          '🔍 Token for API call: ${token != null ? "Found (${token.length} chars)" : "NULL"}');

      // Build the URL with optional parameters
      List<String> queryParams = [];

      if (branchCode != null && branchCode.isNotEmpty) {
        // Ensure branchCode is properly formatted (no spaces, etc.)
        final cleanBranchCode = branchCode.trim();
        queryParams.add('branchCode=$cleanBranchCode');
      }

      if (fromDate != null && fromDate.isNotEmpty) {
        // Ensure date format is correct (dd-MM-yyyy)
        queryParams.add('fromDate=$fromDate');
      }

      if (toDate != null && toDate.isNotEmpty) {
        // Ensure date format is correct (dd-MM-yyyy)
        queryParams.add('toDate=$toDate');
      }

      String url = '$_baseUrl/CRF/kon/pengurangan-android/list';
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      debugPrint('🔍 Pengurangan API URL: $url');

      final response = await _debugHttp(
        () => _client
            .get(
              Uri.parse(url),
              headers: apiHeaders,
            )
            .timeout(_timeout),
        'getPenguranganAndroidList',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        // Log full response for debugging
        debugPrint('🔍 Full API response: ${response.body}');

        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> penguranganDataList = responseData['data'];
          debugPrint(
              '🔍 API returned ${penguranganDataList.length} pengurangan items');

          // Debug: Print first item's fields and values
          if (penguranganDataList.isNotEmpty) {
            final firstItem = penguranganDataList[0];
            debugPrint('🔍 First item fields: ${firstItem.keys.join(', ')}');
            firstItem.forEach((key, value) {
              debugPrint('🔍 First item[$key] = $value');
            });
          }

          return penguranganDataList
              .map((json) => PenguranganData.fromJson(json))
              .toList();
        } else {
          // Check if there's an error message
          final message = responseData['message'] ?? 'Unknown error';
          debugPrint('🔍 API returned no data or success=false: $message');
          return [];
        }
      } else {
        debugPrint('🔍 API error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('🔍 Error fetching pengurangan data: $e');
      return [];
    }
  }
}

class KonsolData {
  final String? id;
  final String? codeBank;
  final String? atmCode;
  final String? jnsMesin;
  final String? name;
  final String? denomCode;
  final int? a1;
  final int? a2;
  final int? a5;
  final int? a10;
  final int? a20;
  final int? a50;
  final int? a75;
  final int? a100;
  final int? tQty;
  final int? tValue;
  final String? branchCode;
  final String? dateSTReturn;
  final String? tglPrepare;
  final String? dateReplenish;
  final String? actualDateReplenish;
  final String? keterangan;
  final String? typeData;
  final String? typeDataReturn;
  final String? consoleIdTool;
  final int? a1Edit;
  final int? a2Edit;
  final int? a5Edit;
  final int? a10Edit;
  final int? a20Edit;
  final int? a50Edit;
  final int? a75Edit;
  final int? a100Edit;
  final int? a1Default;
  final int? a2Default;
  final int? a5Default;
  final int? a10Default;
  final int? a20Default;
  final int? a50Default;
  final int? a75Default;
  final int? a100Default;
  final int? tQtyEdit;
  final int? tValueEdit;
  final String? tableCode;
  final String? cashier;
  final String? tlCode;
  final String? timeStart;
  final String? timeFinish;
  final String? edited;
  final String? validate;
  final String? isClosing;

  KonsolData({
    this.id,
    this.codeBank,
    this.atmCode,
    this.jnsMesin,
    this.name,
    this.denomCode,
    this.a1,
    this.a2,
    this.a5,
    this.a10,
    this.a20,
    this.a50,
    this.a75,
    this.a100,
    this.tQty,
    this.tValue,
    this.branchCode,
    this.dateSTReturn,
    this.tglPrepare,
    this.dateReplenish,
    this.actualDateReplenish,
    this.keterangan,
    this.typeData,
    this.typeDataReturn,
    this.consoleIdTool,
    this.a1Edit,
    this.a2Edit,
    this.a5Edit,
    this.a10Edit,
    this.a20Edit,
    this.a50Edit,
    this.a75Edit,
    this.a100Edit,
    this.a1Default,
    this.a2Default,
    this.a5Default,
    this.a10Default,
    this.a20Default,
    this.a50Default,
    this.a75Default,
    this.a100Default,
    this.tQtyEdit,
    this.tValueEdit,
    this.tableCode,
    this.cashier,
    this.tlCode,
    this.timeStart,
    this.timeFinish,
    this.edited,
    this.validate,
    this.isClosing,
  });

  factory KonsolData.fromJson(Map<String, dynamic> json) {
    // Debug: Print raw json for troubleshooting
    debugPrint(
        '🔍 Processing JSON: id=${json['id']}, timeStart=${json['timeStart']}');

    // Try to parse fields with case-insensitive approach
    String? findField(String fieldName) {
      // First try exact match
      if (json.containsKey(fieldName)) {
        return json[fieldName]?.toString();
      }

      // Then try case-insensitive match
      final lowercaseField = fieldName.toLowerCase();
      final matchingKey = json.keys.firstWhere(
        (key) => key.toLowerCase() == lowercaseField,
        orElse: () => '',
      );

      return matchingKey.isNotEmpty ? json[matchingKey]?.toString() : null;
    }

    int? tryParseInt(String? fieldName) {
      if (fieldName == null) return null;
      final value = findField(fieldName);
      if (value == null) return null;
      return int.tryParse(value);
    }

    return KonsolData(
      id: findField('id'),
      codeBank: findField('codeBank'),
      atmCode: findField('atmCode'),
      jnsMesin: findField('jnsMesin'),
      name: findField('name'),
      denomCode: findField('denomCode'),
      a1: tryParseInt('a1'),
      a2: tryParseInt('a2'),
      a5: tryParseInt('a5'),
      a10: tryParseInt('a10'),
      a20: tryParseInt('a20'),
      a50: tryParseInt('a50'),
      a75: tryParseInt('a75'),
      a100: tryParseInt('a100'),
      tQty: tryParseInt('tQty'),
      tValue: tryParseInt('tValue'),
      branchCode: findField('branchCode'),
      dateSTReturn: findField('dateSTReturn'),
      tglPrepare: findField('tglPrepare'),
      dateReplenish: findField('dateReplenish'),
      actualDateReplenish: findField('actualDateReplenish'),
      keterangan: findField('keterangan'),
      typeData: findField('typeData'),
      typeDataReturn: findField('typeDataReturn'),
      consoleIdTool: findField('consoleIdTool'),
      a1Edit: tryParseInt('a1Edit'),
      a2Edit: tryParseInt('a2Edit'),
      a5Edit: tryParseInt('a5Edit'),
      a10Edit: tryParseInt('a10Edit'),
      a20Edit: tryParseInt('a20Edit'),
      a50Edit: tryParseInt('a50Edit'),
      a75Edit: tryParseInt('a75Edit'),
      a100Edit: tryParseInt('a100Edit'),
      a1Default: tryParseInt('a1Default'),
      a2Default: tryParseInt('a2Default'),
      a5Default: tryParseInt('a5Default'),
      a10Default: tryParseInt('a10Default'),
      a20Default: tryParseInt('a20Default'),
      a50Default: tryParseInt('a50Default'),
      a75Default: tryParseInt('a75Default'),
      a100Default: tryParseInt('a100Default'),
      tQtyEdit: tryParseInt('tQtyEdit'),
      tValueEdit: tryParseInt('tValueEdit'),
      tableCode: findField('tableCode'),
      cashier: findField('cashier'),
      tlCode: findField('tlCode'),
      timeStart: findField('timeStart'),
      timeFinish: findField('timeFinish'),
      edited: findField('edited'),
      validate: findField('validate'),
      isClosing: findField('isClosing'),
    );
  }
}

class ClosingAndroidListItem {
  final String? id;
  final String? tanggalClosing;
  final String? codeBank;
  final String? jenisMesin;
  final int? a1;
  final int? a2;
  final int? a5;
  final int? a10;
  final int? a20;
  final int? a50;
  final int? a75;
  final int? a100;
  final String? userClosing;
  final String? branchCode;

  ClosingAndroidListItem({
    this.id,
    this.tanggalClosing,
    this.codeBank,
    this.jenisMesin,
    this.a1,
    this.a2,
    this.a5,
    this.a10,
    this.a20,
    this.a50,
    this.a75,
    this.a100,
    this.userClosing,
    this.branchCode,
  });

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  factory ClosingAndroidListItem.fromJson(Map<String, dynamic> json) {
    return ClosingAndroidListItem(
      id: json['id']?.toString(),
      tanggalClosing: json['tanggalClosing']?.toString(),
      codeBank: json['codeBank']?.toString(),
      jenisMesin: json['jenisMesin']?.toString(),
      a1: _toInt(json['a1']),
      a2: _toInt(json['a2']),
      a5: _toInt(json['a5']),
      a10: _toInt(json['a10']),
      a20: _toInt(json['a20']),
      a50: _toInt(json['a50']),
      a75: _toInt(json['a75']),
      a100: _toInt(json['a100']),
      userClosing: json['userClosing']?.toString(),
      branchCode: json['branchCode']?.toString(),
    );
  }
}
