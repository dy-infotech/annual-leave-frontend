import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../models/leave_request_models.dart';
import '../theme/app_theme.dart';
import '../widgets/leave_status_badge.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; 

class LeaveRequestDetailScreen extends StatefulWidget {
  final int requestId;

  const LeaveRequestDetailScreen({super.key, required this.requestId});

  @override
  State<LeaveRequestDetailScreen> createState() =>
      _LeaveRequestDetailScreenState();
}

class _LeaveRequestDetailScreenState extends State<LeaveRequestDetailScreen> {
  LeaveRequestDetail? _detail;
  bool _isLoading = true;
  String? _errorMessage;

  static const Map<String, String> _leaveTypeMap = {
    'FULL': '연차',
    'AM_HALF': '반차(오전)',
    'PM_HALF': '반차(오후)',
    'ALTERNATIVE': '대체 휴가',
    'PARENTAL': '출산 휴가',
    'FAMILY': '가족 돌봄 휴가',
    'OTHER': '기타',
  };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final response =
          await ApiClient().dio.get('/api/leave-requests/${widget.requestId}');
      setState(() {
        _detail = LeaveRequestDetail.fromJson(response.data);
      });
    } catch (e) {
      setState(() => _errorMessage = '상세 정보를 불러오지 못했습니다.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '-';
    return DateFormat('yyyy.MM.dd').format(DateTime.parse(raw));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('휴가 신청 상세 정보')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.slate))
          : _errorMessage != null
              ? Center(
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: AppColors.coral)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final d = _detail!;
    final leaveTypeNm = _leaveTypeMap[d.leaveType] ?? d.leaveType;
    final hasApprover = d.approverName != null;

    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
      children: [
        // 1. 휴가자
        _sectionTitle('휴가자'),
        _card([
          _row('사번', d.employeeNumber),
          _row('이름', '${d.employeeName} ${d.position}'),
          _row('부서', d.department),
        ]),

        SizedBox(height: 20.h),

        // 2. 휴가 신청건 진행 정보
        _sectionTitle('휴가 신청건 진행 정보'),
        _card([
          _row('휴가 종류', leaveTypeNm),
          _row(
              '시작일', '${_formatDate(d.startDate)} ~ ${_formatDate(d.endDate)}'),
          _row('사용 연차', '${d.useDays}일'),
          // 상태는 배지로
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Row(
              children: [
                SizedBox(
                    width: 80.w,
                    child: Text('상태',
                        style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600))),
                LeaveStatusBadge(status: d.status),
              ],
            ),
          ),
          _row(
              '신청일',
              d.createdAt != null
                  ? DateFormat('yyyy.MM.dd')
                      .format(DateTime.parse(d.createdAt.toString()))
                  : '-'),
          _row(
              '결재일',
              (d.managedAt == null || d.managedAt.toString() == 'null')
                  ? '-'
                  : DateFormat('yyyy.MM.dd')
                      .format(DateTime.parse(d.managedAt.toString()))),

          // 사유는 권한 있을 때(null 아님)만 표시
          // if (d.leaveReason != null) _row('사유', d.leaveReason!),
          // 사유 표시 (권한 있을때만 내용 표시)
          _row(
              '사유',
              (d.leaveReason == null ||
                      d.leaveReason.toString() == 'null' ||
                      d.leaveReason.toString().isEmpty)
                  ? '-'
                  : d.leaveReason!),
        ]),

        const SizedBox(height: 20),

        // 3. 승인자
        _sectionTitle('승인자'),
        _card(
          hasApprover
              ? [
                  _row('사번', d.approverNumber ?? '-'),
                  _row('이름', '${d.approverName} ${d.approverPosition ?? ''}'),
                  _row('부서', d.approverDepartment ?? '-'),
                ]
              : [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Text('아직 승인되지 않은 요청입니다.',
                        style: TextStyle(
                            fontSize: 14.sp, color: AppColors.textMuted)),
                  ),
                ],
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: Text(text,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.sp)),
      );

  Widget _card(List<Widget> children) => Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _row(String label, String value) => Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 80.w,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600))),
            Expanded(
                child: Text(value,
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary))),
          ],
        ),
      );
}
