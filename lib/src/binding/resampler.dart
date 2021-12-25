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
  PointerEvent? _last;
  PointerEvent? _next;

  /// 拿到小于当前[vsyncTime]的最大指针事件
  void _processPointerEvents(Duration vsyncTime) {
    final list = _queuedEvents.toList();
    PointerEvent? next;
    PointerEvent? lastCache = _last;

    _last = _next;

    if (_last == null && list.isNotEmpty) {
      _last = list[0];
    }

    // 获取最后一个满足条件的`PointerEvent`
    for (var i = list.length - 1; i >= 0; i--) {
      final event = list[i];
      if (event.timeStamp <= vsyncTime) {
        next = event;
        break;
      }
    }

    if (_next == next) {
      _last = lastCache;
    } else {
      _next = next;
    }
  }

  bool _isTracked = false;
  bool _isDown = false;
  int _pointerIdentifier = 0;
  int _hasButtons = 0;

  void resample(Duration vsyncTime, Duration nextTimeStamp,
      HandleEventCallback callback) {
    _processPointerEvents(vsyncTime);

    if (_last == null || _next == null) return;

    final sampleTime = vsyncTime - const Duration(milliseconds: 5);

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

    while (_queuedEvents.isNotEmpty) {
      final event = _queuedEvents.first;

      if (event.timeStamp > endTime) {
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

    if (_isTracked) {
      _samplePointerPosition(sampleTime, callback);
    }
  }

  void _samplePointerPosition(
    Duration sampleTime,
    HandleEventCallback callback,
  ) {
    // Position at `sampleTime`.
    final Offset position = _positionAt(sampleTime);

    // Add `move` or `hover` events if position has changed.
    final PointerEvent? next = _next;
    if (position != _position && next != null) {
      final Offset delta = position - _position;
      callback(_toMoveOrHoverEvent(next, position, delta, _pointerIdentifier,
          sampleTime, _isDown, _hasButtons));
      _position = position;
    }
  }

  Offset _positionAt(Duration sampleTime) {
    // Use `next` position by default.
    double x = _next?.position.dx ?? 0.0;
    double y = _next?.position.dy ?? 0.0;

    final Duration nextTimeStamp = _next?.timeStamp ?? Duration.zero;
    final Duration lastTimeStamp = _last?.timeStamp ?? Duration.zero;

    // Resample if `next` time stamp is past `sampleTime`.
    if (nextTimeStamp > sampleTime && nextTimeStamp > lastTimeStamp) {
      final double interval =
          (nextTimeStamp - lastTimeStamp).inMicroseconds.toDouble();
      final double scalar =
          (sampleTime - lastTimeStamp).inMicroseconds.toDouble() / interval;
      final double lastX = _last?.position.dx ?? 0.0;
      final double lastY = _last?.position.dy ?? 0.0;
      x = lastX + (x - lastX) * scalar;
      y = lastY + (y - lastY) * scalar;
    }

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
