// create(겹침 검사, 별표 표시), list(목록 표시) 두 feature가 공통으로 사용하는 DTO.
class LeaveRequestRecordDto {
  final int requestId;
  final String employeeName;
  final String employeeNumber;
  final String position;
  final String department;
  final String requestedAt;
  final String startDate;
  final String endDate;
  final double useDays;
  final String status;
  final String? rejectReason; // 반려 시에만 값 존재

  LeaveRequestRecordDto({
    required this.requestId,
    required this.employeeName,
    required this.employeeNumber,
    required this.position,
    required this.department,
    required this.requestedAt,
    required this.startDate,
    required this.endDate,
    required this.useDays,
    required this.status,
    this.rejectReason,
  });

  factory LeaveRequestRecordDto.fromJson(Map<String, dynamic> json) {
    return LeaveRequestRecordDto(
      requestId: json['requestId'],
      employeeName: json['employeeName'],
      employeeNumber: json['employeeNumber'],
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
