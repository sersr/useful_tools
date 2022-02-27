import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

import 'botton.dart';

class ListItem extends StatelessWidget {
  const ListItem({
    Key? key,
    required this.child,
    this.onLongPress,
    this.onTap,
    this.background = true,
    this.height,
    this.bgColor,
    this.splashColor,
    this.padding,
    this.outPadding,
  }) : super(key: key);

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool background;
  final double? height;
  final Color? bgColor;
  final Color? splashColor;
  final EdgeInsets? padding;
  final EdgeInsets? outPadding;
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: height == null
          ? null
          : BoxConstraints(maxHeight: height!, minHeight: height!),
      padding: outPadding ??
          const EdgeInsets.symmetric(vertical: 3.0, horizontal: 10.0),
      child: btn1(
          elevation: 0.1,
          padding: padding,
          onTap: onTap,
          background: background,
          onLongPress: onLongPress,
          radius: 6.0,
          bgColor: bgColor ?? const Color.fromRGBO(250, 250, 250, 1),
          splashColor: splashColor ?? const Color.fromRGBO(225, 225, 225, 1),
          child: child),
    );
  }
}

class ListViewBuilder extends StatefulWidget {
  const ListViewBuilder({
    Key? key,
    this.itemCount,
    required this.itemBuilder,
    this.itemExtent,
    this.primary,
    this.cacheExtent,
    this.padding = EdgeInsets.zero,
    this.scrollController,
    this.finishLayout,
    this.refreshDelegate,
    this.color,
    this.physics,
    this.scrollBehavior,
  }) : super(key: key);

  final int? itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double? itemExtent;
  final bool? primary;
  final double? cacheExtent;
  final EdgeInsets padding;
  final ScrollController? scrollController;
  final FinishLayout? finishLayout;
  final Color? color;
  final RefreshDelegate? refreshDelegate;
  final ScrollPhysics? physics;
  final ScrollBehavior? scrollBehavior;
  @override
  State<ListViewBuilder> createState() => _ListViewBuilderState();
}

class _ListViewBuilderState extends State<ListViewBuilder> {
  late _Refresh refresh;
  @override
  void initState() {
    super.initState();
    refresh = _Refresh().._setDelegate(widget.refreshDelegate);
  }

  @override
  void didUpdateWidget(covariant ListViewBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    refresh._setDelegate(widget.refreshDelegate);
  }

  @override
  void dispose() {
    refresh._setDelegate(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = MediaQuery.of(context).padding;

    final _padding = p.bottom == 0.0
        ? widget.padding
        : widget.padding.copyWith(bottom: p.bottom);
    final delegate = MyDelegate(widget.itemBuilder,
        childCount: widget.itemCount, finishLayout: widget.finishLayout);

    final sliveList = widget.itemExtent == null
        ? SliverList(delegate: delegate)
        : SliverFixedExtentList(
            delegate: delegate, itemExtent: widget.itemExtent!);

    final config = ScrollConfiguration.of(context);
    return Container(
      color: widget.color,
      child: NotificationListener(
          onNotification: _onNotification,
          child: ScrollConfiguration(
            behavior: config.copyWith(
                physics: const MyScrollPhysics()
                    .applyTo(config.getScrollPhysics(context))),
            child: CustomScrollView(
              physics: widget.physics,
              primary: widget.primary,
              cacheExtent: widget.cacheExtent,
              controller: widget.scrollController,
              scrollBehavior: widget.scrollBehavior,
              slivers: [
                if (refresh.refreshDelegate != null)
                  SliverToBoxAdapter(
                    child:
                        RepaintBoundary(child: RefreshWidget(refresh: refresh)),
                  ),
                SliverPadding(padding: _padding, sliver: sliveList)
              ],
            ),
          )),
    );
  }

  bool _onNotification(Notification n) {
    refresh.onNotifition(n);
    return false;
  }
}

typedef FinishLayout = void Function(int firstIndex, int lastIndex);

class MyDelegate extends SliverChildBuilderDelegate {
  const MyDelegate(NullableIndexedWidgetBuilder builder,
      {this.finishLayout, int? childCount})
      : super(builder, childCount: childCount);

  final FinishLayout? finishLayout;
  @override
  void didFinishLayout(int firstIndex, int lastIndex) {
    finishLayout?.call(firstIndex, lastIndex);
  }
}

class MyScrollPhysics extends ScrollPhysics {
  const MyScrollPhysics({ScrollPhysics? parent}) : super(parent: parent);
  @override
  bool recommendDeferredLoading(
      double velocity, ScrollMetrics metrics, BuildContext context) {
    return velocity.abs() > 30;
  }

  @override
  MyScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return MyScrollPhysics(parent: buildParent(ancestor));
  }
}

enum RefreshMode {
  // --- 空闲状态
  idle,
  // --- 拖动过程
  dragStart,
  dragEnd,
  // --- 释放刷新
  refreshing,
  // --- 完成刷新
  done,
  // --- 拖动取消
  ignore,
  // --- 动画
  animatedIgnore,
  animatedDone,
}

typedef OnRefreshing = FutureOr<void> Function();

typedef RefreshBuilder = Widget Function(BuildContext context, double offset,
    double maxExtent, RefreshMode mode, bool refreshing);

class RefreshDelegate {
  RefreshDelegate({
    this.onDragStart,
    this.onDragEnd,
    this.onDragIgnore,
    this.onDone,
    this.onRefreshing,
    this.triggerMode = RefreshIndicatorTriggerMode.onEdge,
    required this.maxExtent,
    required this.builder,
  }) : assert(maxExtent > 0.0);
  final VoidCallback? onDragStart;

  /// 当拖动距离达到[maxExtent]调用
  final VoidCallback? onDragEnd;
  final VoidCallback? onDragIgnore;
  final VoidCallback? onDone;
  final OnRefreshing? onRefreshing;
  final RefreshBuilder builder;
  final double maxExtent;
  final RefreshIndicatorTriggerMode triggerMode;

  /// 生命周期自动设置
  _Refresh? _refresh;
  BuildContext? _context;

  void show() {
    if (_context != null && _refresh != null) {
      final position = Scrollable.of(_context!)!.position;
      position.setPixels(position.minScrollExtent);
      _refresh!
        .._setValue(maxExtent)
        .._setMode(RefreshMode.refreshing);
    }
  }

  void hide() {
    _refresh?._setValue(0.0);
  }
}

class _Refresh extends ChangeNotifier {
  _Refresh();
  RefreshDelegate? refreshDelegate;
  void _setDelegate(RefreshDelegate? delegate) {
    refreshDelegate?._refresh = null;
    refreshDelegate = delegate;
    refreshDelegate?._refresh = this;
  }

  double get maxExtent => refreshDelegate?.maxExtent ?? 0.0;

  double get fac => maxExtent == 0.0 ? 0.0 : value / maxExtent;
  double _value = 0.0;

  double get value => _value;
  bool canRefresh = false;

  void reset(double extentBefore) {
    canRefresh =
        refreshDelegate?.triggerMode == RefreshIndicatorTriggerMode.anywhere ||
            extentBefore == 0.0; // onEdge
  }

  void _setValue(double v, [bool animated = false]) {
    final _v = v.clamp(0.0, maxExtent);
    if (_v == _value) return;
    _value = _v;
    if (!animated) {
      if (_value == 0.0) {
        _setMode(RefreshMode.idle);
      } else if (_value == maxExtent) {
        _setMode(RefreshMode.dragEnd);
      } else {
        _setMode(RefreshMode.dragStart);
      }
    }
    notifyListeners();
  }

  final ValueNotifier<RefreshMode> _mode = ValueNotifier(RefreshMode.idle);
  RefreshMode get mode => _mode.value;

  addModeListener(VoidCallback listener) {
    _mode.addListener(listener);
  }

  removeModeListener(VoidCallback listener) {
    _mode.removeListener(listener);
  }

  void _setMode(RefreshMode m) {
    _mode.value = m;
  }

  bool get _active => refreshDelegate != null;

  void onNotifition(Notification notification) {
    if (!_active) return;
    if (notification is OverscrollIndicatorNotification) {
      if (notification.leading) {
        notification.disallowIndicator();
      }
    } else if (notification is ScrollStartNotification) {
      reset(notification.metrics.extentBefore);
    } else if (notification is ScrollUpdateNotification) {
      goScrollUpdate(notification);
    } else if (notification is OverscrollNotification) {
      goOverScroll(notification);
    } else if (notification is ScrollEndNotification) {
      goScrollEnd(notification);
    }
  }

  /// [goScrollUpdate]满足条件: value > 0
  /// 下拉会调用 [goOverScroll]
  /// 如果列表内容没有占满视口,就会出现`extentBefore == 0.0 && extentAfter == 0.0`
  void goScrollUpdate(ScrollUpdateNotification n) {
    if (!_active) return;
    if (mode != RefreshMode.animatedDone &&
        mode != RefreshMode.animatedIgnore) {
      final scrollDelta = n.scrollDelta;

      if (scrollDelta != null && n.dragDetails != null) {
        final mes = n.metrics;

        /// refresh 模式下: [ScrollUpdateNotification]只有在`value > 0.0`才有效
        if (value > 0.0 && (scrollDelta > 0 || mes.extentBefore == 0.0)) {
          final newValue = (value - scrollDelta).clamp(0.0, maxExtent);
          Scrollable.of(n.context!)!.position.correctBy(-scrollDelta);
          _setValue(newValue);
        }
      }
    }
  }

  void goOverScroll(OverscrollNotification n) {
    if (!_active) return;

    final mes = n.metrics;
    final beforeZero = mes.extentBefore == 0.0;
    final overscroll = n.overscroll;
    if (overscroll < 0 || (beforeZero && value > 0.0)) {
      if (canRefresh) {
        final newValue = (value - overscroll).clamp(0.0, maxExtent);

        _setValue(newValue);
      }
    }
  }

  void goScrollEnd(ScrollEndNotification n) {
    if (!_active) return;
    if ((value - maxExtent).abs() < 0.5) {
      _setMode(RefreshMode.refreshing);
    } else {
      _setMode(RefreshMode.ignore);
    }
  }
}

class RefreshWidget extends StatefulWidget {
  const RefreshWidget({Key? key, required this.refresh}) : super(key: key);

  final _Refresh refresh;
  @override
  _RefreshWidgetState createState() => _RefreshWidgetState();
}

class _RefreshWidgetState extends State<RefreshWidget>
    with TickerProviderStateMixin {
  late _Refresh refresh;
  late AnimationController animationController;
  @override
  void initState() {
    super.initState();
    refresh = widget.refresh;
    animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    animationController.addListener(_tick);
    refresh.addModeListener(_updateMode);
    refresh.refreshDelegate!._context = context;
  }

  void _tick() {
    final controller = refresh;
    final value = animationController.value * controller.maxExtent;

    controller._setValue(value, true);
  }

  Timer? waitAnimated;

  void _updateMode() {
    final controller = refresh;
    waitAnimated?.cancel();

    void _startAnimated() {
      animationController.value = controller.fac;
      animationController.animateTo(0,
          duration: Duration(milliseconds: (controller.fac * 600).toInt()),
          curve: Curves.ease);
    }

    final r = controller.refreshDelegate;
    final mode = controller.mode;

    if (r == null) return;

    switch (mode) {
      case RefreshMode.dragStart:
        r.onDragStart?.call();
        break;
      case RefreshMode.dragEnd:
        r.onDragEnd?.call();
        break;
      // 刷新事件
      case RefreshMode.refreshing:
        final onRefreshing = r.onRefreshing;
        // 在刷新期间是否阻止再次刷新事件？
        if (onRefreshing != null) {
          EventQueue.run(_RefreshWidgetState, () async {
            if (!mounted) return;
            bool refreshCondition() {
              return controller == refresh &&
                  refresh.refreshDelegate == controller.refreshDelegate &&
                  refresh.refreshDelegate?.onRefreshing == onRefreshing;
            }

            if (refreshCondition()) {
              await onRefreshing();
            }
            if (refreshCondition() &&
                controller.mode == RefreshMode.refreshing) {
              controller._setMode(RefreshMode.done);
            } else if (mounted) {
              _update();
            }
          });
        } else {
          controller._setMode(RefreshMode.done);
        }
        _update();

        break;

      // 动画事件
      case RefreshMode.ignore:
        r.onDragIgnore?.call();
        // if (animationController.isAnimating) {
        //   animationController.stop(canceled: true);
        // }

        _startAnimated();
        controller._setMode(RefreshMode.animatedIgnore);
        // _update();
        break;
      case RefreshMode.done:
        r.onDone?.call();
        // if (animationController.isAnimating) {
        //   animationController.stop(canceled: true);
        // }

        waitAnimated = Timer(const Duration(milliseconds: 800), () {
          if (refresh == controller && mounted) {
            _startAnimated();
            refresh._setMode(RefreshMode.animatedDone);
          }
        });
        _update();
        break;
      default:
    }
    switch (mode) {
      // 用户行为
      case RefreshMode.idle:
      case RefreshMode.dragStart:
      case RefreshMode.dragEnd:
      case RefreshMode.refreshing:
        waitAnimated?.cancel();
        if (animationController.isAnimating) {
          animationController.stop(canceled: true);
        }
        break;
      default:
    }
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant RefreshWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (refresh != widget.refresh) {
      refresh.removeListener(_updateMode);
      refresh = widget.refresh;
      refresh.addListener(_updateMode);
    }
    refresh.refreshDelegate!._context = context;
  }

  @override
  void dispose() {
    animationController.dispose();
    refresh.removeModeListener(_updateMode);
    refresh.refreshDelegate!._context = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = Scrollable.of(context)!.position;
    return AnimatedBuilder(
        animation: refresh,
        builder: (context, _) {
          assert(refresh.refreshDelegate != null);
          final builder = refresh.refreshDelegate!.builder;

          return SizedBox(
            height: position.axis == Axis.vertical ? refresh.value : 0.0,
            width: position.axis == Axis.vertical ? 0.0 : refresh.value,
            child: builder(
              context,
              refresh.maxExtent - refresh._value,
              refresh.maxExtent,
              refresh.mode,
              EventQueue.getQueueState(_RefreshWidgetState),
            ),
          );
        });
  }
}

///TODO: 未实现
class Loading {}
