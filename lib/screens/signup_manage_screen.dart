import 'package:annual_leave_frontend/models/enums/RoleType.dart';
import 'package:annual_leave_frontend/screens/dashboard_screen.dart';
import 'package:annual_leave_frontend/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/date_input_dialog.dart';

class SignupManageScreen extends StatefulWidget {
  const SignupManageScreen({super.key});

  @override
  State<SignupManageScreen> createState() => _SignupManageScreenState();
}

class _SignupManageScreenState extends State<SignupManageScreen> {
  final _employeeNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _hireDateController = TextEditingController();
  DateTime? _selectedDate; // 선택된 날짜 상태 변수
  bool _isLoading = false;
  String? _errorMessage; //공통에러
  String? _employeeNameError; //사용자명에러
  String? _departmentError; //부서에러
  String? _teamError; //팀에러
  String? _positionError; //직급에러
  String? _emailError; //이메일에러
  String? _hireDateError; //입사일에러

  final List<String> _teamList = []; //팀
  final List<String> _departmentList = []; //부서
  final List<String> _positionList = []; //직급
  String? _selectedTeam; //선택된 팀
  String? _otherTeamName; //기타선택시 입력된 팀명
  String? _selectedDepartment; //선택된 부서
  String? _selectedPosition; //선택된 직급
  RoleType? _selectedManagerYn = RoleType.employee; //선택된 관리자여부
  String? formatDate;

  @override
  void initState() {
    super.initState();

    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient().dio.get(
            '/api/admin/auth/common',
          );
      setState(() {
        final data = response.data as Map<String, dynamic>;

        if (data.length >= 3) {
          _departmentList.clear();
          _teamList.clear();
          _positionList.clear();

          _departmentList.addAll(List<String>.from(data['department']));
          _teamList.addAll(List<String>.from(data['accessibleTeam']));
          _positionList.addAll(List<String>.from(data['position']));

          DateTime today = DateTime.now();
          _selectedDate = _selectedDate ?? today;
          _hireDateController.text = DateFormat(
                  '${_selectedDate?.year}년 ${_selectedDate?.month}월 ${_selectedDate?.day}일')
              .format(_selectedDate!);
        } else {
          // 데이터가 이상할 때 대비한 예외처리
          setState(() => _errorMessage = '기초데이터 조회에 실패했습니다.');
          return;
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignup() async {
    if (_employeeNameController.text.isEmpty) {
      setState(() => _employeeNameError = '사용자명을 입력해 주세요.');
      return;
    }
    if (_selectedDepartment == null) {
      setState(() => _departmentError = '부서를 입력해 주세요.');
      return;
    }
    if (_selectedTeam == null) {
      setState(() => _teamError = '팀을 선택해 주세요.');
      return;
    }
    if (_selectedPosition == null) {
      setState(() => _positionError = '직급을 입력해 주세요.');
      return;
    }
    if (_emailController.text.isEmpty) {
      setState(() => _emailError = '이메일 정보를 입력해 주세요.');
      return;
    }
    if (_hireDateController.text.isEmpty) {
      setState(() => _hireDateError = '입사일 정보를 입력해 주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthProvider>().adminAuthRegister(
          _employeeNameController.text.trim(),
          _selectedDepartment ?? '',
          (_selectedTeam == '기타'
              ? (_otherTeamName ?? '')
              : (_selectedTeam ?? '')),
          _selectedPosition ?? '',
          _selectedManagerYn?.code ?? '',
          _emailController.text.trim(),
          formatDate.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사용자 등록이 완료되었습니다. 사용 등록 후 로그인 가능합니다.')),
        );
        //Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen()),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().contains('Exception')
          ? '사용자 등록에 실패했습니다.' + e.toString()
          : '');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    //DateTime today = DateTime.now();
    //_selectedDate = _selectedDate ?? today;

    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => DateInputDialog(
        initialDate: _selectedDate,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        formatDate = DateFormat('yyyy-MM-dd').format(picked);
        _hireDateController.text =
            '${picked.year}년 ${picked.month}월 ${picked.day}일';
        _errorMessage = null; // 예: 날짜 선택 시 오류 초기화
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final info = auth.employeeInfo;
    String userPosition = info != null ? info.position : '';
    if (auth.isAdmin && userPosition == "사장" && !_teamList.contains('기타')) {
      //신규 팀 정보 생성 시 필요
      // 관리자이고 사장일 때만 "기타" 추가
      _teamList.add('기타');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('신규 사원 등록')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                TextField(
                  controller: _employeeNameController,
                  decoration: InputDecoration(
                    labelText: '사용자명',
                    errorText: _employeeNameError,
                  ),
                  keyboardType: TextInputType.text,
                  obscureText: false,
                  onChanged: (value) {
                    setState(() {
                      _employeeNameError = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: '부서',
                    border: const OutlineInputBorder(),
                    errorText: _departmentError,
                  ),
                  value: _selectedDepartment,
                  items: _departmentList
                      .map((dept) => DropdownMenuItem<String>(
                            value: dept,
                            child: Text(dept),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDepartment = value;
                      _departmentError = null;
                    });
                  },
                  onSaved: (value) {
                    _selectedDepartment = value;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: '팀',
                    border: const OutlineInputBorder(),
                    errorText: _teamError,
                  ),
                  value: _selectedTeam,
                  items: _teamList
                      .map((team) => DropdownMenuItem<String>(
                            value: team,
                            child: Text(team),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedTeam = value;
                      _teamError = null;
                      if (value != '기타') {
                        _otherTeamName = null;
                      }
                    });
                  },
                  onSaved: (value) {
                    _selectedTeam = value;
                  },
                ),
                if (_selectedTeam == '기타') ...[
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '기타 팀명을 입력하세요',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (text) {
                      setState(() {
                        _otherTeamName = text;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: '직급',
                    border: const OutlineInputBorder(),
                    errorText: _positionError,
                  ),
                  value: _selectedPosition,
                  items: _positionList
                      .map((pos) => DropdownMenuItem<String>(
                            value: pos,
                            child: Text(pos),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPosition = value;
                      _positionError = null;
                    });
                  },
                  onSaved: (value) {
                    _selectedPosition = value;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RoleType>(
                  decoration: const InputDecoration(
                    labelText: '역할 선택',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedManagerYn,
                  items: RoleType.values.map((role) {
                    return DropdownMenuItem<RoleType>(
                      value: role,
                      child: Text(role.label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedManagerYn = value;
                    });
                  },
                  onSaved: (value) {
                    _selectedManagerYn = value;
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  decoration:
                      InputDecoration(labelText: '이메일', errorText: _emailError),
                  obscureText: false,
                  onChanged: (value) {
                    setState(() {
                      _emailError = null;
                    });
                  },
                  //onSubmitted: (_) => _handleSignup(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _hireDateController,
                  readOnly: true, // 직접 입력 막기 (선택만 가능)
                  decoration: InputDecoration(
                    labelText: '입사일',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _selectDate,
                    ),
                    errorText: _hireDateError,
                  ),
                  onTap: _selectDate, // 텍스트 필드 눌러도 날짜 선택 가능하도록
                  onChanged: (value) {
                    setState(() {
                      _hireDateError = null;
                    });
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMessage!,
                      style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    child: _isLoading
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
