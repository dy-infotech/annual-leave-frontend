// ADM002_M01: 사용자 등록 관리 화면
import 'package:annual_leave_frontend/features/admin/repositories/common_code_repository.dart';
import 'package:annual_leave_frontend/features/admin/repositories/signup_manage_repository.dart';
import 'package:annual_leave_frontend/features/admin/view_models/ADM002_M01_view_model.dart';
import 'package:annual_leave_frontend/features/auth/models/enums/RoleType.dart';
import 'package:annual_leave_frontend/screens/DSH001_M01.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import 'package:annual_leave_frontend/core/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:annual_leave_frontend/providers/auth_provider.dart';
import '../widgets/date_input_dialog.dart';
import 'package:flutter/services.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(), // 입력된 텍스트를 대문자로 변환
      selection: newValue.selection, // 커서 위치 유지
    );
  }
}

class SignupManageScreen extends StatelessWidget {
  /// 미지정 시 실제 API를 호출한다. 테스트에서 페이크를 주입한다.
  final SignupManageRepository? repository;
  final CommonCodeRepository? commonCodeRepository;

  const SignupManageScreen(
      {super.key, this.repository, this.commonCodeRepository});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SignupManageViewModel(
        repository: repository,
        commonCodeRepository: commonCodeRepository,
      )..fetch(),
      child: const _SignupManageView(),
    );
  }
}

class _SignupManageView extends StatefulWidget {
  const _SignupManageView();

  @override
  State<_SignupManageView> createState() => _SignupManageViewState();
}

class _SignupManageViewState extends State<_SignupManageView> {
  SignupManageViewModel get _vm => context.read<SignupManageViewModel>();

  Future<void> _handleSignup() async {
    if (!_vm.validateInputs()) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = await _vm.register();
    if (ok && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('사용자 등록이 완료되었습니다. 사용 등록 후 로그인 가능합니다.')),
      );
      //Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen()),
      );
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => DateInputDialog(
        initialDate: _vm.selectedDate,
      ),
    );

    if (picked != null) {
      _vm.setHireDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<SignupManageViewModel>();
    final auth = context.watch<AuthProvider>();
    final info = auth.employeeInfo;
    // 1. [상태 변수 선언부] 현재 로그인한 사용자의 실제 데이터 정보가 담겨있다고 가정합니다.
    final String currentUserPosition =
        info != null ? info.position.toString() : ''; //"사장"; // 현재 접속자의 직급
    final String currentUserRole = info != null ? info.role.toString() : '';

    //final RoleType currentUserRole = RoleType.admin; // 현재 접속자의 역할 (관리자)

    String userPosition = info != null ? info.position : '';
    // if (auth.isAdmin && userPosition == "사장" && !_vm.teamList.contains('기타')) {
    //   //신규 팀 정보 생성 시 필요
    //   // 관리자이고 사장일 때만 "기타" 추가
    //   _vm.teamList.add('기타');
    // }

    return Scaffold(
      appBar: AppBar(title: const Text('사용자 등록 관리')),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '신규 사용자 정보를 등록합니다. \n 등록된 사용자는 사용 등록 후 로그인 가능합니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                // 사번 채번에서 수기 입력으로 변경
                // const SizedBox(height: 32),
                // TextField(
                //   controller: _vm.employeeNumberController,
                //   decoration: InputDecoration(
                //     labelText: '사번',
                //     errorText: _vm.employeeNumberError,
                //   ),
                //   keyboardType: TextInputType.text,
                //   obscureText: false,
                //   onChanged: (value) {
                //     setState(() {
                //       _vm.employeeNumberError = null;
                //     });
                //   },
                // ),
                const SizedBox(height: 32),
                TextField(
                  controller: _vm.employeeNumberController,
                  decoration: InputDecoration(
                    labelText: '사번',
                    errorText: _vm.employeeNumberError,
                  ),
                  keyboardType: TextInputType.text,
                  obscureText: false,
                  // 영문/숫자 제한 및 실시간 대문자 변환 속성 추가
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9]')), // 영문 및 숫자만 허용
                    UpperCaseTextFormatter(), // 소문자 입력 시 실시간 대문자 변환
                  ],
                  onChanged: (_) => _vm.clearEmployeeNumberError(),
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: _vm.employeeNameController,
                  decoration: InputDecoration(
                    labelText: '사용자명',
                    errorText: _vm.employeeNameError,
                  ),
                  keyboardType: TextInputType.text,
                  obscureText: false,
                  onChanged: (_) => _vm.clearEmployeeNameError(),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: '부서',
                    border: const OutlineInputBorder(),
                    errorText: _vm.departmentError,
                  ),
                  value: _vm.selectedDepartment,
                  // 🌟 변경 포인트: 사장이 아닐 경우, 전체 부서 목록 중 본인의 소속 부서(auth.employeeInfo.department) 하나만 노출되도록 필터링합니다.
                  items: _vm.departmentList
                      .where((dept) {
                        if (currentUserPosition == '사장') {
                          return true; // 사장 계정은 전사 모든 부서 표시 및 선택 가능
                        }
                        // 일반 중간 관리자는 오직 본인의 실제 소속 부서 명칭만 리스트에 남김
                        return dept ==
                            (context
                                    .read<AuthProvider>()
                                    .employeeInfo
                                    ?.department ??
                                '');
                      })
                      .map((dept) => DropdownMenuItem<String>(
                            value: dept,
                            child: Text(dept),
                          ))
                      .toList(),
                  onChanged: _vm.selectDepartment,
                  onSaved: (_) {},
                ),

                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: '팀',
                    border: const OutlineInputBorder(),
                    errorText: _vm.teamError,
                  ),
                  value: _vm.selectedTeam,
                  // 🌟 변경 포인트: 전체 팀 목록 중 현재 선택된 부서에 맞는 팀만 필터링하여 노출합니다.
                  items: _vm.teamList
                      .where((team) {
                        if (_vm.selectedDepartment == '대표이사') {
                          // 부서가 '대표이사'일 때는 팀명에 '대표'가 포함되거나 '대표이사'인 팀만 필터링
                          return team == '대표이사' || team.contains('대표');
                        }
                        // 다른 부서일 때는 '대표이사' 팀을 제외하고 표시 (필요에 따라 규칙 추가 가능)
                        return team != '대표이사';
                      })
                      .map((team) => DropdownMenuItem<String>(
                            value: team,
                            child: Text(team),
                          ))
                      .toList(),
                  onChanged: _vm.selectTeam,
                  onSaved: (_) {},
                ),

                // if (_vm.selectedTeam == '기타') ...[
                //   const SizedBox(height: 12),
                //   TextField(
                //     decoration: const InputDecoration(
                //       labelText: '기타 팀명을 입력하세요',
                //       border: OutlineInputBorder(),
                //     ),
                //     onChanged: (text) {
                //       setState(() {
                //         _otherTeamName = text;
                //       });
                //     },
                //   ),
                // ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: '직급',
                    border: const OutlineInputBorder(),
                    errorText: _vm.positionError,
                  ),
                  value: _vm.selectedPosition,
                  items: _vm.positionList
                      .map((pos) => DropdownMenuItem<String>(
                            value: pos,
                            child: Text(pos),
                          ))
                      .toList(),
                  onChanged: _vm.selectPosition,
                  onSaved: (_) {},
                ),

                // 역할 선택
                const SizedBox(height: 12),
                DropdownButtonFormField<RoleType>(
                  decoration: const InputDecoration(
                    labelText: '역할 선택',
                    border: OutlineInputBorder(),
                  ),
                  value: _vm.selectedManagerYn,

                  // 변경 포인트: 화면 선택 값이 아닌 '현재 접속자 정보'를 기준으로 필터링합니다.
                  items: RoleType.values.where((role) {
                    // 1. 리스트 아이템 중 검사 중인 항목이 관리자(admin)인지 확인
                    final bool isManagerItem = role == RoleType.admin;

                    // 2. 현재 접속자가 사장이면서 동시에 관리자인지 권한 확인
                    final bool isCurrentUserCeoAndAdmin =
                        (currentUserPosition == "사장" &&
                            currentUserRole == "ADMIN");

                    // 3. 만약 관리자 아이템인데, 현재 접속자가 [사장 + 관리자] 조건에 맞지 않는다면 리스트에서 숨김(제외)
                    if (isManagerItem && !isCurrentUserCeoAndAdmin) {
                      return false;
                    }
                    return true;
                  }).map((role) {
                    return DropdownMenuItem<RoleType>(
                      value: role,
                      child: Text(role.label),
                    );
                  }).toList(),
                  onChanged: _vm.selectManagerYn,
                  onSaved: (_) {},
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: _vm.emailController,
                  decoration:
                      InputDecoration(labelText: '이메일', errorText: _vm.emailError),
                  obscureText: false,
                  onChanged: (_) => _vm.clearEmailError(),
                  //onSubmitted: (_) => _handleSignup(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _vm.hireDateController,
                  readOnly: true, // 직접 입력 막기 (선택만 가능)
                  decoration: InputDecoration(
                    labelText: '입사일',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _selectDate,
                    ),
                    errorText: _vm.hireDateError,
                  ),
                  onTap: _selectDate, // 텍스트 필드 눌러도 날짜 선택 가능하도록
                  onChanged: (_) => _vm.clearHireDateError(),
                ),
                if (_vm.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_vm.errorMessage!,
                      style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _vm.isLoading ? null : _handleSignup,
                    child: _vm.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('등록하기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}