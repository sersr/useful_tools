import 'dart:async';

import 'package:flutter/material.dart';

import '../../common.dart';

class TextCache {
  void clear() {
    final cLength = _textRefCaches.length;
    clearDisposeRef(_textRefCaches);
    if (cLength < 30) {
      clearDisposeRef(_liveTextRefs);
    }
  }

  void clearDisposeRef(Map<ListKey, _TextRef> map) {
    Log.i('textRef dispose: ${map.length}', onlyDebug: false);
    map.clear();
  }

  final _liveTextRefs = <ListKey, _TextRef>{};
  final _textRefCaches = <ListKey, _TextRef>{};

  final _textLooper = EventQueue();

  /// [LinkedHashMap]
  final _textListeners = <ListKey, TextStream>{};

  TextStream? getListener(ListKey key) {
    return _textListeners[key];
  }

  TextInfo? getTextRef(ListKey key) {
    var textRef = _liveTextRefs[key];
    if (textRef == null) {
      textRef = _textRefCaches.remove(key);
      if (textRef != null) {
        assert(Log.i('move textRef'));
        textRef.reset();
        _liveTextRefs[key] = textRef;
      }
    }

    if (textRef != null) {
      assert(!textRef._disposed);
      return TextInfo.text(textRef);
    }
  }

  TextStream putIfAbsent(List keys, TextLayoutCallback callback) {
    final key = ListKey(keys);

    final _text = getListener(key);
    if (_text != null) return _text;

    final stream = _textListeners[key] = TextStream(onRemove: (stream) {
      final _stream = _textListeners[key];
      if (stream == _stream) {
        _textListeners.remove(key);
      }
      stream.dispose();
    });

    _textLooper.addEventTask(() async {
      // innerCaches
      Map<ListKey, TextInfo>? _map;
      List<TextInfo> _list = [];

      TextInfo? innerGetTextRef(ListKey key) {
        var info = _map![key]?.clone();
        info ??= getTextRef(key);
        return info;
      }

      /// read only
      ///
      /// 返回的 [TextInfo] 不能调用 dispose
      TextInfo putIfAbsentTextRef(List keys, TextPainterBuilder builder) {
        final key = ListKey(keys);
        _map ??= <ListKey, TextInfo>{};

        var _textInfo = innerGetTextRef(key);
        if (_textInfo == null) {
          assert(!_map!.containsKey(key));
          final _built = builder();

          final _text = _liveTextRefs[key] = _TextRef(_built, (ref) {
            assert(!_textRefCaches.containsKey(key));

            final text = _liveTextRefs[key];
            // 有可能不是同一个对象
            if (text == ref) {
              _liveTextRefs.remove(key);
              if (_textRefCaches.length > 150) {
                final keyFirst = _textRefCaches.keys.first;
                _textRefCaches.remove(keyFirst);
              }
              _textRefCaches[key] = ref;
            }
          });
          _textInfo = _map![key] = TextInfo.text(_text);
        }
        _list.add(_textInfo);
        return _textInfo;
      }

      await releaseUI;

      if (stream.isEmpty) {
        _map?.clear();
        _list.forEach(TextInfo.disposeTextInfo);
        stream.setTextInfo(null);
        return;
      }
      try {
        await callback(putIfAbsentTextRef);
      } catch (s, e) {
       assert(Log.e('...error:$s\n $e'));
      } finally {
        _map?.clear();
        await releaseUI;
        stream.setTextInfo(_list);
      }
    });

    return stream;
  }
}

typedef PutIfAbsentText = TextInfo Function(List keys, TextPainterBuilder text);

typedef TextLayoutCallback = Future<void> Function(PutIfAbsentText putIfAbsent);

typedef TextPainterBuilder = TextPainter Function();

typedef TextStreamRemove = void Function(TextStream);

class TextStream {
  TextStream({required this.onRemove});

  final TextStreamRemove onRemove;
  List<TextInfo>? _textInfos;

  bool _done = false;

  bool get success => _textInfos != null && _done;

  void setTextInfo(List<TextInfo>? textInfos) {
    assert(!_done);

    _done = true;

    for (final listener in _lists) {
      assert(textInfos != null && textInfos.isNotEmpty);
      listener(_map(textInfos), false);
    }

    if (disposed) {
      textInfos?.forEach(TextInfo.disposeTextInfo);
    } else {
      _textInfos = textInfos;
      _sech();
    }
  }

  final _lists = <ListenerFunction>[];
  void addListener(ListenerFunction listener) {
    _lists.add(listener);
    if (!_done) return;

    listener(_map(_textInfos), true);
  }

  List<TextInfo>? _map(List<TextInfo>? infos) {
    return infos?.map((e) => e.clone()).toList();
  }

  void removeListener(ListenerFunction listener) {
    _lists.remove(listener);

    _sech();
  }

  void _sech() {
    if (isEmpty && !disposed && _done) {
      if (_schedule) return;
      // 启动微任务
      scheduleMicrotask(() {
        _schedule = false;
        if (isEmpty && !disposed) onRemove(this);
      });
      _schedule = true;
    }
  }

  bool get isEmpty => _lists.isEmpty;

  bool _schedule = false;
  bool disposed = false;

  @visibleForTesting
  void dispose() {
    assert(!disposed, Log.e('disposed', onlyDebug: false));

    disposed = true;
    _textInfos?.forEach(TextInfo.disposeTextInfo);
    _textInfos = null;
  }
}

typedef ListenerFunction = void Function(List<TextInfo>? textInfo, bool sync);

class TextInfo {
  TextInfo.text(_TextRef _text) : this._(_text);

  TextInfo._(this._text) {
    _text._handles.add(this);
  }

  static void disposeTextInfo(TextInfo info) {
    info.dispose();
  }

  final _TextRef _text;

  Size get size => _text.text.size;
  TextPainter get painter => _text.text;

  void paint(Canvas canvas, Offset offset) {
    _text.text.paint(canvas, offset);
  }

  TextInfo clone() {
    assert(!disposed);
    final _clone = TextInfo._(_text);
    return _clone;
  }

  bool get disposed => _text._disposed;

  bool _dispose = false;
  void dispose() {
    assert(!_dispose, Log.e('error: textInfo...', onlyDebug: false));

    _dispose = true;
    _text._handles.remove(this);
    if (_text._handles.isEmpty) {
      _text.dispose();
    }
  }
}

// 管理一个引用
class _TextRef {
  _TextRef(this.text, this.onDispose);

  final TextPainter text;
  final void Function(_TextRef ref) onDispose;

  final _handles = <TextInfo>{};

  bool _disposed = false;

  void reset() {
    _disposed = false;
  }

  void dispose() {
    assert(!_disposed);

    _disposed = true;
    onDispose(this);
  }
}
