import 'dart:async';

import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

import 'nav_overlay_mixin.dart';

// single side
mixin OverlayMixinSide on OverlayMixin {
  Duration get stay;
  final _privateKey = GlobalKey();
  GlobalKey get privateKey => _privateKey;

  OverlayEntry? _entry;
  OverlayEntry get entry => _entry!;
  Widget get content;

  bool _user = false;
  bool _userMode = false;

  bool get canHide => hided;

  Color? get color => null;
  BorderRadius? get radius => null;
  double? get positionLeft => 0;
  double? get positionRight => 0;
  double? get positionTop => 0;
  double? get positionBottom => 0;
  void _userEnter(_) {
    if (closed || _userMode) return;

    _userMode = true;
    controller.stop(canceled: true);
    _user = true;
  }

  void _userleave([_]) {
    if (closed) return;
    _userMode = false;
    _user = value != 1.0;

    if (hided || value < 0.5) {
      hide();
    } else {
      show();
    }
  }

  void _userUpdate(DragUpdateDetails d) {
    if (closed) return;
    if (overlay.mounted) {
      try {
        final localSize = size;
        final offset = d.primaryDelta;
        if (localSize != null && offset != null) {
          // assert(Log.w('....$hided $localSize $value'));

          final delta = offset / localSize.height;
          onUserUpdate(delta);
          if (closed) return;
        }
      } catch (e, s) {
        assert(Log.e('error: $e\n$s'));
      }
    }
  }

  void onUserUpdate(double delta) {
    if (isTop || isLeft) {
      value = value + delta;
    } else if (isBottom || isRight) {
      value = value - delta;
    }
  }

  VoidCallback? get onTap => null;

  Size? get size {
    try {
      return _privateKey.currentContext?.size;
    } catch (e) {
      Log.i(e);
    }
  }

  @override
  bool shouldHide() => !_userMode;

  Curve get curve => Curves.ease;

  final tween = Tween<double>(begin: 0.0, end: 1.0);
  late final curveTween = tween.chain(CurveTween(curve: curve));

  double get tweenValue => controller.drive(_user ? tween : curveTween).value;

  @override
  void onCompleted() {
    EventQueue.runOne(_privateKey, () => release(stay).whenComplete(hide));
  }

  bool get closeOndismissed => true;

  @override
  void onDismissed() {
    if (closeOndismissed) {
      close();
    }
  }

  Object? get showKey => OverlayMixinSide;

  @override
  FutureOr<bool> showAsync() {
    if (showKey == null) {
      return show().then((value) => future.then((_) => value));
    }
    return EventQueue.runTask(showKey, () {
      return show().then((value) => future.then((_) => value));
    });
  }

  @override
  void onCreateOverlayEntry() {
    _entry = OverlayEntry(builder: build);
    overlay.insert(entry);
  }

  @override
  void onRemoveOverlayEntry() {
    if (entry.mounted) {
      entry.remove();
    }
  }

  @mustCallSuper
  Widget buildChild(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final themeColor = isDark
        ? colorScheme.onSurface
        : Color.alphaBlend(
            colorScheme.onSurface.withOpacity(0.80), colorScheme.surface);
    var padding = MediaQuery.of(context).padding;
    var innerPadding = EdgeInsets.zero;
    var remove = onTap == null;

    if (isTop) {
      innerPadding = EdgeInsets.only(
        left: padding.left,
        right: padding.right,
        top: padding.top + positionTop!,
      );
    } else if (isBottom) {
      innerPadding = EdgeInsets.only(left: padding.left, right: padding.right);
    } else if (isHorizontal) {
      innerPadding = EdgeInsets.only(top: padding.top, bottom: padding.bottom);
    }
    return MediaQuery.removePadding(
      context: context,
      removeBottom: remove,
      removeLeft: remove,
      removeRight: remove,
      removeTop: remove,
      child: Container(
        key: _privateKey,
        padding: isTop ? innerPadding : null,
        child: Material(
          color: color ?? themeColor,
          borderRadius: radius,
          child: Container(
            padding: isTop ? null : innerPadding,
            child: DefaultTextStyle(
              style: TextStyle(
                  color: isDark
                      ? const Color.fromARGB(255, 44, 44, 44)
                      : const Color.fromARGB(255, 221, 221, 221)),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        ),
      ),
    );
  }

  bool get topNull => positionTop == null;
  bool get leftNull => positionLeft == null;
  bool get rightNull => positionRight == null;
  bool get bottomNull => positionBottom == null;
  bool get isTop => bottomNull && !topNull && !leftNull && !rightNull;
  bool get isLeft => rightNull && !topNull && !leftNull && !bottomNull;
  bool get isBottom => topNull && !leftNull && !rightNull && !bottomNull;
  bool get isRight => leftNull && !topNull && !rightNull && !bottomNull;
  bool get isHorizontal => isLeft || isRight;
  bool get isVertical => isTop || isBottom;

  Widget build(BuildContext context) {
    Widget child = RepaintBoundary(
      child: Builder(
        builder: (context) {
          return buildChild(context, child: content);
        },
      ),
    );
    if (onTap != null) {
      child = GestureDetector(onTap: onTap, child: child);
    } else {
      child = GestureDetector(
        onHorizontalDragDown: isHorizontal ? _userEnter : null,
        onHorizontalDragStart: isHorizontal ? _userEnter : null,
        onHorizontalDragUpdate: isHorizontal ? _userUpdate : null,
        onHorizontalDragEnd: isHorizontal ? _userleave : null,
        onHorizontalDragCancel: isHorizontal ? _userleave : null,
        onVerticalDragDown: isVertical ? _userEnter : null,
        onVerticalDragStart: isVertical ? _userEnter : null,
        onVerticalDragUpdate: isVertical ? _userUpdate : null,
        onVerticalDragEnd: isVertical ? _userleave : null,
        onVerticalDragCancel: isVertical ? _userleave : null,
        child: child,
      );
    }
    return Positioned(
      top: isTop ? null : positionTop,
      left: positionLeft,
      right: positionRight,
      bottom: positionBottom,
      child: Builder(builder: (context) {
        var padding = MediaQuery.of(context).padding;

        var margin = EdgeInsets.zero;

        if (isTop) {
        } else if (isBottom) {
          margin = EdgeInsets.only(bottom: padding.bottom);
        } else if (isLeft) {
          margin = EdgeInsets.only(left: padding.left);
        } else if (isRight) {
          margin = EdgeInsets.only(right: padding.right);
        }
        return Container(padding: margin, child: child);
      }),
    );
  }
}

abstract class OverlaySideDefault with OverlayMixin, OverlayMixinSide {
  OverlaySideDefault({
    required this.stay,
    required this.content,
    BorderRadius? radius,
    this.color,
    Curve? curve,
    bool? closeOndismissed,
  })  : _curve = curve,
        _closeOnDissmissed = closeOndismissed ?? true,
        _radius = radius;

  @override
  final Duration stay;
  @override
  final Widget content;
  @override
  final Color? color;

  final Curve? _curve;
  @override
  Curve get curve => _curve ?? super.curve;

  final BorderRadius? _radius;
  @override
  BorderRadius? get radius => _radius;

  final bool _closeOnDissmissed;
  @override
  bool get closeOndismissed => _closeOnDissmissed;

  Alignment? get alignment => null;

  @override
  Widget buildChild(BuildContext context, {required Widget child}) {
    child = super.buildChild(context, child: child);
    if (onTap != null) {
      return child;
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Align(
          heightFactor: isVertical ? tweenValue : null,
          widthFactor: isHorizontal ? tweenValue : null,
          alignment: alignment ?? Alignment.center,
          child: child,
        );
      },
      child: child,
    );
  }
}
