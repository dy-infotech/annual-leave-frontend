class LeaveInfoDto {
  final double totalLeaveDays;
  final double usedLeaveDays;
  final double remainingLeaveDays;

  LeaveInfoDto({
    required this.totalLeaveDays,
    required this.usedLeaveDays,
    required this.remainingLeaveDays,
  });

  factory LeaveInfoDto.fromJson(Map<String, dynamic> json) {
    return LeaveInfoDto(
      totalLeaveDays: (json['totalLeaveDays'] as num).toDouble(),
      usedLeaveDays: (json['usedLeaveDays'] as num).toDouble(),
      remainingLeaveDays: (json['remainingLeaveDays'] as num).toDouble(),
    );
  }
}

class LeaveRequestSummaryDto {
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;

  LeaveRequestSummaryDto({
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
  });

  factory LeaveRequestSummaryDto.fromJson(Map<String, dynamic> json) {
    return LeaveRequestSummaryDto(
      pendingCount: json['pendingCount'],
      approvedCount: json['approvedCount'],
      rejectedCount: json['rejectedCount'],
    );
  }
}

class DashboardDataDto {
  final LeaveInfoDto myLeaveInfo;
  final LeaveRequestSummaryDto myRequestSummary;
  final LeaveRequestSummaryDto? allEmployeeRequestSummary; // ADMIN 권한을 가진 사용자만 값 존재

  DashboardDataDto({
    required this.myLeaveInfo,
    required this.myRequestSummary,
    this.allEmployeeRequestSummary,
  });

  factory DashboardDataDto.fromJson(Map<String, dynamic> json) {
    return DashboardDataDto(
      myLeaveInfo: LeaveInfoDto.fromJson(json['myLeaveInfoResponse']),
      myRequestSummary: LeaveRequestSummaryDto.fromJson(json['myRequestSummary']),
      allEmployeeRequestSummary: json['allEmployeeRequestSummary'] != null
          ? LeaveRequestSummaryDto.fromJson(json['allEmployeeRequestSummary'])
          : null,
    );
  }
}
