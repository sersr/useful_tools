import 'package:flutter/material.dart';

import 'nav_overlay_mixin.dart';
import 'overlay_dismissible.dart';

class SnackBarController with OverlayMixin, OverlayDismissible {
  SnackBarController({
    required this.stay,
    required this.content,
  });
  @override
  final Duration stay;
  @override
  final Widget content;

  @override
  double? get positionTop => null;

  @override
  Object get showKey => SnackBarController;

  @override
  Widget buildChild(BuildContext context, Widget child) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Align(
          heightFactor: tweenValue,
          alignment: Alignment.topCenter,
          child: child,
        );
      },
      child: child,
    );
  }
}
