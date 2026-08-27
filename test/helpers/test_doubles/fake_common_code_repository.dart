import 'package:annual_leave_frontend/features/admin/repositories/common_code_repository.dart';

/// CommonCodeRepository 인메모리 페이크.
class FakeCommonCodeRepository implements CommonCodeRepository {
  /// 기초 코드 응답. 화면들이 키 개수 검증(length >= 3)을 하므로 3개 키를 기본 제공한다.
  Map<String, dynamic> codesToReturn = {
    'accessibleTeam': ['SI사업팀', 'BI사업팀'],
    'position': ['사원', '대리', '과장'],
    'department': ['경영지원부'],
  };
  Object? errorToThrow;

  int fetchCount = 0;

  @override
  Future<Map<String, dynamic>> fetchCommonCodes() async {
    fetchCount++;
    if (errorToThrow != null) throw errorToThrow!;
    return codesToReturn;
  }
}
