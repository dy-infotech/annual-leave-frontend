import 'package:annual_leave_frontend/features/admin/repositories/signup_manage_repository.dart';
import 'package:annual_leave_frontend/features/auth/models/auth_models.dart';

/// SignupManageRepository 인메모리 페이크.
class FakeSignupManageRepository implements SignupManageRepository {
  Object? errorToThrow;

  final List<AdminAuthRegisterRequest> registeredRequests = [];

  @override
  Future<void> registerUser(AdminAuthRegisterRequest request) async {
    registeredRequests.add(request);
    if (errorToThrow != null) throw errorToThrow!;
  }
}
