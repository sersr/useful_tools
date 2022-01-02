import 'dart:async';

import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

import 'nav_overlay_mixin.dart';
import 'overlay_event.dart';

mixin OverlaySideBase on OverlayMixin, OverlayEvent {
  Duration? get stay;

  /// 获取size
  final _privateKey = GlobalKey();
  GlobalKey get privateKey => _privateKey;
  
  OverlayEntry? _entry;
  OverlayEntry get entry => _entry!;

  bool _user = false;
  bool _userMode = false;

  bool get canHide => hided;

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

  void _userleave([DragEndDetails? details]) {
    if (closed) return;
    _userMode = false;
    _user = value != 1.0;

    var vHide = false;
    final velocity = details?.primaryVelocity;

    if (velocity != null) {
      if (isTop || isLeft) {
        vHide = velocity < -100;
      } else if (isBottom || isRight) {
        vHide = velocity > 100;
      }
    }

    if (hided || value < 0.5 || vHide) {
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

        double? extent;
        if (isVertical) {
          extent = localSize?.height;
        } else if (isHorizontal) {
          extent = localSize?.width;
        }

        if (extent != null && offset != null) {
          // assert(Log.w('....$hided $localSize $value'));
          final delta = offset / extent;
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
    return null;
  }

  @override
  bool shouldHide() => !_userMode;

  Curve get curve => Curves.ease;

  final tween = Tween<double>(begin: 0.0, end: 1.0);
  late final curveTween = tween.chain(CurveTween(curve: curve));

  double get tweenValue => controller.drive(_user ? tween : curveTween).value;

  @override
  void onCompleted() {
    super.onCompleted();
    final hold = stay;
    if (hold != null) {
      EventQueue.runOne(_privateKey, () => release(hold).whenComplete(hide));
    }
  }

  bool get closeOndismissed => true;

  @override
  void onDismissed() {
    super.onDismissed();
    if (closeOndismissed) {
      close();
    }
  }

  Object? get showKey => OverlaySideBase;

  @override
  FutureOr<bool> showAsync() {
    FutureOr<bool> inner() {
      return super.showAsync().then((value) => future.then((_) => value));
    }

    if (showKey == null) return inner();

    return EventQueue.runTask(showKey, inner);
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
    // context 发生改变
    Widget child = Builder(
      builder: (context) {
        return buildChild(context);
      },
    );
    child = transitionBuild(child);

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
        child: SafeArea(top: false, child: child));
  }

  Widget buildChild(BuildContext context);

  Widget transitionBuild(Widget child) {
    return child;
  }
}

// single side
mixin OverlayMixinSide on OverlayMixin, OverlayEvent, OverlaySideBase {
  Widget get content;
  bool get useMaterial => true;

  Color? get color => null;
  BorderRadius? get radius => null;

  @override
  Widget buildChild(BuildContext context) {
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

    Widget body = Container(
      padding: isTop ? null : innerPadding,
      child: DefaultTextStyle(
        style: TextStyle(
            color: isDark
                ? const Color.fromARGB(255, 44, 44, 44)
                : const Color.fromARGB(255, 221, 221, 221)),
        child: content,
      ),
    );
    if (useMaterial) {
      body = Material(
        color: color ?? themeColor,
        borderRadius: radius,
        child: body,
      );
    }
    return MediaQuery.removePadding(
      context: context,
      removeBottom: remove,
      removeLeft: remove,
      removeRight: remove,
      removeTop: remove,
      child: Container(
        key: privateKey,
        padding: isTop ? innerPadding : null,
        child: body,
      ),
    );
  }
}

abstract class OverlaySideDefault
    with OverlayMixin, OverlayEvent, OverlaySideBase, OverlayMixinSide {
  OverlaySideDefault({
    required this.content,
    BorderRadius? radius,
    this.stay,
    this.color,
    Curve? curve,
    bool? closeOndismissed,
  })  : _curve = curve,
        _closeOnDissmissed = closeOndismissed ?? true,
        _radius = radius;

  @override
  final Duration? stay;
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
  Widget transitionBuild(Widget child) {
    if (onTap != null) {
      return child;
    }
    if (isHorizontal) {
      child = IntrinsicWidth(child: child);
    } else if (isVertical) {
      child = IntrinsicHeight(child: child);
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
