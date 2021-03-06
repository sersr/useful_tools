import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nop/event_queue.dart';
import 'package:nop/utils.dart';

import 'image_ref_info.dart';

class ImageRefCache {
  Future<ui.Image> _decode(Uint8List bytes,
      {int? cacheWidth, int? cacheHeight}) async {
    final ui.Codec codec;
    if (kDartIsWeb) {
      codec = await ui.instantiateImageCodec(bytes,
          targetHeight: cacheHeight, targetWidth: cacheWidth);
    } else {
      codec = await imageCodec(bytes,
          cacheWidth: cacheWidth, cacheHeight: cacheHeight);
    }
    final frameInfo = await codec.getNextFrame();

    return frameInfo.image;
  }

  SchedulerBinding get scheduler => SchedulerBinding.instance!;

  Future<ui.Codec> imageCodec(
    Uint8List list, {
    int? cacheWidth,
    int? cacheHeight,
    bool allowUpscaling = false,
  }) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(list);

    final descriptor = await ui.ImageDescriptor.encoded(buffer);

    if (!allowUpscaling) {
      if (cacheWidth != null && cacheWidth > descriptor.width) {
        cacheWidth = descriptor.width;
      }
      if (cacheHeight != null && cacheHeight > descriptor.height) {
        cacheHeight = descriptor.height;
      }
    }
    buffer.dispose();
    return descriptor.instantiateCodec(
      targetWidth: cacheWidth,
      targetHeight: cacheHeight,
    );
  }

  int printDone() {
    var count = 0;
    final values = _liveImageRefs.values;
    for (final p in values) {
      if (!p.done) count += 1;
    }
    return count;
  }

  final _liveImageRefs = <ListKey, ImageRefStream>{};
  final _loadQueue = EventQueue();

  static const _defaultSizeBytes = 40 << 20;

  var _maxSizeBytes = _defaultSizeBytes;
  set maxSizeBytes(int max) {
    assert(max > 0);
    _maxSizeBytes = max;
    _autoClear();
  }

  var _length = 320;
  set length(int size) {
    assert(size > 0);
    _length = size;
    _autoClear();
  }

  var _sizeBytes = 0;

  void _autoClear() {
    while (_sizeBytes > _maxSizeBytes || _imageRefCaches.length > _length) {
      if (_imageRefCaches.isEmpty) return;
      final keyFirst = _imageRefCaches.keys.first;
      final cache = _imageRefCaches[keyFirst]!;
      final _cacheSizeBytes = cache.sizeBytes;
      if (_cacheSizeBytes != null) {
        _sizeBytes -= _cacheSizeBytes;
        assert(_sizeBytes >= 0);
      }
      cache.dispose();
      _imageRefCaches.remove(keyFirst);
    }
  }

  final _imageRefCaches = <ListKey, ImageRefStream>{};

  static int timeWaitS = 1000 * 30;

  bool timeout(int time) {
    return time + timeWaitS <= DateTime.now().millisecondsSinceEpoch;
  }

  ImageRefStream? getImage(ListKey key) {
    var listener = _liveImageRefs[key];

    if (listener == null) {
      listener = _imageRefCaches.remove(key);

      if (listener != null) {
        final streamSizeBytes = listener.sizeBytes;
        if (streamSizeBytes != null) {
          _sizeBytes -= streamSizeBytes;
        }
        _liveImageRefs[key] = listener;
      }
    }

    assert(!_imageRefCaches.containsKey(key));

    if (listener != null) {
      if (listener.error && timeout(listener.time)) {
        _liveImageRefs.remove(key);
        listener = null;
      }
    }

    return listener;
  }

  ImageRefStream preCacheBuilder(List keys, {required _PreBuilder callback}) {
    final key = ListKey(keys);
    final _img = getImage(key);

    if (_img != null) return _img;

    final stream = _liveImageRefs[key] = ImageRefStream(onRemove: (stream) {
      assert(!_imageRefCaches.containsKey(key));

      final _stream = _liveImageRefs[key];
      if (_stream == stream) {
        _liveImageRefs.remove(key);

        if (stream.save) {
          _imageRefCaches[key] = stream;
          final streamSizeBytes = stream.sizeBytes;
          if (streamSizeBytes != null) {
            _sizeBytes += streamSizeBytes;
          }
        } else {
          stream.dispose();
        }
      } else {
        stream.dispose();
      }
      _autoClear();
    });

    LoadStatus _defLoad() {
      if (!stream.hasListener) {
        /// ????????????????????????????????? [_pictures] ???????????????[stream]??????
        /// ?????????????????????????????????????????????????????????
        assert(stream.close || _liveImageRefs[key] == stream);

        return LoadStatus.inactive;
      }

      return stream.defLoad ? LoadStatus.defLoad : LoadStatus.active;
    }

    var _done = false;
    callback(_defLoad, (ui.Image? image, bool error) {
      if (_done) Log.e('done : setImage', onlyDebug: false);
      _done = true;

      ImageRefInfo? imageRefInfo;

      if (image != null) {
        imageRefInfo = ImageRefInfo.imageRef(image);
      }
      stream.setImage(imageRefInfo?.clone(), error);
      imageRefInfo?.dispose();
    });

    return stream;
  }

  Future<T?> _def<T>(LoadStatus Function() defLoad,
      FutureOr<T> Function() callback, VoidCallback dispose) async {
    assert(EventQueue.currentTask != null);

    await scheduler.endOfFrame;
    final _load = defLoad();
    switch (_load) {
      case LoadStatus.defLoad:

        /// ?????????????????????
        EventQueue.currentTask!.addLast();

        break;
      case LoadStatus.active:
        return callback();
      default:
        dispose();
    }
    return null;
  }

  /// ??????????????????????????????????????????
  ImageRefStream preCacheUrl(String url,
      {required double cacheWidth,
      required double cacheHeight,
      required PathFuture getPath,
      BoxFit fit = BoxFit.fitHeight}) {
    return preCacheBuilder([url, cacheWidth, cacheHeight, fit, 'preCacheUrl'],
        callback: (deferred, setImage) async {
      var _done = false;
      final w = ui.window;
      void _autoDone() {
        _done = true;
        setImage(null, false);
      }

      final path = await EventQueue.run(
          preCacheUrl,
          () => _def(deferred, () async {
                final _path = await getPath(url);
                // ???????????????????????????
                if (_path == null) {
                  Log.w('_path == null', onlyDebug: false);
                  setImage(null, true);
                }
                return _path;
              }, _autoDone),
          channels: 6);
      if (path == null) {
        assert(_done);
        return;
      }

      final f = File(path);
      if (!await f.exists()) {
        _autoDone();
        return;
      }

      Future<void> _imageTask() async {
        ui.Image? image;
        var error = false;

        try {
          await idleWait;
          final bytes = await f.readAsBytes();

          if (fit == BoxFit.fitHeight) {
            image = await _decode(bytes,
                cacheHeight: (cacheHeight * w.devicePixelRatio).toInt());
          } else {
            image = await _decode(bytes,
                cacheWidth: (cacheWidth * w.devicePixelRatio).toInt());
          }
        } catch (e) {
          Log.e(e);
          error = true;
        } finally {
          _done = true;
          final local = image?.clone();
          image?.dispose();
          _loadQueue.addEventTask(() async {
            setImage(local, error);
            await scheduler.endOfFrame;
          });
        }
      }

      EventQueue.run(this, () => _def(deferred, _imageTask, _autoDone),
          channels: 4);
    });
  }

  /// ???????????? [Uint8List] ??????
  ImageRefStream preCacheUrlMemory(key,
      {required double cacheWidth,
      required double cacheHeight,
      required Unit8ListFuture getPath,
      BoxFit fit = BoxFit.fitHeight}) {
    final keys = key is Iterable ? key : [key];
    return preCacheBuilder(
        [...keys, cacheWidth, cacheHeight, fit, 'preCacheUrlMemory'],
        callback: (deferred, setImage) async {
      var _done = false;
      final devicePixelRatio = ui.window.devicePixelRatio;
      void _autoDone() {
        _done = true;
        setImage(null, false);
      }

      final bytes = await EventQueue.run(
          preCacheUrlMemory,
          () => _def(deferred, () async {
                final bytes = await getPath();
                // ???????????????????????????
                if (bytes == null) {
                  await scheduler.endOfFrame;
                  _done = true;
                  setImage(null, true);
                }
                return bytes;
              }, _autoDone),
          channels: 6);

      if (bytes == null) {
        assert(_done);
        return;
      }

      Future<void> _imageTask() async {
        ui.Image? image;
        var error = false;

        try {
          if (fit == BoxFit.fitHeight) {
            image = await _decode(bytes,
                cacheHeight: (cacheHeight * devicePixelRatio).toInt());
          } else {
            image = await _decode(bytes,
                cacheWidth: (cacheWidth * devicePixelRatio).toInt());
          }
        } catch (e) {
          /// ??????????????????
          Log.e('$key\n$e', lines: 3, onlyDebug: false);
          error = true;
        } finally {
          _done = true;
          final local = image?.clone();
          image?.dispose();
          _loadQueue.addEventTask(() async {
            setImage(local, error);
            await scheduler.endOfFrame;
          });
        }
      }

      EventQueue.push(this, () => _def(deferred, _imageTask, _autoDone));
    });
  }

  void clear() {
    _clear(_imageRefCaches);
    _sizeBytes = 0;
  }

  void clearLiveImages() {
    _clear(_liveImageRefs);
  }

  void _clear(Map<ListKey, ImageRefStream> map) {
    final _map = List.of(map.values);
    map.clear();
    Timer.run(() async {
      for (final stream in _map) {
        stream.dispose();
        await idleWait;
      }
    });
  }
}

typedef SetImage = void Function(ui.Image? image, bool error);
typedef _PreBuilder = Future<void> Function(LoadStatus Function(), SetImage);
typedef PathFuture = FutureOr<String?> Function(String url);
typedef Unit8ListFuture = FutureOr<Uint8List?> Function();
enum LoadStatus {
  defLoad,
  inactive,
  active,
}
