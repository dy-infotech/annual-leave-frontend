// 앱 전역에서 재사용하는 날짜/숫자 포맷 유틸.

/// yyyy-MM-dd (API 쿼리 및 목록 표시용)
String formatDateDashed(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// yyyy.MM.dd (휴가 신청 화면 표시용)
String formatDateDotted(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

/// 정수면 소수점 없이, 아니면 소수 첫째 자리까지 (연차 일수 표시용)
String formatDays(double value) =>
    value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
