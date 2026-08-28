import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../../helpers/fixture_reader.dart';

/// LeaveRepository 특성화 테스트.
///
/// 9개 엔드포인트가 실제로 만들어 보내는 HTTP 메서드, 경로, 쿼리, 본문과
/// 응답 매핑을 기록한다. 요청 내용은 기록용 인터셉터로 가로채 확인한다.
void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late List<RequestOptions> sentRequests;
  late LeaveRepository repository;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    sentRequests = <RequestOptions>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      sentRequests.add(options);
      handler.next(options);
    }));
    dioAdapter = DioAdapter(dio: dio);
    repository = LeaveRepository(dio: dio);
  });

  RequestOptions lastRequest() => sentRequests.last;

  List<Map<String, dynamic>> listItems() => [
        fixtureJson('leave/leave_request_list_item.json'),
      ];

  group('fetchLeaveRequestDetail', () {
    test('GET /api/leave-requests/{requestId}로 조회하고 상세 모델로 매핑한다', () async {
      dioAdapter.onGet(
        '/api/leave-requests/11',
        (server) =>
            server.reply(200, fixtureJson('leave/leave_request_detail.json')),
      );

      final detail = await repository.fetchLeaveRequestDetail(11);

      expect(lastRequest().method, 'GET');
      expect(lastRequest().path, '/api/leave-requests/11');
      expect(detail.employeeName, '홍길동');
      expect(detail.leaveType, 'AM_HALF');
      expect(detail.useDays, 0.5);
      expect(detail.status, 'APPROVED');
      expect(detail.approverName, '김결재');
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onGet(
        '/api/leave-requests/11',
        (server) => server.reply(403, {'message': '조회 권한이 없습니다.'}),
      );

      await expectLater(
        repository.fetchLeaveRequestDetail(11),
        throwsA(isA<DioException>().having(
            (e) => e.response?.statusCode, 'statusCode', 403)),
      );
    });
  });

  group('fetchMyLeaveRequests', () {
    test('조건이 하나도 없으면 쿼리 파라미터 없이 GET /api/leave-requests/my를 호출한다', () async {
      dioAdapter.onGet(
        '/api/leave-requests/my',
        (server) => server.reply(200, listItems()),
      );

      await repository.fetchMyLeaveRequests();

      expect(lastRequest().method, 'GET');
      expect(lastRequest().path, '/api/leave-requests/my');
      expect(lastRequest().queryParameters, isEmpty);
      expect(lastRequest().uri.hasQuery, isFalse);
    });

    test('조건을 모두 넘기면 status/startDate/endDate가 쿼리로 실린다', () async {
      dioAdapter.onGet(
        '/api/leave-requests/my',
        (server) => server.reply(200, listItems()),
        queryParameters: {
          'status': 'PENDING',
          'startDate': '2026-01-01',
          'endDate': '2026-12-31',
        },
      );

      await repository.fetchMyLeaveRequests(
        status: 'PENDING',
        startDate: '2026-01-01',
        endDate: '2026-12-31',
      );

      expect(lastRequest().queryParameters, {
        'status': 'PENDING',
        'startDate': '2026-01-01',
        'endDate': '2026-12-31',
      });
    });

    test('일부 조건만 넘기면 그 키만 쿼리에 실린다', () async {
      dioAdapter.onGet(
        '/api/leave-requests/my',
        (server) => server.reply(200, listItems()),
        queryParameters: {'status': 'APPROVED'},
      );

      await repository.fetchMyLeaveRequests(status: 'APPROVED');

      expect(lastRequest().queryParameters, {'status': 'APPROVED'});
    });

    test('배열 응답을 목록 모델로 매핑한다', () async {
      dioAdapter.onGet(
        '/api/leave-requests/my',
        (server) => server.reply(200, listItems()),
      );

      final items = await repository.fetchMyLeaveRequests();

      expect(items, hasLength(1));
      expect(items.first, isA<LeaveRequestListItem>());
      expect(items.first.requestId, 11);
      expect(items.first.employeeName, '홍길동');
      expect(items.first.useDays, 2.0);
    });

    test('빈 배열 응답은 빈 목록이 된다', () async {
      dioAdapter.onGet(
        '/api/leave-requests/my',
        (server) => server.reply(200, []),
      );

      expect(await repository.fetchMyLeaveRequests(), isEmpty);
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onGet(
        '/api/leave-requests/my',
        (server) => server.reply(500, {'message': '서버 오류'}),
      );

      await expectLater(
        repository.fetchMyLeaveRequests(),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('fetchAllLeaveRequests', () {
    test('조건이 없으면 쿼리 파라미터 없이 GET /api/leave-requests/all을 호출한다', () async {
      dioAdapter.onGet(
        '/api/leave-requests/all',
        (server) => server.reply(200, listItems()),
      );

      final items = await repository.fetchAllLeaveRequests();

      expect(lastRequest().method, 'GET');
      expect(lastRequest().path, '/api/leave-requests/all');
      expect(lastRequest().queryParameters, isEmpty);
      expect(items.first.requestId, 11);
    });

    test('조건을 넘기면 쿼리로 실린다', () async {
      dioAdapter.onGet(
        '/api/leave-requests/all',
        (server) => server.reply(200, []),
        queryParameters: {
          'status': 'REJECTED',
          'startDate': '2026-08-01',
          'endDate': '2026-08-31',
        },
      );

      await repository.fetchAllLeaveRequests(
        status: 'REJECTED',
        startDate: '2026-08-01',
        endDate: '2026-08-31',
      );

      expect(lastRequest().queryParameters, {
        'status': 'REJECTED',
        'startDate': '2026-08-01',
        'endDate': '2026-08-31',
      });
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onGet(
        '/api/leave-requests/all',
        (server) => server.reply(403, {'message': '권한이 없습니다.'}),
      );

      await expectLater(
        repository.fetchAllLeaveRequests(),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('cancelLeaveRequest', () {
    test('DELETE /api/leave-requests/{requestId}를 본문 없이 호출한다', () async {
      dioAdapter.onDelete(
        '/api/leave-requests/11',
        (server) => server.reply(200, null),
      );

      await repository.cancelLeaveRequest(11);

      expect(lastRequest().method, 'DELETE');
      expect(lastRequest().path, '/api/leave-requests/11');
      expect(lastRequest().data, isNull);
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onDelete(
        '/api/leave-requests/11',
        (server) => server.reply(400, {'message': '이미 결재된 신청입니다.'}),
      );

      await expectLater(
        repository.cancelLeaveRequest(11),
        throwsA(isA<DioException>().having(
            (e) => e.response?.statusCode, 'statusCode', 400)),
      );
    });
  });

  group('submitLeaveRequest', () {
    test('POST /api/leave-requests에 신청 본문을 그대로 실어 보낸다', () async {
      dioAdapter.onPost(
        '/api/leave-requests',
        (server) => server.reply(200, {}),
        data: {
          'leaveType': 'FULL',
          'startDate': '2026-08-10',
          'endDate': '2026-08-11',
          'useDays': 2.0,
          'leaveReason': null,
        },
      );

      await repository.submitLeaveRequest(LeaveRequestCreate(
        leaveType: 'FULL',
        startDate: DateTime(2026, 8, 10),
        endDate: DateTime(2026, 8, 11),
        useDays: 2.0,
        leaveReason: null,
      ));

      expect(lastRequest().method, 'POST');
      expect(lastRequest().path, '/api/leave-requests');
      expect(lastRequest().data, {
        'leaveType': 'FULL',
        'startDate': '2026-08-10',
        'endDate': '2026-08-11',
        'useDays': 2.0,
        'leaveReason': null,
      });
    });

    test('사유가 있는 휴가는 leaveReason이 본문에 담긴다', () async {
      dioAdapter.onPost(
        '/api/leave-requests',
        (server) => server.reply(200, {}),
        data: {
          'leaveType': 'FAMILY',
          'startDate': '2026-08-10',
          'endDate': '2026-08-10',
          'useDays': 1.0,
          'leaveReason': '가족 돌봄',
        },
      );

      await repository.submitLeaveRequest(LeaveRequestCreate(
        leaveType: 'FAMILY',
        startDate: DateTime(2026, 8, 10),
        endDate: DateTime(2026, 8, 10),
        useDays: 1.0,
        leaveReason: '가족 돌봄',
      ));

      expect((lastRequest().data as Map)['leaveReason'], '가족 돌봄');
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onPost(
        '/api/leave-requests',
        (server) => server.reply(400, {'message': '잔여 연차가 부족합니다.'}),
        data: {
          'leaveType': 'FULL',
          'startDate': '2026-08-10',
          'endDate': '2026-08-10',
          'useDays': 1.0,
          'leaveReason': null,
        },
      );

      await expectLater(
        repository.submitLeaveRequest(LeaveRequestCreate(
          leaveType: 'FULL',
          startDate: DateTime(2026, 8, 10),
          endDate: DateTime(2026, 8, 10),
          useDays: 1.0,
          leaveReason: null,
        )),
        throwsA(isA<DioException>().having(
            (e) => e.response?.statusCode, 'statusCode', 400)),
      );
    });
  });

  group('searchAdminLeaveRequests', () {
    test('status가 경로와 쿼리 양쪽에 실린다', () async {
      dioAdapter.onGet(
        '/api/admin/leave-requests/PENDING',
        (server) => server.reply(200, listItems()),
        queryParameters: {'status': 'PENDING', 'team': 'SI사업팀'},
      );

      await repository.searchAdminLeaveRequests(
        status: 'PENDING',
        team: 'SI사업팀',
      );

      expect(lastRequest().path, '/api/admin/leave-requests/PENDING');
      expect(lastRequest().queryParameters['status'], 'PENDING');
      expect(lastRequest().queryParameters['team'], 'SI사업팀');
    });

    test('team이 null이어도 team 키는 쿼리에 유지된다', () async {
      dioAdapter.onGet(
        '/api/admin/leave-requests/PENDING',
        (server) => server.reply(200, []),
        queryParameters: {'status': 'PENDING', 'team': null},
      );

      await repository.searchAdminLeaveRequests(status: 'PENDING', team: null);

      expect(lastRequest().queryParameters.containsKey('team'), isTrue);
      expect(lastRequest().queryParameters['team'], isNull);
      // 발견한 문제: 리포지토리 주석은 "dio가 null 값은 전송하지 않음"이라고 적혀 있지만
      // 실제로는 값 없는 키(team)가 쿼리 문자열에 그대로 실린다.
      // 서버는 team 을 빈 문자열로 받게 되므로 주석과 동작이 어긋난다.
      expect(lastRequest().uri.query, 'status=PENDING&team');
    });

    test('employeeParam을 넘기면 쿼리에 함께 실린다', () async {
      dioAdapter.onGet(
        '/api/admin/leave-requests/APPROVED',
        (server) => server.reply(200, []),
        queryParameters: {
          'status': 'APPROVED',
          'team': null,
          'employeeParam': 'A0001',
        },
      );

      await repository.searchAdminLeaveRequests(
        status: 'APPROVED',
        team: null,
        employeeParam: 'A0001',
      );

      expect(lastRequest().queryParameters['employeeParam'], 'A0001');
    });

    // 발견한 문제: status가 null이면 경로에 문자열 'null'이 그대로 들어가
    // /api/admin/leave-requests/null 을 호출한다. (전체 상태 조회 의도로 null을
    // 넘기면 404가 난다)
    test('status가 null이면 경로에 문자열 null이 들어간다', () async {
      dioAdapter.onGet(
        '/api/admin/leave-requests/null',
        (server) => server.reply(200, []),
        queryParameters: {'team': 'SI사업팀'},
      );

      await repository.searchAdminLeaveRequests(
        status: null,
        team: 'SI사업팀',
      );

      expect(lastRequest().path, '/api/admin/leave-requests/null');
      expect(lastRequest().queryParameters.containsKey('status'), isFalse);
    });

    test('배열 응답을 목록 모델로 매핑한다', () async {
      dioAdapter.onGet(
        '/api/admin/leave-requests/PENDING',
        (server) => server.reply(200, listItems()),
        queryParameters: {'status': 'PENDING', 'team': null},
      );

      final items =
          await repository.searchAdminLeaveRequests(status: 'PENDING', team: null);

      expect(items, hasLength(1));
      expect(items.first.status, 'PENDING');
      expect(items.first.team, 'SI사업팀');
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onGet(
        '/api/admin/leave-requests/PENDING',
        (server) => server.reply(403, {'message': '권한이 없습니다.'}),
        queryParameters: {'status': 'PENDING', 'team': null},
      );

      await expectLater(
        repository.searchAdminLeaveRequests(status: 'PENDING', team: null),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('fetchPendingLeaveRequests', () {
    test('GET /api/admin/leave-requests/pending을 호출하고 결재 대기 모델로 매핑한다',
        () async {
      dioAdapter.onGet(
        '/api/admin/leave-requests/pending',
        (server) => server.reply(
            200, [fixtureJson('leave/pending_leave_request.json')]),
      );

      final items = await repository.fetchPendingLeaveRequests();

      expect(lastRequest().method, 'GET');
      expect(lastRequest().path, '/api/admin/leave-requests/pending');
      expect(lastRequest().queryParameters, isEmpty);
      expect(items, hasLength(1));
      expect(items.first, isA<PendingLeaveRequest>());
      expect(items.first.requestId, 21);
      expect(items.first.employeeName, '이신청');
      expect(items.first.useDays, 2.0);
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onGet(
        '/api/admin/leave-requests/pending',
        (server) => server.reply(401, {'message': '인증이 필요합니다.'}),
      );

      await expectLater(
        repository.fetchPendingLeaveRequests(),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('approveLeaveRequest', () {
    test('POST /api/admin/leave-requests/{requestId}/approve를 본문 없이 호출한다',
        () async {
      dioAdapter.onPost(
        '/api/admin/leave-requests/11/approve',
        (server) => server.reply(200, {}),
      );

      await repository.approveLeaveRequest(11);

      expect(lastRequest().method, 'POST');
      expect(lastRequest().path, '/api/admin/leave-requests/11/approve');
      expect(lastRequest().data, isNull);
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onPost(
        '/api/admin/leave-requests/11/approve',
        (server) => server.reply(400, {'message': '이미 처리된 신청입니다.'}),
      );

      await expectLater(
        repository.approveLeaveRequest(11),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('rejectLeaveRequest', () {
    test('POST .../reject에 rejectReason을 본문으로 보낸다', () async {
      dioAdapter.onPost(
        '/api/admin/leave-requests/11/reject',
        (server) => server.reply(200, {}),
        data: {'rejectReason': '업무 일정 조정 필요'},
      );

      await repository.rejectLeaveRequest(11, rejectReason: '업무 일정 조정 필요');

      expect(lastRequest().method, 'POST');
      expect(lastRequest().path, '/api/admin/leave-requests/11/reject');
      expect(lastRequest().data, {'rejectReason': '업무 일정 조정 필요'});
    });

    test('사유를 넘기지 않으면 rejectReason은 null로 실린다', () async {
      dioAdapter.onPost(
        '/api/admin/leave-requests/11/reject',
        (server) => server.reply(200, {}),
        data: {'rejectReason': null},
      );

      await repository.rejectLeaveRequest(11);

      expect(lastRequest().data, {'rejectReason': null});
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onPost(
        '/api/admin/leave-requests/11/reject',
        (server) => server.reply(400, {'message': '이미 처리된 신청입니다.'}),
        data: {'rejectReason': null},
      );

      await expectLater(
        repository.rejectLeaveRequest(11),
        throwsA(isA<DioException>()),
      );
    });
  });
}
