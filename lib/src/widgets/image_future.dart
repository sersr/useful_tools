import 'dart:async';

import 'package:flutter/material.dart';

import '../../image_ref_cache.dart';
import '../binding/cache_binding.dart';

typedef ImageBuilder = Widget Function(Widget image, bool hasImage);

class ImageFuture extends StatefulWidget {
  const ImageFuture(
      {Key? key,
      this.builder,
      this.errorBuilder,
      required this.url,
      required this.getPath,
      required this.height,
      required this.width,
      this.boxFit = BoxFit.fitWidth})
      : super(key: key);

  final String url;
  final BoxFit boxFit;
  final ImageBuilder? builder;
  final double height;
  final double width;
  final Widget Function(BuildContext context)? errorBuilder;
  final FutureOr<String?> Function(String url) getPath;
  @override
  ImageState createState() => ImageState();
}

class ImageState extends State<ImageFuture> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub();
  }

  @override
  void didUpdateWidget(covariant ImageFuture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url ||
        widget.height != oldWidget.height ||
        widget.width != oldWidget.width ||
        widget.getPath != oldWidget.getPath ||
        _error) {
      _sub();
    }
  }

  ImageRefInfo? pictureInfo;
  ImageRefStream? listener;

  void _sub() {
    final url = widget.url;
    final width = widget.width;
    final height = widget.height;
    final getPath = widget.getPath;

    final _listener = imageCacheLoop!.preCacheUrl(url,
        getPath: getPath,
        cacheWidth: width,
        cacheHeight: height,
        fit: widget.boxFit);

    if (listener != _listener) {
      final l = PictureListener(onListener, load: onDefLoad);
      listener?.removeListener(l);
      _listener.addListener(l);
      listener = _listener;
    }
  }

  var _error = false;
  void onListener(ImageRefInfo? img, bool error, bool sync) {
    assert(mounted);

    setState(() {
      pictureInfo?.dispose();
      pictureInfo = img;
      _error = error;
    });
  }

  bool onDefLoad() =>
      mounted && Scrollable.recommendDeferredLoadingForContext(context);

  @override
  void dispose() {
    listener?.removeListener(PictureListener(onListener, load: onDefLoad));
    listener = null;

    pictureInfo?.dispose();
    pictureInfo = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = ImageRefWidget(info: pictureInfo);

    if (_error) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context);
      }
    } else {
      if (widget.builder != null) {
        return widget.builder!(image, pictureInfo != null);
      }
    }

    return image;
  }
}
