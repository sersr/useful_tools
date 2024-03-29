import 'dart:async';
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:nop/event_queue.dart';
import 'package:nop/utils.dart';

typedef LoadCallback = FutureOr<Uint8List?> Function();

class CallbackWithKeyImage extends ImageProvider<CallbackWithKeyImage> {
  const CallbackWithKeyImage(
      {required this.keys, required this.callback, this.scale = 1.0});

  final Object keys;
  final LoadCallback callback;
  final double scale;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }

    if (identical(other, this)) return true;
    return other is CallbackWithKeyImage &&
        other.scale == scale &&
        (other.keys == keys ||
            const DeepCollectionEquality().equals(other.keys, keys));
  }

  @override
  int get hashCode => Object.hash(
      keys is Iterable ? Object.hashAll(keys as Iterable) : keys, scale);

  static final _imageCallQueue = EventQueue(channels: 4);

  Future<ui.Codec> _loadAsync(
      CallbackWithKeyImage key, ImageDecoderCallback decode) async {
    assert(key == this);
    final bytes = await _imageCallQueue.awaitTask(callback);
    if (bytes == null) {
      assert(Log.w('图片加载失败'));
      PaintingBinding.instance.imageCache.evict(key);
      throw StateError('$keys is empty and cannot be loaded as an image.');
    }
    final im = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(im);
  }

  @override
  ImageStreamCompleter loadImage(
      CallbackWithKeyImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: 'CallbackWithKeyImage(${describeIdentity(keys)})',
    );
  }

  @override
  Future<CallbackWithKeyImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  String toString() =>
      '${objectRuntimeType(this, 'CallbackWithKeyImage')}(${describeIdentity(keys)}, '
      'scale: $scale)';
}

extension ResizeImageProvider<T extends ImageProvider<Object>> on T {
  ImageProvider<Object> resize({int? height, int? width}) {
    return ResizeImage.resizeIfNeeded(width, height, this);
  }
}
