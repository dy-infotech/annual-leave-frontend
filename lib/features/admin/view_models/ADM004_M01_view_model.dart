import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/repositories/admin_employee_repository.dart';
import 'package:annual_leave_frontend/features/admin/repositories/common_code_repository.dart';
import 'package:flutter/material.dart';

/// 사원 사번 조회 화면(ADM004_M01)의 ViewModel.
class SearchEmployeeNumberViewModel extends ChangeNotifier {
  SearchEmployeeNumberViewModel({
    AdminEmployeeRepository? repository,
    CommonCodeRepository? commonCodeRepository,
  })  : _repository = repository ?? AdminEmployeeRepository(),
        _commonCodeRepository = commonCodeRepository ?? CommonCodeRepository();

  final AdminEmployeeRepository _repository;
  final CommonCodeRepository _commonCodeRepository;

  static const int _pageSize = 50;

  List<Employee> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _nextPage = 0;
  bool _disposed = false;
  int _requestSeq = 0;
  int _teamRequestSeq = 0;
  String _appliedKeyword = '';
  String _appliedStatus = 'ALL';
  String _appliedTeamFilter = '전체';

  // 등록 상태 검색 조건 ('ALL', 'REGISTERED', 'UNREGISTERED')
  String _selectedStatus = 'ALL';

  // 팀 검색조건
  final List<String> _filterTeamList = ['전체'];
  String _selectedTeamFilter = '전체';

  /// 사번/성명 검색어. 조회 시점의 입력값을 그대로 읽기 위해 컨트롤러를 VM이 소유한다.
  final TextEditingController searchParamController = TextEditingController();

  List<Employee> get items => _items;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String get selectedStatus => _selectedStatus;
  List<String> get filterTeamList => _filterTeamList;
  String get selectedTeamFilter => _selectedTeamFilter;

  void setStatus(String status) {
    if (_disposed) return;
    _selectedStatus = status;
    notifyListeners();
    fetch();
  }

  void setTeamFilter(String team) {
    if (_disposed) return;
    _selectedTeamFilter = team;
    notifyListeners();
    fetch();
  }

  /// 기초 코드에서 팀 목록 조회. (현재 화면 진입 시에는 사용하지 않음, 기존 코드 유지)
  Future<void> fetchCommonTeams() async {
    final seq = ++_teamRequestSeq;
    try {
      final data = await _commonCodeRepository.fetchCommonCodes();
      if (_disposed || seq != _teamRequestSeq) return;
      final List<String> fetchedTeams =
          List<String>.from(data['accessibleTeam'] ?? data['team'] ?? []);

      _filterTeamList.clear();
      _filterTeamList.add('전체');
      _filterTeamList.addAll(fetchedTeams);
      notifyListeners();
    } catch (e) {
      print('필터 팀 목록 로드 실패: $e');
    }
  }

  Future<void> load() async {
    await fetchCommonTeams();
    await fetch();
  }

  bool? _registeredFilter(String status) {
    return switch (status) {
      'REGISTERED' => true,
      'UNREGISTERED' => false,
      _ => null,
    };
  }

  Future<List<Employee>> _fetchPage(int page) {
    return _repository.fetchEmployeesPage(
      searchParam: _appliedKeyword,
      team: _appliedTeamFilter == '전체' ? null : _appliedTeamFilter,
      registered: _registeredFilter(_appliedStatus),
      page: page,
      size: _pageSize,
    );
  }

  Future<void> fetch() async {
    if (_disposed) return;
    final seq = ++_requestSeq;

    _appliedKeyword = searchParamController.text.trim();
    _appliedStatus = _selectedStatus;
    _appliedTeamFilter = _selectedTeamFilter;
    _nextPage = 0;
    _hasMore = true;
    _isLoading = true;
    _isLoadingMore = false;
    notifyListeners();

    try {
      final page = await _fetchPage(0);
      if (_disposed || seq != _requestSeq) return;

      _items = page;
      _hasMore = page.length == _pageSize;
      if (page.isNotEmpty) _nextPage = 1;
    } catch (e) {
      debugPrint('사원 리스트 조회 실패: $e');
    } finally {
      if (!_disposed && seq == _requestSeq) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (_disposed || _isLoading || _isLoadingMore || !_hasMore) return;

    final seq = _requestSeq;
    final pageNumber = _nextPage;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _fetchPage(pageNumber);
      if (_disposed || seq != _requestSeq) return;

      final existingNumbers =
          _items.map((item) => item.employeeNumber).toSet();
      _items.addAll(
        page.where((item) => existingNumbers.add(item.employeeNumber)),
      );
      _hasMore = page.length == _pageSize;
      if (page.isNotEmpty) _nextPage++;
    } catch (e) {
      debugPrint('추가 사원 목록 조회 실패: $e');
    } finally {
      if (!_disposed && seq == _requestSeq) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestSeq++;
    searchParamController.dispose();
    super.dispose();
  }
}
