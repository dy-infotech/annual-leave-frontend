// create(겹침 판단 기준: 대기/승인 상태), list(상태 필터 드롭다운) 두 feature가
// 공통으로 사용하는 enum.
enum LeaveState {

  pending('PENDING', '대기'),
  approved('APPROVED', '승인'),
  rejected('REJECTED', '반려'),
  cancelled('CANCELLED', '취소'); // 사용자가 스스로 취소한 경우

  final String code;
  final String label;
  const LeaveState(this.code, this.label);
}
