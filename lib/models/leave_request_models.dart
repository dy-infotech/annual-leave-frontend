class LeaveRequestCreate {
  final DateTime startDate;
  final DateTime endDate;
  final double useDays;

  LeaveRequestCreate({
    required this.startDate,
    required this.endDate,
    required this.useDays,
  });

  Map<String, dynamic> toJson() => {
        'startDate': _formatDate(startDate),
        'endDate': _formatDate(endDate),
        'useDays': useDays,
      };

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class LeaveRequestListItem {
  final int requestId;
  final String employeeName;
  final String position;
  final String department;
  final String requestedAt;
  final String startDate;
  final String endDate;
  final double useDays;
  final String status;
  final String? rejectReason;   // 반려 시에만 값 존재

  LeaveRequestListItem({
    required this.requestId,
    required this.employeeName,
    required this.position,
    required this.department,
    required this.requestedAt,
    required this.startDate,
    required this.endDate,
    required this.useDays,
    required this.status,
    this.rejectReason,
  });

  factory LeaveRequestListItem.fromJson(Map<String, dynamic> json) {
    return LeaveRequestListItem(
      requestId: json['requestId'],
      employeeName: json['employeeName'],
      position: json['position'] ?? '',
      department: json['department'] ?? '',
      requestedAt: json['requestedAt'],
      startDate: json['startDate'],
      endDate: json['endDate'],
      useDays: (json['useDays'] as num).toDouble(),
      status: json['status'],
      rejectReason: json['rejectReason'],
    );
  }
}
