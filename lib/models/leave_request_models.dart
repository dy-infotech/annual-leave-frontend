class LeaveRequestCreate {
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final double useDays;
  final String? leaveReason; // 연차, 반차 제외한 휴가만 값 존재

  LeaveRequestCreate({
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.useDays,
    required this.leaveReason,
  });

  Map<String, dynamic> toJson() => {
        'leaveType': leaveType,
        'startDate': _formatDate(startDate),
        'endDate': _formatDate(endDate),
        'useDays': useDays,
        'leaveReason': leaveReason,
      };

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class LeaveRequestListItem {
  final int requestId;
  final String employeeName;
  final String employeeNumber;
  final String position;
  final String department;
  final String leaveType;
  final String requestedAt;
  final String startDate;
  final String endDate;
  final double useDays;
  final String status;
  final String? rejectReason; // 반려 시에만 값 존재

  LeaveRequestListItem({
    required this.requestId,
    required this.employeeName,
    required this.employeeNumber,
    required this.position,
    required this.department,
    required this.leaveType,
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
      employeeNumber: json['employeeNumber'],
      position: json['position'] ?? '',
      department: json['department'] ?? '',
      leaveType: json['leaveType'],
      requestedAt: json['requestedAt'],
      startDate: json['startDate'],
      endDate: json['endDate'],
      useDays: (json['useDays'] as num).toDouble(),
      status: json['status'],
      rejectReason: json['rejectReason'],
    );
  }
}

class PendingLeaveRequest {
  final int requestId;
  final String employeeNumber;
  final String employeeName;
  final String department;
  final String position;
  final String startDate;
  final String endDate;
  final double useDays;
  final String createdAt;
  final String leaveType;

  PendingLeaveRequest({
    required this.requestId,
    required this.employeeNumber,
    required this.employeeName,
    required this.department,
    required this.position,
    required this.startDate,
    required this.endDate,
    required this.useDays,
    required this.createdAt,
    required this.leaveType,
  });

  factory PendingLeaveRequest.fromJson(Map<String, dynamic> json) {
    return PendingLeaveRequest(
      requestId: json['requestId'],
      employeeNumber: json['employeeNumber'],
      employeeName: json['employeeName'],
      department: json['department'] ?? '',
      position: json['position'] ?? '',
      startDate: json['startDate'],
      endDate: json['endDate'],
      useDays: (json['useDays'] as num).toDouble(),
      createdAt: json['createdAt'],
      leaveType: json['leaveType'],
    );
  }
}
