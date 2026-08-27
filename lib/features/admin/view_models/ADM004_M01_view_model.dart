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

  List<Employee> _items = [];
  bool _isLoading = true;

  // 등록 상태 검색 조건 ('ALL', 'REGISTERED', 'UNREGISTERED')
  String _selectedStatus = 'ALL';

  // 팀 검색조건
  final List<String> _filterTeamList = ['전체'];
  String _selectedTeamFilter = '전체';

  /// 사번/성명 검색어. 조회 시점의 입력값을 그대로 읽기 위해 컨트롤러를 VM이 소유한다.
  final TextEditingController searchParamController = TextEditingController();

  List<Employee> get items => _items;
  bool get isLoading => _isLoading;
  String get selectedStatus => _selectedStatus;
  List<String> get filterTeamList => _filterTeamList;
  String get selectedTeamFilter => _selectedTeamFilter;

  void setStatus(String status) {
    _selectedStatus = status;
    notifyListeners();
    fetch();
  }

  void setTeamFilter(String team) {
    _selectedTeamFilter = team;
    notifyListeners();
    fetch();
  }

  /// 기초 코드에서 팀 목록 조회. (현재 화면 진입 시에는 사용하지 않음, 기존 코드 유지)
  Future<void> fetchCommonTeams() async {
    try {
      final data = await _commonCodeRepository.fetchCommonCodes();
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

  Future<void> fetch() async {
    _isLoading = true;
    notifyListeners();
    try {
      // 서버로 사원 정보 요청 발송 (검색창에 글자가 있을 때만 파라미터 전달)
      final List<Employee> allFetchedItems = await _repository.fetchEmployees(
        searchParam: searchParamController.text.trim(),
      );

      // 검색 조건이 없을 때(최초 로드 시), 전체 사원 데이터에서 전사 팀 리스트를 동적으로 추출하여 드롭다운을 채웁니다.
      if (searchParamController.text.trim().isEmpty) {
        final List<String> extractedTeams = allFetchedItems
            .map((emp) => emp.team.trim())
            .where((team) => team.isNotEmpty)
            .toSet() // 중복 제거
            .toList();

        extractedTeams.sort(); // 가나다 순 정렬

        _filterTeamList.clear();
        _filterTeamList.add('전체');
        _filterTeamList.addAll(extractedTeams);
      }

      List<Employee> processedItems = allFetchedItems;

      // 팀 필터링 적용 (기준 문자열 공백 제거 비교)
      if (_selectedTeamFilter != '전체') {
        processedItems = processedItems
            .where((emp) => emp.team.replaceAll(' ', '').contains(
                _selectedTeamFilter.replaceAll(' 팀', '').replaceAll(' ', '')))
            .toList();
      }

      // 등록 / 미등록 조건 상태 필터링 연동
      if (_selectedStatus == 'ALL') {
        _items = processedItems;
      } else if (_selectedStatus == 'REGISTERED') {
        _items =
            processedItems.where((item) => item.isRegisted == true).toList();
      } else if (_selectedStatus == 'UNREGISTERED') {
        _items =
            processedItems.where((item) => item.isRegisted != true).toList();
      }
    } catch (e) {
      print('사원 리스트 조회 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    searchParamController.dispose();
    super.dispose();
  }
}
