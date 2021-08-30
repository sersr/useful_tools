import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

import '../../image_ref_cache.dart';
import '../binding/cache_binding.dart';

typedef ImageBuilder = Widget Function(Widget image, bool hasImage);

class ImageFuture extends StatefulWidget {
  const ImageFuture.file(
      {Key? key,
      this.builder,
      this.errorBuilder,
      required this.imageKey,
      required PathFuture getFile,
      required this.height,
      required this.width,
      this.boxFit = BoxFit.fitWidth})
      : getPath = getFile,
        super(key: key);

  const ImageFuture.memory(
      {Key? key,
      this.builder,
      this.errorBuilder,
      required this.imageKey,
      required Unit8ListFuture getMemory,
      required this.height,
      required this.width,
      this.boxFit = BoxFit.fitWidth})
      : getPath = getMemory,
        super(key: key);

  const ImageFuture(
      {Key? key,
      this.builder,
      this.errorBuilder,
      required this.imageKey,
      required this.getPath,
      required this.height,
      required this.width,
      this.boxFit = BoxFit.fitWidth})
      : assert(getPath is PathFuture || getPath is Unit8ListFuture),
        super(key: key);

  final dynamic imageKey;
  final BoxFit boxFit;
  final ImageBuilder? builder;
  final double height;
  final double width;
  final Widget Function(BuildContext context)? errorBuilder;
  final Function getPath;
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
    if (!const DeepCollectionEquality()
            .equals(widget.imageKey, oldWidget.imageKey) ||
        widget.height != oldWidget.height ||
        widget.width != oldWidget.width ||
        _error) {
      _sub();
    }
  }

  ImageRefInfo? imageRefInfo;
  ImageRefStream? stream;

  void _sub() {
    final imageKey = widget.imageKey;
    final width = widget.width;
    final height = widget.height;
    final getPath = widget.getPath;
    late ImageRefStream _stream;

    if (getPath is PathFuture) {
      _stream = imageRefCache!.preCacheUrl(imageKey,
          getPath: getPath,
          cacheWidth: width,
          cacheHeight: height,
          fit: widget.boxFit);
    } else if (getPath is Unit8ListFuture) {
      _stream = imageRefCache!.preCacheUrlMemory(imageKey,
          getPath: getPath,
          cacheWidth: width,
          cacheHeight: height,
          fit: widget.boxFit);
    }

    if (stream != _stream) {
      final l = PictureListener(onListener, load: onDefLoad);
      stream?.removeListener(l);
      _stream.addListener(l);
      stream = _stream;
    }
  }

  var _error = false;

  void onListener(ImageRefInfo? img, bool error, bool sync) {
    assert(mounted);

    setState(() {
      imageRefInfo?.dispose();
      imageRefInfo = img;
      _error = error;
    });
  }

  bool onDefLoad() =>
      mounted && Scrollable.recommendDeferredLoadingForContext(context);

  @override
  void dispose() {
    stream?.removeListener(PictureListener(onListener, load: onDefLoad));
    stream = null;

    imageRefInfo?.dispose();
    imageRefInfo = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = RawImage(image: imageRefInfo?.image, fit: BoxFit.contain);
    if (_error) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context);
      }
    } else {
      if (widget.builder != null) {
        return widget.builder!(image, imageRefInfo != null);
      }
    }

    return image;
  }
}
