import 'package:flutter/material.dart';

import '../navigation/export.dart';

typedef SnackbarDelegate = OverlayMixinDelegate;
typedef BannerDelegate = OverlayMixinDelegate;
typedef ToastDelegate = OverlayMixinDelegate;

extension SnackBarExt on OverlayBase {
  SnackbarDelegate snackBar(
    Widget content, {
    Duration duration = const Duration(seconds: 3),
    Duration animationDuration = const Duration(milliseconds: 300),
    Duration delayDuration = Duration.zero,
    bool? closeOndismissed,
    Color? color,
  }) =>
      _syncSnackBar(
        content,
        duration: duration,
        animationDuration: animationDuration,
        delayDuration: delayDuration,
        color: color,
        closeOndismissed: closeOndismissed,
      );

  BannerDelegate banner(
    Widget content, {
    Duration duration = const Duration(seconds: 3),
    Duration animationDuration = const Duration(milliseconds: 300),
    Duration delayDuration = Duration.zero,
    Color? color,
    BorderRadius? radius = const BorderRadius.all(Radius.circular(8)),
  }) {
    return _syncBanner(
      content,
      duration: duration,
      animationDuration: animationDuration,
      delayDuration: delayDuration,
      radius: radius,
      color: color,
    );
  }

  Future<void> showSnackBar(SnackbarDelegate snackbar) => showOverlay(snackbar);

  ToastDelegate toast(
    Widget content, {
    Duration duration = const Duration(seconds: 3),
    Duration animationDuration = const Duration(milliseconds: 300),
    BorderRadius? radius = const BorderRadius.all(Radius.circular(8)),
    Color? color,
    double bottomPadding = 80.0,
    EdgeInsets? padding,
    bool? closeOndismissed,
  }) {
    return _syncToast(
      content,
      duration: duration,
      radius: radius,
      color: color,
      bottomPadding: bottomPadding,
      padding: padding,
      closeOndismissed: closeOndismissed,
    );
  }
}

Future<void> showOverlay(OverlayDelegate overlay) {
  overlay.init();
  return overlay.future;
}

SnackbarDelegate _syncSnackBar(
  Widget content, {
  Duration duration = const Duration(seconds: 3),
  Duration animationDuration = const Duration(milliseconds: 400),
  Duration delayDuration = Duration.zero,
  Color? color,
  bool? closeOndismissed,
}) {
  final controller = SnackBarController(
    stay: duration,
    content: content,
    color: color,
    closeOndismissed: closeOndismissed,
  );
  return SnackbarDelegate(
    controller,
    animationDuration,
    delayDuration: delayDuration,
  )..show();
}

BannerDelegate _syncBanner(
  Widget content, {
  Duration duration = const Duration(seconds: 3),
  Duration animationDuration = const Duration(milliseconds: 400),
  Duration delayDuration = Duration.zero,
  BorderRadius? radius,
  Color? color,
  bool? closeOndismissed,
}) {
  final controller = BannerController(
    stay: duration,
    content: content,
    radius: radius,
    color: color,
    closeOndismissed: closeOndismissed,
  );
  return BannerDelegate(
    controller,
    animationDuration,
    delayDuration: delayDuration,
  )..show();
}

ToastDelegate _syncToast(
  Widget content, {
  Duration duration = const Duration(seconds: 3),
  Duration animationDuration = const Duration(milliseconds: 400),
  BorderRadius? radius,
  Color? color,
  double bottomPadding = 80.0,
  EdgeInsets? padding,
  bool? closeOndismissed,
}) {
  final controller = ToastController(
    content: content,
    stay: duration,
    bottomPadding: bottomPadding,
    color: color,
    radius: radius,
    padding: padding,
    closeOndismissed: closeOndismissed,
  );
  return ToastDelegate(
    controller,
    animationDuration,
  )..show();
}
