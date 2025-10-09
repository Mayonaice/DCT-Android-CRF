class ClosingAndroidRequest {
  final String codeBank;
  final String jnsMesin;
  final String dateReplenish;

  ClosingAndroidRequest({
    required this.codeBank,
    required this.jnsMesin,
    required this.dateReplenish,
  });

  Map<String, dynamic> toJson() {
    return {
      'codeBank': codeBank,
      'jnsMesin': jnsMesin,
      'dateReplenish': dateReplenish,
    };
  }
}

class ClosingAndroidResponse {
  final bool success;
  final String message;
  final int? insertedID;

  ClosingAndroidResponse({
    required this.success,
    required this.message,
    this.insertedID,
  });

  factory ClosingAndroidResponse.fromJson(Map<String, dynamic> json) {
    return ClosingAndroidResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      insertedID: json['insertedID'],
    );
  }
}

class ClosingPreviewItem {
  final String id;
  final String codeBank;
  final String atmCode;
  final String jnsMesin;
  final String name;
  final String branchCode;
  final int a1Edit;
  final int a2Edit;
  final int a5Edit;
  final int a10Edit;
  final int a20Edit;
  final int a50Edit;
  final int a75Edit;
  final int a100Edit;
  final int tQtyEdit;
  final double tValueEdit;
  final String timeStart;
  final String timeFinish;
  final String isClosing;
  final String dateReplenish;

  ClosingPreviewItem({
    required this.id,
    required this.codeBank,
    required this.atmCode,
    required this.jnsMesin,
    required this.name,
    required this.branchCode,
    required this.a1Edit,
    required this.a2Edit,
    required this.a5Edit,
    required this.a10Edit,
    required this.a20Edit,
    required this.a50Edit,
    required this.a75Edit,
    required this.a100Edit,
    required this.tQtyEdit,
    required this.tValueEdit,
    required this.timeStart,
    required this.timeFinish,
    required this.isClosing,
    required this.dateReplenish,
  });

  factory ClosingPreviewItem.fromJson(Map<String, dynamic> json) {
    return ClosingPreviewItem(
      id: json['Id']?.toString() ?? '',
      codeBank: json['CodeBank']?.toString() ?? '',
      atmCode: json['AtmCode']?.toString() ?? '',
      jnsMesin: json['JnsMesin']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      branchCode: json['BranchCode']?.toString() ?? '',
      a1Edit: json['A1Edit'] is int ? json['A1Edit'] : int.tryParse(json['A1Edit']?.toString() ?? '0') ?? 0,
      a2Edit: json['A2Edit'] is int ? json['A2Edit'] : int.tryParse(json['A2Edit']?.toString() ?? '0') ?? 0,
      a5Edit: json['A5Edit'] is int ? json['A5Edit'] : int.tryParse(json['A5Edit']?.toString() ?? '0') ?? 0,
      a10Edit: json['A10Edit'] is int ? json['A10Edit'] : int.tryParse(json['A10Edit']?.toString() ?? '0') ?? 0,
      a20Edit: json['A20Edit'] is int ? json['A20Edit'] : int.tryParse(json['A20Edit']?.toString() ?? '0') ?? 0,
      a50Edit: json['A50Edit'] is int ? json['A50Edit'] : int.tryParse(json['A50Edit']?.toString() ?? '0') ?? 0,
      a75Edit: json['A75Edit'] is int ? json['A75Edit'] : int.tryParse(json['A75Edit']?.toString() ?? '0') ?? 0,
      a100Edit: json['A100Edit'] is int ? json['A100Edit'] : int.tryParse(json['A100Edit']?.toString() ?? '0') ?? 0,
      tQtyEdit: json['TQtyEdit'] is int ? json['TQtyEdit'] : int.tryParse(json['TQtyEdit']?.toString() ?? '0') ?? 0,
      tValueEdit: json['TValueEdit'] is double 
          ? json['TValueEdit'] 
          : double.tryParse(json['TValueEdit']?.toString() ?? '0.0') ?? 0.0,
      timeStart: json['TimeStart']?.toString() ?? '',
      timeFinish: json['TimeFinish']?.toString() ?? '',
      isClosing: json['IsClosing']?.toString() ?? '',
      dateReplenish: json['DateReplenish']?.toString() ?? '',
    );
  }
}