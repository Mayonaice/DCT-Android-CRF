class PenguranganData {
  final String? id;
  final String? jenis; // "Penambahan" or "Pengurangan"
  final String? tanggalReplenish; // TglPrepare converted to "dd MMM yyyy"
  final String? tanggalProses; // TimeInput converted to "dd MMM yyyy"
  final String? bank; // CodeBank
  final String? mesin; // JnsMesin
  final int? a1;
  final int? a2;
  final int? a5;
  final int? a10;
  final int? a20;
  final int? a50;
  final int? a75;
  final int? a100;
  final String? userInput;
  final String? keterangan;
  final String? closingDate;
  final String? tlCode;
  final String? branchCode;

  PenguranganData({
    this.id,
    this.jenis,
    this.tanggalReplenish,
    this.tanggalProses,
    this.bank,
    this.mesin,
    this.a1,
    this.a2,
    this.a5,
    this.a10,
    this.a20,
    this.a50,
    this.a75,
    this.a100,
    this.userInput,
    this.keterangan,
    this.closingDate,
    this.tlCode,
    this.branchCode,
  });

  factory PenguranganData.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse integers
    int? parseIntSafely(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    return PenguranganData(
      id: json['id']?.toString(),
      jenis: json['jenis']?.toString(),
      tanggalReplenish: json['tanggalReplenish']?.toString(),
      tanggalProses: json['tanggalProses']?.toString(),
      bank: json['bank']?.toString(),
      mesin: json['mesin']?.toString(),
      a1: parseIntSafely(json['a1']),
      a2: parseIntSafely(json['a2']),
      a5: parseIntSafely(json['a5']),
      a10: parseIntSafely(json['a10']),
      a20: parseIntSafely(json['a20']),
      a50: parseIntSafely(json['a50']),
      a75: parseIntSafely(json['a75']),
      a100: parseIntSafely(json['a100']),
      userInput: json['userInput']?.toString(),
      keterangan: json['keterangan']?.toString(),
      closingDate: json['closingDate']?.toString(),
      tlCode: json['tlCode']?.toString(),
      branchCode: json['branchCode']?.toString(),
    );
  }
}