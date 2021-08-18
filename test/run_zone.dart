// ignore_for_file: avoid_print

import 'dart:async';

import 'package:useful_tools/common.dart';

Future<void> runZone(FutureOr<void> Function() callback) async {
  return runZoned(callback,
      zoneSpecification: ZoneSpecification(
          scheduleMicrotask: (zone, parentDelegate, self, callback) {
        Log.w('scheduleMictotask', showPath: false);
        return parentDelegate.scheduleMicrotask(zone, callback);
      }, registerUnaryCallback: <R, T>(zone, parenDelegate, self, callback) {
        Log.w('registerUnaryCallback', showPath: false);
        return parenDelegate.registerUnaryCallback(zone, callback);
      }, createTimer: (zone, parent, self, duration, callback) {
        Log.w('createTimer', showPath: false);
        return parent.createTimer(zone, duration, callback);
      }, print: (zone, parent, self, line) {
        return Zone.root.print(line);
      }));
}
