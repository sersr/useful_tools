import 'dart:ui' as ui;
import 'log.dart';

class PictureRefInfo {
  PictureRefInfo(ui.Picture picture) : this._(_PictureRef(picture));

  PictureRefInfo._(this._pictureRef) {
    _pictureRef._handles.add(this);
  }
  /// 需要观察 [_pictureRef] 是否正确释放时设置为 true
  static var observe = false;
  final _PictureRef _pictureRef;
  ui.Picture get picture => _pictureRef.picture;

  PictureRefInfo clone() {
    return PictureRefInfo._(_pictureRef);
  }

  bool isCloneOf(PictureRefInfo other) {
    return other._pictureRef == _pictureRef;
  }

  void dispose() {
    _pictureRef._handles.remove(this);
    // 在筛选器中输入`hashCode`观察引用个数的变化
    assert(!observe ||
        Log.w(
            'dispose: ${_pictureRef._handles.length} ${_pictureRef.hashCode}'));
    if (_pictureRef._handles.isEmpty) {
      _pictureRef.dispose();
    }
  }
}

class _PictureRef {
  _PictureRef(this.picture);

  final ui.Picture picture;

  final _handles = <PictureRefInfo>{};

  bool _disposed = false;
  void dispose() {
    assert(!_disposed);
    assert(_handles.isEmpty);
    _disposed = true;
    picture.dispose();
  }
}
