import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class FindAccountScreen extends StatefulWidget {
  const FindAccountScreen({super.key});

  @override
  State<FindAccountScreen> createState() => _FindAccountScreenState();
}

class _FindAccountScreenState extends State<FindAccountScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 공통 및 아이디 찾기용 컨트롤러
  final _nameController = TextEditingController();
  final _emailForIdController = TextEditingController();

  // 비밀번호 찾기용 컨트롤러
  final _employeeNoController = TextEditingController();
  final _emailForPwController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _foundId; // 찾은 아이디 저장 변수

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 탭 변경 시 에러 메시지 및 결과 초기화
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _clearInputs();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailForIdController.dispose();
    _employeeNoController.dispose();
    _emailForPwController.dispose();
    super.dispose();
  }

  void _clearInputs() {
    setState(() {
      _errorMessage = null;
      _foundId = null;
    });
  }

  // 아이디 찾기 요청 처리
  Future<void> _handleFindId() async {
    if (_nameController.text.isEmpty || _emailForIdController.text.isEmpty) {
      setState(() => _errorMessage = '성함과 이메일을 모두 입력해 주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _foundId = null;
    });

    try {
      // 💡 AuthProvider에 findId 기능을 구현하여 호출해야 합니다.
      final resultId = await context.read<AuthProvider>().findId(
            _nameController.text.trim(),
            _emailForIdController.text.trim(),
          );

      if (mounted) {
        setState(() => _foundId = resultId);
      }
    } catch (e) {
      print("아이디 찾기 에러 발생: $e");
      setState(() => _errorMessage = '등록된 정보가 일치하지 않습니다.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 비밀번호 찾기(이메일 발송) 요청 처리
  Future<void> _handleForgotPassword() async {
    // 사번이나 이메일 중 하나라도 비어있으면 에러 메시지 표시
    if (_employeeNoController.text.isEmpty ||
        _emailForPwController.text.isEmpty) {
      setState(() {
        _errorMessage = '사번과 이메일을 모두 입력해 주세요.';
      });
      return; // 실행 중단
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthProvider>().sendPasswordResetEmail(
            _employeeNoController.text.trim(),
            _emailForPwController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비밀번호 재설정 이메일이 발송되었습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print("비밀번호 찾기 에러 발생: $e");
      setState(() => _errorMessage = '등록된 정보가 일치하지 않거나 발송에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              '등록된 가입 정보(성함, 이메일)를 입력하시면\n아이디를 확인할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '성함'),
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailForIdController,
              decoration: const InputDecoration(labelText: '이메일 주소'),
              keyboardType: TextInputType.emailAddress,
            ),
            _buildErrorSection(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleFindId,
                child: _isLoading
                    ? _buildLoadingIndicator()
                    : const Text('아이디 찾기'),
              ),
            ),
            // 아이디 결과 표시 영역
            if (_foundId != null) ...[
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    const Text('확인된 아이디 정보',
                        style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(
                      _foundId!,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
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
              '등록된 사번과 이메일을 입력하시면\n임시 비밀번호(또는 링크)를 발송해 드립니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _employeeNoController,
              decoration: const InputDecoration(labelText: '사번'),
              keyboardType: TextInputType.text,
              enableSuggestions: false,
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailForPwController,
              decoration: const InputDecoration(labelText: '이메일 주소'),
              keyboardType: TextInputType.emailAddress,
            ),
            _buildErrorSection(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleForgotPassword,
                child: _isLoading
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
    if (_errorMessage == null) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
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
