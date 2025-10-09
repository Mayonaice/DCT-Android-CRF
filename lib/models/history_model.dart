class HistoryResponse {
  final bool success;
  final String message;
  final List<HistoryItem> data;

  HistoryResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory HistoryResponse.fromJson(Map<String, dynamic> json) {
    List<HistoryItem> dataList = [];
    
    if (json['data'] != null) {
      if (json['data'] is List) {
        dataList = (json['data'] as List)
            .map((item) => HistoryItem.fromJson(item))
            .toList();
      }
    }

    return HistoryResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: dataList,
    );
  }
}

class HistoryItem {
  final String id;
  final String atmCode;
  final String timeStart;
  final String timeFinish;
  final String codeBank;
  final String lokasi;
  final String idTypeATM;
  final String total;

  HistoryItem({
    required this.id,
    required this.atmCode,
    required this.timeStart,
    required this.timeFinish,
    required this.codeBank,
    required this.lokasi,
    required this.idTypeATM,
    required this.total,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id']?.toString() ?? '',
      atmCode: json['atmCode']?.toString() ?? '',
      timeStart: json['timeStart']?.toString() ?? '',
      timeFinish: json['timeFinish']?.toString() ?? '',
      codeBank: json['codeBank']?.toString() ?? '',
      lokasi: json['lokasi']?.toString() ?? '',
      idTypeATM: json['idTypeATM']?.toString() ?? '',
      total: json['total']?.toString() ?? '',
    );
  }

  // Helper methods untuk format data sesuai requirement
  String get formattedStartTime {
    if (timeStart.isEmpty) return '--:--';
    try {
      final dateTime = DateTime.parse(timeStart);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--';
    }
  }

  String get formattedFinishTime {
    if (timeFinish.isEmpty) return '--:--';
    try {
      final dateTime = DateTime.parse(timeFinish);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--';
    }
  }

  String get formattedTotal {
    if (total.isEmpty) return '0';
    try {
      final number = double.parse(total);
      return number.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
    } catch (e) {
      return total;
    }
  }

  String get formattedDate {
    if (timeFinish.isEmpty) return '--';
    try {
      final dateTime = DateTime.parse(timeFinish);
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dateTime.day.toString().padLeft(2, '0')} ${months[dateTime.month]} ${dateTime.year}';
    } catch (e) {
      return '--';
    }
  }
}

class HistoryRequest {
  final String branchCode;
  final String userId;

  HistoryRequest({
    required this.branchCode,
    required this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'branchcode': branchCode,
      'userId': userId,
    };
  }
}