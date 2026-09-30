// AUT003_M01: 계정 찾기 화면 (아이디/비밀번호 찾기 탭)
import 'package:flutter/material.dart';
import 'package:annual_leave_frontend/features/auth/repositories/auth_repository.dart';
import 'package:annual_leave_frontend/features/auth/view_models/AUT003_M01_view_model.dart';
import 'package:provider/provider.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';
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

class FindAccountScreen extends StatelessWidget {
  /// 미지정 시 실제 API를 호출한다. 테스트에서 페이크를 주입한다.
  final AuthRepository? repository;

  const FindAccountScreen({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FindAccountViewModel(repository: repository),
      child: const _FindAccountView(),
    );
  }
}

class _FindAccountView extends StatefulWidget {
  const _FindAccountView();

  @override
  State<_FindAccountView> createState() => _FindAccountViewState();
}

class _FindAccountViewState extends State<_FindAccountView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  FindAccountViewModel get _vm => context.read<FindAccountViewModel>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 탭 변경 시 에러 메시지 및 결과 초기화
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _vm.clearInputs();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 아이디 찾기 요청 처리
  Future<void> _handleFindId() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _vm.findId();
    if (ok && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('아이디를 성공적으로 전송하였습니다.')),
      );
      Navigator.pop(context);
    }
  }

  // 비밀번호 찾기(이메일 발송) 요청 처리
  Future<void> _handleForgotPassword() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _vm.sendPasswordResetEmail();
    if (ok && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('비밀번호 재설정 이메일이 발송되었습니다.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FindAccountViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('계정 정보 찾기'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '아이디 찾기'),
            Tab(text: '비밀번호 찾기'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildFindIdTab(),
            _buildFindPwTab(),
          ],
        ),
      ),
    );
  }

  // 1. 아이디 찾기 탭 화면
  Widget _buildFindIdTab() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '등록된 가입 정보(성함, 이메일)를 입력하시면 \n 아이디를 빌송해 드립니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _vm.nameController,
              decoration: const InputDecoration(labelText: '성함'),
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vm.emailForIdController,
              decoration: const InputDecoration(labelText: '이메일 주소'),
              keyboardType: TextInputType.emailAddress,
            ),
            _buildErrorSection(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _vm.isLoading ? null : _handleFindId,
                child: _vm.isLoading
                    ? _buildLoadingIndicator()
                    : const Text('이메일 전송'),
              ),
            ),
            // const SizedBox(height: 24),
            // SizedBox(
            //   width: double.infinity,
            //   child: ElevatedButton(
            //     onPressed: _vm.isLoading ? null : _handleFindId,
            //     child: _isLoading
            //         ? _buildLoadingIndicator()
            //         : const Text('아이디 찾기'),
            //   ),
            // ),
            // // 아이디 결과 표시 영역
            // if (_foundId != null) ...[
            //   const SizedBox(height: 32),
            //   Container(
            //     width: double.infinity,
            //     padding: const EdgeInsets.all(16),
            //     decoration: BoxDecoration(
            //       color: Colors.grey[100],
            //       borderRadius: BorderRadius.circular(8),
            //       border: Border.all(color: Colors.grey[300]!),
            //     ),
            //     child: Column(
            //       children: [
            //         const Text('확인된 아이디 정보',
            //             style: TextStyle(fontSize: 14, color: Colors.grey)),
            //         const SizedBox(height: 8),
            //         Text(
            //           _foundId!,
            //           style: const TextStyle(
            //               fontSize: 18,
            //               fontWeight: FontWeight.bold,
            //               color: AppColors.textPrimary),
            //         ),
            //       ],
            //     ),
            //   ),
            // ],
          ],
        ),
      ),
    );
  }

  // 2. 비밀번호 찾기 탭 화면
  Widget _buildFindPwTab() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '등록된 사번과 이메일을 입력하시면\n임시 비밀번호를 발송해 드립니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary),
            ),
            // const SizedBox(height: 32),
            // TextField(
            //   controller: _employeeNoController,
            //   decoration: const InputDecoration(labelText: '사번'),
            //   keyboardType: TextInputType.text,
            //   enableSuggestions: false,
            //   autocorrect: false,
            // ),
            const SizedBox(height: 32),
            TextField(
              controller: _vm.employeeNoController,
              decoration: const InputDecoration(labelText: '사번'),
              keyboardType: TextInputType.text,
              enableSuggestions: false,
              autocorrect: false,
              // 영문/숫자 제한 및 실시간 대문자 변환 속성 결합
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9]')), // 영문 및 숫자만 허용
                UpperCaseTextFormatter(), // 소문자 입력 시 실시간 대문자 변환
              ],
            ),

            const SizedBox(height: 12),
            TextField(
              controller: _vm.emailForPwController,
              decoration: const InputDecoration(labelText: '이메일 주소'),
              keyboardType: TextInputType.emailAddress,
            ),
            _buildErrorSection(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _vm.isLoading ? null : _handleForgotPassword,
                child: _vm.isLoading
                    ? _buildLoadingIndicator()
                    : const Text('이메일 전송'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 공통 에러 출력 위젯
  Widget _buildErrorSection() {
    if (_vm.errorMessage == null) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(_vm.errorMessage!, style: const TextStyle(color: Colors.red)),
      ],
    );
  }

  // 공통 로딩 인디케이터
  Widget _buildLoadingIndicator() {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Colors.white,
      ),
    );
  }
}