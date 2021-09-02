import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:math' as math;
import '../../common.dart';

class SliverDelegate extends SliverPersistentHeaderDelegate {
  SliverDelegate(
      {this.minExtent = 0,
      required this.maxExtent,
      this.color = Colors.blue,
      this.overflow = false});

  @override
  final double minExtent;
  @override
  final double maxExtent;
  final Color color;
  final bool overflow;
  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    Log.i('shrinkOffset:$shrinkOffset #$color');
    final height = maxExtent - shrinkOffset;
    if (overflow) {
      return Container(
          height: height, child: const Text('hello'), color: color);
    }
    return Container(
        height: height.clamp(minExtent, maxExtent),
        child: const Text('hello'),
        color: color);
  }

  @override
  bool shouldRebuild(covariant SliverDelegate oldDelegate) {
    return oldDelegate.minExtent != minExtent ||
        oldDelegate.maxExtent != maxExtent;
  }
}

class LoadingWidget extends RenderObjectWidget {
  const LoadingWidget({Key? key, required this.deleagete}) : super(key: key);
  final SliverBuilderDeleagete deleagete;

  @override
  RenderObjectElement createElement() {
    return LoadingElement(this);
  }

  @override
  RenderObject createRenderObject(BuildContext context) {
    return LoadingSliver();
  }
}

class LoadingElement extends RenderObjectElement {
  LoadingElement(LoadingWidget widget) : super(widget);
  @override
  LoadingWidget get widget => super.widget as LoadingWidget;
  @override
  LoadingSliver get renderObject => super.renderObject as LoadingSliver;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    renderObject._element = this;
  }

  @override
  void unmount() {
    renderObject._element = null;
    super.unmount();
  }

  Element? _child;
  void layoutChild(double offset, BoxConstraints constraints) {
    owner!.buildScope(this, () {
      _child = updateChild(
          _child, widget.deleagete.build(offset, constraints), null);
    });
  }

  @override
  void insertRenderObjectChild(
      covariant RenderBox child, covariant Object? slot) {
    renderObject.updateChild(child);
  }

  @override
  void removeRenderObjectChild(
      covariant RenderBox child, covariant Object? slot) {
    renderObject.removeChild(child);
  }
}

typedef WidgetBuilder = Widget Function(
    double offset, BoxConstraints constraints);

class LoadingSliver extends RenderSliver with RenderSliverHelpers {
  LoadingElement? _element;
  RenderBox? _child;
  void updateChild(RenderBox child) {
    if (_child != null) {
      dropChild(_child!);
    }
    _child = child;
    adoptChild(child);
  }

  void removeChild(RenderBox child) {
    // assert(_child == child);
    adoptChild(child);
    _child = null;
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_child != null) visitor(_child!);
  }

  @override
  void performLayout() {
    final c = constraints;
    final maxExtent = c.remainingPaintExtent;
    late double height;
    late double width;
    if (c.axis == Axis.vertical) {
      height = maxExtent;
      width = c.crossAxisExtent;
    } else {
      height = c.crossAxisExtent;
      width = maxExtent;
    }

    final box = BoxConstraints(maxHeight: height, maxWidth: width);
    invokeLayoutCallback<SliverConstraints>((SliverConstraints constraints) {
      _element!.layoutChild(c.scrollOffset, box);
    });

    if (_child != null) {
      _child!.layout(box, parentUsesSize: true);
      final size = _child!.size;
      late double extent;
      if (c.axis == Axis.vertical) {
        extent = size.height;
      } else {
        extent = size.width;
      }
      extent = math.min(extent, maxExtent);
      final double sc = (extent - c.scrollOffset).clamp(0, extent);
      geometry = SliverGeometry(
        scrollExtent: extent,
        paintExtent: sc,
        maxPaintExtent: extent,
        layoutExtent: sc,
      );
      return;
    }
    geometry = SliverGeometry.zero;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_child != null && geometry?.visible == true) {
      context.paintChild(
          _child!,
          offset +
              Offset(0.0, -geometry!.maxPaintExtent + geometry!.paintExtent));
    }
  }

  @override
  bool hitTestChildren(SliverHitTestResult result,
      {required double mainAxisPosition, required double crossAxisPosition}) {
    return _child != null &&
        hitTestBoxChild(BoxHitTestResult.wrap(result), _child!,
            mainAxisPosition: mainAxisPosition,
            crossAxisPosition: crossAxisPosition);
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    applyPaintTransformForBoxChild(child as RenderBox, transform);
  }

  @override
  double childMainAxisPosition(covariant RenderObject child) {
    return 0.0;
  }
}

class SliverBuilderDeleagete {
  SliverBuilderDeleagete(
      {required this.builder, this.wapRepaintBundary = true});
  final bool wapRepaintBundary;
  final WidgetBuilder builder;

  Widget? build(double offset, BoxConstraints constraints) {
    Widget child = builder(offset, constraints);
    if (wapRepaintBundary) child = RepaintBoundary(child: child);
    return child;
  }
}
