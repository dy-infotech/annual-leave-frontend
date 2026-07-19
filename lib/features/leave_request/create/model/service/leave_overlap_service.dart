import '../../../common/model/dto/leave_request_record_dto.dart';
import '../../../common/model/enum/leave_state.dart';

// 선택한 기간이 기존 대기/승인 신청과 겹치는지, 캘린더에 별표를 표시할 날짜인지
// 판단하는 순수 계산 로직. 신청(create) 화면에서만 쓰임 — 네트워크/DB 접근 없이
// 이미 불러온 목록(List<LeaveRequestRecordDto>)만 가지고 판단한다.
class LeaveOverlapService {
  final List<LeaveRequestRecordDto> items;
  LeaveOverlapService(this.items);

  static DateTime _normalize(DateTime dateTime) {
    final local = dateTime.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  List<LeaveRequestRecordDto> get _activeItems => items.where(
    (item) => item.status == LeaveState.pending.code || item.status == LeaveState.approved.code,
  ).toList();

  bool hasOverlap(DateTime start, DateTime end) {
    final normalizedStart = _normalize(start);
    final normalizedEnd = _normalize(end);

    return _activeItems.any((item) {
      final itemStart = _normalize(DateTime.parse(item.startDate));
      final itemEnd = _normalize(DateTime.parse(item.endDate));
      return !normalizedStart.isAfter(itemEnd) && !normalizedEnd.isBefore(itemStart);
    });
  }

  bool isRequestedDate(DateTime dateTime) {
    final target = _normalize(dateTime);

    return _activeItems.any((item) {
      final itemStart = _normalize(DateTime.parse(item.startDate));
      final itemEnd = _normalize(DateTime.parse(item.endDate));
      return !target.isBefore(itemStart) && !target.isAfter(itemEnd);
    });
  }
}
