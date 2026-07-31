enum LeaveType {
  full('FULL', '연차'),
  amHalf('AM_HALF', '반차(오전)'),
  pmHalf('PM_HALF', '반차(오후)'),
<<<<<<< HEAD
  alternative('ALTERNATIVE', '대체 휴가'),
=======
  alternate('ALTERNATIVE', '대체 휴가'),
>>>>>>> ffc23b8 (fix: (테스트 결과)사용자 등록 오류 메세지 수정)
  parental('PARENTAL', '출산 휴가'),
  family('FAMILY', '가족 돌봄 휴가'),
  other('OTHER', '기타');

  final String code;
  final String label;
  const LeaveType(this.code, this.label);
}
