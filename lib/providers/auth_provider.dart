import 'dart:async' show StreamSubscription;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/auth_models.dart';
import '../models/employee.dart';
import '../services/api_client.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  bool _isLoggedIn = false;
  String? _role;
  String? _name;
  Employee? _employeeInfo;

  bool get isLoggedIn => _isLoggedIn;
  bool get isAdmin => _role == 'ADMIN';
  String? get name => _name;
  Employee? get employeeInfo => _employeeInfo;

  StreamSubscription? _foregroundNotificationSubscription;
  StreamSubscription? _openedNotificationSubscription;

  Future<void> fetchMyInfo() async {
    final response = await _apiClient.dio.get('/api/employees/me');
    _employeeInfo = Employee.fromJson(response.data);
  }

  // 앱 시작 시 저장된 JWT가 있을 경우 로그인 상태로 간주
  Future<void> tryAutoLogin() async {
    final token = await _apiClient.getToken();
    if (token == null) {
      return;
    }

    try {
      _isLoggedIn = true;
      await fetchMyInfo();
      notifyListeners();
    } catch (e) {
      // 저장된 JWT가 만료됐거나 서버 응답 실패 시,
      // JWT를 지우고 로그인 안 된 상태로 되돌려서 다시 로그인하도록 유도
      await _apiClient.clearToken();
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  Future<void> login(String employeeNumber, String password) async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission();

    final fcmToken = kIsWeb
        ? await messaging.getToken(
            vapidKey:
                "BK0OMc8V4bjy1iL0C1OUY2L_u3XaMHaHAdyMjDnmXTeDPb1LALjEeYQDZD_uQ0VkYVZIiArZ9OMSwRC7NPZBjfI",
          )
        : await messaging.getToken();

    final response = await _apiClient.dio.post(
      '/api/auth/signin',
      data: LoginRequest(
              employeeNumber: employeeNumber,
              password: password,
              fcmToken: fcmToken,
              deviceOs: kIsWeb
                  ? "Web"
                  : Platform.isAndroid
                      ? "Android"
                      : Platform.isIOS
                          ? "iOS"
                          : "Unknown")
          .toJson(),
    );

    final loginResponse = LoginResponse.fromJson(response.data);
    await _apiClient.saveToken(loginResponse.token);

    _isLoggedIn = true;
    _role = loginResponse.role;
    _name = loginResponse.name;

    await fetchMyInfo();
    _foregroundNotificationSubscription ??=
        FirebaseMessaging.onMessage.listen((message) {
      // TODO: 실행 도중 alert 팜업 필요할 수도.
      //       나중에 팝업 필요하면 flutter_local_notifications 추가 또는
      //       onMessage에서 local notification 호출
      debugPrint("앱 실행 중 FCM 수신");
      debugPrint(message.notification?.title);
      debugPrint(message.notification?.body);
    });

    _openedNotificationSubscription ??=
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      // TODO: 알림 클릭시 관련 장소로 네비게이팅 필요할 수도.
      debugPrint("알림 클릭");
      debugPrint(message.data.toString());
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint("종료 상태에서 알림 클릭");
      debugPrint(initialMessage.data.toString());

      // TODO: 해당 메시지를 파싱해서 신청 승인 목록으로 이동하는 네비게이팅 코드 필요.
      //       현재 코드는 임시 의사 코드
      // final type = initialMessage.data['type'];

      // if (type == 'approval') {
      //   final approvalId = initialMessage.data['approvalId'];

      //   // 승인 상세 화면 이동
      //   navigatorKey.currentState?.pushNamed(
      //     '/approval-detail',
      //     arguments: approvalId,
      //   );
      // }
    }

    notifyListeners();
  }

  Future<void> signUp(String employeeNumber, String password) async {
    await _apiClient.dio.post(
      '/api/auth/signup',
      data: SignUpRequest(employeeNumber: employeeNumber, password: password)
          .toJson(),
    );
  }

  Future<void> adminAuthRegister(String name, String department, String team,
      String position, String role, String email, String hireDate) async {
    await _apiClient.dio.post(
      '/api/admin/auth/register',
      data: AdminAuthRegisterRequest(
              name: name,
              department: department,
              team: team,
              position: position,
              role: role,
              email: email,
              hireDate: hireDate)
          .toJson(),
    );
  }

  Future<void> sendPasswordResetEmail(
    String employeeNumber,
    String email,
  ) async {
    try {
      // 본인의 백엔드 '비밀번호 찾기(메일발송)' API 주소로 변경하세요.
      final response = await _apiClient.dio.post(
        '/api/auth/forgot-password',
        data: {'employeeNumber': employeeNumber, 'email': email},
      );

      if (response.statusCode != 200) {
        throw Exception('발송 실패');
      }

      notifyListeners(); // 필요한 경우 상태 업데이트
    } catch (e) {
      rethrow; // 에러를 화면단(ForgotPasswordScreen)으로 던져서 에러 메시지를 띄우게 합니다.
    }
  }

  Future<void> logout() async {
    await _foregroundNotificationSubscription?.cancel();
    await _openedNotificationSubscription?.cancel();
    _foregroundNotificationSubscription = null;
    _openedNotificationSubscription = null;
    await _apiClient.clearToken();
    _isLoggedIn = false;
    _role = null;
    _name = null;
    _employeeInfo = null;
    notifyListeners();
  }

  Future<void> updateEmail(newEmail) async {
    // 기존 employeeInfo 객체에 이메일 갱신
    _employeeInfo = _employeeInfo!.copyWith(email: newEmail);
    notifyListeners();
  }

  // 💡 아이디 찾기 기능 추가
  Future<void> findId(String name, String email) async {
    try {
      // 본인의 백엔드 '아이디 찾기' API 주소로 변경하세요.
      final response = await _apiClient.dio.post(
        '/api/auth/find-id',
        data: {
          'name': name,
          'email': email,
        },
      );

      // 서버 응답에서 사번(아이디) 추출 (백엔드가 주는 key 이름에 맞게 수정하세요)
      // 예: { "employeeNumber": "EMP123456" } 형태로 온다고 가정한 코드입니다.
      // final String foundEmployeeNumber = response.data['employeeNumber'];

      // return foundEmployeeNumber;

      if (response.statusCode != 200) {
        throw Exception('발송 실패');
      }

      notifyListeners(); // 필요한 경우 상태 업데이트
    } catch (e) {
      // 에러를 화면단(FindAccountScreen)으로 던져서 에러 메시지를 띄우게 합니다.
      rethrow;
    }
  }
}
