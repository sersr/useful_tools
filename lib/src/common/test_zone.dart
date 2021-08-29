import 'dart:async';

FutureOr<T> runZonePrint<T>(FutureOr<T> Function() callback) {
  return runZoned(callback,
      zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => Zone.root.print(line)));
}
