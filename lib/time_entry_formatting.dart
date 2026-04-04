DateTime dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime startOfWeekMonday(DateTime value) {
  final day = dateOnly(value);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

String formatDurationMinutes(int durationMinutes) {
  if (durationMinutes <= 0) {
    return '0m';
  }

  final hours = durationMinutes ~/ 60;
  final minutes = durationMinutes % 60;

  if (hours == 0) {
    return '${minutes}m';
  }

  if (minutes == 0) {
    return '${hours}h';
  }

  return '${hours}h ${minutes}m';
}

String formatDayHeading(DateTime day) {
  const weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final normalizedDay = dateOnly(day);
  final weekdayName = weekdayNames[normalizedDay.weekday - 1];
  final monthName = monthNames[normalizedDay.month - 1];
  return '$weekdayName ${normalizedDay.day} $monthName ${normalizedDay.year}';
}

String formatWeekHeading(DateTime weekStart) {
  return 'Week of ${formatDayHeading(startOfWeekMonday(weekStart))}';
}
