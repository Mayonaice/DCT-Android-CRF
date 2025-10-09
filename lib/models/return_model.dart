// Import shared models from prepare_model.dart instead of duplicating them
import 'dart:convert'; // Added for jsonDecode

// Model untuk response validasi dan replenish dari API
class ValidateAndGetReplenishResponse {
  final bool success;
  final String message;
  final ValidateAndGetReplenishData? data;

  ValidateAndGetReplenishResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory ValidateAndGetReplenishResponse.fromJson(Map<String, dynamic> json) {
    return ValidateAndGetReplenishResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? ValidateAndGetReplenishData.fromJson(json['data']) : null,
    );
  }
}

class ValidateAndGetReplenishData {
  final String validationStatus;
  final String errorCode;
  final String errorMessage;
  final String atmCode;
  final String idToolPrepare;
  final int currentIdTool;
  final String codeBank;
  final String jnsMesin;
  final String lokasi;
  final String idTypeAtm;
  final String timeSTReturn;
  final List<CatridgeReplenishData> catridges;

  ValidateAndGetReplenishData({
    required this.validationStatus,
    required this.errorCode,
    required this.errorMessage,
    required this.atmCode,
    required this.idToolPrepare,
    required this.currentIdTool,
    this.codeBank = '',
    this.jnsMesin = '',
    this.lokasi = '',
    this.idTypeAtm = '',
    this.timeSTReturn = '',
    required this.catridges,
  });

  factory ValidateAndGetReplenishData.fromJson(Map<String, dynamic> json) {
    List<CatridgeReplenishData> catridgesList = [];
    
    if (json['catridges'] != null) {
      if (json['catridges'] is List) {
        catridgesList = (json['catridges'] as List)
            .map((item) => CatridgeReplenishData.fromJson(item))
            .toList();
      }
    }
    
    return ValidateAndGetReplenishData(
      validationStatus: json['validationStatus'] ?? '',
      errorCode: json['errorCode'] ?? '',
      errorMessage: json['errorMessage'] ?? '',
      atmCode: json['atmCode'] ?? '',
      idToolPrepare: json['idToolPrepare'] ?? '',
      currentIdTool: json['currentIdTool'] ?? 0,
      codeBank: json['codeBank'] ?? '',
      jnsMesin: json['jnsMesin'] ?? '',
      lokasi: json['lokasi'] ?? '',
      idTypeAtm: json['idTypeAtm'] ?? '',
      timeSTReturn: json['timeSTReturn'] ?? '',
      catridges: catridgesList,
    );
  }
}

// Model untuk response validasi return catridge dari API
class ReturnCatridgeValidationResponse {
  final bool success;
  final String message;
  final dynamic data;

  ReturnCatridgeValidationResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory ReturnCatridgeValidationResponse.fromJson(Map<String, dynamic> json) {
    return ReturnCatridgeValidationResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] ?? {},
    );
  }
}

// Model untuk response catridge replenish dari API
class CatridgeReplenishResponse {
  final bool success;
  final String message;
  final List<CatridgeReplenishData> data;

  CatridgeReplenishResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory CatridgeReplenishResponse.fromJson(Map<String, dynamic> json) {
    List<CatridgeReplenishData> dataList = [];
    
    if (json['data'] != null) {
      // Handle data if it's a JSON string
      if (json['data'] is String) {
        try {
          final List<dynamic> parsedData = jsonDecode(json['data'] as String);
          dataList = parsedData
              .map((item) => CatridgeReplenishData.fromJson(item))
              .toList();
        } catch (e) {
          print("Error parsing CatridgeReplenish data: $e");
        }
      } 
      // Handle data if it's already a list
      else if (json['data'] is List) {
        dataList = (json['data'] as List)
            .map((item) => CatridgeReplenishData.fromJson(item))
            .toList();
      }
      // Handle data if it contains a 'catridges' field which is a list
      else if (json['data'] is Map && json['data']['catridges'] is List) {
        dataList = (json['data']['catridges'] as List)
            .map((item) => CatridgeReplenishData.fromJson(item))
            .toList();
      }
    }

    return CatridgeReplenishResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: dataList,
    );
  }
}

// Model untuk data catridge replenish
class CatridgeReplenishData {
  final String dataType;
  final String catridgeCode;
  final String catridgeSeal;
  final String atmCode;
  final String tripType;
  final String bagCode;
  final String sealCode;
  final String sealCodeReturn;
  final String typeCatridgeTrx;

  CatridgeReplenishData({
    required this.dataType,
    required this.catridgeCode,
    required this.catridgeSeal,
    required this.atmCode,
    required this.tripType,
    this.bagCode = '',
    this.sealCode = '',
    this.sealCodeReturn = '',
    this.typeCatridgeTrx = '',
  });

  factory CatridgeReplenishData.fromJson(Map<String, dynamic> json) {
    return CatridgeReplenishData(
      dataType: json['dataType'] ?? 'REPLENISH_DATA',
      catridgeCode: json['catridgeCode'] ?? json['CatridgeCode'] ?? '',
      catridgeSeal: json['catridgeSeal'] ?? json['CatridgeSeal'] ?? '',
      atmCode: json['atmCode'] ?? '',
      tripType: json['tripType'] ?? '',
      bagCode: json['bagCode'] ?? '',
      sealCode: json['sealCode'] ?? '',
      sealCodeReturn: json['sealCodeReturn'] ?? '',
      typeCatridgeTrx: json['typeCatridgeTrx'] ?? '',
    );
  }
}

class ReturnCatridgeResponse {
  final bool success;
  final String message;
  final List<ReturnCatridgeData> data;
  final int recordCount;

  ReturnCatridgeResponse({
    required this.success,
    required this.message,
    required this.data,
    required this.recordCount,
  });

  factory ReturnCatridgeResponse.fromJson(Map<String, dynamic> json) {
    var dataList = json['data'] as List<dynamic>? ?? [];
    List<ReturnCatridgeData> returnCatridgeList = dataList
        .map((item) => ReturnCatridgeData.fromJson(item))
        .toList();

    return ReturnCatridgeResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: returnCatridgeList,
      recordCount: json['recordCount'] ?? 0,
    );
  }
}

class ReturnCatridgeData {
  final String idTool;
  final String catridgeCode;
  final String catridgeSeal;
  final String denomCode;
  final String typeCatridge;
  final String? bagCode; // Tambahkan bagCode
  final String? qty; // Tambahkan qty
  final String? typeCatridgeTrx; // Add typeCatridgeTrx property
  final String? sealCodeReturn; // Add sealCodeReturn property

  ReturnCatridgeData({
    required this.idTool,
    required this.catridgeCode,
    required this.catridgeSeal,
    required this.denomCode,
    required this.typeCatridge,
    this.bagCode, // Property opsional
    this.qty, // Property opsional
    this.typeCatridgeTrx, // Property opsional
    this.sealCodeReturn, // Property opsional
  });

  factory ReturnCatridgeData.fromJson(Map<String, dynamic> json) {
    return ReturnCatridgeData(
      idTool: json['idTool'] ?? '',
      catridgeCode: json['catridgeCode'] ?? '',
      catridgeSeal: json['catridgeSeal'] ?? '',
      denomCode: json['denomCode'] ?? '',
      typeCatridge: json['typeCatridge'] ?? '',
      bagCode: json['bagCode'], // Tambahkan mapping untuk bagCode
      qty: json['qty'], // Tambahkan mapping untuk qty
      typeCatridgeTrx: json['typeCatridgeTrx'] ?? 'C', // Default to 'C' if not provided
      sealCodeReturn: json['sealCodeReturn'], // Add mapping for sealCodeReturn
    );
  }
}

// Model for detail return items in the right panel
class DetailReturnItem {
  final int index;
  String noCatridge;
  String sealCatridge;
  int value;
  String total;
  String denom;

  DetailReturnItem({
    required this.index,
    this.noCatridge = '',
    this.sealCatridge = '',
    this.value = 0,
    this.total = '',
    this.denom = '',
  });
}

// Model for return data input
class ReturnInputData {
  final String idTool;
  final String bagCode;
  final String catridgeCode;
  final String sealCode;
  final String catridgeSeal;
  final String denomCode;
  final int qty;
  final String userInput;
  final bool isBalikKaset;
  final String catridgeCodeOld;

  ReturnInputData({
    required this.idTool,
    required this.bagCode,
    required this.catridgeCode,
    required this.sealCode,
    required this.catridgeSeal,
    required this.denomCode,
    required this.qty,
    required this.userInput,
    this.isBalikKaset = false,
    this.catridgeCodeOld = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'idTool': idTool,
      'bagCode': bagCode,
      'catridgeCode': catridgeCode,
      'sealCode': sealCode,
      'catridgeSeal': catridgeSeal,
      'denomCode': denomCode,
      'qty': qty.toString(),
      'userInput': userInput,
      'isBalikKaset': isBalikKaset ? 'Y' : 'N',
      'catridgeCodeOld': catridgeCodeOld,
      'scanCatStatus': 'TEST',
      'scanCatStatusRemark': 'TEST',
      'scanSealStatus': 'TEST',
      'scanSealStatusRemark': 'TEST',
    };
  }
}

class ReturnHeaderData {
  String atmCode;
  String namaBank;
  String lokasi;
  String typeATM;
  // Add new fields to match the API response
  String codeBank;
  String jnsMesin;
  String idTypeAtm;
  String timeSTReturn;

  ReturnHeaderData({
    this.atmCode = '',
    this.namaBank = '',
    this.lokasi = '',
    this.typeATM = '',
    this.codeBank = '',
    this.jnsMesin = '',
    this.idTypeAtm = '',
    this.timeSTReturn = '',
  });

  factory ReturnHeaderData.fromJson(Map<String, dynamic> json) {
    return ReturnHeaderData(
      atmCode: json['atmCode']?.toString() ?? '',
      namaBank: json['namaBank']?.toString() ?? '',
      lokasi: json['lokasi']?.toString() ?? '',
      typeATM: json['typeATM']?.toString() ?? '',
      codeBank: json['codeBank']?.toString() ?? '',
      jnsMesin: json['jnsMesin']?.toString() ?? '',
      idTypeAtm: json['idTypeAtm']?.toString() ?? '',
      timeSTReturn: json['timeSTReturn']?.toString() ?? '',
    );
  }
}

class ReturnHeaderResponse {
  final bool success;
  final String message;
  final ReturnHeaderData? header;
  final List<ReturnCatridgeData> data;

  ReturnHeaderResponse({
    required this.success,
    required this.message,
    this.header,
    required this.data,
  });

  factory ReturnHeaderResponse.fromJson(Map<String, dynamic> json) {
    return ReturnHeaderResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      header: json['header'] != null ? ReturnHeaderData.fromJson(json['header']) : null,
      data: (json['data'] as List<dynamic>? ?? [])
          .map((item) => ReturnCatridgeData.fromJson(item))
          .toList(),
    );
  }
}

class ReturnDataFromView {
  final String id;
  final String atmCode;
  final String namaBank;
  final String lokasi;
  final String typeATM;
  final String denomCode;
  final double total;

  ReturnDataFromView({
    required this.id,
    required this.atmCode,
    required this.namaBank,
    required this.lokasi,
    required this.typeATM,
    required this.denomCode,
    required this.total,
  });

  factory ReturnDataFromView.fromJson(Map<String, dynamic> json) {
    return ReturnDataFromView(
      id: json['id'] ?? '',
      atmCode: json['atmCode'] ?? '',
      namaBank: json['namaBank'] ?? '',
      lokasi: json['lokasi'] ?? '',
      typeATM: json['typeATM'] ?? '',
      denomCode: json['denomCode'] ?? '',
      total: (json['total'] ?? 0).toDouble(),
    );
  }
}

class ReturnDataFromViewResponse {
  final bool success;
  final String message;
  final List<ReturnDataFromView> data;

  ReturnDataFromViewResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory ReturnDataFromViewResponse.fromJson(Map<String, dynamic> json) {
    return ReturnDataFromViewResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: (json['data'] as List<dynamic>? ?? [])
          .map((item) => ReturnDataFromView.fromJson(item))
          .toList(),
    );
  }
}

// Note: ApiResponse and TLSupervisorValidationResponse are imported from prepare_model.dart