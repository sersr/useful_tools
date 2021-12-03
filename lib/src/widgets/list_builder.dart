import 'dart:async';

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
          const EdgeInsets.symmetric(vertical: 3.0, horizontal: 2.0),
      child: btn1(
          padding: padding ??
              const EdgeInsets.symmetric(vertical: 3.0, horizontal: 10.0),
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

    return ColoredBox(
      color: widget.color ?? const Color.fromRGBO(236, 236, 236, 1),
      child: NotificationListener(
          onNotification: _onNotification,
          child: CustomScrollView(
            physics:
                const MyScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            primary: widget.primary,
            cacheExtent: widget.cacheExtent,
            controller: widget.scrollController,
            slivers: [
              if (refresh.refreshDelegate != null)
                SliverToBoxAdapter(
                  child:
                      RepaintBoundary(child: RefreshWidget(refresh: refresh)),
                ),
              SliverPadding(padding: _padding, sliver: sliveList)
            ],
          )),
    );
  }

  bool _onNotification(Notification n) {
    if (refresh.refreshDelegate == null) return false;
    final maxExtent = refresh.maxExtent;
    if (n is OverscrollIndicatorNotification) {
      if (n.leading || refresh.disallowTrailingIndicator) {
        n.disallowIndicator();
      } else if (!n.leading) {
        refresh.showTrailingIndicator = true;
      }
    } else if (n is ScrollStartNotification) {
      refresh.reset(n.metrics.extentBefore);
    } else if (n is ScrollUpdateNotification) {
      if (refresh.mode != RefreshMode.animatedDone &&
          refresh.mode != RefreshMode.animatedIgnore) {
        final scrollDelta = n.scrollDelta;

        final mes = n.metrics;

        if (scrollDelta != null && mes.extentAfter > 0.0) {
          if (refresh.value > 0.0 && scrollDelta > 0) {
            final value = (refresh.value - scrollDelta).clamp(0.0, maxExtent);
            final delta = refresh.value - value;
            Scrollable.of(n.context!)!.position.correctBy(-delta);
            refresh._setValue(value);
          }
        }
      }
    } else if (n is OverscrollNotification) {
      final mes = n.metrics;
      final afterZero = mes.extentAfter == 0.0;
      final overscroll = n.overscroll;
      if (overscroll < 0 || afterZero) {
        if (refresh.showTrailingIndicator) {
          return false;
        }
        if (refresh.canRefresh) {
          final value = (refresh.value - overscroll).clamp(0.0, maxExtent);

          if (!refresh.disallowTrailingIndicator) {
            /// sliver 占不满空间不显示尾部Indicator
            refresh._disallowTrailingIndicator =
                afterZero && mes.pixels == 0.0 && value > 0.0;
          }

          refresh._setValue(value);
        }
      }
    } else if (n is ScrollEndNotification) {
      if ((refresh.value - maxExtent).abs() < 0.5) {
        refresh._setMode(RefreshMode.refreshing);
      } else {
        refresh._setMode(RefreshMode.ignore);
      }
    }
    return false;
  }
}

typedef FinishLayout = void Function(int firstIndex, int lastIndex);

class MyDelegate extends SliverChildBuilderDelegate {
  MyDelegate(NullableIndexedWidgetBuilder builder,
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
    return velocity.abs() > 300;
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

  /// 生命周期自动设置
  _Refresh? _refresh;
  BuildContext? _context;

  void show() {
    if (_context != null && _refresh != null) {
      _refresh!
        .._setValue(maxExtent)
        .._setMode(RefreshMode.refreshing);
      Scrollable.of(_context!)!.position.jumpTo(0.0);
      // Scrollable.of(_context!)!.position.correctPixels(0.0);
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
  bool _disallowTrailingIndicator = false;
  bool get disallowTrailingIndicator => _disallowTrailingIndicator;
  bool showTrailingIndicator = false;

  void reset(double extentBefore) {
    _disallowTrailingIndicator = _value != 0.0;
    showTrailingIndicator = false;
    canRefresh = extentBefore == 0.0;
  }

  void _setValue(double v, [bool animated = false]) {
    final _v = v.clamp(0.0, maxExtent);
    if (_v == _value) return;
    _value = _v;
    if (_value == 0.0) {
      _setMode(RefreshMode.idle);
    } else if (_value == maxExtent) {
      _setMode(RefreshMode.dragEnd);
    } else if (!animated) {
      _setMode(RefreshMode.dragStart);
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
          duration: Duration(milliseconds: (controller.fac * 500).toInt()),
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
          EventQueue.runTaskOnQueue(_RefreshWidgetState, () async {
            if (!mounted) return;
            bool _con() {
              return controller == refresh &&
                  refresh.refreshDelegate == controller.refreshDelegate &&
                  refresh.refreshDelegate?.onRefreshing == onRefreshing;
            }

            if (_con()) {
              await onRefreshing();
            }
            if (_con() && controller.mode == RefreshMode.refreshing) {
              controller._setMode(RefreshMode.done);
            } else if (mounted) {
              _update();
            }
          });
        } else {
          if (controller.mode == RefreshMode.refreshing) {
            controller._setMode(RefreshMode.done);
          }
        }
        _update();

        break;

      // 动画事件
      case RefreshMode.ignore:
        r.onDragIgnore?.call();
        if (animationController.isAnimating) {
          animationController.stop(canceled: true);
        }

        _startAnimated();
        controller._setMode(RefreshMode.animatedIgnore);
        // _update();
        break;
      case RefreshMode.done:
        r.onDone?.call();
        if (animationController.isAnimating) {
          animationController.stop(canceled: true);
        }

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
                EventQueue.getQueueRunner(_RefreshWidgetState) != null),
          );
        });
  }
}

///TODO: 未实现
class Loading {}
