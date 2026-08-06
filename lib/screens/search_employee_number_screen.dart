import 'package:annual_leave_frontend/main.dart';
import 'package:annual_leave_frontend/models/employee.dart';
import 'employee_detail_screen.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/registe_status_badge.dart';

class SearchEmployeeNumberScreen extends StatefulWidget {
  const SearchEmployeeNumberScreen({super.key});

  @override
  State<SearchEmployeeNumberScreen> createState() =>
      _SearchEmployeeNumberScreenState();
}

class _SearchEmployeeNumberScreenState extends State<SearchEmployeeNumberScreen>
    with RouteAware {
  List<Employee> _items = [];
  bool _isLoading = true;
  final TextEditingController _searchParamController = TextEditingController();

  // 등록 상태 검색 조건 상태 변수 ('ALL', 'REGISTERED', 'UNREGISTERED')
  String _selectedStatus = 'ALL';

  // 팀 검색조건
  final List<String> _filterTeamList = ['전체 팀']; // 💡 '전체' -> '전체 팀'으로 변경
  String _selectedTeamFilter = '전체 팀'; // 💡 '전체' -> '전체 팀'으로 변경

  Future<void> _fetchCommonTeams() async {
    try {
      final response = await ApiClient().dio.get('/api/admin/auth/common');
      final data = response.data as Map<String, dynamic>;
      final List<String> fetchedTeams =
          List<String>.from(data['accessibleTeam'] ?? data['team'] ?? []);

      setState(() {
        _filterTeamList.clear();
        _filterTeamList.add('전체 팀'); // 💡 콤보박스 첫 칸 명칭을 '전체 팀'으로 고정
        _filterTeamList.addAll(fetchedTeams);
      });
    } catch (e) {
      print('필터 팀 목록 로드 실패: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchCommonTeams(); // 💡 DB 팀 관리 테이블 데이터 먼저 조회
    _fetch();
  }

  // 📄 2페이지 전체를 이 정제된 다중 필터 구조 코드로 대체하세요.
  // 📄 2페이지의 _fetch() 함수 전체를 이 최종 버전으로 완전히 교체하세요.
  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> queryParams = {};

      // 1️⃣ [수정] 텍스트 검색창(사번/이름 입력)에 글자가 있을 때만 백엔드로 파라미터를 보냅니다.
      // 팀 필터 드롭다운 값은 절대로 백엔드로 보내지 않고 공백으로 날려, 백엔드가 전체 사원 데이터(11건)를 안전하게 리턴하도록 유도합니다.
      if (_searchParamController.text.trim().isNotEmpty) {
        queryParams['searchParam'] = _searchParamController.text.trim();
      }

      // 서버로 GET 요청 발송 (팀 필터링 조건은 서버로 절대 보내지 않음)
      final response = await ApiClient().dio.get(
            '/api/admin/employees/all',
            queryParameters: queryParams.isEmpty ? null : queryParams,
          );

      // 백엔드가 온전하게 내려준 전체 사원 리스트 수집
      final List<Employee> allFetchedItems = (response.data as List)
          .map((json) => Employee.fromJson(json))
          .toList();
      setState(() {
        List<Employee> processedItems = allFetchedItems;

        // 💡 기준 문자열을 '전체'에서 '전체 팀'으로 일치시킵니다.
        if (_selectedTeamFilter != '전체 팀') {
          processedItems = processedItems
              .where((emp) =>
                  emp.team != null &&
                  emp.team!.replaceAll(' ', '').contains(_selectedTeamFilter
                      .replaceAll(' 팀', '')
                      .replaceAll(' ', '')))
              .toList();
        }

        // 이하 등록/미등록 상태 필터 조건문 동일 유지...

        // 이하 등록/미등록 상태 필터 조건문 동일 유지...

        // 3️⃣ 기존 등록 / 미등록 조건 상태 필터링 연동 마감
        if (_selectedStatus == 'ALL') {
          _items = processedItems;
        } else if (_selectedStatus == 'REGISTERED') {
          _items =
              processedItems.where((item) => item.isRegisted == true).toList();
        } else if (_selectedStatus == 'UNREGISTERED') {
          _items =
              processedItems.where((item) => item.isRegisted != true).toList();
        }
      });
    } catch (e) {
      print('사원 리스트 조회 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _searchParamController.dispose(); // 메모리 누수 방지
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사용자 정보 조회')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Column(
              children: [
                // 첫 번째 줄: 상태 드롭다운 + 팀 드롭다운 + 검색어 입력창
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1️⃣ 왼쪽: 등록/미등록 상태 선택 Dropdown
                    // Expanded(
                    //   flex: 1,
                    //   child: Container(
                    //     height: 35,
                    //     padding: const EdgeInsets.symmetric(horizontal: 6),
                    //     decoration: BoxDecoration(
                    //       color: Colors.white,
                    //       border: Border.all(color: Colors.grey.shade400),
                    //       borderRadius: BorderRadius.circular(8),
                    //     ),
                    //     child: DropdownButtonHideUnderline(
                    //       child: DropdownButton<String>(
                    //         isExpanded: true,
                    //         value: _selectedStatus,
                    //         style: const TextStyle(
                    //             fontSize: 13, color: Colors.black),
                    //         icon: const Icon(Icons.arrow_drop_down,
                    //             color: Colors.grey),
                    //         onChanged: (String? newValue) {
                    //           if (newValue != null) {
                    //             setState(() {
                    //               _selectedStatus = newValue;
                    //             });
                    //             _fetch();
                    //           }
                    //         },
                    //         items: const [
                    //           DropdownMenuItem(
                    //               value: 'ALL', child: Text('전체상태')),
                    //           DropdownMenuItem(
                    //               value: 'REGISTERED', child: Text('등록')),
                    //           DropdownMenuItem(
                    //               value: 'UNREGISTERED', child: Text('미등록')),
                    //         ],
                    //       ),
                    //     ),
                    //   ),
                    // ),
                    Expanded(
                      flex:
                          10, // 💡 앞서 매칭한 가로 분할 비율(10)을 적용하여 전체 팀, 검색창과 균형을 맞춥니다.
                      child: Container(
                        height: 35,
                        // ❌ 기존의 padding: const EdgeInsets.symmetric(horizontal: 6) 속성은
                        // 내부 정렬을 방해하여 글자를 치우치게 만들었으므로 과감히 삭제합니다.
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedStatus,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black),
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Colors.grey),

                            // 💡 [핵심 추가] 드롭다운 메뉴 아이템들이 컨테이너 높이(35) 기준으로 수직 정중앙에 위치하도록 배치 정렬을 선언합니다.
                            alignment: Alignment.centerLeft,

                            // 💡 [핵심 추가] 글자가 박스 왼쪽 테두리에 너무 밀착되지 않도록 드롭다운 자체 내부 여백을 줍니다.
                            padding: const EdgeInsets.only(left: 8),

                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedStatus = newValue;
                                });
                                _fetch();
                              }
                            },
                            items: const [
                              DropdownMenuItem(
                                  value: 'ALL', child: Text('전체상태')),
                              DropdownMenuItem(
                                  value: 'REGISTERED', child: Text('등록')),
                              DropdownMenuItem(
                                  value: 'UNREGISTERED', child: Text('미등록')),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6), // 간격 보정
                    // 2️⃣ 🔥 [중앙 추가] 팀별 소속 선택 Dropdown 위젯 신설
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 35,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedTeamFilter,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black),
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Colors.grey),
                            // 📄 4페이지 DropdownButtonFormField 내부 items 매핑 영역 수정
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedTeamFilter = newValue;
                                });
                                _fetch();
                              }
                            },
                            items: (_filterTeamList == null ||
                                    _filterTeamList.isEmpty)
                                ? [
                                    const DropdownMenuItem<String>(
                                      value: '전체 팀', // 💡 '전체' -> '전체 팀'
                                      child: Text('전체 팀'),
                                    )
                                  ]
                                : _filterTeamList.map((String team) {
                                    return DropdownMenuItem<String>(
                                      value: team,
                                      child: Text(team,
                                          overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // 3️⃣ [우측] 사번/성명 검색 입력창 (가로폭 확보를 위해 비율을 2로 세팅)
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 35,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchParamController,
                                textInputAction: TextInputAction.search,
                                style: const TextStyle(fontSize: 13),
                                onSubmitted: (_) => _fetch(),
                                decoration: const InputDecoration(
                                  hintText: '사번 또는 성명',
                                  hintStyle: TextStyle(
                                      fontSize: 13, color: AppColors.textMuted),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,

                                  // 💡 [핵심 수정] 가로 여백만 주고 세로 대칭 패딩을 0으로 주어 강제로 수직 중앙 정렬합니다.
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 0),

                                  // 💡 테두리가 없는 인풋창에서 수직 중앙 정렬을 강제할 때 두 속성의 조합이 필수적입니다.
                                  isCollapsed: true,
                                  isDense: true,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: _fetch,
                              child: Container(
                                width: 36,
                                height: double.infinity,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1F3A5F),
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.search,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // 두 번째 줄: 검색 조건 아래에 우측 정렬로 배치되는 조회 건수 Row
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, right: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${_items.length}건', // 💡 필터링된 실시간 개수가 실시간 표기됩니다.
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 하단 전체 리스트 뷰 영역
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.slate))
                : _items.isEmpty
                    ? const Center(
                        child: Text('조회된 내역이 없습니다.',
                            style: TextStyle(color: AppColors.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.only(
                            top: 10.0, left: 20.0, right: 20.0, bottom: 20.0),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        EmployeeDetailScreen(employee: item)),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding:
                                  const EdgeInsets.fromLTRB(16, 10, 16, 10),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.name} ${item.position} (${item.employeeNumber})',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14.5),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      RegisteStatusBadge(
                                          status: item.isRegisted == true
                                              ? '등록'
                                              : '미등록'),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.email ?? '',
                                          style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
