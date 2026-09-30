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
      expect(lastRequest().queryParameters, {'page': 0, 'size': 50});
      expect(lastRequest().uri.hasQuery, isTrue);
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
        'page': 0,
        'size': 50,
      });
    });

    test('일부 조건만 넘기면 그 키만 쿼리에 실린다', () async {
      dioAdapter.onGet(
        '/api/leave-requests/my',
        (server) => server.reply(200, listItems()),
        queryParameters: {'status': 'APPROVED'},
      );

      await repository.fetchMyLeaveRequests(status: 'APPROVED');

      expect(lastRequest().queryParameters, {'status': 'APPROVED', 'page': 0, 'size': 50});
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
      expect(lastRequest().queryParameters, {'page': 0, 'size': 50});
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
        'page': 0,
        'size': 50,
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
    test('approved 상태는 approved 경로로 보내고 값 있는 필터만 쿼리에 싣는다', () async {
      dioAdapter.onGet(
        '/api/admin/leave-requests/approved',
        (server) => server.reply(200, listItems()),
        queryParameters: {'team': 'SI사업팀'},
      );

      await repository.searchAdminLeaveRequests(
        status: 'APPROVED',
        team: ' SI사업팀 ',
      );

      expect(lastRequest().path, '/api/admin/leave-requests/approved');
      expect(lastRequest().queryParameters, {'team': 'SI사업팀', 'page': 0, 'size': 50});
    });

    test('team이 null이면 빈 team 쿼리를 만들지 않는다', () async {
      dioAdapter.onGet(
        '/api/admin/leave-requests/approved',
        (server) => server.reply(200, []),
      );

      await repository.searchAdminLeaveRequests(status: 'approved', team: null);

      expect(lastRequest().queryParameters.containsKey('team'), isFalse);
      expect(lastRequest().uri.query, isEmpty);
    });

    test('employeeParam은 trim 후 값이 있을 때만 전송한다', () async {
      dioAdapter.onGet(
        '/api/admin/leave-requests/rejected',
        (server) => server.reply(200, []),
        queryParameters: {'employeeParam': 'A0001'},
      );

      await repository.searchAdminLeaveRequests(
        status: 'rejected',
        team: null,
        employeeParam: ' A0001 ',
      );

      expect(lastRequest().queryParameters, {'employeeParam': 'A0001', 'page': 0, 'size': 50});
    });

    test('status가 null이면 잘못된 null 경로를 호출하지 않고 즉시 거절한다', () async {
      await expectLater(
        repository.searchAdminLeaveRequests(
          status: null,
          team: 'SI사업팀',
        ),
        throwsArgumentError,
      );
    });

    test('배열 응답을 목록 모델로 매핑한다', () async {
      dioAdapter.onGet(
        '/api/admin/leave-requests/approved',
        (server) => server.reply(200, listItems()),
      );

      final items =
          await repository.searchAdminLeaveRequests(status: 'approved', team: null);

      expect(items, hasLength(1));
      expect(items.first.status, 'PENDING');
      expect(items.first.team, 'SI사업팀');
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onGet(
        '/api/admin/leave-requests/approved',
        (server) => server.reply(403, {'message': '권한이 없습니다.'}),
      );

      await expectLater(
        repository.searchAdminLeaveRequests(status: 'approved', team: null),
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
      expect(lastRequest().queryParameters, {'page': 0, 'size': 50});
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
