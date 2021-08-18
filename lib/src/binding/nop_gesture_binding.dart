// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';

import 'resampler.dart';

typedef _HandleSampleTimeChangedCallback = void Function();

class _Resampler {
  _Resampler(this._handlePointerEvent, this._handleSampleTimeChanged);

  final Map<int, Resampler> _resamplers = <int, Resampler>{};
  // Flag to track if a frame callback has been scheduled.
  bool _frameCallbackScheduled = false;

  Duration _frameTime = Duration.zero;
  Duration _lastFrameTime = Duration.zero;
  Duration _llf = Duration.zero;

  final HandleEventCallback _handlePointerEvent;

  final _HandleSampleTimeChangedCallback _handleSampleTimeChanged;

  void addOrDispatch(PointerEvent event) {
    final scheduler = SchedulerBinding.instance;
    assert(scheduler != null);

    if (event.kind == PointerDeviceKind.touch) {
      // _lastEventTime = event.timeStamp;

      final _my = _resamplers.putIfAbsent(event.device, () => Resampler());

      _my.addEvent(event);
    } else {
      _handlePointerEvent(event);
    }
  }

  void sample() {
    final scheduler = SchedulerBinding.instance;
    assert(scheduler != null);
    final sampleTime = _llf;
    final nextSampleTime = _lastFrameTime;

    for (final resampler in _resamplers.values) {
      resampler.resample(sampleTime, nextSampleTime, _handlePointerEvent);
    }

    // Remove inactive resamplers.
    _resamplers.removeWhere((int key, Resampler resampler) {
      return !resampler.hasPendingEvents && !resampler.isDown;
    });
    final isNotEmpty = _resamplers.isNotEmpty;

    // _lastSampleTime = sampleTime;

    if (!_frameCallbackScheduled && isNotEmpty) {
      _frameCallbackScheduled = true;
      scheduler?.scheduleFrameCallback((_) {
        _frameCallbackScheduled = false;

        _llf = _lastFrameTime;
        _lastFrameTime = _frameTime;
        _frameTime = scheduler.currentSystemFrameTimeStamp;
        // final resamplingMargin = _lastEventTime - _lastSampleTime;
        // Log.i('$resamplingMargin', onlyDebug: false);

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
    _lastFrameTime = Duration.zero;
    _frameTime = Duration.zero;
    _llf = Duration.zero;
  }
}

mixin NopGestureBinding on GestureBinding {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }

  static NopGestureBinding? _instance;
  static NopGestureBinding? get instance => _instance;
  @override
  void handlePointerEvent(PointerEvent event) {
    assert(!locked);

    if (nopResamplingEnabled) {
      _resampler.addOrDispatch(event);

      _resampler.sample();
      return;
    }

    _resampler.stop();
    super.handlePointerEvent(event);
  }

  void _handleSampleTimeChanged() {
    if (!locked) {
      if (nopResamplingEnabled) {
        _resampler.sample();
      } else {
        _resampler.stop();
      }
    }
  }

  void _handleEvent(PointerEvent event) {
    super.handlePointerEvent(event);
  }

  bool nopResamplingEnabled = true;

  // Resampler used to filter incoming pointer events when resampling
  // is enabled.
  late final _Resampler _resampler = _Resampler(
    _handleEvent,
    _handleSampleTimeChanged,
  );
}
