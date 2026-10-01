import 'dart:async';

import 'package:annual_leave_frontend/features/admin/repositories/common_code_repository.dart';
import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';
import 'package:flutter/material.dart';

class AdminSearchLeaveRequestsViewModel extends ChangeNotifier {
  AdminSearchLeaveRequestsViewModel({
    this.initialStatus,
    this.initialFilter,
    LeaveRepository? repository,
    CommonCodeRepository? commonCodeRepository,
  })  : _repository = repository ?? LeaveRepository(),
        _commonCodeRepository = commonCodeRepository ?? CommonCodeRepository();

  final String? initialStatus;
  final String? initialFilter;
  final LeaveRepository _repository;
  final CommonCodeRepository _commonCodeRepository;

  static const int _pageSize = LeaveRepository.defaultPageSize;

  List<LeaveRequestListItem> _items = [];
  String? _errorMessage;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _cursorCreatedAt;
  int? _cursorRequestId;
  String? _status;
  String? _selectedTeam = '전체';
  String? _appliedEmployeeParam;
  final List<String> _teamList = [];
  int _requestSeq = 0;
  bool _disposed = false;

  final TextEditingController searchEmployeeController =
      TextEditingController();

  List<LeaveRequestListItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  String? get status => _status;
  String? get selectedTeam => _selectedTeam;
  List<String> get teamList => _teamList;
  String get statusName => _status == 'rejected' ? '반려' : '승인';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String? _normalizeStatus(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'approved' || 'admin_approved' => 'approved',
      'rejected' || 'admin_rejected' => 'rejected',
      _ => null,
    };
  }

  Future<void> load() async {
    _status = _normalizeStatus(initialStatus ?? initialFilter) ?? 'approved';
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

  Future<List<LeaveRequestListItem>> _fetchPage({
    bool continueFromCursor = false,
  }) {
    return _repository.searchAdminLeaveRequestsPage(
      status: _status,
      team: _selectedTeam == '전체' ? null : _selectedTeam,
      employeeParam: _appliedEmployeeParam,
      page: 0,
      size: _pageSize,
      cursorCreatedAt: continueFromCursor ? _cursorCreatedAt : null,
      cursorRequestId: continueFromCursor ? _cursorRequestId : null,
    );
  }

  Future<void> fetch() async {
    final normalizedEmployeeParam = searchEmployeeController.text.trim();
    _appliedEmployeeParam =
        normalizedEmployeeParam.isEmpty ? null : normalizedEmployeeParam;

    final seq = ++_requestSeq;
    _isLoading = true;
    _isLoadingMore = false;
    _hasMore = true;
    _cursorCreatedAt = null;
    _cursorRequestId = null;
    _errorMessage = null;
    _notify();

    try {
      final page = await _fetchPage();
      if (_disposed || seq != _requestSeq) return;
      _items = page;
      _applyPageCursor(page);
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

  Future<void> loadMore() async {
    if (_disposed || _isLoading || _isLoadingMore || !_hasMore) return;
     final seq = _requestSeq;
    _isLoadingMore = true;
    _notify();
    try {
      final page = await _fetchPage(continueFromCursor: true);
      if (_disposed || seq != _requestSeq) return;
      final existingIds = _items.map((item) => item.requestId).toSet();
      _items.addAll(page.where((item) => existingIds.add(item.requestId)));
      _applyPageCursor(page);
    } catch (_) {
      if (!_disposed && seq == _requestSeq) {
        _errorMessage = '추가 목록을 불러오지 못했습니다.';
      }
    } finally {
      if (!_disposed && seq == _requestSeq) {
        _isLoadingMore = false;
        _notify();
      }
    }
  }

  void _applyPageCursor(List<LeaveRequestListItem> page) {
    _hasMore = page.length == _pageSize;
    if (page.isNotEmpty) {
      final last = page.last;
      _cursorCreatedAt = last.requestedAt;
      _cursorRequestId = last.requestId;
    }
  }

  void setFilter(String? status) {
    final normalized = _normalizeStatus(status);
    if (normalized == null) return;
    _status = normalized;
    _notify();
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
    _requestSeq++;
    searchEmployeeController.dispose();
    super.dispose();
  }
}
