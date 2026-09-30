import 'dart:async';

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
  String? _status;
  String? _selectedTeam = '전체';
  final List<String> _teamList = [];
  int _requestSeq = 0;
  bool _disposed = false;

  final TextEditingController searchEmployeeController =
      TextEditingController();

  List<LeaveRequestListItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get status => _status;
  String? get selectedTeam => _selectedTeam;
  List<String> get teamList => _teamList;
  String get statusName => _status == 'rejected' ? '반려' : '승인';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (initialFilter != null) {
      _status = initialFilter == 'admin_rejected' ? 'rejected' : 'approved';
    }
    await getComData();
    await fetch();
  }

  Future<void> getComData() async {
    try {
      final data = await _commonCodeRepository.fetchCommonCodes();
      if (_disposed) return;
      final rawTeams = data['accessibleTeam'];
      if (rawTeams is List) {
        _teamList
          ..clear()
          ..add('전체')
          ..addAll(rawTeams.map((team) => team.toString()));
        _errorMessage = null;
      } else {
        _errorMessage = '기초데이터 조회에 실패했습니다.';
      }
    } catch (_) {
      if (!_disposed) _errorMessage = '기초데이터 조회에 실패했습니다.';
    }
    _notify();
  }

  Future<void> fetch() async {
    final seq = ++_requestSeq;
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      final items = await _repository.searchAdminLeaveRequests(
        status: _status,
        team: _selectedTeam == '전체' ? null : _selectedTeam,
        employeeParam: searchEmployeeController.text.trim().isNotEmpty
            ? searchEmployeeController.text.trim()
            : null,
      );
      if (_disposed || seq != _requestSeq) return;
      _items = items;
    } catch (_) {
      if (_disposed || seq != _requestSeq) return;
      _errorMessage = '목록을 불러오지 못했습니다.';
    } finally {
      if (!_disposed && seq == _requestSeq) {
        _isLoading = false;
        _notify();
      }
    }
  }

  void setFilter(String? filter) {
    _status = filter == 'admin_rejected' ? 'rejected' : 'approved';
    unawaited(fetch());
  }

  void selectTeam(String newValue) {
    _selectedTeam = newValue;
    _notify();
    unawaited(fetch());
  }

  @override
  void dispose() {
    _disposed = true;
    searchEmployeeController.dispose();
    super.dispose();
  }
}
