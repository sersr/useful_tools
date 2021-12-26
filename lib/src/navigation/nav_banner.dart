import 'package:flutter/material.dart';

import 'overlay_side.dart';

class BannerController extends OverlaySideDefault {
  BannerController({
    required Duration stay,
    required Widget content,
    BorderRadius? radius,
    Color? color,
    Curve? curve,
    bool? closeOndismissed,
  }) : super(
          stay: stay,
          content: content,
          radius: radius,
          color: color,
          curve: curve,
          closeOndismissed: closeOndismissed,
        );

  @override
  double? get positionBottom => null;

  @override
  double? get positionLeft => 8;
  @override
  double? get positionRight => 8;
  @override
  double? get positionTop => 8;
  @override
  Object get showKey => BannerController;
  @override
  Alignment? get alignment => Alignment.bottomCenter;
}
