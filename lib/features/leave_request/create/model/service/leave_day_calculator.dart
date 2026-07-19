// 주말 + 공휴일을 제외하고 실제 사용 가능한 휴가 일수를 계산하는 순수 함수.
// 공휴일 판단은 호출하는 쪽에서 predicate로 주입받아, 이 파일이 PublicHolidayDto
// feature를 몰라도 되게 한다. 신청(create) 화면에서만 쓰임.
int calculateUsableDays(DateTime start, DateTime end, bool Function(DateTime day) isHoliday) {
  int count = 0;
  DateTime cursor = start;
  while (!cursor.isAfter(end)) {
    final isWeekend = cursor.weekday == DateTime.saturday || cursor.weekday == DateTime.sunday;
    if (!isWeekend && !isHoliday(cursor)) count++;
    cursor = cursor.add(const Duration(days: 1));
  }
  return count;
}
