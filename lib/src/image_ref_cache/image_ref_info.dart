import 'dart:async';
import 'dart:ui' as ui;

import 'package:utils/utils.dart';


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

  void dispose() {
    _imageRef._handles.remove(this);

    if (_imageRef._handles.isEmpty) {
      _imageRef.dispose();
    }
  }
}

class _ImageRef {
  _ImageRef._(this.rawImage);
  final ui.Image rawImage;

  final Set<ImageRefInfo> _handles = <ImageRefInfo>{};

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
    return null;
  }

  final void Function(ImageRefStream stream)? onRemove;

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
      assert(!_schedule);
      _image = img;
      if (_streamError) {
        _time = DateTime.now().millisecondsSinceEpoch;
      }
      _sche();
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
    _sche();
  }

  void _sche() {
    if (!hasListener && !_dispose && onRemove != null && _done) {
      if (_schedule) return;

      scheduleMicrotask(() {
        _schedule = false;
        if (!hasListener && !_dispose) {
          onRemove!(this);
        }
      });
      _schedule = true;
    }
  }

  bool _schedule = false;

  bool get hasListener => _list.isNotEmpty;

  bool get close => _dispose;

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
