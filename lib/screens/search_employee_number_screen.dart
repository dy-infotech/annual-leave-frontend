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

  // ✅ 등록 상태 검색 조건 상태 변수 추가 ('ALL', 'REGISTERED', 'UNREGISTERED')
  String _selectedStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetch();
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

  // Future<void> _fetch() async {
  //   setState(() => _isLoading = true);
  //   try {
  //     final response = await ApiClient().dio.get(
  //           '/api/admin/employees/all',
  //           queryParameters: _searchParamController.text.isEmpty
  //               ? null
  //               : {'searchParam': _searchParamController.text},
  //         );
  //     setState(() {
  //       _items = (response.data as List)
  //           .map((json) => Employee.fromJson(json))
  //           .toList();
  //     });
  //   } catch (e) {
  //     // 에러 처리 로직 필요 시 추가
  //   } finally {
  //     setState(() => _isLoading = false);
  //   }
  // }
  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      // 1️⃣ 백엔드 API 명세에 맞춰 쿼리 파라미터는 'searchParam' 딱 하나만 구성합니다.
      final Map<String, dynamic> queryParams = {};

      if (_searchParamController.text.trim().isNotEmpty) {
        queryParams['searchParam'] = _searchParamController.text.trim();
      }

      // 서버로 GET 요청 전송
      final response = await ApiClient().dio.get(
            '/api/admin/employees/all',
            queryParameters: queryParams.isEmpty ? null : queryParams,
          );

      // 서버에서 가져온 전체 원본 리스트 데이터
      final List<Employee> allFetchedItems = (response.data as List)
          .map((json) => Employee.fromJson(json))
          .toList();

      setState(() {
        // 2️⃣ ✅ [핵심] '등록 / 미등록' 조건 필터링을 플러터 자체적으로 수행합니다.
        if (_selectedStatus == 'ALL') {
          _items = allFetchedItems; // 전체보기
        } else if (_selectedStatus == 'REGISTERED') {
          // 상태가 '등록'인 사원들만 필터링해서 화면 변수에 바인딩
          _items =
              allFetchedItems.where((item) => item.isRegisted == true).toList();
        } else if (_selectedStatus == 'UNREGISTERED') {
          // 상태가 '미등록'인 사원들만 필터링해서 화면 변수에 바인딩
          _items =
              allFetchedItems.where((item) => item.isRegisted != true).toList();
        }
      });
    } catch (e) {
      print('사원 리스트 조회 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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
            // ✅ 부모를 Column으로 선언하여 검색창과 건수가 위아래로 올바르게 배치됩니다.
            child: Column(
              children: [
                // 첫 번째 줄: 상태 드롭다운 + 검색어 입력창
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1️⃣ 왼쪽: 등록/미등록 상태 선택 Dropdown (전체 가로의 1만큼 차지)
                    Expanded(
                      flex: 1, // 비율 설정
                      child: Container(
                        height: 35,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded:
                                true, // 💡 중요: 드롭다운 내부 텍스트가 박스 크기에 맞게 채워지도록 설정
                            value: _selectedStatus,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black),
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Colors.grey),
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
                    ),

                    const SizedBox(width: 8), // 두 컴포넌트 사이의 가로 여백 간격

                    // 2️⃣ 오른쪽: 사번/성명 검색 입력창 (전체 가로의 1만큼 차지)
                    Expanded(
                      flex: 1, // 비율 설정 (왼쪽과 똑같이 1로 주어 1:1 매칭)
                      child: Container(
                        padding: const EdgeInsets.only(left: 2),
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
                                style: const TextStyle(fontSize: 14),
                                onSubmitted: (_) => _fetch(),
                                decoration: const InputDecoration(
                                  hintText: '사번 또는 성명',
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textMuted,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.only(
                                    left: 8,
                                    right: 10,
                                    top: 10,
                                    bottom: 10,
                                  ),
                                  isDense: true,
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              color: Colors.grey.shade300,
                            ),
                            InkWell(
                              onTap: _fetch,
                              child: Container(
                                width: 42,
                                height: double.infinity,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1F3A5F),
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.search,
                                  color: Colors.white,
                                  size: 20,
                                ),
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
                        '${_items.length}건',
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

//           Expanded(
//             child: _isLoading
//                 ? const Center(
//                     child: CircularProgressIndicator(color: AppColors.slate))
//                 : _items.isEmpty
//                     ? const Center(
//                         child: Text('조회된 내역이 없습니다.',
//                             style: TextStyle(color: AppColors.textMuted)))
//                     : ListView.builder(
//                         // padding: const EdgeInsets.all(20),
//                         padding: const EdgeInsets.only(
//                             top: 10.0, left: 20.0, right: 20.0, bottom: 20.0),

//                         itemCount: _items.length,
//                         itemBuilder: (context, index) {
//                           final item = _items[index];
//                           return InkWell(
//                             onTap: () {
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                     builder: (context) =>
//                                         EmployeeDetailScreen(employee: item)),
//                               );
//                             },
//                             borderRadius: BorderRadius.circular(16),
//                             child: Container(
//                               margin: const EdgeInsets.only(bottom: 6),
//                               padding:
//                                   const EdgeInsets.fromLTRB(16, 10, 16, 10),
//                               decoration: BoxDecoration(
//                                 color: AppColors.surface,
//                                 borderRadius: BorderRadius.circular(16),
//                                 border: Border.all(color: AppColors.divider),
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Row(
//                                     mainAxisAlignment:
//                                         MainAxisAlignment.spaceBetween,
//                                     children: [
//                                       Expanded(
//                                         child: Text(
//                                           '${item.name} ${item.position} (${item.employeeNumber})',
//                                           style: const TextStyle(
//                                               fontWeight: FontWeight.w700,
//                                               fontSize: 14.5),
//                                           overflow: TextOverflow.ellipsis,
//                                         ),
//                                       ),
//                                       RegisteStatusBadge(
//                                           status: item.isRegisted == true
//                                               ? '등록'
//                                               : '미등록'),
//                                     ],
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Row(
//                                     children: [
//                                       Expanded(
//                                         child: Text(
//                                           item.email ?? '',
//                                           style: const TextStyle(
//                                               color: AppColors.textMuted,
//                                               fontSize: 12),
//                                           overflow: TextOverflow.ellipsis,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//           ),
//         ],
//       ),
//     );
//   }
// }
