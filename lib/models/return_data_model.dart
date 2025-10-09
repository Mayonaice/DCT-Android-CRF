class ReturnData {
  final String id;
  final String codeBank;
  final String atmCode;
  final String jnsMesin;
  final String name;
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
  final String branchCode;
  final String? dateSTReturn;
  final String? tglPrepare;
  final String? dateReplenish;
  final String? actualDateReplenish;
  final String? keterangan;
  final String? typeData;
  final String? typeDataReturn;

  ReturnData({
    required this.id,
    required this.codeBank,
    required this.atmCode,
    required this.jnsMesin,
    required this.name,
    this.denomCode,
    this.a1 = 0,
    this.a2 = 0,
    this.a5 = 0,
    this.a10 = 0,
    this.a20 = 0,
    this.a50 = 0,
    this.a75 = 0,
    this.a100 = 0,
    this.tQty = 0,
    this.tValue = 0,
    required this.branchCode,
    this.dateSTReturn,
    this.tglPrepare,
    this.dateReplenish,
    this.actualDateReplenish,
    this.keterangan,
    this.typeData,
    this.typeDataReturn,
  });

  factory ReturnData.fromJson(Map<String, dynamic> json) {
    return ReturnData(
      id: json['Id']?.toString() ?? '',
      codeBank: json['CodeBank']?.toString() ?? '',
      atmCode: json['AtmCode']?.toString() ?? '',
      jnsMesin: json['JnsMesin']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      denomCode: json['DenomCode']?.toString(),
      a1: json['A1'] != null ? int.tryParse(json['A1'].toString()) ?? 0 : 0,
      a2: json['A2'] != null ? int.tryParse(json['A2'].toString()) ?? 0 : 0,
      a5: json['A5'] != null ? int.tryParse(json['A5'].toString()) ?? 0 : 0,
      a10: json['A10'] != null ? int.tryParse(json['A10'].toString()) ?? 0 : 0,
      a20: json['A20'] != null ? int.tryParse(json['A20'].toString()) ?? 0 : 0,
      a50: json['A50'] != null ? int.tryParse(json['A50'].toString()) ?? 0 : 0,
      a75: json['A75'] != null ? int.tryParse(json['A75'].toString()) ?? 0 : 0,
      a100: json['A100'] != null ? int.tryParse(json['A100'].toString()) ?? 0 : 0,
      tQty: json['TQty'] != null ? int.tryParse(json['TQty'].toString()) ?? 0 : 0,
      tValue: json['TValue'] != null ? int.tryParse(json['TValue'].toString()) ?? 0 : 0,
      branchCode: json['BranchCode']?.toString() ?? '',
      dateSTReturn: json['DateSTReturn']?.toString(),
      tglPrepare: json['TglPrepare']?.toString(),
      dateReplenish: json['DateReplenish']?.toString(),
      actualDateReplenish: json['ActualDateReplenish']?.toString(),
      keterangan: json['Keterangan']?.toString(),
      typeData: json['TypeData']?.toString(),
      typeDataReturn: json['TypeDataReturn']?.toString(),
    );
  }
}