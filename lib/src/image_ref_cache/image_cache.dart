import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../common.dart';
import '../../event_queue.dart';
import 'image_ref_info.dart';

class ImageCacheLoop {
  Future<ui.Image> _decode(Uint8List bytes,
      {int? cacheWidth, int? cacheHeight}) async {
    await releaseUI;
    final codec = await imageCodec(bytes,
        cacheHeight: cacheHeight, cacheWidth: cacheWidth);
    final frameInfo = await codec.getNextFrame();
    await releaseUI;

    return frameInfo.image;
  }

  Future<ui.Codec> imageCodec(
    Uint8List list, {
    int? cacheWidth,
    int? cacheHeight,
    bool allowUpscaling = false,
  }) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(list);
    await releaseUI;

    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    await releaseUI;

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

  void picturePrint() {
    var count = 0;
    final values = _pictures.values;
    for (final p in values) {
      if (!p.done) count += 1;
    }
    Log.i('steram !done: $count', onlyDebug: false);
  }

  final _pictures = <ListKey, ImageRefStream>{};
  final _imgLooper = EventQueue.iOQueue;
  final _pathLooper = EventQueue(channels: 6);
  static const _defaultSizeBytes = 80 << 20;

  var _maxSizeBytes = _defaultSizeBytes;
  set maxSizeBytes(int max) {
    assert(max > 0);
    _maxSizeBytes = max;
    _z();
  }

  var _sizeBytes = 0;

  void _z() {
    while (_sizeBytes > _maxSizeBytes || _pictureDisposes.length > 650) {
      if (_pictureDisposes.isEmpty) return;
      final keyFirst = _pictureDisposes.keys.first;
      final cache = _pictureDisposes[keyFirst]!;
      final _cacheSizeBytes = cache.sizeBytes;
      assert(_cacheSizeBytes != null);
      if (_cacheSizeBytes != null) {
        _sizeBytes -= _cacheSizeBytes;
        assert(_sizeBytes >= 0);
      }
      Log.w(_sizeBytes);
      cache.dispose();
      _pictureDisposes.remove(keyFirst);
    }
  }

  final _pictureDisposes = <ListKey, ImageRefStream>{};

  ImageRefStream? getImage(ListKey key) {
    var listener = _pictures[key];

    if (listener == null) {
      listener = _pictureDisposes.remove(key);

      if (listener != null) {
        _pictures[key] = listener;
      }
    }

    assert(!_pictureDisposes.containsKey(key));
    assert(listener == null || listener.success || !listener.done);
    return listener;
  }

  void clearDispose(Map<ListKey, ImageRefStream> map) {
    Log.i('image dispose: ${map.length}', onlyDebug: false);
    final _map = List.of(map.values);
    map.clear();

    Timer.run(() {
      for (final stream in _map) {
        // await releaseUI;
        stream.dispose();
      }
    });
  }

  ImageRefStream preCacheBuilder(
    List keys, {
    required Future<void> Function(LoadStatus Function(),
            Future<void> Function(ui.Image? image, bool error) setImage)
        callback,
  }) {
    final key = ListKey(keys);
    final _img = getImage(key);

    if (_img != null) {
      // Log.i('contains');
      return _img;
    }

    final stream = _pictures[key] = ImageRefStream(onRemove: (stream) {
      assert(!_pictureDisposes.containsKey(key));

      final _stream = _pictures[key];
      if (_stream == stream) _pictures.remove(key);

      if (stream.success) {
        if (_stream != null) {
          _z();

          _pictureDisposes[key] = stream;
        }
      } else {
        stream.dispose();
      }
    });

    LoadStatus _defLoad() {
      if (!stream.hasListener) {
        Log.e('stream：no listeners');

        /// 如果资源没被释放，那么 [_pictures] 中必定包含[stream]对象
        /// 因为移动操作只有当前任务完成之后才有效
        assert(() {
          if (!stream.close) {
            final _stream = _pictures[key];
            return stream == _stream;
          }
          return true;
        }());

        return LoadStatus.inactive;
      }

      if (stream.defLoad) {
        return LoadStatus.defLoad;
      }

      return LoadStatus.active;
    }

    var _done = false;
    callback(_defLoad, (ui.Image? image, bool error) async {
      if (_done) Log.i('done : setImage', onlyDebug: false);
      _done = true;

      ImageRefInfo? imageRefInfo;

      if (image != null) {
        imageRefInfo = ImageRefInfo.imageRef(image);
      }

      await releaseUI;
      stream.setImage(imageRefInfo?.clone(), error);
      final streamSizeBytes = stream.sizeBytes;
      if (streamSizeBytes != null) {
        _sizeBytes += streamSizeBytes;
      }
      await EventQueue.scheduler.endOfFrame;
      imageRefInfo?.dispose();
    }).then((_) {
      assert(_done);
    });

    return stream;
  }

  @Deprecated('use preCacheUrl instead.')
  ImageRefStream preCache(File f,
      {required double cacheWidth,
      required double cacheHeight,
      BoxFit fit = BoxFit.fitHeight}) {
    return preCacheBuilder([f.path, cacheWidth, cacheHeight, fit],
        callback: (defLoad, setImage) async {
      final w = ui.window;

      Future<void> _getData() async {
        ui.Image? image;
        var error = false;

        try {
          await releaseUI;

          final bytes = await f.readAsBytes();
          await releaseUI;

          if (fit == BoxFit.fitHeight) {
            image = await _decode(bytes,
                cacheHeight: (cacheHeight * w.devicePixelRatio).toInt());
          } else {
            image = await _decode(bytes,
                cacheWidth: (cacheWidth * w.devicePixelRatio).toInt());
          }
          await releaseUI;
        } catch (e) {
          Log.e('e: $e');
          error = true;
        } finally {
          await setImage(image?.clone(), error);
          image?.dispose();
        }
      }

      await _imgLooper.addEventTask(
          () => _def(defLoad, _getData, () => setImage(null, true)));
    });
  }

  /// 如果返回状态无效[inactive]，会自动进行清理，
  /// 如果返回[active]，那么就必须手动处理
  Future<T?> _def<T>(LoadStatus Function() defLoad,
      FutureOr<T> Function() callback, VoidCallback dispose) async {
    await releaseUI;
    final _load = defLoad();
    switch (_load) {
      case LoadStatus.defLoad:

        /// 添加到队列末尾
        EventQueue.currentTask?.loop = true;
        break;
      case LoadStatus.active:
        return callback();
      default:
        dispose();
    }
  }

  /// 把网络任务添加进延迟加载验证
  ImageRefStream preCacheUrl(String url,
      {required double cacheWidth,
      required double cacheHeight,
      required PathFuture getPath,
      BoxFit fit = BoxFit.fitHeight}) {
    return preCacheBuilder([url, cacheWidth, cacheHeight, fit],
        callback: (deferred, setImage) async {
      var _done = false;
      final w = ui.window;
      void _sDone() {
        _done = true;
        setImage(null, true);
      }

      final path =
          await _pathLooper.addEventTask(() => _def(deferred, () async {
                final _path = await getPath(url);
                // 手动处理失败的情况
                if (_path == null) {
                  Log.w('_path == null', onlyDebug: false);
                  _sDone();
                }
                return _path;
              }, _sDone));

      // 所有任务都已处理
      if (path == null) {
        assert(_done);
        return;
      }

      final f = File(path);

      Future<void> _imageTask() async {
        ui.Image? image;
        var error = false;

        try {
          await releaseUI;
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
          await EventQueue.scheduler.endOfFrame;
          _done = true;
          await setImage(image?.clone(), error);
          image?.dispose();
        }
      }

      // 手动处理失败的情况
      if (await f.exists()) {
        await _imgLooper.addEventTask(() => _def(deferred, _imageTask, _sDone));
      } else {
        Log.w('file no exists.', onlyDebug: false);
        _sDone();
      }
      assert(_done);
    });
  }

  void clear() {
    clearDispose(_pictureDisposes);
    clearDispose(_pictures);
    _sizeBytes = 0;
  }
}

typedef PathFuture = FutureOr<String?> Function(String url);
enum LoadStatus {
  defLoad,
  inactive,
  active,
}
