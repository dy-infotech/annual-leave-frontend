// 서버로 보내는 날짜 포맷(yyyy-MM-dd). create의 신청 DTO와 list의 기간 필터
// 쿼리 파라미터 양쪽에서 공통으로 쓰여서 common/util로 둠.
String formatIsoDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
