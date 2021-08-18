import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../../common.dart';

class ImageRefInfo {
  ImageRefInfo.imageRef(ui.Image rawImage) : this._(_ImageRef._(rawImage));

  ImageRefInfo._(this._imageRef) {
    _imageRef._handles.add(this);
  }
  final _ImageRef _imageRef;
  ui.Image get image => _imageRef.rawImage;
  void drawImageRef(
      ui.Canvas canvas, ui.Rect src, ui.Rect dst, ui.Paint paint) {
    assert(!disposed);

    canvas.drawImageRect(_imageRef.rawImage, src, dst, paint);
  }

  ui.Size get size {
    assert(!disposed);
    final image = _imageRef.rawImage;

    return ui.Size(image.width.toDouble(), image.height.toDouble());
  }

  ImageRefInfo clone() {
    assert(!disposed);
    return ImageRefInfo._(_imageRef);
  }

  bool isCloneOf(ImageRefInfo info) {
    return _imageRef == info._imageRef;
  }

  bool get disposed => _imageRef._dispose;

  /// 可以通过[hashCode]标识查看[_imageRef]是否 得到释放
  void dispose() {
    _imageRef._handles.remove(this);
    // assert(Log.w(
    //     'image handle: ${_imageRef._handles.length} #${_imageRef.hashCode}'));
    if (_imageRef._handles.isEmpty) {
      _imageRef.dispose();
    }
  }
}

class _ImageRef {
  _ImageRef._(this.rawImage);
  final ui.Image rawImage;

  final Set<ImageRefInfo> _handles = <ImageRefInfo>{};

  // void add(ImageRefInfo info) {
  //   assert(!_dispose);
  //   _handles.add(info);
  // }

  bool _dispose = false;
  void dispose() {
    assert(!_dispose);
    _dispose = true;
    rawImage.dispose();
  }
}

typedef ImageRefListenerCallback = void Function(
    ImageRefInfo? image, bool error, bool sync);

class ImageRefStream {
  ImageRefStream({this.onRemove});
  ImageRefInfo? _image;
  bool _streamError = false;
  int? get sizeBytes {
    final image = _image?._imageRef.rawImage;
    if (image != null) {
      return image.width * image.height * 4;
    }
  }

  final void Function(ImageRefStream stream)? onRemove;

  /// 理论上监听者数量不会太多
  bool get defLoad => _list.any((element) {
        final def = element.load;
        return def != null && def();
      });

  bool _done = false;

  // 任务的状态：任务是否执行完成
  bool get done => _done;
  // 任务的状态：任务是否取得成功
  bool get success => _done && _image != null;
  bool get ignore => _done && _image == null && !_error;
  bool get failed => _done && _image == null && _error;

  // 成功或失败都要保存           success      || failed
  bool get save => _done && (_image != null || _error);
  bool get error => _done && (_error || _image == null);

  int get time => _time;

  int _time = 0;
  bool _error = false;

  void setImage(ImageRefInfo? img, bool error) {
    if (_done) {
      Log.e('done', onlyDebug: false);
    }
    _error = error;
    _done = true;
    _streamError = error || img == null;
    for (var listener in _list) {
      final callback = listener.onDone;

      callback(img?.clone(), _streamError, false);
    }

    if (_dispose) {
      img?.dispose();
      return;
    } else {
      assert(!schedule);
      _image = img;
      if (_streamError) {
        _time = DateTime.now().millisecondsSinceEpoch;
      }
      if (!hasListener && onRemove != null) onRemove!(this);
    }
  }

  final _list = <PictureListener>[];

  void addListener(PictureListener callback) {
    assert(!_dispose);
    _list.add(callback);

    if (!_done) return;

    callback.onDone(_image?.clone(), _streamError, true);
  }

  void removeListener(PictureListener callback) {
    _list.remove(callback);
    //                                                  如果任务未完成则不处理
    if (!hasListener && !_dispose && onRemove != null && _done) {
      if (schedule) return;

      scheduleMicrotask(() {
        schedule = false;
        if (!hasListener && !_dispose) {
          onRemove!(this);
        }
      });
      schedule = true;
    }
  }

  @visibleForTesting
  bool schedule = false;

  bool get hasListener => _list.isNotEmpty;

  bool get close => _dispose;
  // bool get active => _image?.close != false;

  bool _dispose = false;

  void dispose() {
    if (_dispose) return;

    _dispose = true;
    _image?.dispose();
  }
}

typedef DeffLoad = bool Function();

class PictureListener {
  PictureListener(this.onDone, {this.load});
  final DeffLoad? load;
  final ImageRefListenerCallback onDone;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PictureListener &&
            load == other.load &&
            onDone == other.onDone;
  }

  @override
  int get hashCode => ui.hashValues(load, onDone);
}
