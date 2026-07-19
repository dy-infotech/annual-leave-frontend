// 승인 대기 목록(pending_approval_screen)에서만 쓰이는 DTO라 approval feature 하위로 배치.
class PendingLeaveRequestDto {
  final int requestId;
  final String employeeNumber;
  final String employeeName;
  final String department;
  final String position;
  final String startDate;
  final String endDate;
  final double useDays;
  final String createdAt;

  PendingLeaveRequestDto({
    required this.requestId,
    required this.employeeNumber,
    required this.employeeName,
    required this.department,
    required this.position,
    required this.startDate,
    required this.endDate,
    required this.useDays,
    required this.createdAt,
  });

  factory PendingLeaveRequestDto.fromJson(Map<String, dynamic> json) {
    return PendingLeaveRequestDto(
      requestId: json['requestId'],
      employeeNumber: json['employeeNumber'],
      employeeName: json['employeeName'],
      department: json['department'] ?? '',
      position: json['position'] ?? '',
      startDate: json['startDate'],
      endDate: json['endDate'],
      useDays: (json['useDays'] as num).toDouble(),
      createdAt: json['createdAt'],
    );
  }
}
