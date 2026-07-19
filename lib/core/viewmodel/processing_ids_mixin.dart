import 'package:flutter/foundation.dart';

// "이 id는 지금 처리 중이다"를 표시하는 Set을 관리하는 패턴이
// LeaveRequestListViewModel(취소), LeaveApprovalViewModel(승인/반려)에
// 거의 동일하게 반복되어 있어서 공통 믹스인으로 뽑음.
// ChangeNotifier를 쓰는 ViewModel이라면 어디서든 재사용 가능하다.
mixin ProcessingIdsMixin on ChangeNotifier {
  final Set<int> processingIds = {};

  bool isProcessing(int id) => processingIds.contains(id);

  // id를 처리중 표시하고 action을 실행한 뒤, 성공/실패와 무관하게 표시를 해제한다.
  // action이 던진 예외는 그대로 다시 던지므로, 실패 처리는 호출부에서 try/catch로 이어서 하면 된다.
  Future<T> runWithProcessing<T>(int id, Future<T> Function() action) async {
    processingIds.add(id);
    notifyListeners();
    try {
      return await action();
    } finally {
      processingIds.remove(id);
      notifyListeners();
    }
  }
}
