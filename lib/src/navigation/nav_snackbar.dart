import 'package:flutter/material.dart';

import 'overlay_side.dart';

class SnackBarController extends OverlaySideDefault {
  SnackBarController({
    required Duration stay,
    required Widget content,
    BorderRadius? radius,
    Color? color,
    bool? closeOndismissed,
  }) : super(
          stay: stay,
          content: content,
          radius: radius,
          color: color,
          closeOndismissed: closeOndismissed,
        );

  @override
  double? get positionTop => null;

  @override
  Object get showKey => SnackBarController;
  @override
  Alignment? get alignment => Alignment.topCenter;
}