// 신청 화면의 휴가 종류 선택에서만 쓰이는 enum이라 create feature 하위로 배치.
enum LeaveType {

  full('FULL', '연차'),
  amHalf('AM_HALF', '반차(오전)'),
  pmHalf('PM_HALF', '반차(오후)'),
  alternate('ALTERNATE', '대체 휴가'),
  parental('PARENTAL', '출산 휴가'),
  family('FAMILY', '가족 돌봄 휴가'),
  other('OTHER', '기타');

  final String code;
  final String label;
  const LeaveType(this.code, this.label);
}
