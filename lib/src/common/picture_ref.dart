import 'dart:ui' as ui;

class PictureRefInfo {
  PictureRefInfo(ui.Picture picture) : this._(PictureRef(picture));

  PictureRefInfo._(this.pictureRef) {
    pictureRef._handles.add(this);
  }

  final PictureRef pictureRef;

  PictureRefInfo clone() {
    return PictureRefInfo._(pictureRef);
  }

  bool isCloneOf(PictureRefInfo other) {
    return other.pictureRef == pictureRef;
  }

  void dispose() {
    pictureRef._handles.remove(this);
    if (pictureRef._handles.isEmpty) {
      pictureRef.dispose();
    }
  }
}

class PictureRef {
  PictureRef(this.picture);

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
