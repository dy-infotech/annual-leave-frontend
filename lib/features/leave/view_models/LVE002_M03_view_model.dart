import 'package:annual_leave_frontend/features/admin/repositories/common_code_repository.dart';
import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';
import 'package:flutter/material.dart';

/// 관리자 휴가 검색 화면(LVE002_M03)의 ViewModel.
class AdminSearchLeaveRequestsViewModel extends ChangeNotifier {
  AdminSearchLeaveRequestsViewModel({
    this.initialFilter,
    LeaveRepository? repository,
    CommonCodeRepository? commonCodeRepository,
  })  : _repository = repository ?? LeaveRepository(),
        _commonCodeRepository = commonCodeRepository ?? CommonCodeRepository();

  final String? initialFilter;
  final LeaveRepository _repository;
  final CommonCodeRepository _commonCodeRepository;

  List<LeaveRequestListItem> _items = [];
  String? _errorMessage;
  bool _isLoading = true;
  String? _status; // 진행 상태 (null = 전체)
  String? _selectedTeam = '전체'; // 선택된 팀 (null = 전체)
  final List<String> _teamList = []; //팀

  /// 사번/성명 검색어. 조회 시점의 입력값을 그대로 읽기 위해 컨트롤러를 VM이 소유한다.
  final TextEditingController searchEmployeeController =
      TextEditingController();

  List<LeaveRequestListItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get status => _status;
  String? get selectedTeam => _selectedTeam;
  List<String> get teamList => _teamList;
  String get statusName => _status == 'approved' ? "승인" : "반려";

  /// 화면 진입 시 1회 호출한다.
  Future<void> load() async {
    if (initialFilter != null) {
      setFilter(initialFilter);
    }

    getComData();

    await fetch();
  }

  Future<void> getComData() async {
    //기초데이터 조회: 팀목록
    final data = await _commonCodeRepository.fetchCommonCodes();

    if (data.length >= 3) {
      _teamList.clear();
      _teamList.add('전체'); //전체 item 추가
      _teamList.addAll(List<String>.from(data['accessibleTeam']));
    } else {
      // 데이터가 이상할 때 대비한 예외처리
      _errorMessage = '기초데이터 조회에 실패했습니다.';
    }
    notifyListeners();
  }

  Future<void> fetch() async {
    _isLoading = true;
    notifyListeners();
    try {
      final items = await _repository.searchAdminLeaveRequests(
        status: _status,
        team: _selectedTeam == '전체' ? null : _selectedTeam,
        employeeParam: searchEmployeeController.text.isNotEmpty
            ? searchEmployeeController.text
            : null,
      );
      _items = items;
    } catch (e) {
      _errorMessage = '목록을 불러오지 못했습니다.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(String? status) {
    _status = initialFilter! == 'admin_approved' ? "approved" : "rejected";

    fetch();
  }

  void selectTeam(String newValue) {
    _selectedTeam = newValue;
    notifyListeners();
    fetch();
  }

  @override
  void dispose() {
    searchEmployeeController.dispose();
    super.dispose();
  }
}
