import 'dart:async';

import 'package:flutter/material.dart';

import '../../common.dart';
import '../../event_queue.dart';

class TextCache {
  void clear() {
    clearDispose(_textCaches);
    clearDispose(_textListeners);

    clearDisposeRef(_textRefDispose);
    clearDisposeRef(_textRef);
  }

  void clearDispose(Map<ListKey, TextStream> map) {
    Log.i('text dispose: ${map.length}', onlyDebug: false);
    final _map = List.of(map.values);
    map.clear();
    for (var stream in _map) {
      stream.dispose();
    }
  }

  void clearDisposeRef(Map<ListKey, _TextRef> map) {
    Log.i('textRef dispose: ${map.length}', onlyDebug: false);
    map.clear();
  }

  final _textRef = <ListKey, _TextRef>{};
  final _textRefDispose = <ListKey, _TextRef>{};

  final _textLooper = EventQueue();
  final _textListeners = <ListKey, TextStream>{};
  final _textCaches = <ListKey, TextStream>{};

  TextStream? getListener(ListKey key) {
    var listener = _textListeners[key];

    if (listener == null) {
      listener = _textCaches.remove(key);

      if (listener != null) {
        _textListeners[key] = listener;
      }
    }

    assert(!_textCaches.containsKey(key));

    return listener;
  }

  TextInfo? getTextRef(ListKey key) {
    var textRef = _textRef[key];
    if (textRef == null) {
      textRef = _textRefDispose.remove(key);
      if (textRef != null) {
        _textRef[key] = textRef;
      }
    }

    assert(!_textCaches.containsKey(key));

    if (textRef != null) {
      assert(!textRef._disposed);
      return TextInfo.text(textRef);
    }
  }

  TextStream putIfAbsent(List keys, TextLayoutCallback callback) {
    final key = ListKey(keys);

    final _text = getListener(key);
    if (_text != null) {
      assert(_text.success || !_text._done);
      return _text;
    }

    final stream = _textListeners[key] = TextStream(onRemove: (stream) {
      assert(!_textCaches.containsKey(key));

      if (_textListeners.containsKey(key)) {
        final _stream = _textListeners.remove(key);
        assert(_stream == stream);
        if (stream.success) {
          if (_textCaches.length > 150) {
            final keyFirst = _textCaches.keys.first;
            final _text = _textCaches.remove(keyFirst);
            _text!.dispose();
          }

          _textCaches[key] = stream;
        } else {
          stream.dispose();
        }
      } else {
        stream.dispose();
      }
    });

    _textLooper.addEventTask(() async {
      // caches
      Map<ListKey, TextInfo>? _list;

      TextInfo? innerGetTextRef(List keys) {
        final key = ListKey(keys);
        var info = _list![key]?.clone();
        info ??= getTextRef(key);
        return info;
      }

      /// 返回的 [TextInfo] 不能调用 dispose
      Future<TextInfo> putIfAbsent(
          List keys, TextPainterBuilder builder) async {
        final key = ListKey(keys);
        _list ??= <ListKey, TextInfo>{};

        var _textInfo = innerGetTextRef(keys);

        if (_textInfo == null) {
          final _built = builder();
          TextPainter _textPainter;
          if (_built is Future) {
            _textPainter = await _built;
          } else {
            _textPainter = _built;
          }

          final _text = _textRef[key] = _TextRef(_textPainter, (ref) {
            if (_textRef.containsKey(key)) {
              final text = _textRef.remove(key);
              assert(text == ref, '$text, $ref');

              if (_textRefDispose.length > 150) {
                final keyFirst = _textRefDispose.keys.first;
                _textRefDispose.remove(keyFirst);
              }
              _textRefDispose[key] = ref;
            }
          });
          _textInfo = TextInfo.text(_text);
        }
        _list![key] = _textInfo;
        return _textInfo;
      }

      // await releaseUI;
      var error = false;
      final isEmpty = stream.isEmpty;

      try {
        if (!isEmpty) {
          await callback(innerGetTextRef, putIfAbsent);
        }
      } catch (e) {
        error = true;
      } finally {
        final infos = _list?.values;
        // if (!isEmpty) await releaseUI;
        stream.setTextInfo(infos?.toList(), error);
      }
    });

    return stream;
  }
}

typedef FindTextInfo = TextInfo? Function(List keys);
typedef PutIfAbsentText = Future<TextInfo> Function(
    List keys, TextPainterBuilder text);

typedef TextLayoutCallback = Future<void> Function(
    FindTextInfo find, PutIfAbsentText putIfAbsent);

typedef TextPainterBuilder = FutureOr<TextPainter> Function();

typedef TextStreamRemove = void Function(TextStream);

class TextStream {
  TextStream({required this.onRemove});

  final TextStreamRemove onRemove;
  List<TextInfo>? _textInfos;

  bool _done = false;
  bool _error = false;

  bool get success => _textInfos != null && !_error && _done;

  void setTextInfo(List<TextInfo>? textInfos, bool error) {
    assert(!_done);

    _done = true;
    _error = error;

    for (final listener in _lists) {
      listener(_map(textInfos), error);
    }

    if (disposed) {
      textInfos?.forEach(disposeTextInfo);
    } else {
      assert(!_schedule);
      _textInfos = textInfos;
      if (_lists.isEmpty) onRemove(this);
    }
  }

  final _lists = <ListenerFunction>[];
  void addListener(ListenerFunction listener) {
    _lists.add(listener);
    if (!_done) return;

    listener(_map(_textInfos), _error);
  }

  List<TextInfo>? _map(List<TextInfo>? infos) {
    return infos?.map((e) => e.clone()).toList();
  }

  void removeListener(ListenerFunction listener) {
    _lists.remove(listener);

    if (_lists.isEmpty && !disposed && _done) {
      if (_schedule) return;
      // 启动微任务
      scheduleMicrotask(() {
        _schedule = false;
        if (_lists.isEmpty && !disposed) onRemove(this);
      });
      _schedule = true;
    }
  }

  bool get isEmpty => _lists.isEmpty;

  bool _schedule = false;
  bool disposed = false;
  void dispose() {
    // assert(!disposed);
    if (disposed) {
      Log.e('disposed', onlyDebug: false);
      return;
    }
    disposed = true;
    _textInfos?.forEach(disposeTextInfo);
    _textInfos = null;
  }
}

typedef ListenerFunction = void Function(List<TextInfo>? textInfo, bool error);

void disposeTextInfo(TextInfo info) {
  info.dispose();
}

class TextInfo {
  TextInfo.text(_TextRef _text) : this._(_text);

  TextInfo._(this._text) {
    _text._handles.add(this);
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
    if (_dispose) {
      Log.e('error: textInfo...', onlyDebug: false);
      return;
    }

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
  void dispose() {
    assert(!_disposed);
    _disposed = true;
    onDispose(this);
  }
}
