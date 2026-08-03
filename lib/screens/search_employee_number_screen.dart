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
      appBar: AppBar(title: const Text('사용자 조회')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: TextField(
                      controller: _searchParamController,
                      textInputAction:
                          TextInputAction.search, // 키보드 엔터키를 검색 모양으로 변경
                      onSubmitted: (_) => _fetch(), // 엔터키 누르면 바로 조회 실행
                      decoration: InputDecoration(
                        hintText: '사번 또는 성명',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _fetch,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      minimumSize: const Size(70, 36),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search, size: 20),
                        SizedBox(width: 1),
                        Text(
                          '조회',
                          style: TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.fromLTRB(16, 5, 16, 10),
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
