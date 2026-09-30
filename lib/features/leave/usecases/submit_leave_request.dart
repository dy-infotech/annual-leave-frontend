import 'package:annual_leave_frontend/core/error/failure.dart';
import 'package:annual_leave_frontend/core/error/result.dart';
import 'package:annual_leave_frontend/features/leave/models/enums/LeaveState.dart';
import 'package:annual_leave_frontend/features/leave/models/enums/LeaveType.dart';
import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';

/// 휴가 신청 유스케이스.
///
/// 화면과 무관하게 성립하는 신청 규칙(기간 중복 판정, 잔여 연차 초과 판정)을
/// 순수 함수로 담고, 제출 결과를 Result로 돌려준다.
class SubmitLeaveRequest {
  SubmitLeaveRequest({LeaveRepository? repository})
      : _repository = repository ?? LeaveRepository();

  final LeaveRepository _repository;

  /// 휴가 신청 제출.
  Future<Result<void>> call(LeaveRequestCreate request) async {
    try {
      await _repository.submitLeaveRequest(request);
      return const Ok(null);
    } catch (e) {
      return const Err(Failure('신청 중 오류가 발생했습니다. 입력값을 확인해 주세요.'));
    }
  }

  /// 새 신청의 기간(start~end)과 종류(newLeaveType)가 기존 대기/승인 신청과
  /// 겹치는지 판정한다. 같은 날이라도 서로 다른 시간대 반차끼리는 허용한다.
  static bool hasOverlap(
    List<LeaveRequestListItem> existingRequests,
    DateTime start,
    DateTime end,
    String newLeaveType,
  ) {
    // 시간 정보를 제거하고 순수 날짜(연/월/일)만 남긴 로컬 DateTime으로 정규화
    DateTime normalize(DateTime dateTime) {
      final local = dateTime.toLocal();
      return DateTime(local.year, local.month, local.day);
    }

    final normalizedStart = normalize(start);
    final normalizedEnd = normalize(end);

    return existingRequests
        .where((item) =>
            item.status == LeaveState.pending.code ||
            item.status == LeaveState.approved.code)
        .any((item) {
      final itemStart = normalize(DateTime.parse(item.startDate));
      final itemEnd = normalize(DateTime.parse(item.endDate));

      // 1. 날짜 범위가 안 겹치면 무조건 겹침 아님
      final dateOverlaps = !normalizedStart.isAfter(itemEnd) &&
          !normalizedEnd.isBefore(itemStart);
      if (!dateOverlaps) return false;

      // 2. 날짜는 겹치는데, 둘 다 반차이고 오전/오후가 서로 다르면 겹침 아님
      // (예: 기존 오전 반차 + 신규 오후 반차 -> 허용)
      if (isHalf(newLeaveType) && isHalf(item.leaveType)) {
        // 서로 다른 반차 시간대면 겹치지 않음
        if (newLeaveType != item.leaveType) return false;
      }

      // 그 외(종일이 하나라도 끼거나, 같은 시간대 반차끼리)는 겹침
      return true;
    });
  }

  /// 반차(오전/오후) 여부
  static bool isHalf(String leaveType) {
    return (leaveType == LeaveType.amHalf.code) ||
        (leaveType == LeaveType.pmHalf.code);
  }

  /// 사용 일수가 잔여 연차를 초과하는지 판정한다.
  static bool exceedsRemaining({
    required double useDays,
    required double remainingLeaveDays,
  }) {
    return useDays > remainingLeaveDays;
  }
}
