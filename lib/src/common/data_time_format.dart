extension DateTimeFormat on DateTime {
  String get toStringFormat {
    return '$month/$day/$year ${hour.timePadLeft}:${minute.timePadLeft}:${second.timePadLeft} ${hour < 9 ? 'AM' : 'PM'}';
  }

  String get hourAndMinuteFormat {
    return '${hour.timePadLeft}:${minute.timePadLeft}';
  }
}

extension on int {
  String get timePadLeft {
    return toString().padLeft(2, '0');
  }
}
