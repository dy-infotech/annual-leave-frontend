import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';

/// LeaveRepository 인메모리 페이크.
///
/// 반환할 값을 필드에 미리 넣어두고, 호출 기록을 남긴다.
/// errorToThrow가 설정되면 해당 예외를 던진다.
class FakeLeaveRepository implements LeaveRepository {
  LeaveRequestDetail? detailToReturn;
  Object? errorToThrow;

  final List<int> fetchedDetailIds = [];

  @override
  Future<LeaveRequestDetail> fetchLeaveRequestDetail(int requestId) async {
    fetchedDetailIds.add(requestId);
    if (errorToThrow != null) throw errorToThrow!;
    return detailToReturn!;
  }
}
