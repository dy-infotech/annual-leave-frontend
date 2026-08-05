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

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient().dio.get(
            '/api/admin/employees/all',
            queryParameters: _searchParamController.text.isEmpty
                ? null
                : {'searchParam': _searchParamController.text},
          );
      setState(() {
        _items = (response.data as List)
            .map((json) => Employee.fromJson(json))
            .toList();
      });
    } catch (e) {
      // 에러 처리 로직 필요 시 추가
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 검색 조건
                Expanded(
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
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                            onSubmitted: (_) => _fetch(),
                            decoration: const InputDecoration(
                              hintText: '사번 또는 성명',
                              hintStyle: TextStyle(
                                fontSize: 14, // placeholder 크기 조정
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
                              color: Color(0xFF1F3A5F), // 네이비
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
                // 1. 💡 건수와 검색창 사이의 여백을 꽉 채워 검색창을 우측 끝으로 밀어냄
                const Spacer(),
                // 2. 💡 우측 끝에 배치될 조회 건수 텍스트 (변수나 list.length를 바인딩하세요)
                Text(
                  '${_items.length}건', // 사용 중인 리스트 변수명으로 변경하세요.
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.slate))
                : _items.isEmpty
                    ? const Center(
                        child: Text('조회된 내역이 없습니다.',
                            style: TextStyle(color: AppColors.textMuted)))
                    : ListView.builder(
                        // padding: const EdgeInsets.all(20),
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
