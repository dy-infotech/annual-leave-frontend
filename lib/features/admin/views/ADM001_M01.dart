// ADM001_M01: 관리자별 관리팀 설정 화면
import 'package:flutter/material.dart';
import 'package:annual_leave_frontend/features/admin/repositories/admin_employee_repository.dart';
import 'package:annual_leave_frontend/features/admin/repositories/common_code_repository.dart';
import 'package:annual_leave_frontend/features/admin/view_models/ADM001_M01_view_model.dart';
import 'package:provider/provider.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import 'package:annual_leave_frontend/core/widgets/app_drawer.dart';

class AdminSettingsScreen extends StatelessWidget {
  /// 미지정 시 실제 API를 호출한다. 테스트에서 페이크를 주입한다.
  final AdminEmployeeRepository? repository;
  final CommonCodeRepository? commonCodeRepository;

  const AdminSettingsScreen(
      {super.key, this.repository, this.commonCodeRepository});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminSettingsViewModel(
        repository: repository,
        commonCodeRepository: commonCodeRepository,
      )..fetchEmployees(),
      child: const _AdminSettingsView(),
    );
  }
}

class _AdminSettingsView extends StatefulWidget {
  const _AdminSettingsView();

  @override
  State<_AdminSettingsView> createState() => _AdminSettingsViewState();
}

class _AdminSettingsViewState extends State<_AdminSettingsView> {
  final ScrollController _employeeScrollController =
      ScrollController(); //스크롤 컨트롤러

  AdminSettingsViewModel get _vm => context.read<AdminSettingsViewModel>();

  @override
  void dispose() {
    //스크롤 해제
    _employeeScrollController.dispose();
    super.dispose();
  }

  // 서버 전송: 저장 결과에 따라 오류 안내만 처리하고 나머지는 ViewModel에 위임
  Future<void> _saveChanges() async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await _vm.saveChanges();
    if (error != null && mounted) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AdminSettingsViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('관리자별 관리팀 설정')),
      drawer: const AppDrawer(),
      body: _vm.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.slate))
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                // 💡 Row를 Column으로 감싸서 하단 공간을 확보합니다.
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        // 📄 [왼쪽 컬럼] 사용자 (이름/아이디)
                        Expanded(
                          flex: 3,
                          child: _buildPanel(
                            title: '사용자 선택',
                            child: ListView.builder(
                              controller: _employeeScrollController,
                              itemCount: _vm.employees.length,
                              itemBuilder: (context, index) {
                                final emp = _vm.employees[index];
                                final isSelected =
                                    _vm.selectedEmployee?.employeeNumber ==
                                        emp.employeeNumber;

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 0, // 🔽 리스트 간 간격 제거
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected
                                        ? Border.all(
                                            color: const Color(0xFFFFDAB9),
                                            width: 2.0)
                                        : null,
                                  ),
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: ListTile(
                                      selected: isSelected,
                                      selectedTileColor: Colors.transparent,
                                      dense: true, // 🔥 높이 축소
                                      visualDensity: const VisualDensity(
                                        vertical: -4, // 🔥 세로 간격 축소
                                      ),
                                      title: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            emp.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isSelected
                                                  ? const Color(0xFFE97451)
                                                  : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            emp.position,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: isSelected
                                                  ? const Color(0xFFF4A460)
                                                  : Colors.black54,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            emp.employeeNumber,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isSelected
                                                  ? const Color(0xFFF4A460)
                                                  : Colors.black45,
                                            ),
                                          ),
                                        ],
                                      ),
                                      onTap: () => _vm.selectEmployee(emp),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 📄 [중앙 컬럼] 일반 팀 목록
                        Expanded(
                          flex: 4,
                          child: _buildPanel(
                            title: '팀 목록',
                            child: ListView.builder(
                              itemCount: _vm.generalTeams.length,
                              itemBuilder: (context, index) {
                                final team = _vm.generalTeams[index];
                                final isSelected =
                                    _vm.selectedGeneralTeam == team;

                                return GestureDetector(
                                  onDoubleTap: () {
                                    _vm.selectGeneralTeam(team);
                                    _vm.moveToAdmin();
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: isSelected
                                          ? Border.all(
                                              color: const Color(0xFFFFDAB9),
                                              width: 2.0,
                                            )
                                          : null,
                                    ),
                                    child: Material(
                                      type: MaterialType.transparency,
                                      child: ListTile(
                                        dense: true,
                                        visualDensity: const VisualDensity(
                                          vertical: -4,
                                        ),
                                        selected: isSelected,
                                        selectedTileColor:
                                            Colors.orange.shade50,
                                        title: Text(
                                          team,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isSelected
                                                ? const Color(0xFFE97451)
                                                : Colors.black87,
                                          ),
                                        ),
                                        onTap: () =>
                                            _vm.selectGeneralTeam(team),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 📄 [중앙 화살표 제어부] 컨트롤러 버튼 영역
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: _vm.selectedGeneralTeam != null
                                    ? _vm.moveToAdmin
                                    : null,
                                style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(36, 36), // 버튼 크기
                                    backgroundColor: const Color(0xFF1F3A5F),
                                    padding: const EdgeInsets.all(8)),
                                child: const Icon(
                                    Icons.keyboard_double_arrow_down_sharp,
                                    color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _vm.selectedManagedTeam != null
                                    ? _vm.moveToGeneral
                                    : null,
                                style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(36, 36), // 버튼 크
                                    backgroundColor: Colors.grey.shade700,
                                    padding: const EdgeInsets.all(8)),
                                child: const Icon(
                                    Icons.keyboard_double_arrow_up_sharp,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 📄 [우측 컬럼] 관리자 팀 목록
                        Expanded(
                          flex: 4,
                          child: _buildPanel(
                            title: '관리팀',
                            child: ListView.builder(
                              itemCount: _vm.managedTeams.length,
                              itemBuilder: (context, index) {
                                final team = _vm.managedTeams[index];
                                final isSelected =
                                    _vm.selectedManagedTeam == team;
                                return GestureDetector(
                                  onDoubleTap: () {
                                    _vm.selectManagedTeam(team);
                                    _vm.moveToGeneral();
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 0, // 🔽 리스트 간 간격 제거
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: isSelected
                                          ? Border.all(
                                              color: const Color(0xFFFFDAB9),
                                              width: 2.0)
                                          : null,
                                    ),
                                    child: Material(
                                      type: MaterialType.transparency,
                                      child: ListTile(
                                        dense: true, // 🔥 높이 축소
                                        visualDensity: const VisualDensity(
                                          vertical: -4, // 🔥 세로 간격 축소
                                        ),
                                        selected: isSelected,
                                        selectedTileColor: Colors.green.shade50,
                                        title: Text(team,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green)),
                                        onTap: () =>
                                            _vm.selectManagedTeam(team),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🎯 화면 최하단 우측 정렬 저장 버튼 영역
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed:
                            _vm.selectedEmployee != null ? _saveChanges : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F3A5F),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          '변경 사항 저장하기',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )),
    );
  }

  // 외곽 아웃라인 테두리 가이드 패널 빌더
  Widget _buildPanel({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      // 📄 기존 decoration: BoxDecoration(...) 아랫줄부터 이어서 붙여넣으세요.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  if (title == "사용자 선택") ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: TextField(
                          controller: _vm.employeeInfoController,
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: '사용자 이름 입력 또는 선택',
                            hintStyle: const TextStyle(
                              fontSize: 12,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onChanged: _selectEmployeeByName,
                        ),
                      ),
                    ),
                  ],
                ],
              )),
          Expanded(child: child),
        ],
      ),
    );
  }

  void _selectEmployeeByName(String value) {
    final index = _vm.selectEmployeeByName(value);

    if (index == -1) return;

    _scrollToEmployee(index);
  }

  void _scrollToEmployee(int index) {
    const double itemHeight = 35.0; // 한 행의 실제 높이에 맞게 조정

    _employeeScrollController.animateTo(
      index * itemHeight,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
} // 💡 State 클래스를 완전히 종료하는 마지막 중괄호입니다.
