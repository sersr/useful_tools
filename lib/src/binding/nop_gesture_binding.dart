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

  final HandleEventCallback _handlePointerEvent;

  final _HandleSampleTimeChangedCallback _handleSampleTimeChanged;

  void addOrDispatch(PointerEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      final _my = _resamplers.putIfAbsent(event.device, () => Resampler());

      _my.addEvent(event);
    } else {
      _handlePointerEvent(event);
    }
  }

  /// 每一个指针传入都会调用此方法，‘启动’与‘实现’分离
  /// 启动
  void sample() {
    final scheduler = SchedulerBinding.instance;
    final isNotEmpty = _resamplers.isNotEmpty;
    final sampleTime = _lastFrameTime;
    final nextSampleTime = _frameTime;

    for (final resampler in _resamplers.values) {
      resampler.resample(sampleTime, nextSampleTime, _handlePointerEvent);
    }

    _resamplers.removeWhere((int key, Resampler resampler) {
      return !resampler.hasPendingEvents && !resampler.isDown;
    });
    if (!_frameCallbackScheduled && isNotEmpty) {
      _frameCallbackScheduled = true;
      scheduler.scheduleFrameCallback((_) {
        _frameCallbackScheduled = false;

        _lastFrameTime = _frameTime;
        _frameTime = scheduler.currentSystemFrameTimeStamp;
        _handleSampleTimeChanged();
      });
    }
  }

  /// 实现
  void _sample() {
    sample();
  }

  void stop() {
    for (final my in _resamplers.values) {
      my.stop(_handlePointerEvent);
    }
    _resamplers.clear();
    _lastFrameTime = Duration.zero;
    _frameTime = Duration.zero;
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
  void handlePointerEvent(PointerEvent event, {bool self = false}) {
    assert(!locked);
    if (self) {
      super.handlePointerEvent(event);
      return;
    }
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
        _resampler._sample();
      } else {
        _resampler.stop();
      }
    }
  }

  void _handleEvent(PointerEvent event) {
    handlePointerEvent(event, self: true);
  }

  /// 不使用[samplingOffset]
  bool nopResamplingEnabled = false;

  late final _Resampler _resampler = _Resampler(
    _handleEvent,
    _handleSampleTimeChanged,
  );
}
