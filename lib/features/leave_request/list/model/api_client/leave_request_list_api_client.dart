import 'package:flutter/material.dart' show DateTimeRange;
import '../../../../../core/network/api_client.dart';
import '../../../common/model/dto/leave_request_record_dto.dart';
import '../../../common/model/util/leave_date_format.dart';

// "전체 목록 조회"와 "취소"는 list 화면에서만 쓰여서 list feature 전용 서비스로 분리.
// (내 목록 조회는 create와 공유하므로 common/service/leave_request_common_api_client.dart에 있음)
class LeaveRequestListApiClient {
  final ApiClient _apiClient;
  LeaveRequestListApiClient(this._apiClient);

  Future<List<LeaveRequestRecordDto>> fetchAllList({
    String? status,
    DateTimeRange? dateRange,
  }) async {
    final response = await _apiClient.dio.get(
      '/api/leave-requests/all',
      queryParameters: _buildQuery(status, dateRange),
    );
    return (response.data as List).map((json) => LeaveRequestRecordDto.fromJson(json)).toList();
  }

  Future<void> cancel(int requestId) async {
    await _apiClient.dio.delete('/api/leave-requests/$requestId');
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
