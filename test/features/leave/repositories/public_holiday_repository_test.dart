import 'package:annual_leave_frontend/features/leave/repositories/public_holiday_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../../helpers/fixture_reader.dart';

/// PublicHolidayRepository 특성화 테스트.
///
/// 캐시가 static이라 테스트 간에 그대로 남으므로 setUp/tearDown에서
/// clearCache()로 반드시 비운다.
void main() {
  const currentYearPath = '/api/leave-requests/current-year-special-days';
  const nextYearPath = '/api/leave-requests/next-year-special-days';

  late Dio dio;
  late DioAdapter dioAdapter;
  late List<RequestOptions> sentRequests;
  late PublicHolidayRepository repository;

  Map<String, dynamic> holiday(String name, String date) =>
      fixtureJson('leave/public_holiday.json')
        ..['name'] = name
        ..['date'] = date;

  void stubHolidays({
    required List<Map<String, dynamic>> currentYear,
    required List<Map<String, dynamic>> nextYear,
  }) {
    dioAdapter.onGet(currentYearPath, (server) => server.reply(200, currentYear));
    dioAdapter.onGet(nextYearPath, (server) => server.reply(200, nextYear));
  }

  setUp(() {
    PublicHolidayRepository.clearCache();
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    sentRequests = <RequestOptions>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      sentRequests.add(options);
      handler.next(options);
    }));
    dioAdapter = DioAdapter(dio: dio);
    repository = PublicHolidayRepository(dio: dio);
  });

  tearDown(PublicHolidayRepository.clearCache);

  group('조회', () {
    test('당해년도와 내년 공휴일을 순서대로 각각 조회해 합친다', () async {
      stubHolidays(
        currentYear: [holiday('광복절', '2026-08-15')],
        nextYear: [holiday('신정', '2027-01-01')],
      );

      final holidays = await repository.fetchPublicHolidays();

      expect(sentRequests.map((r) => r.path), [currentYearPath, nextYearPath]);
      expect(sentRequests.every((r) => r.method == 'GET'), isTrue);
      expect(holidays, hasLength(2));
      expect(holidays.first.name, '광복절');
      expect(holidays.first.date, DateTime(2026, 8, 15));
      expect(holidays.last.name, '신정');
      expect(holidays.last.date, DateTime(2027, 1, 1));
    });

    test('양쪽이 모두 비어 있으면 빈 목록을 돌려준다', () async {
      stubHolidays(currentYear: [], nextYear: []);

      expect(await repository.fetchPublicHolidays(), isEmpty);
      expect(sentRequests, hasLength(2));
    });
  });

  group('캐시', () {
    test('두 번째 호출부터는 캐시를 써서 API를 다시 호출하지 않는다', () async {
      stubHolidays(
        currentYear: [holiday('광복절', '2026-08-15')],
        nextYear: [holiday('신정', '2027-01-01')],
      );

      final first = await repository.fetchPublicHolidays();
      final second = await repository.fetchPublicHolidays();

      expect(sentRequests, hasLength(2));
      expect(identical(first, second), isTrue);
    });

    test('캐시는 static이라 다른 인스턴스에서도 공유된다', () async {
      stubHolidays(
        currentYear: [holiday('광복절', '2026-08-15')],
        nextYear: [holiday('신정', '2027-01-01')],
      );
      await repository.fetchPublicHolidays();

      final other = PublicHolidayRepository(dio: dio);
      final holidays = await other.fetchPublicHolidays();

      expect(sentRequests, hasLength(2));
      expect(holidays, hasLength(2));
    });

    test('refresh=true면 캐시가 있어도 다시 조회한다', () async {
      stubHolidays(
        currentYear: [holiday('광복절', '2026-08-15')],
        nextYear: [holiday('신정', '2027-01-01')],
      );
      await repository.fetchPublicHolidays();

      await repository.fetchPublicHolidays(refresh: true);

      expect(sentRequests, hasLength(4));
      expect(sentRequests.map((r) => r.path),
          [currentYearPath, nextYearPath, currentYearPath, nextYearPath]);
    });

    test('refresh=true로 다시 조회한 결과가 캐시를 덮어쓴다', () async {
      stubHolidays(
        currentYear: [holiday('광복절', '2026-08-15')],
        nextYear: [],
      );
      await repository.fetchPublicHolidays();

      // 새 DioAdapter를 붙여 같은 경로에 다른 응답을 준비한다.
      dioAdapter = DioAdapter(dio: dio);
      stubHolidays(
        currentYear: [holiday('개천절', '2026-10-03')],
        nextYear: [holiday('신정', '2027-01-01')],
      );

      final refreshed = await repository.fetchPublicHolidays(refresh: true);
      final cached = await repository.fetchPublicHolidays();

      expect(refreshed.map((h) => h.name), ['개천절', '신정']);
      expect(cached.map((h) => h.name), ['개천절', '신정']);
      expect(sentRequests, hasLength(4));
    });

    test('clearCache()를 호출하면 다음 조회에서 API를 다시 호출한다', () async {
      stubHolidays(
        currentYear: [holiday('광복절', '2026-08-15')],
        nextYear: [],
      );
      await repository.fetchPublicHolidays();

      PublicHolidayRepository.clearCache();
      await repository.fetchPublicHolidays();

      expect(sentRequests, hasLength(4));
    });
  });

  group('실패', () {
    test('당해년도 조회가 실패하면 예외가 전파되고 내년 조회는 하지 않는다', () async {
      dioAdapter.onGet(
        currentYearPath,
        (server) => server.reply(500, {'message': '서버 오류'}),
      );
      dioAdapter.onGet(nextYearPath, (server) => server.reply(200, []));

      await expectLater(
        repository.fetchPublicHolidays(),
        throwsA(isA<DioException>()),
      );
      expect(sentRequests.map((r) => r.path), [currentYearPath]);
    });

    test('실패한 조회 결과는 캐시에 남지 않아 다음 호출에서 다시 조회한다', () async {
      dioAdapter.onGet(
        currentYearPath,
        (server) => server.reply(500, {'message': '서버 오류'}),
      );
      await expectLater(
        repository.fetchPublicHolidays(),
        throwsA(isA<DioException>()),
      );

      dioAdapter = DioAdapter(dio: dio);
      stubHolidays(
        currentYear: [holiday('광복절', '2026-08-15')],
        nextYear: [],
      );
      final holidays = await repository.fetchPublicHolidays();

      expect(holidays.map((h) => h.name), ['광복절']);
      expect(sentRequests, hasLength(3));
    });

    test('내년 조회가 실패해도 캐시는 채워지지 않는다', () async {
      dioAdapter.onGet(
        currentYearPath,
        (server) => server.reply(200, [holiday('광복절', '2026-08-15')]),
      );
      dioAdapter.onGet(
        nextYearPath,
        (server) => server.reply(500, {'message': '서버 오류'}),
      );

      await expectLater(
        repository.fetchPublicHolidays(),
        throwsA(isA<DioException>()),
      );

      dioAdapter = DioAdapter(dio: dio);
      stubHolidays(
        currentYear: [holiday('광복절', '2026-08-15')],
        nextYear: [holiday('신정', '2027-01-01')],
      );
      final holidays = await repository.fetchPublicHolidays();

      expect(holidays, hasLength(2));
      expect(sentRequests, hasLength(4));
    });
  });
}
