class PublicHoliday {
  final String name;
  final DateTime date;

  PublicHoliday({
    required this.name,
    required this.date,
  });

  factory PublicHoliday.fromJson(Map<String, dynamic> json) {
    return PublicHoliday(
      name: json['name'],
      date: DateTime.parse(json['date']),
    );
  }

  int get year => date.year;
  int get month => date.month;
  int get day => date.day;
}
