import 'dart:async';

import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

import 'nav_overlay_mixin.dart';

typedef WidgetBuilder = Widget Function(BuildContext context);

mixin OverlayPannel on OverlayMixin {
  final _entries = <OverlayEntry>[];

  addEntry(OverlayEntry entry) {
    _entries.add(entry);
    if (inited) {
      overlay.insert(entry);
    }
  }

  remove(OverlayEntry entry) {
    _entries.remove(entry);
  }

  @override
  void onCreateOverlayEntry() {
    overlay.insertAll(_entries);
  }

  @override
  void onRemoveOverlayEntry() {
    for (var item in _entries) {
      item.remove();
    }
    _entries.clear();
  }

  Completer<void>? _completer;

  void _complete() {
    if (_completer?.isCompleted == false) {
      _completer?.complete();
      _completer = null;
    }
  }

  Future<void> get _future {
    _completer ??= Completer();
    return _completer!.future;
  }

  @override
  void onCompleted() {
    _complete();
    super.onCompleted();
  }

  @override
  void onDismissed() {
    _complete();
    super.onDismissed();
  }

  @override
  FutureOr<bool> showAsync() {
    return show().then((value) {
      return _future.then((_) => value);
    });
  }

  @override
  FutureOr<bool> hideAsync() {
    return hide().then((value) {
      return _future.then((_) => value);
    });
  }
}

class OverlayVerticalPannels with OverlayMixin, OverlayPannel {
  OverlayVerticalPannels({
    List<WidgetBuilder>? builders,
    this.onHideEnd,
    this.onShowEnd,
  }) {
    builders?.map((e) => OverlayEntry(builder: e)).forEach(addEntry);
  }

  @override
  final VoidCallback? onHideEnd;
  @override
  final VoidCallback? onShowEnd;
}

class OverlayPannelWidget extends StatefulWidget {
  const OverlayPannelWidget({
    Key? key,
    required this.controller,
    required this.builder,
    this.onHide,
    this.curve,
    this.reverseCurve,
  }) : super(key: key);
  final AnimationController controller;
  final VoidCallback? onHide;
  final Curve? curve;
  final Curve? reverseCurve;
  final Widget Function(BuildContext context, Animation<double> animation)
      builder;
  @override
  _OverlayPannelWidgetState createState() => _OverlayPannelWidgetState();
}

class _OverlayPannelWidgetState extends State<OverlayPannelWidget> {
  @override
  void initState() {
    super.initState();
    update();
  }

  @override
  void didUpdateWidget(covariant OverlayPannelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    update();
  }

  CurvedAnimation? curvedAnimation;
  void update() {
    curvedAnimation?.dispose();

    final curve = widget.curve ?? Curves.ease;
    curvedAnimation = CurvedAnimation(
      parent: widget.controller,
      curve: curve,
      reverseCurve: widget.reverseCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: widget.builder(context, curvedAnimation!));
  }
}
