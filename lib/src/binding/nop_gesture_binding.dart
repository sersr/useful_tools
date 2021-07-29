// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';

import 'resampler.dart';

typedef _HandleSampleTimeChangedCallback = void Function();

class _Resampler {
  _Resampler(this._handlePointerEvent, this._handleSampleTimeChanged);

  // Resamplers used to filter incoming pointer events.
  final Map<int, Resampler> _resamplers = <int, Resampler>{};
  // Flag to track if a frame callback has been scheduled.
  bool _frameCallbackScheduled = false;

  // Last frame time for resampling.
  Duration _frameTime = Duration.zero;
  Duration _lastFrameTime = Duration.zero;
  Duration _llf = Duration.zero;

  // Time since `_frameTime` was updated.

  // Last sample time and time stamp of last event.
  //
  // Only used for debugPrint of resampling margin.
  Duration _lastSampleTime = Duration.zero;
  Duration _lastEventTime = Duration.zero;

  // Callback used to handle pointer events.
  final HandleEventCallback _handlePointerEvent;

  // Callback used to handle sample time changes.
  final _HandleSampleTimeChangedCallback _handleSampleTimeChanged;

  // Add `event` for resampling or dispatch it directly if
  // not a touch event.
  void addOrDispatch(PointerEvent event) {
    final scheduler = SchedulerBinding.instance;
    assert(scheduler != null);
    // Add touch event to resampler or dispatch pointer event directly.
    if (event.kind == PointerDeviceKind.touch) {
      // Save last event time for debugPrint of resampling margin.
      _lastEventTime = event.timeStamp;

      final _my = _resamplers.putIfAbsent(event.device, () => Resampler());

      _my.addEvent(event);
    } else {
      _handlePointerEvent(event);
    }
  }

  // Sample and dispatch events.
  //
  // The `samplingOffset` is relative to the current frame time, which
  // can be in the past when we're not actively resampling.
  // The `samplingClock` is the clock used to determine frame time age.
  void sample(Duration samplingOffset) {
    final scheduler = SchedulerBinding.instance;
    assert(scheduler != null);

    // Determine sample time by adding the offset to the current
    // frame time. This is expected to be in the past and not
    // result in any dispatched events unless we're actively
    // resampling events.
    // final sampleTime = _frameTime + samplingOffset;
    final sampleTime = _llf + samplingOffset;

    // Determine next sample time by adding the sampling interval
    // to the current sample time.
    final nextSampleTime = _lastFrameTime + samplingOffset;

    for (final resampler in _resamplers.values) {
      resampler.resample(sampleTime, nextSampleTime, _handlePointerEvent);
    }

    // Remove inactive resamplers.
    _resamplers.removeWhere((int key, Resampler resampler) {
      return !resampler.hasPendingEvents && !resampler.isDown;
    });
    final isNotEmpty = _resamplers.isNotEmpty;

    _lastSampleTime = sampleTime;

    if (!_frameCallbackScheduled && isNotEmpty) {
      _frameCallbackScheduled = true;
      scheduler?.scheduleFrameCallback((_) {
        _frameCallbackScheduled = false;

        _llf = _lastFrameTime;
        _lastFrameTime = _frameTime;
        _frameTime = scheduler.currentSystemFrameTimeStamp;
        assert(() {
          if (debugPrintResamplingMargin) {
            final resamplingMargin = _lastEventTime - _lastSampleTime;
            debugPrint('$resamplingMargin');
          }
          return true;
        }());
        _handleSampleTimeChanged();
      });
    }
  }

  // Stop all resampling and dispatched any queued events.
  void stop() {
    for (final my in _resamplers.values) {
      my.stop(_handlePointerEvent);
    }
    _resamplers.clear();
    _frameTime = Duration.zero;
  }
}

mixin NopGestureBinding on GestureBinding {
  final Map<int, HitTestResult> _hitTests = <int, HitTestResult>{};

  /// Dispatch an event to the targets found by a hit test on its position.
  ///
  /// This method sends the given event to [dispatchEvent] based on event types:
  ///
  ///  * [PointerDownEvent]s and [PointerSignalEvent]s are dispatched to the
  ///    result of a new [hitTest].
  ///  * [PointerUpEvent]s and [PointerMoveEvent]s are dispatched to the result of hit test of the
  ///    preceding [PointerDownEvent]s.
  ///  * [PointerHoverEvent]s, [PointerAddedEvent]s, and [PointerRemovedEvent]s
  ///    are dispatched without a hit test result.
  @override
  void handlePointerEvent(PointerEvent event) {
    assert(!locked);

    if (resamplingEnabled) {
      _resampler.addOrDispatch(event);

      _resampler.sample(samplingOffset);
      return;
    }

    // Stop resampler if resampling is not enabled. This is a no-op if
    // resampling was never enabled.
    _resampler.stop();
    _handlePointerEventImmediately(event);
  }

  void _handlePointerEventImmediately(PointerEvent event) {
    HitTestResult? hitTestResult;
    if (event is PointerDownEvent ||
        event is PointerSignalEvent ||
        event is PointerHoverEvent) {
      assert(!_hitTests.containsKey(event.pointer));
      hitTestResult = HitTestResult();
      hitTest(hitTestResult, event.position);
      if (event is PointerDownEvent) {
        _hitTests[event.pointer] = hitTestResult;
      }
      assert(() {
        if (debugPrintHitTestResults) debugPrint('$event: $hitTestResult');
        return true;
      }());
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      hitTestResult = _hitTests.remove(event.pointer);
    } else if (event.down) {
      // Because events that occur with the pointer down (like
      // [PointerMoveEvent]s) should be dispatched to the same place that their
      // initial PointerDownEvent was, we want to re-use the path we found when
      // the pointer went down, rather than do hit detection each time we get
      // such an event.
      hitTestResult = _hitTests[event.pointer];
    }
    assert(() {
      if (debugPrintMouseHoverEvents && event is PointerHoverEvent) {
        debugPrint('$event');
      }
      return true;
    }());
    if (hitTestResult != null ||
        event is PointerAddedEvent ||
        event is PointerRemovedEvent) {
      dispatchEvent(event, hitTestResult);
    }
  }

  void _handleSampleTimeChanged() {
    if (!locked) {
      if (resamplingEnabled) {
        _resampler.sample(samplingOffset);
      } else {
        _resampler.stop();
      }
    }
  }

  // Resampler used to filter incoming pointer events when resampling
  // is enabled.
  late final _Resampler _resampler = _Resampler(
    _handlePointerEventImmediately,
    _handleSampleTimeChanged,
  );
}
