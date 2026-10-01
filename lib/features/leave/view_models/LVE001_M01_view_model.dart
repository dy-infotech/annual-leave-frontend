import 'dart:math';

import 'package:annual_leave_frontend/features/leave/models/enums/LeaveState.dart';
import 'package:annual_leave_frontend/features/leave/models/enums/LeaveType.dart';
import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/models/public_holiday.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';
import 'package:annual_leave_frontend/features/leave/repositories/public_holiday_repository.dart';
import 'package:annual_leave_frontend/core/error/result.dart';
import 'package:annual_leave_frontend/features/leave/usecases/submit_leave_request.dart';
import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';
import 'package:flutter/material.dart';

/// 휴가 신청 화면(LVE001_M01)의 ViewModel.
///
/// 기존 LeaveRequestListProvider(내 신청 목록, 중복 검증, 캘린더 별표 상태)와
/// PublicHolidayProvider(공휴일 판정)의 로직을 흡수했다.
class LeaveRequestViewModel extends ChangeNotifier {
  LeaveRequestViewModel({
    required AuthSession authProvider,
    LeaveRepository? repository,
    PublicHolidayRepository? holidayRepository,
    SubmitLeaveRequest? submitLeaveRequest,
  })  : _authProvider = authProvider,
        _repository = repository ?? LeaveRepository(),
        _holidayRepository = holidayRepository ?? PublicHolidayRepository(),
        _submitLeaveRequest =
            submitLeaveRequest ?? SubmitLeaveRequest(repository: repository);

  final AuthSession _authProvider;
  final LeaveRepository _repository;
  final PublicHolidayRepository _holidayRepository;
  final SubmitLeaveRequest _submitLeaveRequest;

  DateTime focusedDay = DateTime.now();

  // /my/period 조회 실패 시에만 현재 회계연도를 fallback으로 사용한다.
  // 정상 응답이 있으면 정책 종류와 무관하게 서버가 준 범위가 정본이다.
  DateTime _leavePeriodStart = DateTime(DateTime.now().year, 1, 1);
  DateTime _leavePeriodEnd = DateTime(DateTime.now().year, 12, 31);

  LeaveType _selectedLeaveType = LeaveType.full;
  DateTime? _startDate;
  DateTime? _endDate;
  String _useDaysText = '0';
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _disposed = false;
  int _requestSeq = 0;
  String? _submitIdempotencyKey;
  String? _submitPayloadSignature;

  /// 사유 입력값. 조회 시점의 입력값을 그대로 읽기 위해 컨트롤러를 VM이 소유한다.
  final TextEditingController reasonController = TextEditingController();

  List<LeaveRequestListItem> _myRequests = [];
  List<PublicHoliday> _holidays = [];

  LeaveType get selectedLeaveType => _selectedLeaveType;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String get useDaysText => _useDaysText;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  DateTime get calendarFirstDay => _leavePeriodStart;
  DateTime get calendarLastDay => _leavePeriodEnd;

  double get useDays => double.tryParse(_useDaysText) ?? 0;

  String? get leaveReason {
    final text = reasonController.text.trim();
    return text.isEmpty ? null : text;
  }

  // 사유 입력란 필요 여부 (연차, 반차 제외한 나머지)
  bool get needsReason => ![
        LeaveType.full,
        LeaveType.amHalf,
        LeaveType.pmHalf,
      ].contains(_selectedLeaveType);

  double get remainingLeaveDays =>
      _authProvider.employeeInfo?.remainingLeaveDays ?? 0;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  void _applyLeavePeriod(LeavePeriod period) {
    final start = _dateOnly(period.startDate);
    final end = _dateOnly(period.endDate);
    if (end.isBefore(start)) return;

    _leavePeriodStart = start;
    _leavePeriodEnd = end;

    final focused = _dateOnly(focusedDay);
    if (focused.isBefore(start)) {
      focusedDay = start;
    } else if (focused.isAfter(end)) {
      focusedDay = end;
    }
  }

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<List<LeaveRequestListItem>> _fetchMyRequestsForLeavePeriod() {
    return _repository.fetchMyLeaveRequests(
      startDate: _formatDate(_leavePeriodStart),
      endDate: _formatDate(_leavePeriodEnd),
    );
  }

  /// 화면 진입 시 1회 호출한다.
  Future<void> load() async {
    if (_disposed) return;
    final seq = ++_requestSeq;
    try {
      await _authProvider.fetchMyInfo();
    } catch (_) {
      // 내 정보 갱신 실패 시 기존 세션 정보를 유지한다.
    }

    try {
      final period = await _repository.fetchMyLeavePeriod();
      if (_disposed || seq != _requestSeq) return;
      _applyLeavePeriod(period);
    } catch (_) {
      // 서버 기간 조회가 실패하면 초기 fallback(현재 회계연도)을 유지한다.
    }

    try {
      // 캘린더에 별표를 표시하기 위한 내 휴가 신청 목록 조회
      final requests = await _fetchMyRequestsForLeavePeriod();
      if (_disposed || seq != _requestSeq) return;
      _myRequests = requests;
    } catch (_) {
      // 기존 provider와 동일하게 조회 실패 시 빈 목록을 유지한다.
    }
    try {
      final holidays = await _holidayRepository.fetchPublicHolidays();
      if (_disposed || seq != _requestSeq) return;
      _holidays = holidays;
    } catch (_) {
      // 공휴일 조회 실패 시 공휴일 없이 동작한다. (기존 provider와 동일)
    }
    if (!_disposed && seq == _requestSeq) notifyListeners();
  }

  /// 날짜 선택 처리. 종료일(또는 반차 단일일)이 확정되면 true를 돌려준다.
  bool selectDay(DateTime selectedDay, DateTime newFocusedDay) {
    bool rangeConfirmed = false;

    focusedDay = newFocusedDay;

    // 날짜를 새로 선택하면 이전 에러 메시지 제거
    _errorMessage = null;

    final isHalfDay = _selectedLeaveType == LeaveType.amHalf ||
        _selectedLeaveType == LeaveType.pmHalf;

    if (isHalfDay) {
      if (!isSelectableDay(selectedDay)) {
        _errorMessage = '주말·공휴일 또는 재직기간 밖 날짜에는 반차를 신청할 수 없습니다.';
        _startDate = null;
        _endDate = null;
        _useDaysText = '0';
        notifyListeners();
        return false;
      }
      _startDate = selectedDay;
      _endDate = selectedDay;
      _useDaysText = '0.5';
      rangeConfirmed = true;
    } else if (_startDate == null || (_startDate != null && _endDate != null)) {
      _startDate = selectedDay;
      _endDate = null;
      _useDaysText = '0';
    } else if (selectedDay.isBefore(_startDate!)) {
      _startDate = selectedDay;
      _useDaysText = '0';
    } else {
      _endDate = selectedDay;
      _useDaysText = _calculateUsableDays().toString();
      rangeConfirmed = true;
    }

    notifyListeners();
    return rangeConfirmed;
  }

  /// 휴가 종류 변경 처리. 사유 입력란이 새로 표시되면 true를 돌려준다.
  bool setLeaveType(LeaveType value) {
    final wasHalfDay = _selectedLeaveType == LeaveType.amHalf ||
        _selectedLeaveType == LeaveType.pmHalf;
    final isHalfDay = value == LeaveType.amHalf || value == LeaveType.pmHalf;
    final willShowReason = ![
      LeaveType.full,
      LeaveType.amHalf,
      LeaveType.pmHalf,
    ].contains(value);

    _selectedLeaveType = value;

    if (isHalfDay) {
      // 시작일과 종료일이 다르면 (1일 초과 선택된 상태라면) 초기화
      if (_startDate != null && _endDate != null && _startDate != _endDate) {
        _startDate = null;
        _endDate = null;
        _useDaysText = '0';
      }
      // 정확히 하루만 선택되어 있었다면 반차(0.5일) 기간으로 동기화
      else if (_startDate != null) {
        _endDate = _startDate; // 시작일과 종료일을 같게 설정
        _useDaysText = '0.5';
      }
      // 날짜가 아예 선택되지 않은 상태라면 사용일수만 0.5로 설정
      else {
        _useDaysText = '0.5';
      }
    } else if (wasHalfDay) {
      // 반차에서 일반 휴가로 바꿀 때, 기존에 선택된 날짜가 있다면 사용일수 재계산
      if (_startDate != null) {
        _useDaysText = _calculateUsableDays().toString();
      } else {
        _useDaysText = '0';
      }
    }

    notifyListeners();
    return willShowReason;
  }

  void setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // 주말 + 공휴일 제외하고 계산
  int _calculateUsableDays() {
    if (_startDate == null || _endDate == null) return 0;
    int count = 0;
    DateTime cursor = _startDate!;
    while (!cursor.isAfter(_endDate!)) {
      final isWeekend = cursor.weekday == DateTime.saturday ||
          cursor.weekday == DateTime.sunday;
      if (!isWeekend && !isHoliday(cursor)) count++;
      cursor = cursor.add(const Duration(days: 1));
    }
    return count;
  }

  bool isHoliday(DateTime day) {
    return _holidays.any((h) =>
        h.year == day.year && h.month == day.month && h.day == day.day);
  }

  bool isSelectableDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    if (date.isBefore(_leavePeriodStart) || date.isAfter(_leavePeriodEnd)) {
      return false;
    }
    if (date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday ||
        isHoliday(date)) {
      return false;
    }

    final employee = _authProvider.employeeInfo;
    final hireDate = DateTime.tryParse(employee?.hireDate ?? '');
    if (hireDate != null) {
      final hireDay = DateTime(hireDate.year, hireDate.month, hireDate.day);
      if (date.isBefore(hireDay)) return false;
    }

    final fireDate = DateTime.tryParse(employee?.fireDate ?? '');
    if (fireDate != null) {
      final fireDay = DateTime(fireDate.year, fireDate.month, fireDate.day);
      if (date.isAfter(fireDay)) return false;
    }
    return true;
  }

  bool isInRange(DateTime day) {
    if (_startDate == null) {
      return false;
    }

    final end = _endDate ?? _startDate!;
    return !day.isBefore(_startDate!) && !day.isAfter(end);
  }

  /// 현재 선택된 기간이 기존 대기/승인 신청과 겹치는지 확인한다.
  /// refresh가 true면 목록을 다시 조회한 뒤 판정한다.
  Future<bool> hasOverlapForSelection({bool refresh = false}) async {
    if (_disposed || _startDate == null) return false;

    if (refresh) {
      try {
        final requests = await _fetchMyRequestsForLeavePeriod();
        if (_disposed) return false;
        _myRequests = requests;
        notifyListeners();
      } catch (_) {
        // 조회 실패 시 기존 목록 기준으로 판정한다.
      }
    }
    final effectiveEndDate = _endDate ?? _startDate!;

    return SubmitLeaveRequest.hasOverlap(
        _myRequests, _startDate!, effectiveEndDate, _selectedLeaveType.code);
  }

  /// 선택한 기간의 사용 일수가 잔여 연차를 초과하는지 확인한다.
  bool exceedsRemaining() {
    if ([
      LeaveType.alternative,
      LeaveType.parental,
      LeaveType.family,
    ].contains(_selectedLeaveType)) {
      return false;
    }
    return SubmitLeaveRequest.exceedsRemaining(
        useDays: useDays, remainingLeaveDays: remainingLeaveDays);
  }

  String _newSubmitIdempotencyKey() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  String _submitSignature(LeaveRequestCreate request) {
    final data = request.toJson();
    return [
      data['leaveType'],
      data['startDate'],
      data['endDate'],
      data['useDays'],
      data['leaveReason'] ?? '',
    ].join('|');
  }

  String? _validateSubmitInput() {
    if (_startDate == null) {
      return '날짜를 선택해주세요.';
    }
    if (useDays <= 0) {
      return '사용 일수는 0보다 커야 합니다.';
    }
    if (needsReason && leaveReason == null) {
      return '휴가 사유를 입력해주세요.';
    }
    return null;
  }

  /// 휴가 신청 제출. 성공 시 데이터를 갱신하고 선택 상태를 초기화한다.
  Future<bool> submit() async {
    if (_disposed || _isSubmitting) return false;

    final validationError = _validateSubmitInput();
    if (validationError != null) {
      _errorMessage = validationError;
      notifyListeners();
      return false;
    }

    final seq = ++_requestSeq;
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final request = LeaveRequestCreate(
        leaveType: _selectedLeaveType.code,
        startDate: _startDate!,
        endDate: _endDate ?? _startDate!,
        useDays: useDays,
        leaveReason: leaveReason,
      );

      final signature = _submitSignature(request);
      if (_submitPayloadSignature != signature || _submitIdempotencyKey == null) {
        _submitPayloadSignature = signature;
        _submitIdempotencyKey = _newSubmitIdempotencyKey();
      }

      final result = await _submitLeaveRequest(
        request,
        idempotencyKey: _submitIdempotencyKey,
      );
      if (result case Err(:final failure)) {
        _errorMessage = failure.message;
        return false;
      }

      if (_disposed || seq != _requestSeq) return true;

      // 신청 자체는 이미 성공했다. 이후 화면 갱신 실패는 신청 실패로 바꾸지 않는다.
      try {
        await _authProvider.fetchMyInfo();
        if (_disposed || seq != _requestSeq) return true;

        final requests = await _fetchMyRequestsForLeavePeriod();
        if (_disposed || seq != _requestSeq) return true;
        _myRequests = requests;
      } catch (_) {
        // 다음 명시적 새로고침에서 복구한다.
      }

      if (_disposed || seq != _requestSeq) return true;

      _startDate = null;
      _endDate = null;
      _useDaysText = '0';
      _selectedLeaveType = LeaveType.full;
      reasonController.clear();
      _submitIdempotencyKey = null;
      _submitPayloadSignature = null;
      return true;
    } finally {
      if (!_disposed && seq == _requestSeq) {
        _isSubmitting = false;
        notifyListeners();
      }
    }
  }

  // 특정 날짜의 휴가 신청 상태 (오전/오후 각각의 상태)
  // 반환값 status: null(없음) / 'PENDING' / 'APPROVED'
  ({String? amStatus, String? pmStatus}) halfDayStatus(DateTime dateTime) {
    DateTime normalize(DateTime d) {
      final local = d.toLocal();
      return DateTime(local.year, local.month, local.day);
    }

    final target = normalize(dateTime);
    String? amStatus;
    String? pmStatus;

    for (final item in _myRequests.where((item) =>
        item.status == LeaveState.pending.code ||
        item.status == LeaveState.approved.code)) {
      final itemStart = normalize(DateTime.parse(item.startDate));
      final itemEnd = normalize(DateTime.parse(item.endDate));
      final inRange = !target.isBefore(itemStart) && !target.isAfter(itemEnd);
      if (!inRange) continue;

      if (item.leaveType == LeaveType.amHalf.code) {
        // 오전
        amStatus = item.status;
      } else if (item.leaveType == LeaveType.pmHalf.code) {
        // 오후
        pmStatus = item.status;
      } else {
        // 종일 등 반차가 아닌 신청은 오전/오후 모두 점유
        amStatus = item.status;
        pmStatus = item.status;
      }
    }

    return (amStatus: amStatus, pmStatus: pmStatus);
  }

  @override
  void dispose() {
    _disposed = true;
    _requestSeq++;
    reasonController.dispose();
    super.dispose();
  }
}
