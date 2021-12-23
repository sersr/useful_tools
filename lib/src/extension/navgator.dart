import 'dart:async';

import 'package:utils/utils.dart';

import '../navigation/export.dart';
import 'package:flutter/material.dart';

extension SnackBarExt on NavGlobal {
  OverlayState? get overlay => observer.navigator?.overlay;

  SnackbarDelagate snackBar(
    Widget content, {
    Duration duration = const Duration(seconds: 3),
    Duration animationDuration = const Duration(milliseconds: 300),
    Duration delayDuration = Duration.zero,
  }) {
    return _syncSnackBar(
      content,
      getOverlay,
      duration: duration,
      animationDuration: animationDuration,
      delayDuration: delayDuration,
    );
  }

  Future<void> showSnackBar(SnackbarDelagate snackbar) {
    snackbar.init(getOverlay);
    return snackbar.future;
  }
}

SnackbarDelagate _syncSnackBar(
  Widget content,
  OverlayGetter overlay, {
  Duration duration = const Duration(seconds: 3),
  Duration animationDuration = const Duration(milliseconds: 300),
  Duration delayDuration = Duration.zero,
}) {
  final controller = SnackBarController(stay: duration, content: content);
  return SnackbarDelagate(
    controller,
    animationDuration,
    delayDuration: delayDuration,
  )..init(overlay);
}

class SnackBarController with OverlayMixin {
  SnackBarController({
    required this.stay,
    required this.content,
  });
  final Duration stay;
  final _privateKey = GlobalKey();
  final Widget content;

  bool _user = false;
  bool _userMode = false;
  bool _userHide = false;
  bool get canHide => _userHide || hided;

  void _userEnter(_) {
    _userMode = true;
    _user = true;
  }

  void _userleave([_]) {
    _userMode = false;
    if (value == 1.0) {
      _user = false;
    }
    if (canHide) hide();
  }

  void _userUpdate(DragUpdateDetails d) {
    if (closed) return;
    if (overlay.mounted) {
      try {
        final size = _privateKey.currentContext?.size;
        final offset = d.primaryDelta;
        if (size != null && offset != null) {
          value = value - offset / size.height;
          _userHide = value < 1.0;
        }
      } catch (e) {
        Log.e('error: $e');
      }
    }
  }

  @override
  bool shouldHide() => !_userMode;

  @override
  double get tweenValue => controller.drive(_user ? tween : curve).value;

  @override
  void onCompleted() {
    hided
        ? hide()
        : EventQueue.runOne(
            _privateKey, () => release(stay).whenComplete(hide));
  }

  @override
  void onDismissed() => close();

  @override
  void onShow() {
    EventQueue.push(SnackBarController, () {
      super.onShow();
      return future;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onVerticalDragStart: _userEnter,
        onVerticalDragUpdate: _userUpdate,
        onVerticalDragEnd: _userleave,
        onVerticalDragCancel: _userleave,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Align(
              heightFactor: tweenValue,
              alignment: Alignment.topCenter,
              child: child,
            );
          },
          child: RepaintBoundary(
            key: _privateKey,
            child: Material(
              child: SizedBox(width: double.infinity, child: content),
            ),
          ),
        ),
      ),
    );
  }
}

typedef WidgetBuilder = Widget Function(BuildContext context);

/// 必须先调用[init]初始化
mixin OverlayMixin {
  OverlayState? _overlayState;
  OverlayEntry? _entry;

  OverlayState get overlay => _overlayState!;
  OverlayEntry get entry => _entry!;
  Future<void> get future => _completer.future;

  late final _completer = Completer<void>();
  void _complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  final tween = Tween<double>(begin: 0.0, end: 1.0);
  late final curve = tween.chain(CurveTween(curve: Curves.ease));
  double get tweenValue => controller.drive(curve).value;

  late AnimationController controller;

  double get value => controller.value;
  set value(double v) {
    controller.value = v.clamp(0.0, 1.0);
  }

  bool get inited => _inited;

  bool _inited = false;
  void init({required OverlayState overlayState, required Duration duration}) {
    if (closed) return;
    if (!mounted) _inited = false;
    if (_inited) return;
    _overlayState = overlayState;
    if (mounted) {
      _inited = true;
      controller = AnimationController(vsync: overlayState, duration: duration);
      _entry = OverlayEntry(builder: build);
      overlayState.insert(entry);
      controller.addStatusListener(listenStatus);
    } else {
      _overlayState = null;
      _entry?.remove();
    }
  }

  void listenStatus(AnimationStatus status) {
    if (closed) return;

    switch (controller.status) {
      case AnimationStatus.completed:
        onCompleted();
        break;
      case AnimationStatus.dismissed:
        onDismissed();
        break;
      default:
    }
  }

  Widget build(BuildContext context);

  @protected
  void onCompleted() {}

  @protected
  void onDismissed() {}

  void show() {
    if (closed) return;
    onShow();
  }

  void onShow() {
    controller.forward();
  }

  bool get mounted => _overlayState?.mounted ?? false;

  bool _hided = false;
  bool get hided => _hided;

  void hide() {
    if (closed) return;
    _hided = true;
    if (shouldHide() && mounted) onHide();
  }

  void onHide() {
    controller.reverse();
  }

  bool shouldHide() => true;

  bool _closed = false;
  bool get closed => _closed;

  /// 如果被调用了，对象将不可用
  void close() {
    if (closed) return;
    _closed = true;
    _complete();
    if (entry.mounted) {
      entry.remove();
    }
    controller.dispose();
    onClose();
  }

  @protected
  void onClose() {}
}

class SnackbarDelagate with OverlayDelagete {
  SnackbarDelagate(this._controller, this.duration,
      {this.delayDuration = Duration.zero});
  @override
  Object get key => _controller;
  final SnackBarController _controller;

  final Duration duration;
  final Duration delayDuration;

  bool _cancel = false;

  @override
  FutureOr<void> initRun(OverlayState overlayState) async {
    if (_controller.mounted) return;

    _controller.init(overlayState: overlayState, duration: duration);
    if (delayDuration != Duration.zero) {
      await release(delayDuration);
    }
    // 如果没有调用一次`show`,`hide`不会触发状态监听
    _cancel ? _controller.close() : _controller.show();
    return _controller.future;
  }

  Future<void> get future => _controller.future;

  void show() {
    _cancel = false;
    if (done) {
      _controller.show();
    }
  }

  bool get done => EventQueue.getQueueState(_controller);
  void hide() {
    _cancel = true;
    if (done) {
      _controller.hide();
    }
  }
}

mixin OverlayDelagete {
  @protected
  Object get key;

  void init(OverlayGetter overlayGetter) {
    EventQueue.runOne(key, () => overlayGetter().then(initRun));
  }

  @protected
  FutureOr<void> initRun(OverlayState overlayState) {}
}
