import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

import 'nav_overlay_mixin.dart';
import 'overlay_side.dart';

class ToastController with OverlayMixin, OverlaySide {
  ToastController({
    required this.content,
    required this.stay,
    double bottomPadding = 80,
    this.color,
    this.radius = const BorderRadius.all(Radius.circular(8)),
    this.padding,
  }) : positionBottom = bottomPadding;

  @override
  final Duration stay;
  @override
  final Widget content;

  @override
  final Color? color;
  @override
  final BorderRadius? radius;

  @override
  final double positionBottom;
  @override
  final double? positionTop = null;

  @override
  VoidCallback? get onTap => _onTap;

  final EdgeInsets? padding;
  void _onTap() => hide();

  @override
  Widget buildChild(BuildContext context, {required Widget child}) {
    return AnimatedBuilder(
      animation: _ignore,
      builder: (context, child) {
        return IgnorePointer(ignoring: _ignore.value, child: child);
      },
      child: Center(
        child: IntrinsicWidth(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: RepaintBoundary(
              child: super.buildChild(
                context,
                child: Container(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }

  final _ignore = ValueNotifier(true);
  late final fadeAnimation = curve.animate(controller);

  @override
  Object get showKey => ToastController;

  @override
  Future<bool> showAsync() {
    return EventQueue.runTask(showKey, () {
      if (show()) {
        if (_ignore.value) {
          _ignore.value = false;
        }
        return future.then((_) => true);
      }
      return false;
    });
  }

  @override
  bool hide() {
    if (super.hide()) {
      if (!_ignore.value) {
        _ignore.value = true;
      }
      return true;
    }
    return false;
  }
}
