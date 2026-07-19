class PublicHolidayDto {
  final String name;
  final DateTime date;

  PublicHolidayDto({required this.name, required this.date});

  factory PublicHolidayDto.fromJson(Map<String, dynamic> json) {
    return PublicHolidayDto(name: json['name'], date: DateTime.parse(json['date']));
  }

  int get year => date.year;
  int get month => date.month;
  int get day => date.day;
}
