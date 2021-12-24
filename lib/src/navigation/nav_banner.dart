import 'package:flutter/material.dart';

import 'nav_overlay_mixin.dart';
import 'overlay_dismissible.dart';

class BannerController with OverlayMixin, OverlayDismissible {
  BannerController({
    required this.stay,
    required this.content,
    BorderRadius? radius,
  }) : _radius = radius;
  @override
  final Duration stay;
  @override
  final Widget content;
  final BorderRadius? _radius;

  @override
  BorderRadius? get radius => _radius;

  @override
  double? get positionBottom => null;

  @override
  double? get positionLeft => 16;
  @override
  double? get positionRight => 16;

  @override
  double? get positionTop => 8;
  @override
  Object get showKey => BannerController;

  @override
  void onUserUpdate(double offset) {
    value = value + offset;
  }

  @override
  Widget buildChild(BuildContext context, Widget child) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Align(
          heightFactor: tweenValue,
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
      child: child,
    );
  }
}
