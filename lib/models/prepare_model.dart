class PrepareReplenishResponse {
  final bool success;
  final String message;
  final ATMPrepareReplenishData? data;
  final int recordCount;

  PrepareReplenishResponse({
    required this.success,
    required this.message,
    this.data,
    required this.recordCount,
  });

  factory PrepareReplenishResponse.fromJson(Map<String, dynamic> json) {
    return PrepareReplenishResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? ATMPrepareReplenishData.fromJson(json['data']) : null,
      recordCount: json['recordCount'] ?? 0,
    );
  }
}

class CatridgeDetail {
  final int id;
  final String code;
  final String seal;
  final int denom;
  final int value;
  final String typeCatridgeTrx;

  CatridgeDetail({
    required this.id,
    required this.code,
    required this.seal,
    required this.denom,
    required this.value,
    this.typeCatridgeTrx = 'C',
  });

  factory CatridgeDetail.fromJson(Map<String, dynamic> json) {
    return CatridgeDetail(
      id: json['id'] ?? 0,
      code: json['code'] ?? '',
      seal: json['seal'] ?? '',
      denom: json['denom'] ?? 0,
      value: json['value'] ?? 0,
      typeCatridgeTrx: json['typeCatridgeTrx'] ?? 'C',
    );
  }
}

class ATMPrepareReplenishData {
  final int id;
  final String planNo;
  final int idLokasi;
  final DateTime datePlanning;
  final String atmCode;
  final String jnsMesin;
  final String codeBank;
  final String idTypeATM;
  final String idCust1;
  final String idCust2;
  final String cashierCode;
  final DateTime? dateStart;
  final DateTime? dateFinish;
  final String tripType;
  final String bagCode;
  final String catridgeCode;
  final String sealCode;
  final String catridgeSeal;
  final String denomCode;
  final int qty;
  final String runCode;
  final String nmRun;
  final int value;
  final int total;
  final String lokasi;
  final String namaBank;
  final String name;
  final String typeCatridge;
  final DateTime? dateReplenish;
  final String siklusCode;
  final String tableCode;
  final String typeATM;
  final int jmlKaset;
  final int standValue;
  final String branchCode;
  final String kasir;
  final String tipeDenom;
  final int jumlah;
  final int denomCass1;
  final int denomCass2;
  final int denomCass3;
  final int denomCass4;
  final int denomCass5;
  final int denomCass6;
  final int denomCass7;
  final int jmlCass1;
  final int jmlCass2;
  final int jmlCass3;
  final int jmlCass4;
  final int jmlCass5;
  final int jmlCass6;
  final int jmlCass7;
  final bool isEmpty;
  final bool isNoBag;
  final bool isMDM;
  final List<CatridgeDetail> listCatridge;
  final CatridgeDetail? divertCatridge;
  final CatridgeDetail? pocketCatridge;

  ATMPrepareReplenishData({
    required this.id,
    required this.planNo,
    required this.idLokasi,
    required this.datePlanning,
    required this.atmCode,
    required this.jnsMesin,
    required this.codeBank,
    required this.idTypeATM,
    required this.idCust1,
    required this.idCust2,
    required this.cashierCode,
    this.dateStart,
    this.dateFinish,
    required this.tripType,
    required this.bagCode,
    required this.catridgeCode,
    required this.sealCode,
    required this.catridgeSeal,
    required this.denomCode,
    required this.qty,
    required this.runCode,
    required this.nmRun,
    required this.value,
    required this.total,
    required this.lokasi,
    required this.namaBank,
    required this.name,
    required this.typeCatridge,
    this.dateReplenish,
    required this.siklusCode,
    required this.tableCode,
    required this.typeATM,
    required this.jmlKaset,
    required this.standValue,
    required this.branchCode,
    required this.kasir,
    required this.tipeDenom,
    required this.jumlah,
    required this.denomCass1,
    required this.denomCass2,
    required this.denomCass3,
    required this.denomCass4,
    required this.denomCass5,
    required this.denomCass6,
    required this.denomCass7,
    required this.jmlCass1,
    required this.jmlCass2,
    required this.jmlCass3,
    required this.jmlCass4,
    required this.jmlCass5,
    required this.jmlCass6,
    required this.jmlCass7,
    required this.isEmpty,
    required this.isNoBag,
    required this.isMDM,
    required this.listCatridge,
    this.divertCatridge,
    this.pocketCatridge,
  });

  factory ATMPrepareReplenishData.fromJson(Map<String, dynamic> json) {
    List<CatridgeDetail> catridgeList = [];
    
    // Check for catridge data in different formats
    if (json['listCatridge'] != null) {
      // If listCatridge field is present as an array
      catridgeList = (json['listCatridge'] as List)
          .map((item) => CatridgeDetail.fromJson(item))
          .toList();
    } else {
      // Create a synthetic list from individual catridge data
      // Add each catridge that has valid data
      if (json['catridgeCode'] != null && json['catridgeCode'].toString().isNotEmpty) {
        catridgeList.add(CatridgeDetail(
          id: 1,
          code: json['catridgeCode'] ?? '',
          seal: json['catridgeSeal'] ?? '',
          denom: json['denomCass1'] ?? 0,
          value: json['value'] ?? 0,
          typeCatridgeTrx: 'C',
        ));
      }
      
      // Add additional catridges based on jmlKaset if needed
      int jmlKaset = json['jmlKaset'] ?? 0;
      for (int i = 1; i < jmlKaset; i++) {
        if (i >= catridgeList.length) {
          catridgeList.add(CatridgeDetail(
            id: i + 1,
            code: '',
            seal: '',
            denom: i == 1 ? (json['denomCass2'] ?? 0) :
                  i == 2 ? (json['denomCass3'] ?? 0) :
                  i == 3 ? (json['denomCass4'] ?? 0) :
                  i == 4 ? (json['denomCass5'] ?? 0) :
                  i == 5 ? (json['denomCass6'] ?? 0) :
                  i == 6 ? (json['denomCass7'] ?? 0) : 0,
            value: 0,
            typeCatridgeTrx: 'C',
          ));
        }
      }
    }

    // Parse divert and pocket catridge if present
    CatridgeDetail? divertCatridge;
    if (json['divertCatridge'] != null) {
      divertCatridge = CatridgeDetail.fromJson({
        ...json['divertCatridge'],
        'typeCatridgeTrx': 'D',
      });
    }

    CatridgeDetail? pocketCatridge;
    if (json['pocketCatridge'] != null) {
      pocketCatridge = CatridgeDetail.fromJson({
        ...json['pocketCatridge'],
        'typeCatridgeTrx': 'P',
      });
    }
    
    return ATMPrepareReplenishData(
      id: json['id'] ?? 0,
      planNo: json['planNo'] ?? '',
      idLokasi: json['idLokasi'] ?? 0,
      datePlanning: json['datePlanning'] != null ? DateTime.parse(json['datePlanning']) : DateTime.now(),
      atmCode: json['atmCode'] ?? '',
      jnsMesin: json['jnsMesin'] ?? '',
      codeBank: json['codeBank'] ?? '',
      idTypeATM: json['idTypeATM'] ?? '',
      idCust1: json['idCust1'] ?? '',
      idCust2: json['idCust2'] ?? '',
      cashierCode: json['cashierCode'] ?? '',
      dateStart: json['dateStart'] != null ? DateTime.parse(json['dateStart']) : null,
      dateFinish: json['dateFinish'] != null ? DateTime.parse(json['dateFinish']) : null,
      tripType: json['tripType'] ?? '',
      bagCode: json['bagCode'] ?? '',
      catridgeCode: json['catridgeCode'] ?? '',
      sealCode: json['sealCode'] ?? '',
      catridgeSeal: json['catridgeSeal'] ?? '',
      denomCode: json['denomCode'] ?? '',
      qty: json['qty'] ?? 0,
      runCode: json['runCode'] ?? '',
      nmRun: json['nmRun'] ?? '',
      value: json['value'] ?? 0,
      total: json['total'] ?? 0,
      lokasi: json['lokasi'] ?? '',
      namaBank: json['namaBank'] ?? '',
      name: json['name'] ?? '',
      typeCatridge: json['typeCatridge'] ?? '',
      dateReplenish: json['dateReplenish'] != null ? DateTime.parse(json['dateReplenish']) : null,
      siklusCode: json['siklusCode'] ?? '',
      tableCode: json['tableCode'] ?? '',
      typeATM: json['typeATM'] ?? '',
      jmlKaset: json['jmlKaset'] ?? 0,
      standValue: json['standValue'] ?? 0,
      branchCode: json['branchCode'] ?? '',
      kasir: json['kasir'] ?? '',
      tipeDenom: json['tipeDenom'] ?? '',
      jumlah: json['jumlah'] ?? 0,
      denomCass1: json['denomCass1'] ?? 0,
      denomCass2: json['denomCass2'] ?? 0,
      denomCass3: json['denomCass3'] ?? 0,
      denomCass4: json['denomCass4'] ?? 0,
      denomCass5: json['denomCass5'] ?? 0,
      denomCass6: json['denomCass6'] ?? 0,
      denomCass7: json['denomCass7'] ?? 0,
      jmlCass1: json['jmlCass1'] ?? 0,
      jmlCass2: json['jmlCass2'] ?? 0,
      jmlCass3: json['jmlCass3'] ?? 0,
      jmlCass4: json['jmlCass4'] ?? 0,
      jmlCass5: json['jmlCass5'] ?? 0,
      jmlCass6: json['jmlCass6'] ?? 0,
      jmlCass7: json['jmlCass7'] ?? 0,
      isEmpty: json['isEmpty'] ?? false,
      isNoBag: json['isNoBag'] ?? false,
      isMDM: json['isMDM'] ?? false,
      listCatridge: catridgeList,
      divertCatridge: divertCatridge,
      pocketCatridge: pocketCatridge,
    );
  }
}

// Model for catridge lookup response
class CatridgeData {
  final String code;
  final String barCode;
  final String typeCatridge;
  final String codeBank;
  final num standValue;  // Changed from int to num to handle all numeric types

  CatridgeData({
    required this.code,
    required this.barCode,
    required this.typeCatridge,
    required this.codeBank,
    required this.standValue,
  });

  factory CatridgeData.fromJson(Map<String, dynamic> json) {
    // First normalize the keys to handle mixed case in API response
    Map<String, dynamic> normalizedJson = {};
    json.forEach((key, value) {
      normalizedJson[key.toLowerCase()] = value;
    });
    
    // Handle potentially null or invalid format values
    num standValue = 0;
    try {
      // Try to safely parse standValue with various key formats
      if (normalizedJson.containsKey('standvalue')) {
        var sv = normalizedJson['standvalue'];
        if (sv is num) {
          standValue = sv;
        } else if (sv is String) {
          standValue = num.tryParse(sv) ?? 0;
        }
      }
    } catch (e) {
      print('Error parsing StandValue: $e');
    }
    
    // Make sure all string values are handled correctly with normalized keys
    String code = '';
    if (normalizedJson.containsKey('code')) {
      code = normalizedJson['code'].toString();
    }
    
    String barCode = '';
    if (normalizedJson.containsKey('barcode')) {
      barCode = normalizedJson['barcode'].toString();
    }
    
    String typeCatridge = '';
    if (normalizedJson.containsKey('typecatridge')) {
      typeCatridge = normalizedJson['typecatridge'].toString();
    }
    
    String codeBank = '';
    if (normalizedJson.containsKey('codebank')) {
      codeBank = normalizedJson['codebank'].toString();
    }
    
    return CatridgeData(
      code: code,
      barCode: barCode,
      typeCatridge: typeCatridge,
      codeBank: codeBank,
      standValue: standValue,
    );
  }
}

class CatridgeResponse {
  final bool success;
  final String message;
  final List<CatridgeData> data;
  final String? errorType;

  CatridgeResponse({
    required this.success,
    required this.message,
    required this.data,
    this.errorType,
  });

  factory CatridgeResponse.fromJson(Map<String, dynamic> json) {
    var dataList = json['data'] as List<dynamic>? ?? [];
    List<CatridgeData> catridgeList = dataList
        .map((item) => CatridgeData.fromJson(item))
        .toList();

    return CatridgeResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: catridgeList,
      errorType: json['errorType'],
    );
  }
}

// Model for comprehensive seal validation response from SP
class SealValidationData {
  final String validationStatus;
  final String errorCode;
  final String errorMessage;
  final String validatedSealCode;
  final DateTime validationDate;
  final String requestedSealCode;

  SealValidationData({
    required this.validationStatus,
    required this.errorCode,
    required this.errorMessage,
    required this.validatedSealCode,
    required this.validationDate,
    required this.requestedSealCode,
  });

  factory SealValidationData.fromJson(Map<String, dynamic> json) {
    // Normalize keys to handle case insensitivity
    Map<String, dynamic> normalizedJson = {};
    json.forEach((key, value) {
      normalizedJson[key.toLowerCase()] = value;
    });
    
    // Parse validation status with fallbacks
    String status = '';
    if (normalizedJson.containsKey('validationstatus')) {
      status = normalizedJson['validationstatus'].toString();
    } else if (normalizedJson.containsKey('status')) {
      status = normalizedJson['status'].toString();
    } else if (normalizedJson.containsKey('validation_status')) {
      status = normalizedJson['validation_status'].toString();
    }
    
    // Parse error code with fallbacks
    String errorCode = '';
    if (normalizedJson.containsKey('errorcode')) {
      errorCode = normalizedJson['errorcode'].toString();
    } else if (normalizedJson.containsKey('error_code')) {
      errorCode = normalizedJson['error_code'].toString();
    }
    
    // Parse error message with fallbacks
    String errorMsg = '';
    if (normalizedJson.containsKey('errormessage')) {
      errorMsg = normalizedJson['errormessage'].toString();
    } else if (normalizedJson.containsKey('error_message')) {
      errorMsg = normalizedJson['error_message'].toString();
    } else if (normalizedJson.containsKey('message')) {
      errorMsg = normalizedJson['message'].toString();
    }
    
    // Parse validated seal code with fallbacks
    String validatedCode = '';
    if (normalizedJson.containsKey('validatedsealcode')) {
      validatedCode = normalizedJson['validatedsealcode'].toString();
    } else if (normalizedJson.containsKey('validated_seal_code')) {
      validatedCode = normalizedJson['validated_seal_code'].toString();
    } else if (normalizedJson.containsKey('sealcode')) {
      validatedCode = normalizedJson['sealcode'].toString();
    } else if (normalizedJson.containsKey('seal_code')) {
      validatedCode = normalizedJson['seal_code'].toString();
    }
    
    // If we don't have a validated code but do have a requested code, use the requested code if validation is successful
    if (validatedCode.isEmpty && normalizedJson.containsKey('requestedsealcode') && status.toUpperCase() == 'SUCCESS') {
      validatedCode = normalizedJson['requestedsealcode'].toString();
    }
    
    // Parse validation date with fallbacks
    DateTime validationDate = DateTime.now();
    try {
      if (normalizedJson.containsKey('validationdate')) {
        var dateValue = normalizedJson['validationdate'];
        if (dateValue is String) {
          validationDate = DateTime.parse(dateValue);
        }
      } else if (normalizedJson.containsKey('validation_date')) {
        var dateValue = normalizedJson['validation_date'];
        if (dateValue is String) {
          validationDate = DateTime.parse(dateValue);
        }
      }
    } catch (e) {
      print('Error parsing validation date: $e');
    }
    
    // Parse requested seal code with fallbacks
    String requestedCode = '';
    if (normalizedJson.containsKey('requestedsealcode')) {
      requestedCode = normalizedJson['requestedsealcode'].toString();
    } else if (normalizedJson.containsKey('requested_seal_code')) {
      requestedCode = normalizedJson['requested_seal_code'].toString();
    } else if (normalizedJson.containsKey('input_seal')) {
      requestedCode = normalizedJson['input_seal'].toString();
    }
    
    return SealValidationData(
      validationStatus: status,
      errorCode: errorCode,
      errorMessage: errorMsg,
      validatedSealCode: validatedCode,
      validationDate: validationDate,
      requestedSealCode: requestedCode,
    );
  }
}

class SealValidationResponse {
  final bool success;
  final String message;
  final SealValidationData? data;

  SealValidationResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory SealValidationResponse.fromJson(Map<String, dynamic> json) {
    // Normalize keys to handle case insensitivity
    Map<String, dynamic> normalizedJson = {};
    json.forEach((key, value) {
      normalizedJson[key.toLowerCase()] = value;
    });
    
    // Handle API response with different formats
    bool isSuccess = false;
    if (normalizedJson.containsKey('success')) {
      isSuccess = normalizedJson['success'] == true;
    } else if (normalizedJson.containsKey('status')) {
      isSuccess = normalizedJson['status'].toString().toLowerCase() == 'success';
    }
    
    String msg = '';
    if (normalizedJson.containsKey('message')) {
      msg = normalizedJson['message'].toString();
    }
    
    // Handle data in different formats
    SealValidationData? validationData;
    if (normalizedJson.containsKey('data')) {
      var dataValue = normalizedJson['data'];
      if (dataValue != null) {
        // Convert the Map<dynamic, dynamic> to Map<String, dynamic>
        if (dataValue is Map) {
          Map<String, dynamic> stringKeyMap = {};
          dataValue.forEach((key, value) {
            stringKeyMap[key.toString()] = value;
          });
          validationData = SealValidationData.fromJson(stringKeyMap);
        } else {
          validationData = SealValidationData.fromJson(normalizedJson);
        }
      }
    } else {
      // If no data field, try to parse directly from root
      validationData = SealValidationData.fromJson(normalizedJson);
    }
    
    return SealValidationResponse(
      success: isSuccess,
      message: msg,
      data: validationData,
    );
  }
}

// Model for detail catridge items in the right panel
class DetailCatridgeItem {
  final int index;
  String noCatridge;
  String sealCatridge;
  int value;
  String total;
  String denom;
  String bagCode;
  String sealCode;
  String sealReturn;

  DetailCatridgeItem({
    required this.index,
    this.noCatridge = '',
    this.sealCatridge = '',
    this.value = 0,
    this.total = '',
    this.denom = '',
    this.bagCode = '',
    this.sealCode = '',
    this.sealReturn = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'noCatridge': noCatridge,
      'sealCatridge': sealCatridge,
      'value': value,
      'total': total,
      'denom': denom,
      'bagCode': bagCode,
      'sealCode': sealCode,
      'sealReturn': sealReturn,
    };
  }
}

// Generic API Response model for planning/update and atm/catridge APIs
class ApiResponse {
  final bool success;
  final String message;
  final dynamic data;
  final String? status;  // Added for SP response compatibility
  final int? insertedId; // Added for insert operations - NOW OPTIONAL

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.status,
    this.insertedId, // Made optional to avoid errors with APIs that don't support it
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    // Normalize keys to handle case insensitivity
    Map<String, dynamic> normalizedJson = {};
    json.forEach((key, value) {
      normalizedJson[key.toLowerCase()] = value;
    });
    
    // Handle both API controller response and direct SP response
    bool isSuccess = false;
    if (normalizedJson.containsKey('success')) {
      isSuccess = normalizedJson['success'] == true;
    } else if (normalizedJson.containsKey('status')) {
      isSuccess = normalizedJson['status'].toString().toLowerCase() == 'success';
    }
    
    String msg = '';
    if (normalizedJson.containsKey('message')) {
      msg = normalizedJson['message'].toString();
    } else if (normalizedJson.containsKey('msg')) {
      msg = normalizedJson['msg'].toString();
    }
    
    dynamic responseData;
    if (normalizedJson.containsKey('data')) {
      responseData = normalizedJson['data'];
    }
    
    String? statusValue;
    if (normalizedJson.containsKey('status')) {
      statusValue = normalizedJson['status'].toString();
    }
    
    // Only try to extract insertedId if we're confident it's there
    // This avoids the error "Column 'InsertedId' does not belong to table"
    int? insertedIdValue;
    try {
      if (normalizedJson.containsKey('insertedid')) {
        var idValue = normalizedJson['insertedid'];
        if (idValue != null) {
          if (idValue is int) {
            insertedIdValue = idValue;
          } else if (idValue is String) {
            insertedIdValue = int.tryParse(idValue);
          }
        }
      }
    } catch (e) {
      // Ignore any errors when trying to get insertedId
      // It's better to have a successful response without this field
      // than to fail the entire parsing
    }
    
    return ApiResponse(
      success: isSuccess,
      message: msg,
      data: responseData,
      status: statusValue,
      insertedId: insertedIdValue,
    );
  }
}

// TL Supervisor Validation Models
class TLSupervisorValidationData {
  final String validationStatus;
  final String errorMessage;
  final String userRole;
  final String userName;
  final String nik;

  TLSupervisorValidationData({
    required this.validationStatus,
    required this.errorMessage,
    required this.userRole,
    required this.userName,
    required this.nik,
  });

  factory TLSupervisorValidationData.fromJson(Map<String, dynamic> json) {
    return TLSupervisorValidationData(
      validationStatus: json['validationStatus'] ?? '',
      errorMessage: json['errorMessage'] ?? '',
      userRole: json['userRole'] ?? '',
      userName: json['userName'] ?? '',
      nik: json['nik'] ?? '',
    );
  }
}

class TLSupervisorValidationResponse {
  final bool success;
  final String message;
  final TLSupervisorValidationData? data;

  TLSupervisorValidationResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory TLSupervisorValidationResponse.fromJson(Map<String, dynamic> json) {
    return TLSupervisorValidationResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? TLSupervisorValidationData.fromJson(json['data']) : null,
    );
  }
} 

// Model untuk data catridge yang akan dikirimkan dalam QR code
class CatridgeQRData {
  final String idTool;
  final String bagCode;
  final String catridgeCode;
  final String sealCode;
  final String catridgeSeal;
  final String denomCode;
  final String qty;
  final String userInput;
  final String sealReturn;
  final String typeCatridgeTrx;
  final String tableCode;
  final String warehouseCode;
  final String operatorId;
  final String operatorName;

  CatridgeQRData({
    required this.idTool,
    required this.bagCode,
    required this.catridgeCode,
    required this.sealCode,
    required this.catridgeSeal,
    required this.denomCode,
    required this.qty,
    required this.userInput,
    required this.sealReturn,
    required this.typeCatridgeTrx,
    required this.tableCode,
    required this.warehouseCode,
    required this.operatorId,
    required this.operatorName,
  });

  Map<String, dynamic> toJson() {
    return {
      'idTool': idTool,
      'bagCode': bagCode,
      'catridgeCode': catridgeCode,
      'sealCode': sealCode,
      'catridgeSeal': catridgeSeal,
      'denomCode': denomCode,
      'qty': qty,
      'userInput': userInput,
      'sealReturn': sealReturn,
      'typeCatridgeTrx': typeCatridgeTrx,
      'tableCode': tableCode,
      'warehouseCode': warehouseCode,
      'operatorId': operatorId,
      'operatorName': operatorName,
    };
  }

  factory CatridgeQRData.fromJson(Map<String, dynamic> json) {
    return CatridgeQRData(
      idTool: json['idTool']?.toString() ?? '0',
      bagCode: json['bagCode'] as String,
      catridgeCode: json['catridgeCode'] as String,
      sealCode: json['sealCode'] as String,
      catridgeSeal: json['catridgeSeal'] as String,
      denomCode: json['denomCode'] as String,
      qty: json['qty'] as String,
      userInput: json['userInput'] as String,
      sealReturn: json['sealReturn'] as String,
      typeCatridgeTrx: json['typeCatridgeTrx'] as String,
      tableCode: json['tableCode'] as String,
      warehouseCode: json['warehouseCode'] as String,
      operatorId: json['operatorId'] as String,
      operatorName: json['operatorName'] as String,
    );
  }
}

// Model untuk data QR code yang berisi informasi catridge dan kredensial TL
class PrepareQRData {
  final String action;
  final int timestamp;
  final List<CatridgeQRData> catridges;

  PrepareQRData({
    required this.action,
    required this.timestamp,
    required this.catridges,
  });

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'timestamp': timestamp,
      'catridges': catridges.map((c) => c.toJson()).toList(),
    };
  }

  factory PrepareQRData.fromJson(Map<String, dynamic> json) {
    return PrepareQRData(
      action: json['action'] as String,
      timestamp: json['timestamp'] as int,
      catridges: (json['catridges'] as List)
          .map((c) => CatridgeQRData.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}