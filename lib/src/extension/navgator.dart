import 'package:flutter/material.dart';

import '../navigation/export.dart';
import 'nav_snackbar.dart';
import 'nav_toast.dart';

extension SnackBarExt on NavGlobal {
  OverlayState? get overlay => observer.navigator?.overlay;

  SnackbarDelagate snackBar(
    Widget content, {
    Duration duration = const Duration(seconds: 3),
    Duration animationDuration = const Duration(milliseconds: 300),
    Duration delayDuration = Duration.zero,
  }) {
    return _syncSnackBar(
      content,
      duration: duration,
      animationDuration: animationDuration,
      delayDuration: delayDuration,
    );
  }

  Future<void> showSnackBar(SnackbarDelagate snackbar) {
    snackbar.init();
    return snackbar.future;
  }

  ToastDelegate toast(
    Widget content, {
    Duration duration = const Duration(seconds: 3),
    Duration animationDuration = const Duration(milliseconds: 300),
    BorderRadius? radius,
    Color? color,
    double bottomPadding = 80.0,
    EdgeInsets? padding,
  }) {
    return _syncToast(
      content,
      duration: duration,
      radius: radius,
      color: color,
      bottomPadding: bottomPadding,
      padding: padding,
    );
  }
}

SnackbarDelagate _syncSnackBar(
  Widget content, {
  Duration duration = const Duration(seconds: 3),
  Duration animationDuration = const Duration(milliseconds: 300),
  Duration delayDuration = Duration.zero,
}) {
  final controller = SnackBarController(stay: duration, content: content);
  return SnackbarDelagate(
    controller,
    animationDuration,
    delayDuration: delayDuration,
  )..init();
}

ToastDelegate _syncToast(
  Widget content, {
  Duration duration = const Duration(seconds: 3),
  Duration animationDuration = const Duration(milliseconds: 300),
  BorderRadius? radius,
  Color? color,
  double bottomPadding = 80.0,
  EdgeInsets? padding,
}) {
  final controller = ToastController(
    content: content,
    duration: duration,
    bottomPadding: bottomPadding,
    color: color,
    radius: radius,
    padding: padding,
  );
  return ToastDelegate(
    controller,
    animationDuration,
  )..init();
}
