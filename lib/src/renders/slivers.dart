import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../common.dart';

/// TODO: 向外暴露[Animation]
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
