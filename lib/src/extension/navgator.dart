import 'dart:async';

import 'package:utils/utils.dart';

import '../navigation/export.dart';
import 'package:flutter/material.dart';

extension SnackBarExt on NavGlobal {
  OverlayState? get overlay => observer.navigator?.overlay;

  OverlayState? getOverlay() => overlay;

  bool get snackBarState => EventQueue.getQueueState(_snackBar);
  FutureOr<void> snackBar(Widget content) {
    return EventQueue.runTask(_snackBar, () => _snackBar(content, overlay));
  }
}

FutureOr<void> _snackBar(Widget content, OverlayState? overlay) {
  if (overlay != null && overlay.mounted) {
    late SnackBarController controller;
    final key = GlobalKey();
    final entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onVerticalDragUpdate: (d) {
              if (controller.closed) return;
              if (overlay.mounted) {
                try {
                  controller.userMode = true;
                  final size = key.currentContext?.size;
                  final offset = d.primaryDelta;
                  if (size != null && offset != null) {
                    final value = controller.value - offset / size.height;
                    controller.value = value.clamp(0.0, 1.0);
                    controller._userHide = value < 1.0 && offset > 0;
                  }
                } catch (e) {
                  Log.e('controller error: $e');
                }
              }
            },
            onVerticalDragEnd: (d) {
              controller.userMode = false;
              if (controller._shouldHide) controller.hide();
            },
            onVerticalDragCancel: () {
              controller.userMode = false;
            },
            child: AnimatedBuilder(
              animation: controller.controller,
              builder: (context, child) {
                return Align(
                  heightFactor: controller.tweenValue,
                  alignment: Alignment.topCenter,
                  child: child,
                );
              },
              child: RepaintBoundary(
                key: key,
                child: Material(
                  child: SizedBox(width: double.infinity, child: content),
                ),
              ),
            ),
          ),
        );
      },
    );
    controller = SnackBarController(
        overlay: overlay,
        animation: const Duration(milliseconds: 300),
        stay: const Duration(milliseconds: 2000),
        entry: entry);
    overlay.insert(entry);
    controller.show();
    return controller.future;
  }
}

class SnackBarController {
  SnackBarController({
    required this.overlay,
    required this.animation,
    required this.stay,
    required this.entry,
  }) {
    _controller = AnimationController(vsync: overlay, duration: animation);
    _controller!.addStatusListener(_listenStatus);
  }

  final OverlayState overlay;
  final Duration animation;
  final Duration stay;
  final OverlayEntry entry;
  AnimationController? _controller;

  Future<void> get future => _completer.future;

  final _completer = Completer<void>();
  void _complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  bool userMode = false;

  final tween = Tween<double>(begin: 0.0, end: 1.0);
  late final curve = tween.chain(CurveTween(curve: Curves.ease));
  double get tweenValue => controller.drive(userMode ? tween : curve).value;
  AnimationController get controller => _controller!;

  double get value => controller.value;
  set value(double v) {
    controller.value = v;
  }

  void _listenStatus(AnimationStatus status) {
    if (closed) return;
    assert(_controller != null);
    switch (_controller!.status) {
      case AnimationStatus.completed:
        if (_hide) hide();
        EventQueue.runOne(this, () async {
          await release(stay);
          hide();
        });
        break;
      case AnimationStatus.dismissed:
        Log.w('dismissed');
        close();
        break;
      default:
    }
  }

  void show() {
    controller.forward();
  }

  bool get state => overlay.mounted;
  bool get _shouldHide => _userHide || _hide;

  bool _userHide = false;
  bool _hide = false;
  void hide() {
    if (closed) return;
    _hide = true;
    if (state) controller.reverse();
  }

  bool _closed = false;
  bool get closed => _closed;
  void close() {
    if (_closed) return;
    _closed = true;
    _complete();
    if (entry.mounted) {
      entry.remove();
    }
    controller.dispose();
    _controller = null;
  }
}
