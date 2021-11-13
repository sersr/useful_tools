import 'dart:collection';

import 'package:flutter/gestures.dart';

class Resampler {
  final Queue<PointerEvent> _queuedEvents = Queue<PointerEvent>();
  void addEvent(PointerEvent event) {
    _queuedEvents.add(event);
  }

  PointerEvent _toHoverEvent(
    PointerEvent event,
    Offset position,
    Offset delta,
    Duration timeStamp,
    int buttons,
  ) {
    return PointerHoverEvent(
      timeStamp: timeStamp,
      kind: event.kind,
      device: event.device,
      position: position,
      delta: delta,
      buttons: event.buttons,
      obscured: event.obscured,
      pressureMin: event.pressureMin,
      pressureMax: event.pressureMax,
      distance: event.distance,
      distanceMax: event.distanceMax,
      size: event.size,
      radiusMajor: event.radiusMajor,
      radiusMinor: event.radiusMinor,
      radiusMin: event.radiusMin,
      radiusMax: event.radiusMax,
      orientation: event.orientation,
      tilt: event.tilt,
      synthesized: event.synthesized,
      embedderId: event.embedderId,
    );
  }

  PointerEvent _toMoveEvent(
    PointerEvent event,
    Offset position,
    Offset delta,
    int pointerIdentifier,
    Duration timeStamp,
    int buttons,
  ) {
    return PointerMoveEvent(
      timeStamp: timeStamp,
      pointer: pointerIdentifier,
      kind: event.kind,
      device: event.device,
      position: position,
      delta: delta,
      buttons: buttons,
      obscured: event.obscured,
      pressure: event.pressure,
      pressureMin: event.pressureMin,
      pressureMax: event.pressureMax,
      distanceMax: event.distanceMax,
      size: event.size,
      radiusMajor: event.radiusMajor,
      radiusMinor: event.radiusMinor,
      radiusMin: event.radiusMin,
      radiusMax: event.radiusMax,
      orientation: event.orientation,
      tilt: event.tilt,
      platformData: event.platformData,
      synthesized: event.synthesized,
      embedderId: event.embedderId,
    );
  }

  PointerEvent _toMoveOrHoverEvent(
    PointerEvent event,
    Offset position,
    Offset delta,
    int pointerIdentifier,
    Duration timeStamp,
    bool isDown,
    int buttons,
  ) {
    return isDown
        ? _toMoveEvent(
            event, position, delta, pointerIdentifier, timeStamp, buttons)
        : _toHoverEvent(event, position, delta, timeStamp, buttons);
  }

  var _position = Offset.zero;
  PointerEvent? firstEvent;
  PointerEvent? lastEvent;

  /// 拿到小于当前[vsyncTime]的最大指针事件
  void _processPointerEvents(Duration vsyncTime) {
    final list = _queuedEvents.toList();
    PointerEvent? _last;
    PointerEvent? _first;
    var i = list.length - 1;
    // var count = -1;
    for (; i >= 0; i--) {
      final event = list[i];
      // count = i;
      if (event.timeStamp <= vsyncTime) {
        _last = event;
        final _fi = i - 1;

        assert(_fi < list.length);

        if (_fi >= 0) {
          _first = list[_fi];
        }
        break;
      }
    }
    // Log.i('${count + 1} | ${list.length}', onlyDebug: false, showPath: false);
    lastEvent = _last;
    firstEvent = _first ?? _last;
  }

  bool _isTracked = false;
  bool _isDown = false;
  int _pointerIdentifier = 0;
  int _hasButtons = 0;

  void resample(Duration vsyncTime, Duration nextTimeStamp,
      HandleEventCallback callback) {
    _processPointerEvents(vsyncTime);

    final _last = lastEvent;
    final _first = firstEvent;

    if (_last == null || _first == null) return;

    final sampleTime = vsyncTime - const Duration(milliseconds: 5);
    final _lastTimeStamp = _last.timeStamp;
    var endTime = sampleTime;
    final Iterator<PointerEvent> it = _queuedEvents.iterator;
    while (it.moveNext()) {
      final PointerEvent event = it.current;

      // Potentially stop dispatching events if more recent than `sampleTime`.
      if (event.timeStamp > sampleTime) {
        // Definitely stop if more recent than `nextSampleTime`.
        if (event.timeStamp >= nextTimeStamp) {
          break;
        }

        // Update `endTime` to allow early processing of up and removed
        // events as this improves resampling of these events, which is
        // important for fling animations.
        if (event is PointerUpEvent || event is PointerRemovedEvent) {
          endTime = event.timeStamp;
          continue;
        }

        // Stop if event is not move or hover.
        if (event is! PointerMoveEvent && event is! PointerHoverEvent) {
          break;
        }
      }
    }
    var position = _positionAt(sampleTime);
    final _e = sampleTime == endTime;
    while (_queuedEvents.isNotEmpty) {
      final event = _queuedEvents.first;
      if (_e && event == _queuedEvents.last) {
        // 保留最后一个指针事件
        if (event.timeStamp > _lastTimeStamp) {
          break;
        }
      } else if (event.timeStamp > endTime) {
        break;
      }

      final wasTracked = _isTracked;
      final wasDown = _isDown;
      final hadButtons = _hasButtons;

      _isTracked = event is! PointerRemovedEvent;
      _isDown = event.down;
      _hasButtons = event.buttons;

      final pointerIdentifier = event.pointer;
      _pointerIdentifier = pointerIdentifier;

      if (_isTracked && !wasTracked) {
        _position = position;
      }

      if (event is! PointerMoveEvent && event is! PointerHoverEvent) {
        if (position != _position) {
          final delta = position - _position;
          callback(_toMoveOrHoverEvent(event, position, delta,
              _pointerIdentifier, sampleTime, wasDown, hadButtons));
          _position = position;
        }
        callback(event.copyWith(
          position: position,
          delta: Offset.zero,
          pointer: pointerIdentifier,
          timeStamp: sampleTime,
        ));
      }
      _queuedEvents.removeFirst();
    }

    if (position != _position && _isTracked) {
      final delta = position - _position;

      callback(_toMoveOrHoverEvent(_first, position, delta, _pointerIdentifier,
          sampleTime, _isDown, _hasButtons));
      _position = position;
    }
  }

  Offset _positionAt(Duration sampleTime) {
    final _last = lastEvent;
    final _first = firstEvent;
    if (_last == null || _first == null) return Offset.zero;
    final _p = _last.position;
    var x = _p.dx;
    var y = _p.dy;

    final touchTimeDiff = _last.timeStamp - _first.timeStamp;
    final touchSampleTimeDiff = sampleTime - _last.timeStamp;

    final diff = touchTimeDiff.inMicroseconds.toDouble();
    if (diff == 0) return _p;

    final alpha = touchSampleTimeDiff.inMicroseconds.toDouble() / diff;

    final positonDiff = _last.position - _first.position;
    x += positonDiff.dx * alpha;
    y += positonDiff.dy * alpha;
    return Offset(x, y);
  }

  void stop(HandleEventCallback callback) {
    while (_queuedEvents.isNotEmpty) {
      callback(_queuedEvents.removeFirst());
    }
    _isTracked = false;
    _position = Offset.zero;
  }

  bool get hasPendingEvents => _queuedEvents.isNotEmpty;

  /// Returns `true` if pointer is currently tracked.
  bool get isTracked => _isTracked;

  /// Returns `true` if pointer is currently down.
  bool get isDown => _isDown;
}
