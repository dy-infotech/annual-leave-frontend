import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/repositories/admin_employee_repository.dart';
import 'package:annual_leave_frontend/features/admin/repositories/common_code_repository.dart';
import 'package:flutter/material.dart';

// 사원 조회 조건과 목록 상태를 관리한다
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
  String? _errorMessage;
  bool _disposed = false;
  int _requestSeq = 0;
  int _teamRequestSeq = 0;
  String _appliedKeyword = '';
  String _appliedStatus = 'ALL';
  String _appliedTeamFilter = '전체';

  // 등록 상태 검색 조건을 관리한다
  String _selectedStatus = 'ALL';

  // 팀 검색 조건을 관리한다
  final List<String> _filterTeamList = ['전체'];
  String _selectedTeamFilter = '전체';

  // 사번과 성명 검색어를 화면과 함께 관리한다
  final TextEditingController searchParamController = TextEditingController();

  List<Employee> get items => _items;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
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

  // 필요할 때 기초 코드에서 팀 목록을 불러온다
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

  // 팀 목록과 사원 목록을 순서대로 불러온다
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

  // 현재 검색 조건으로 첫 페이지를 다시 조회한다
  Future<void> fetch() async {
    if (_disposed) return;
    final seq = ++_requestSeq;

    _appliedKeyword = searchParamController.text.trim();
    _appliedStatus = _selectedStatus;
    _appliedTeamFilter = _selectedTeamFilter;
    _nextPage = 0;
    _items = [];
    _hasMore = false;
    _errorMessage = null;
    _isLoading = true;
    _isLoadingMore = false;
    notifyListeners();

    try {
      final page = await _fetchPage(0);
      if (_disposed || seq != _requestSeq) return;

      _items = page;
      _errorMessage = null;
      _hasMore = page.length == _pageSize;
      if (page.isNotEmpty) _nextPage = 1;
    } catch (e) {
      if (_disposed || seq != _requestSeq) return;
      _errorMessage = '사원 목록을 불러오지 못했습니다.';
      _hasMore = false;
      debugPrint('사원 리스트 조회 실패: $e');
    } finally {
      if (!_disposed && seq == _requestSeq) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // 현재 검색 조건을 유지한 채 다음 페이지를 조회한다
  Future<void> loadMore() async {
    if (_disposed || _isLoading || _isLoadingMore || !_hasMore || _errorMessage != null) return;

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
      if (!_disposed && seq == _requestSeq) {
        _errorMessage = '추가 사원 목록을 불러오지 못했습니다.';
        _hasMore = false;
      }
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
