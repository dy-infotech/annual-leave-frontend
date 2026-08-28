import 'package:annual_leave_frontend/core/error/failure.dart';
import 'package:annual_leave_frontend/core/error/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Failure', () {
    test('toString은 메시지를 그대로 돌려준다', () {
      const failure = Failure('잔여 연차를 초과했습니다.');

      expect(failure.message, '잔여 연차를 초과했습니다.');
      expect(failure.toString(), '잔여 연차를 초과했습니다.');
      expect('$failure', '잔여 연차를 초과했습니다.');
    });
  });

  group('Result', () {
    test('Ok는 값을 담고 when의 ok 분기를 탄다', () {
      const Result<int> result = Ok(7);

      final branch = result.when(
        ok: (value) => '성공 $value',
        err: (failure) => '실패 ${failure.message}',
      );

      expect(branch, '성공 7');
      expect(result, isA<Ok<int>>());
      expect((result as Ok<int>).value, 7);
    });

    test('Err는 실패를 담고 when의 err 분기를 탄다', () {
      const Result<int> result = Err(Failure('네트워크 오류'));

      final branch = result.when(
        ok: (value) => '성공 $value',
        err: (failure) => '실패 ${failure.message}',
      );

      expect(branch, '실패 네트워크 오류');
      expect(result, isA<Err<int>>());
      expect((result as Err<int>).failure.message, '네트워크 오류');
    });

    test('void 결과도 Ok로 표현할 수 있다', () {
      const Result<void> result = Ok(null);

      var called = false;
      result.when(
        ok: (_) => called = true,
        err: (_) => called = false,
      );

      expect(called, isTrue);
    });

    test('when은 두 분기 중 하나만 실행한다', () {
      const Result<String> result = Ok('값');
      var okCount = 0;
      var errCount = 0;

      result.when(
        ok: (_) => okCount++,
        err: (_) => errCount++,
      );

      expect(okCount, 1);
      expect(errCount, 0);
    });
  });
}
