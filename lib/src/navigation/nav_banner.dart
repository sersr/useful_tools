import 'package:flutter/material.dart';

import 'nav_overlay_mixin.dart';
import 'overlay_side.dart';

class BannerController with OverlayMixin, OverlaySide {
  BannerController({
    required this.stay,
    required this.content,
    BorderRadius? radius,
    this.color,
  }) : _radius = radius;
  @override
  final Duration stay;
  @override
  final Widget content;
  @override
  final Color? color;
  
  final BorderRadius? _radius;
  @override
  BorderRadius? get radius => _radius;

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
  Widget buildChild(BuildContext context, {required Widget child}) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Align(
          heightFactor: tweenValue,
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
      child: super.buildChild(context, child: child),
    );
  }
}
