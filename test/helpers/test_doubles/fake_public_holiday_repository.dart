import 'package:annual_leave_frontend/features/leave/models/public_holiday.dart';
import 'package:annual_leave_frontend/features/leave/repositories/public_holiday_repository.dart';

/// PublicHolidayRepository 인메모리 페이크.
class FakePublicHolidayRepository implements PublicHolidayRepository {
  List<PublicHoliday> holidaysToReturn = [];
  Object? errorToThrow;

  @override
  Future<List<PublicHoliday>> fetchPublicHolidays({bool refresh = false}) async {
    if (errorToThrow != null) throw errorToThrow!;
    return holidaysToReturn;
  }
}
