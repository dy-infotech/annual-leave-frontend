import 'package:annual_leave_frontend/models/employee.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/registe_status_badge.dart';

class SearchEmployeeNumberScreen extends StatefulWidget {
  
  const SearchEmployeeNumberScreen({super.key});

  @override
  State<SearchEmployeeNumberScreen> createState() => _SearchEmployeeNumberScreenState();
}

class _SearchEmployeeNumberScreenState extends State<SearchEmployeeNumberScreen> {
  List<Employee> _items = [];
  bool _isLoading = true;
  //String? _searchFilter; // null = 전체
  final TextEditingController _searchParamController  = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    /* if(widget.status != null){
      _statusFilter = widget.status;

      if(widget.filter != null){
        _buttonLabel = widget.filter! == 'my' ? "내 신청": "전체";
      }
      _setFilter(widget.status);
    } */
    
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {

      final response = await ApiClient().dio.get(
        '/api/admin/employees/all',
        queryParameters: _searchParamController.text.isEmpty ? null : {'searchParam': _searchParamController.text},
      );
      setState(() {
        _items = (response.data as List)
            .map((json) => Employee.fromJson(json))
            .toList();
      });

    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사용자 사번 조회')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end, // 우측 정렬
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: TextField(
                      controller: _searchParamController,
                      decoration: InputDecoration(
                        hintText: '사번 또는 성명',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10), // 인풋 박스와 버튼 사이 간격
                  ElevatedButton(
                    onPressed: () {
                      _fetch();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      minimumSize: const Size(70, 36),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search, size: 20),
                        const SizedBox(width: 1),  // 간격 줄임 (기본은 8~12 정도)
                        const Text(
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
                ? const Center(child: CircularProgressIndicator(color: AppColors.slate))
                : _items.isEmpty
                    ? const Center(child: Text('조회된 내역이 없습니다.', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          //final isProcessing = _processingIds.contains(item.requestId);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // 사번, 성명, 직급, 등록여부 한 줄에 표시
                                    Expanded(
                                      child: Text(
                                        '${item.name} ${item.position}  (${item.employeeNumber})',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    RegisteStatusBadge(status: item.isRegisted == true ? '등록' : '미등록'),
                                  ],
                                ),
                                const SizedBox(height: 4),  // 여백 조금 추가
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.email,
                                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                    
          ),),
        ],
      ),
    );
  }
}

