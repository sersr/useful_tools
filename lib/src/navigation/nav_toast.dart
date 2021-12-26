import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

import 'overlay_side.dart';

class ToastController extends OverlaySideDefault {
  ToastController({
    required Duration stay,
    required Widget content,
    double bottomPadding = 80,
    BorderRadius? radius,
    this.padding,
    Color? color,
    Curve? curve,
    bool? closeOndismissed,
  })  : positionBottom = bottomPadding,
        super(
          stay: stay,
          content: content,
          radius: radius,
          color: color,
          curve: curve,
          closeOndismissed: closeOndismissed,
        );

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
  late final fadeAnimation = curveTween.animate(controller);

  @override
  Object get showKey => ToastController;

  @override
  Future<bool> showAsync() {
    return EventQueue.runTask(
      showKey,
      () => show().then((value) {
        if (value) _ignore.value = false;
        return future.then((_) => value);
      }),
    );
  }

  @override
  bool hide() {
    final value = super.hide();
    if (value) _ignore.value = true;

    return value;
  }
}
