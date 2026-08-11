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
      success: json['success'] ?? json['Success'] ?? false,
      message: json['message']?.toString() ?? json['Message']?.toString() ?? '',
      insertedID: json['insertedID'] ?? json['InsertedID'],
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
  final int a1Default;
  final int a2Default;
  final int a5Default;
  final int a10Default;
  final int a20Default;
  final int a50Default;
  final int a75Default;
  final int a100Default;
  final int a1Edit;
  final int a2Edit;
  final int a5Edit;
  final int a10Edit;
  final int a20Edit;
  final int a50Edit;
  final int a75Edit;
  final int a100Edit;
  final int a1Pengurangan;
  final int a2Pengurangan;
  final int a5Pengurangan;
  final int a10Pengurangan;
  final int a20Pengurangan;
  final int a50Pengurangan;
  final int a75Pengurangan;
  final int a100Pengurangan;
  final int a1Penambahan;
  final int a2Penambahan;
  final int a5Penambahan;
  final int a10Penambahan;
  final int a20Penambahan;
  final int a50Penambahan;
  final int a75Penambahan;
  final int a100Penambahan;
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
    required this.a1Default,
    required this.a2Default,
    required this.a5Default,
    required this.a10Default,
    required this.a20Default,
    required this.a50Default,
    required this.a75Default,
    required this.a100Default,
    required this.a1Edit,
    required this.a2Edit,
    required this.a5Edit,
    required this.a10Edit,
    required this.a20Edit,
    required this.a50Edit,
    required this.a75Edit,
    required this.a100Edit,
    required this.a1Pengurangan,
    required this.a2Pengurangan,
    required this.a5Pengurangan,
    required this.a10Pengurangan,
    required this.a20Pengurangan,
    required this.a50Pengurangan,
    required this.a75Pengurangan,
    required this.a100Pengurangan,
    required this.a1Penambahan,
    required this.a2Penambahan,
    required this.a5Penambahan,
    required this.a10Penambahan,
    required this.a20Penambahan,
    required this.a50Penambahan,
    required this.a75Penambahan,
    required this.a100Penambahan,
    required this.tQtyEdit,
    required this.tValueEdit,
    required this.timeStart,
    required this.timeFinish,
    required this.isClosing,
    required this.dateReplenish,
  });

  factory ClosingPreviewItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    return ClosingPreviewItem(
      id: json['ConsoleIdTool']?.toString() ?? json['Id']?.toString() ?? '',
      codeBank: json['CodeBank']?.toString() ?? '',
      atmCode: json['AtmCode']?.toString() ?? '',
      jnsMesin: json['JnsMesin']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      branchCode: json['BranchCode']?.toString() ?? '',
      a1Default: parseInt(json['A1Default']),
      a2Default: parseInt(json['A2Default']),
      a5Default: parseInt(json['A5Default']),
      a10Default: parseInt(json['A10Default']),
      a20Default: parseInt(json['A20Default']),
      a50Default: parseInt(json['A50Default']),
      a75Default: parseInt(json['A75Default']),
      a100Default: parseInt(json['A100Default']),
      a1Edit: parseInt(json['A1Edit']),
      a2Edit: parseInt(json['A2Edit']),
      a5Edit: parseInt(json['A5Edit']),
      a10Edit: parseInt(json['A10Edit']),
      a20Edit: parseInt(json['A20Edit']),
      a50Edit: parseInt(json['A50Edit']),
      a75Edit: parseInt(json['A75Edit']),
      a100Edit: parseInt(json['A100Edit']),
      a1Pengurangan: parseInt(json['A1Pengurangan']),
      a2Pengurangan: parseInt(json['A2Pengurangan']),
      a5Pengurangan: parseInt(json['A5Pengurangan']),
      a10Pengurangan: parseInt(json['A10Pengurangan']),
      a20Pengurangan: parseInt(json['A20Pengurangan']),
      a50Pengurangan: parseInt(json['A50Pengurangan']),
      a75Pengurangan: parseInt(json['A75Pengurangan']),
      a100Pengurangan: parseInt(json['A100Pengurangan']),
      a1Penambahan: parseInt(json['A1Penambahan']),
      a2Penambahan: parseInt(json['A2Penambahan']),
      a5Penambahan: parseInt(json['A5Penambahan']),
      a10Penambahan: parseInt(json['A10Penambahan']),
      a20Penambahan: parseInt(json['A20Penambahan']),
      a50Penambahan: parseInt(json['A50Penambahan']),
      a75Penambahan: parseInt(json['A75Penambahan']),
      a100Penambahan: parseInt(json['A100Penambahan']),
      tQtyEdit: parseInt(json['TQtyEdit']),
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
