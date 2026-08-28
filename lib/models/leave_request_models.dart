// 휴가 신청 모델
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

// 휴가 신청 리스트 요소 모델
class LeaveRequestListItem {
  final int requestId;
  final String employeeName;
  final String employeeNumber;
  final String position;
  final String department;
  final String team;
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
    required this.team,
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
      team: json['team'] ?? '',
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

// 휴가 신청 상세 정보 모델
class LeaveRequestDetail {
  // 휴가자
  final String employeeNumber;
  final String employeeName;
  final String position;
  final String department;
  final String team;

  // 휴가 정보
  final String leaveType;
  final String startDate;
  final String endDate;
  final double useDays;
  final String status;
  final String? leaveReason; // 권한 없으면 null
  final String? createdAt;
  final double? prevTotalLeaveDays;
  final double? currTotalLeaveDays;

  // 결재자 (미배정 시 null)
  final String? approverNumber;
  final String? approverName;
  final String? approverPosition;
  final String? approverDepartment;
  final String? managedAt;

  LeaveRequestDetail({
    required this.employeeNumber,
    required this.employeeName,
    required this.position,
    required this.department,
    required this.team,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.useDays,
    required this.status,
    this.leaveReason,
    this.createdAt,
    this.prevTotalLeaveDays,
    this.currTotalLeaveDays,
    this.approverNumber,
    this.approverName,
    this.approverPosition,
    this.approverDepartment,
    this.managedAt,
  });

  factory LeaveRequestDetail.fromJson(Map<String, dynamic> json) {
    return LeaveRequestDetail(
      employeeNumber: json['employeeNumber'] ?? '',
      employeeName: json['employeeName'] ?? '',
      position: json['position'] ?? '',
      department: json['department'] ?? '',
      team: json['team'] ?? '',
      leaveType: json['leaveType'] ?? 'FULL',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      useDays: (json['useDays'] ?? 0).toDouble(),
      status: json['status'] ?? '',
      leaveReason: json['leaveReason'],
      createdAt: json['createdAt'],
      prevTotalLeaveDays: json['prevTotalLeaveDays'],
      currTotalLeaveDays: json['currTotalLeaveDays'],
      // prevTotalLeaveDays: (json['prev_total_leave_days'] as num?)?.toDouble(),
      // currTotalLeaveDays: (json['curr_total_leave_days'] as num?)?.toDouble(),
      approverNumber: json['approverNumber'],
      approverName: json['approverName'],
      approverPosition: json['approverPosition'],
      approverDepartment: json['approverDepartment'],
      managedAt: json['managedAt'],
    );
  }
}

// 승인 대기 상태 휴가 정보 모델
class PendingLeaveRequest {
  final int requestId;
  final String employeeNumber;
  final String employeeName;
  final String department;
  final String team;
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
    required this.team,
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
      team: json['team'] ?? '',
      position: json['position'] ?? '',
      startDate: json['startDate'],
      endDate: json['endDate'],
      useDays: (json['useDays'] as num).toDouble(),
      createdAt: json['createdAt'],
      leaveType: json['leaveType'],
    );
  }
}
