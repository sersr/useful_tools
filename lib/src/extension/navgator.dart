import 'package:flutter/material.dart';

import '../navigation/export.dart';

typedef SnackbarDelegate = OverlayDismissibleDelegate;
typedef BannerDelegate = OverlayDismissibleDelegate;

extension SnackBarExt on OverlayBase {
  SnackbarDelegate snackBar(
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

  BannerDelegate banner(
    Widget content, {
    Duration duration = const Duration(seconds: 3),
    Duration animationDuration = const Duration(milliseconds: 300),
    Duration delayDuration = Duration.zero,
    BorderRadius? radius = const BorderRadius.all(Radius.circular(12)),
  }) {
    return _syncBanner(
      content,
      duration: duration,
      animationDuration: animationDuration,
      delayDuration: delayDuration,
      radius: radius,
    );
  }

  Future<void> showSnackBar(SnackbarDelegate snackbar) {
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

SnackbarDelegate _syncSnackBar(
  Widget content, {
  Duration duration = const Duration(seconds: 3),
  Duration animationDuration = const Duration(milliseconds: 300),
  Duration delayDuration = Duration.zero,
}) {
  final controller = SnackBarController(stay: duration, content: content);
  return SnackbarDelegate(
    controller,
    animationDuration,
    delayDuration: delayDuration,
  )..init();
}

BannerDelegate _syncBanner(
  Widget content, {
  Duration duration = const Duration(seconds: 3),
  Duration animationDuration = const Duration(milliseconds: 300),
  Duration delayDuration = Duration.zero,
  BorderRadius? radius,
}) {
  final controller = BannerController(
    stay: duration,
    content: content,
    radius: radius,
  );
  return BannerDelegate(
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
