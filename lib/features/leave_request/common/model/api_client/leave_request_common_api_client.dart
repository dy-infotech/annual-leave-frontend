import 'package:flutter/material.dart' show DateTimeRange;
import '../../../../../core/network/api_client.dart';
import '../util/leave_date_format.dart';
import '../dto/leave_request_record_dto.dart';

// "내 휴가 신청 목록 조회"는 create feature(겹침 검사 + 캘린더 별표 표시용)와
// list feature(내 신청 목록 화면) 양쪽에서 쓰여서, 어느 한쪽 소유로 두지 않고
// common(공용)으로 분리함. 그 외 API(생성/전체조회/취소/승인/반려)는 각 feature
// 전용 서비스로 옮겼다.
class LeaveRequestCommonApiClient {
  final ApiClient _apiClient;
  LeaveRequestCommonApiClient(this._apiClient);

  Future<List<LeaveRequestRecordDto>> fetchMyList({
    String? status,
    DateTimeRange? dateRange,
  }) async {
    final response = await _apiClient.dio.get(
      '/api/leave-requests/my',
      queryParameters: _buildQuery(status, dateRange),
    );
    return (response.data as List).map((json) => LeaveRequestRecordDto.fromJson(json)).toList();
  }

  Map<String, dynamic>? _buildQuery(String? status, DateTimeRange? dateRange) {
    final query = <String, dynamic>{};
    if (status != null) query['status'] = status;
    if (dateRange != null) {
      query['startDate'] = formatIsoDate(dateRange.start);
      query['endDate'] = formatIsoDate(dateRange.end);
    }
    return query.isEmpty ? null : query;
  }
}
