import 'package:annual_leave_frontend/core/error/failure.dart';
import 'package:annual_leave_frontend/core/error/result.dart';
import 'package:annual_leave_frontend/features/leave/models/enums/LeaveState.dart';
import 'package:annual_leave_frontend/features/leave/models/enums/LeaveType.dart';
import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';
import 'package:dio/dio.dart';

// 휴가 신청 검증과 제출 흐름을 처리한다
class SubmitLeaveRequest {
  SubmitLeaveRequest({LeaveRepository? repository})
      : _repository = repository ?? LeaveRepository();

  final LeaveRepository _repository;

  // 검증된 휴가 신청을 서버에 제출한다
  Future<Result<void>> call(
    LeaveRequestCreate request, {
    String? idempotencyKey,
  }) async {
    try {
      await _repository.submitLeaveRequest(
        request,
        idempotencyKey: idempotencyKey,
      );
      return const Ok(null);
    } on DioException catch (e) {
      final message = e.message?.trim();
      return Err(Failure(
        message != null && message.isNotEmpty
            ? message
            : '신청 중 오류가 발생했습니다. 입력값을 확인해 주세요.',
      ));
    } catch (_) {
      return const Err(Failure('신청 중 오류가 발생했습니다. 입력값을 확인해 주세요.'));
    }
  }

  // 새 신청 기간이 기존 대기 또는 승인 신청과 겹치는지 확인한다
  static bool hasOverlap(
    List<LeaveRequestListItem> existingRequests,
    DateTime start,
    DateTime end,
    String newLeaveType,
  ) {
    // 비교 전에 날짜 단위로 값을 맞춘다
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

      // 날짜 범위가 다르면 다음 신청을 확인한다
      final dateOverlaps = !normalizedStart.isAfter(itemEnd) &&
          !normalizedEnd.isBefore(itemStart);
      if (!dateOverlaps) return false;

      // 서로 다른 시간대의 반차는 같은 날에도 허용한다
      if (isHalf(newLeaveType) && isHalf(item.leaveType)) {
        // 반차 시간대가 다르면 다음 신청을 확인한다
        if (newLeaveType != item.leaveType) return false;
      }

      // 그 외 같은 날짜 사용은 중복으로 처리한다
      return true;
    });
  }

  // 반차 종류인지 확인한다
  static bool isHalf(String leaveType) {
    return (leaveType == LeaveType.amHalf.code) ||
        (leaveType == LeaveType.pmHalf.code);
  }

  // 신청 일수가 잔여 연차를 넘는지 확인한다
  static bool exceedsRemaining({
    required double useDays,
    required double remainingLeaveDays,
  }) {
    return useDays > remainingLeaveDays;
  }
}
