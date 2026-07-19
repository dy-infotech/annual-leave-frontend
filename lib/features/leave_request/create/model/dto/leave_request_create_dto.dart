import '../../../common/model/util/leave_date_format.dart';

// 휴가 신청(생성) 요청 DTO. create feature 전용.
class LeaveRequestCreateDto {
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final double useDays;
  final String? leaveReason; // 연차, 반차 제외한 휴가만 값 존재

  LeaveRequestCreateDto({
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.useDays,
    required this.leaveReason,
  });

  Map<String, dynamic> toJson() => {
    'leaveType': leaveType,
    'startDate': formatIsoDate(startDate),
    'endDate': formatIsoDate(endDate),
    'useDays': useDays,
    'leaveReason': leaveReason,
  };
}
