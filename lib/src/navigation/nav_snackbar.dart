import 'package:flutter/material.dart';

import 'nav_overlay_mixin.dart';
import 'overlay_side.dart';

class SnackBarController with OverlayMixin, OverlaySide {
  SnackBarController({
    required this.stay,
    required this.content,
    this.color,
  });
  @override
  final Duration stay;
  @override
  final Widget content;
  @override
  final Color? color;

  @override
  double? get positionTop => null;

  @override
  Object get showKey => SnackBarController;

  @override
  Widget buildChild(BuildContext context, {required Widget child}) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Align(
          heightFactor: tweenValue,
          alignment: Alignment.topCenter,
          child: child,
        );
      },
      child: super.buildChild(context, child: child),
    );
  }
}
