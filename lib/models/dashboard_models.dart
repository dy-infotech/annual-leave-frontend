class LeaveInfo {
  final double totalLeaveDays;
  final double usedLeaveDays;
  final double remainingLeaveDays;

  LeaveInfo({
    required this.totalLeaveDays,
    required this.usedLeaveDays,
    required this.remainingLeaveDays,
  });

  factory LeaveInfo.fromJson(Map<String, dynamic> json) {
    return LeaveInfo(
      totalLeaveDays: (json['totalLeaveDays'] as num).toDouble(),
      usedLeaveDays: (json['usedLeaveDays'] as num).toDouble(),
      remainingLeaveDays: (json['remainingLeaveDays'] as num).toDouble(),
    );
  }
}

class LeaveRequestSummary {
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;

  LeaveRequestSummary({
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
  });

  factory LeaveRequestSummary.fromJson(Map<String, dynamic> json) {
    return LeaveRequestSummary(
      pendingCount: json['pendingCount'],
      approvedCount: json['approvedCount'],
      rejectedCount: json['rejectedCount'],
    );
  }
}

class DashboardData {
  final LeaveInfo myLeaveInfo;
  final LeaveRequestSummary myRequestSummary;
  final LeaveRequestSummary? allEmployeeRequestSummary; // ADMIN 권한을 가진 사용자만 값 존재

  DashboardData({
    required this.myLeaveInfo,
    required this.myRequestSummary,
    this.allEmployeeRequestSummary,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      myLeaveInfo: LeaveInfo.fromJson(json['myLeaveInfoResponse']),
      myRequestSummary: LeaveRequestSummary.fromJson(json['myRequestSummary']),
      allEmployeeRequestSummary: json['allEmployeeRequestSummary'] != null
          ? LeaveRequestSummary.fromJson(json['allEmployeeRequestSummary'])
          : null,
    );
  }
}
