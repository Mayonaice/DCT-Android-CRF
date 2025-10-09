class UpdateQtyCatridgeRequest {
  final String idTool;
  final String a1;
  final String a2;
  final String a5;
  final String a10;
  final String a20;
  final String a50;
  final String a75;
  final String a100;
  final String user;
  final String spvTLCode;
  final String? tableCode; // Optional parameter for TableCode

  UpdateQtyCatridgeRequest({
    required this.idTool,
    this.a1 = "0",
    this.a2 = "0",
    this.a5 = "0",
    this.a10 = "0",
    this.a20 = "0",
    this.a50 = "0",
    this.a75 = "0",
    this.a100 = "0",
    required this.user,
    required this.spvTLCode,
    this.tableCode, // Optional parameter
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'IdTool': idTool,
      'A1': a1,
      'A2': a2,
      'A5': a5,
      'A10': a10,
      'A20': a20,
      'A50': a50,
      'A75': a75,
      'A100': a100,
      'User': user, // This is the field expected by the API
      'SpvTLCode': spvTLCode,
    };
    
    // Only add TableCode if it's not null and not empty
    if (tableCode != null && tableCode!.isNotEmpty) {
      data['TableCode'] = tableCode;
    }
    
    return data;
  }
}