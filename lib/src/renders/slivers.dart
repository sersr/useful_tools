import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../common.dart';

typedef WidgetBuilder = Widget Function(
    AnimationController animationController);

class ListViewLoadingFooter extends StatefulWidget {
  const ListViewLoadingFooter(
      {Key? key, required this.extent, required this.builder})
      : super(key: key);
  final double extent;
  final WidgetBuilder builder;
  @override
  _ListViewLoadingFooterState createState() => _ListViewLoadingFooterState();
}

class _ListViewLoadingFooterState extends State<ListViewLoadingFooter>
    with TickerProviderStateMixin {
  ScrollPosition? _position;
  late AnimationController animationController;
  @override
  void initState() {
    super.initState();
    animationController = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant ListViewLoadingFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _child = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_position != null) {
      _position!.removeListener(_onUpdatePosition);
    }
    _position = Scrollable.of(context)?.position;
    if (_position != null) {
      _position!.addListener(_onUpdatePosition);
    }
  }

  void _onUpdatePosition() {
    assert(_position != null);
    final pixels = _position!.pixels;
    final extent = widget.extent;
    // if (pixels > extent) {
    //   return;
    // }
    final v = ((extent - pixels) / extent).clamp(0.0, 1.0);
    Log.i('pixels: $pixels | $v', onlyDebug: false);
    animationController.value = v;
  }

  Widget? _child;
  @override
  Widget build(BuildContext context) {
    return _child ??= widget.builder(animationController);
  }
}

class Footer extends SingleChildRenderObjectWidget {
  const Footer({Key? key, required Widget child})
      : super(key: key, child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderSliverToBoxAdapter();
  }
}

class RenderSliverToBoxAdapter extends RenderSliverSingleBoxAdapter {
  /// Creates a [RenderSliver] that wraps a [RenderBox].
  RenderSliverToBoxAdapter({RenderBox? child}) : super(child: child);

  @override
  void performLayout() {
    if (child == null) {
      geometry = SliverGeometry.zero;
      return;
    }
    final SliverConstraints constraints = this.constraints;
    child!.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    final double childExtent;
    switch (constraints.axis) {
      case Axis.horizontal:
        childExtent = child!.size.width;
        break;
      case Axis.vertical:
        childExtent = child!.size.height;
        break;
    }
    var _extent = childExtent;
    // if (no.value == 0.0) {
    //   _extent = 0.0;
    // }
    final double paintedChildSize =
        calculatePaintOffset(constraints, from: 0.0, to: _extent);
    final double cacheExtent =
        calculateCacheOffset(constraints, from: 0.0, to: _extent);

    assert(paintedChildSize.isFinite);
    assert(paintedChildSize >= 0.0);

    // if (paintedChildSize == 0 &&
    //     constraints.scrollOffset > 0 &&
    //     geometry != null) {
    //   geometry = const SliverGeometry(scrollOffsetCorrection: -100);
    //   return;
    // }
    geometry = SliverGeometry(
      scrollExtent: childExtent,
      paintExtent: paintedChildSize,
      cacheExtent: cacheExtent,
      maxPaintExtent: childExtent,
      hitTestExtent: paintedChildSize,
      hasVisualOverflow: childExtent > constraints.remainingPaintExtent ||
          constraints.scrollOffset > 0.0,
    );

    setChildParentData(child!, constraints, geometry!);
  }
}
