// ADM004_M01: 사원 사번 조회 화면
import 'package:annual_leave_frontend/main.dart';
import 'package:annual_leave_frontend/models/employee.dart';
import 'ADM004_D01.dart';
import 'package:flutter/material.dart';
import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import 'package:annual_leave_frontend/core/widgets/app_drawer.dart';
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
  final List<String> _filterTeamList = ['전체']; // 💡 '전체' -> '전체'으로 변경
  String _selectedTeamFilter = '전체'; // 💡 '전체' -> '전체'으로 변경

  Future<void> _fetchCommonTeams() async {
    try {
      final response = await ApiClient().dio.get('/api/admin/auth/common');
      final data = response.data as Map<String, dynamic>;
      final List<String> fetchedTeams =
          List<String>.from(data['accessibleTeam'] ?? data['team'] ?? []);

      setState(() {
        _filterTeamList.clear();
        _filterTeamList.add('전체'); // 💡 콤보박스 첫 칸 명칭을 '전체'으로 고정
        _filterTeamList.addAll(fetchedTeams);
      });
    } catch (e) {
      print('필터 팀 목록 로드 실패: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    //_fetchCommonTeams(); // 💡 DB 팀 관리 테이블 데이터 먼저 조회
    _fetch();
  }

  // 📄 2페이지 전체를 이 정제된 다중 필터 구조 코드로 대체하세요.
  // 📄 2페이지의 _fetch() 함수 전체를 이 최종 버전으로 완전히 교체하세요.
//   Future<void> _fetch() async {
//     setState(() => _isLoading = true);
//     try {
//       final Map<String, dynamic> queryParams = {};

//       // 1️⃣ [수정] 텍스트 검색창(사번/이름 입력)에 글자가 있을 때만 백엔드로 파라미터를 보냅니다.
//       // 팀 필터 드롭다운 값은 절대로 백엔드로 보내지 않고 공백으로 날려, 백엔드가 전체 사원 데이터(11건)를 안전하게 리턴하도록 유도합니다.
//       if (_searchParamController.text.trim().isNotEmpty) {
//         queryParams['searchParam'] = _searchParamController.text.trim();
//       }

//       // 서버로 GET 요청 발송 (팀 필터링 조건은 서버로 절대 보내지 않음)
//       final response = await ApiClient().dio.get(
//             '/api/admin/employees/all',
//             queryParameters: queryParams.isEmpty ? null : queryParams,
//           );

//       // 백엔드가 온전하게 내려준 전체 사원 리스트 수집
//       final List<Employee> allFetchedItems = (response.data as List)
//           .map((json) => Employee.fromJson(json))
//           .toList();

// // 💡 [핵심 추가] 전체 사원 데이터에서 실제 등록된 팀 이름들을 중복 없이 추출합니다.
//       final List<String> extractedTeams = allFetchedItems
//           .map((emp) => emp.team?.trim() ?? '') // 공백 제거 및 null 방지
//           .where((team) => team.isNotEmpty) // 빈 값 제외
//           .toSet() // Set 변환으로 중복 제거
//           .toList();

// // 알파벳, 가나다 순으로 깔끔하게 정렬 원할 경우 추가 (선택사항)
//       extractedTeams.sort();

//       setState(() {
//         // 💡 [핵심 추가] 추출한 전사 팀 리스트로 드롭다운 콤보박스 목록을 실시간 강제 갱신합니다.
//         _filterTeamList.clear();
//         _filterTeamList.add('전체');
//         _filterTeamList.addAll(extractedTeams);

//         List<Employee> processedItems = allFetchedItems;

//         // 💡 기준 문자열을 일치시켜 클라이언트 사이드 필터링 진행
//         if (_selectedTeamFilter != '전체') {
//           processedItems = processedItems
//               .where((emp) =>
//                   emp.team != null &&
//                   emp.team!.replaceAll(' ', '').contains(_selectedTeamFilter
//                       .replaceAll(' 팀', '')
//                       .replaceAll(' ', '')))
//               .toList();
//         }
//       });
//     } catch (e) {
//       print('사원 리스트 조회 실패: $e');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> queryParams = {};

      // 1️⃣ 텍스트 검색창에 글자가 있을 때만 백엔드로 파라미터를 보냅니다.
      if (_searchParamController.text.trim().isNotEmpty) {
        queryParams['searchParam'] = _searchParamController.text.trim();
      }

      // 서버로 사원 정보 요청 발송
      final response = await ApiClient().dio.get(
            '/api/admin/employees/all',
            queryParameters: queryParams.isEmpty ? null : queryParams,
          );

      // 백엔드가 내려준 사원 리스트 수집
      final List<Employee> allFetchedItems = (response.data as List)
          .map((json) => Employee.fromJson(json))
          .toList();

      setState(() {
        // 검색 조건이 없을 때(최초 로드 시), 전체 사원 데이터에서 전사 팀 리스트를 동적으로 추출하여 드롭다운을 채웁니다.
        if (_searchParamController.text.trim().isEmpty) {
          final List<String> extractedTeams = allFetchedItems
              .map((emp) => emp.team?.trim() ?? '')
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
              .where((emp) =>
                  emp.team != null &&
                  emp.team!.replaceAll(' ', '').contains(_selectedTeamFilter
                      .replaceAll(' 팀', '')
                      .replaceAll(' ', '')))
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
      });
    } catch (e) {
      print('사원 리스트 조회 실패: $e');
    } finally {
      // 💡 스펠링 교정 완료: 에러 상황이나 정상 상황 모두 로딩을 확실히 종료합니다.
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
                    //  1️⃣ 왼쪽: 등록/미등록 상태 선택 Dropdown
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
                      flex: 1, // 💡 앞서 매칭해 둔 가로 분할 비율(10) 유지
                      child: SizedBox(
                        height: 35, // 💡 기존과 완전히 동일한 높이 규격 유지
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedStatus,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black),
                          icon: const Icon(Icons.arrow_drop_down,
                              color: Colors.grey),

                          // 💡 [핵심 추가] 아웃라인 테두리 왼쪽 위에 '등록 상태' 라벨 텍스트를 강제 배치합니다.
                          decoration: InputDecoration(
                            labelText: '등록 상태',
                            labelStyle: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                            isDense: true,

                            // 🔥 [핵심 수정] 상하(vertical) 패딩을 9.5로 세밀하게 조율하여
                            // 옆의 '전체' 기본 아웃라인 콤보박스 테두리 높이와 완벽하게 수평 정렬을 맞춥니다.
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 9.5),

                            // 💡 인풋 박스 테두리를 둥글게(Radius: 8) 마킹하여 기존 디자인 테두리와 일치시킵니다.
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade400),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade400),
                            ),
                          ),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedStatus = newValue;
                              });
                              _fetch();
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('전체')),
                            DropdownMenuItem(
                                value: 'REGISTERED', child: Text('등록')),
                            DropdownMenuItem(
                                value: 'UNREGISTERED', child: Text('미등록')),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 6), // 간격 보정

                    // 2️⃣ 🔥 [중앙 추가] 팀별 소속 선택 Dropdown 위젯 신설
                    // Expanded(
                    //   flex: 2,
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
                    //         value: _selectedTeamFilter,
                    //         style: const TextStyle(
                    //             fontSize: 13, color: Colors.black),
                    //         icon: const Icon(Icons.arrow_drop_down,
                    //             color: Colors.grey),
                    //         // 📄 4페이지 DropdownButtonFormField 내부 items 매핑 영역 수정
                    //         onChanged: (String? newValue) {
                    //           if (newValue != null) {
                    //             setState(() {
                    //               _selectedTeamFilter = newValue;
                    //             });
                    //             _fetch();
                    //           }
                    //         },
                    //         items: (_filterTeamList == null ||
                    //                 _filterTeamList.isEmpty)
                    //             ? [
                    //                 const DropdownMenuItem<String>(
                    //                   value: '전체', // 💡 '전체' -> '전체'
                    //                   child: Text('전체'),
                    //                 )
                    //               ]
                    //             : _filterTeamList.map((String team) {
                    //                 return DropdownMenuItem<String>(
                    //                   value: team,
                    //                   child: Text(team,
                    //                       overflow: TextOverflow.ellipsis),
                    //                 );
                    //               }).toList(),
                    //       ),
                    //     ),
                    //   ),
                    // ),

                    Expanded(
                      flex: 1, // 💡 앞서 매칭해 둔 가로 폭 비율(13) 반영
                      child: SizedBox(
                        height: 35, // 💡 등록 상태 박스와 동일한 세로 규격 제한 유지
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedTeamFilter,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black),
                          icon: const Icon(Icons.arrow_drop_down,
                              color: Colors.grey),
                          alignment: Alignment.centerLeft,

                          // 💡 [핵심 추가] 아웃라인 테두리 왼쪽 위에 '팀' 라벨 텍스트를 강제 배치합니다.
                          decoration: InputDecoration(
                            labelText: '팀',
                            labelStyle: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                            isDense: true,

                            // 🔥 [높이 정렬 고정] 상하 패딩을 '등록 상태' 박스와 똑같은 '9.5'로 일치시켜
                            // 화면에서 두 콤보박스의 가로선 높이가 자석처럼 완벽한 일직선을 이루게 만듭니다.
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 9.5),

                            // 💡 테두리 곡률(Radius: 8) 및 색상 디자인 통일
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade400),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade400),
                            ),
                          ),
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
                                    value: '전체',
                                    child: Text('전체'),
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

                    const SizedBox(width: 6),

                    // 3️⃣ [우측] 사번/성명 검색 입력창 (가로폭 확보를 위해 비율을 2로 세팅)
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 35,
                        child: TextField(
                          controller: _searchParamController,
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black,
                          ),
                          onSubmitted: (_) => _fetch(),
                          decoration: InputDecoration(
                            labelText: '사번 or 성명',
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 9.5,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade400,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade400,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade400,
                              ),
                            ),
                            suffixIcon: InkWell(
                              onTap: _fetch,
                              child: Container(
                                width: 30,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1F3A5F),
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.search,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                            suffixIconConstraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 35,
                            ),
                          ),
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
                          fontSize: 13,
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