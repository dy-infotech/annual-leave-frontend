import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/leave_request_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  List<PendingLeaveRequest> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<int> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _fetchPendingList();
  }

  Future<void> _fetchPendingList() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient().dio.get('/api/admin/leave-requests/pending');
      final list = (response.data as List)
          .map((json) => PendingLeaveRequest.fromJson(json))
          .toList();
      setState(() => _requests = list);

    } catch (e) {
      setState(() => _errorMessage = '목록을 불러오지 못했습니다.');

    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approve(int requestId) async {
    setState(() => _processingIds.add(requestId));
    try {
      await ApiClient().dio.post('/api/admin/leave-requests/$requestId/approve');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('승인 처리되었습니다.')));
      }
      await _fetchPendingList();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('승인 처리에 실패했습니다.')));
      }

    } finally {
      setState(() => _processingIds.remove(requestId));
    }
  }

  Future<void> _showRejectDialog(int requestId) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('반려 사유', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '반려 사유를 입력해주세요'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('반려', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await _reject(requestId, controller.text.trim());
    }
  }

  Future<void> _reject(int requestId, String reason) async {
    setState(() => _processingIds.add(requestId));
    try {
      await ApiClient().dio.post(
        '/api/admin/leave-requests/$requestId/reject',
        data: {'rejectReason': reason},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('반려 처리되었습니다.')));
      }
      await _fetchPendingList();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('반려 처리에 실패했습니다.')));
      }

    } finally {
      setState(() => _processingIds.remove(requestId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('승인 대기 목록')),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _fetchPendingList,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.slate));
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.textMuted)));
    }
    if (_requests.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(child: Text('대기 중인 휴가 신청이 없습니다.', style: TextStyle(color: AppColors.textMuted))),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final req = _requests[index];
        final isProcessing = _processingIds.contains(req.requestId);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${req.employeeName} (${req.employeeNo})',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                  Text(req.department, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                ],
              ),
              const SizedBox(height: 10),
              Text('${req.startDate} — ${req.endDate}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${req.useDays}일', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isProcessing ? null : () => _approve(req.requestId),
                      child: isProcessing
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('승인'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isProcessing ? null : () => _showRejectDialog(req.requestId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.coral,
                        side: const BorderSide(color: AppColors.coral, width: 1.3),
                      ),
                      child: const Text('반려'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
