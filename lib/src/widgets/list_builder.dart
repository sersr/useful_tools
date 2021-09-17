import 'package:flutter/material.dart';
import 'package:useful_tools/src/renders/slivers.dart';

import '../../common.dart';
import 'botton.dart';

class ListItem extends StatelessWidget {
  const ListItem({
    Key? key,
    required this.child,
    this.onLongPress,
    this.onTap,
    this.background = true,
    this.height,
    this.color = const Color.fromRGBO(242, 242, 242, 1),
    this.bgColor = const Color.fromRGBO(250, 250, 250, 1),
    this.splashColor = const Color.fromRGBO(225, 225, 225, 1),
  }) : super(key: key);

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool background;
  final double? height;
  final Color color;
  final Color bgColor;
  final Color splashColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: height == null
          ? null
          : BoxConstraints(maxHeight: height!, minHeight: height!),
      padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 10.0),
      child: btn1(
          onTap: onTap,
          background: background,
          onLongPress: onLongPress,
          radius: 6.0,
          bgColor: bgColor,
          splashColor: splashColor,
          child: child),
    );
  }
}

class ListViewBuilder extends StatefulWidget {
  const ListViewBuilder({
    Key? key,
    required this.itemCount,
    required this.itemBuilder,
    this.itemExtent,
    this.primary,
    this.cacheExtent,
    this.padding = EdgeInsets.zero,
    this.scrollController,
    this.finishLayout,
    this.load,
  }) : super(key: key);

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double? itemExtent;
  final bool? primary;
  final double? cacheExtent;
  final EdgeInsets padding;
  final ScrollController? scrollController;
  final FinishLayout? finishLayout;
  final Widget? load;

  @override
  State<ListViewBuilder> createState() => _ListViewBuilderState();
}

///TODO: 未完成
class _ListViewBuilderState extends State<ListViewBuilder> {
  final ValueNotifier<double> no = ValueNotifier(0.0);
  final ValueNotifier<bool> canShow = ValueNotifier(false);
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
      color: const Color.fromRGBO(236, 236, 236, 1),
      child: NotificationListener(
          onNotification: (Notification n) {
            Log.w(n.runtimeType);
            if (n is OverscrollIndicatorNotification && n.leading) {
              n.disallowIndicator();
            }
            if (n is ScrollStartNotification) {
              canShow.value = n.metrics.extentBefore == 0.0;
            }
            if (n is ScrollUpdateNotification) {
              if (no.value == 0.0) canShow.value = false;
            }
            if (n is OverscrollNotification) {
              if (canShow.value) {
                if (n.dragDetails != null) {
                  no.value = (no.value - n.overscroll).clamp(0.0, 100.0);
                }
              }
            }
            if (n is ScrollEndNotification) {
              if (n.metrics.pixels - no.value >= 0) {
                Scrollable.of(n.context!)!.position.correctBy(-no.value);
                no.value = 0.0;
              }
            }
            return false;
          },
          child: CustomScrollView(
            physics:
                const MyScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            primary: widget.primary,
            cacheExtent: widget.cacheExtent,
            controller: widget.scrollController,
            slivers: [
              Footer(
                no: no,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                      animation: no,
                      builder: (context, _) {
                        if (no.value <= 0) {
                          return const SizedBox();
                        }
                        return Container(
                          height: no.value,
                          width: 400,
                          color: Colors.blue,
                          child: Center(child: Text('hello ${no.value}')),
                        );
                      }),
                ),
              ),
              // SliverPadding(
              //   padding: _padding.copyWith(left: 0, right: 0, bottom: 0),
              //   sliver: SliverPersistentHeader(
              //       pinned: true,
              //       floating: true,
              //       delegate: SliverDelegate(maxExtent: 100, minExtent: 50)),
              // ),
              // SliverPadding(
              //   padding: _padding.copyWith(left: 0, right: 0, bottom: 0),
              //   sliver: SliverPersistentHeader(
              //       pinned: true,
              //       floating: true,
              //       delegate: SliverDelegate(
              //           maxExtent: 100, minExtent: 50, color: Colors.red)),
              // ),
              // sliveList,
              SliverPadding(
                padding: _padding,
                sliver: sliveList,
              )
            ],
          )),
    );
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
