import 'package:flutter/material.dart';

import '../../image_ref_cache.dart';

class ImageRefWidget extends LeafRenderObjectWidget {
  const ImageRefWidget({Key? key, this.info}) : super(key: key);
  final ImageRefInfo? info;
  @override
  ImageRefRenderBox createRenderObject(BuildContext context) {
    return ImageRefRenderBox(info: info?.clone());
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant ImageRefRenderBox renderObject) {
    renderObject.info = info?.clone();
  }
}

class ImageRefRenderBox extends RenderBox {
  ImageRefRenderBox({ImageRefInfo? info}) : _info = info;

  ImageRefInfo? _info;
  set info(ImageRefInfo? t) {
    if (_info != null && t != null && t.isCloneOf(_info!)) {
      t.dispose();
      return;
    }
    _info?.dispose();
    _info = t;
    markNeedsLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (_info != null) {
      return constraints
          .constrainSizeAndAttemptToPreserveAspectRatio(_info!.size);
    }
    return constraints.smallest;
  }

  @override
  void performLayout() {
    if (_info != null) {
      size =
          constraints.constrainSizeAndAttemptToPreserveAspectRatio(_info!.size);
    } else {
      size = constraints.smallest;
    }
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_info != null) {
      final canvas = context.canvas;

      final src = Offset.zero & _info!.size;
      final paint = Paint()..isAntiAlias = true;

      paint.color = const Color.fromRGBO(0, 0, 0, 1);
      paint.filterQuality = FilterQuality.low;
      // paint.invertColors = invertColors;
      final size =
          constraints.constrainSizeAndAttemptToPreserveAspectRatio(_info!.size);
      _info!.drawImageRef(canvas, src, offset & size, paint);
    }
  }

  @override
  void dispose() {
    super.dispose();
    _info?.dispose();
  }
}
