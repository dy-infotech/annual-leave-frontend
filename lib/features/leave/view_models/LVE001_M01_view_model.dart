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
  LeaveType _selectedLeaveType = LeaveType.full;
  DateTime? _startDate;
  DateTime? _endDate;
  String _useDaysText = '0';
  bool _isSubmitting = false;
  String? _errorMessage;

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

  /// 화면 진입 시 1회 호출한다.
  Future<void> load() async {
    _authProvider.fetchMyInfo();

    try {
      // 캘린더에 별표를 표시하기 위한 내 휴가 신청 목록 조회
      _myRequests = await _repository.fetchMyLeaveRequests();
    } catch (_) {
      // 기존 provider와 동일하게 조회 실패 시 빈 목록을 유지한다.
    }
    try {
      _holidays = await _holidayRepository.fetchPublicHolidays();
    } catch (_) {
      // 공휴일 조회 실패 시 공휴일 없이 동작한다. (기존 provider와 동일)
    }
    notifyListeners();
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
    if (_startDate == null) return false;

    if (refresh) {
      try {
        _myRequests = await _repository.fetchMyLeaveRequests();
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
    return SubmitLeaveRequest.exceedsRemaining(
        useDays: useDays, remainingLeaveDays: remainingLeaveDays);
  }

  /// 휴가 신청 제출. 성공 시 데이터를 갱신하고 선택 상태를 초기화한다.
  Future<bool> submit() async {
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

      final result = await _submitLeaveRequest(request);
      if (result case Err(:final failure)) {
        _errorMessage = failure.message;
        return false; // 신청 실패 시 여기서 종료 (갱신 또는 초기화 진행 안 함)
      }
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }

    // 데이터 갱신
    try {
      await _authProvider.fetchMyInfo(); // 잔여 연차 차감 반영
      _myRequests = await _repository.fetchMyLeaveRequests(); // 캘린더 별표 반영
    } catch (_) {
      // 이 시점에서 신청은 완료됐기 때문에 갱신 실패의 경우 무시
    }

    // 선택한 상태 초기화
    _startDate = null;
    _endDate = null;
    _useDaysText = '0';
    _selectedLeaveType = LeaveType.full;
    reasonController.clear();
    notifyListeners();
    return true;
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
    reasonController.dispose();
    super.dispose();
  }
}
