class PenguranganInsertRequest {
  final String codeBank;
  final String jnsMesin;
  final String jenis;
  final DateTime? tglPrepare;
  final int? a100;
  final int? a75;
  final int? a50;
  final int? a20;
  final int? a10;
  final int? a5;
  final int? a2;
  final int? a1;
  final String? userInput;
  final String tlCode; // Not nullable anymore
  final String? keterangan;
  final String? branchCode;

  PenguranganInsertRequest({
    required this.codeBank,
    required this.jnsMesin,
    required this.jenis,
    this.tglPrepare,
    this.a100,
    this.a75,
    this.a50,
    this.a20,
    this.a10,
    this.a5,
    this.a2,
    this.a1,
    this.userInput,
    required this.tlCode,
    this.keterangan,
    this.branchCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'codeBank': codeBank,
      'jnsMesin': jnsMesin,
      'jenis': jenis,
      'tglPrepare': tglPrepare?.toIso8601String(),
      'a100': a100,
      'a75': a75,
      'a50': a50,
      'a20': a20,
      'a10': a10,
      'a5': a5,
      'a2': a2,
      'a1': a1,
      'userInput': userInput,
      'tlCode': tlCode,
      'keterangan': keterangan,
      'branchCode': branchCode,
    };
  }
}

class PenguranganInsertResponse {
  final bool success;
  final String message;
  final int? insertedID;

  PenguranganInsertResponse({
    required this.success,
    required this.message,
    this.insertedID,
  });

  factory PenguranganInsertResponse.fromJson(Map<String, dynamic> json) {
    return PenguranganInsertResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? 'Unknown response',
      insertedID: json['insertedID'],
    );
  }
}