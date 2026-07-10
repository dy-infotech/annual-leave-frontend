import 'package:flutter/material.dart';
import 'api_client.dart';
import '../models/leave_request_models.dart';
import '../utils/formatters.dart';

/// 휴가 신청 목록을 조회하는 공통 로직.
/// 내 신청(`/api/leave-requests/my`)과 전체 신청(`/api/leave-requests/all`)이
/// 엔드포인트만 다르고 쿼리 파라미터 구성/파싱이 동일하여 하나로 통합.
Future<List<LeaveRequestListItem>> fetchLeaveRequestList(
  String path, {
  String? status,
  DateTimeRange? dateRange,
}) async {
  final queryParams = <String, dynamic>{};
  if (status != null) {
    queryParams['status'] = status;
  }
  if (dateRange != null) {
    queryParams['startDate'] = formatDateDashed(dateRange.start);
    queryParams['endDate'] = formatDateDashed(dateRange.end);
  }

  final response = await ApiClient().dio.get(
    path,
    queryParameters: queryParams.isEmpty ? null : queryParams,
  );

  return (response.data as List)
      .map((json) => LeaveRequestListItem.fromJson(json))
      .toList();
}
