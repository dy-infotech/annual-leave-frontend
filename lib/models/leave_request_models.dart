class LeaveRequestCreate {
  final DateTime startDate;
  final DateTime endDate;
  final double useDays;

  LeaveRequestCreate({
    required this.startDate,
    required this.endDate,
    required this.useDays,
  });

  Map<String, dynamic> toJson() => {
        'startDate': _formatDate(startDate),
        'endDate': _formatDate(endDate),
        'useDays': useDays,
      };

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
