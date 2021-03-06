import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'cache_binding.dart';
import 'nop_gesture_binding.dart';

class NopWidgetsFlutterBinding extends BindingBase
    with
        GestureBinding,
        SchedulerBinding,
        ServicesBinding,
        PaintingBinding,
        SemanticsBinding,
        RendererBinding,
        CacheBinding,
        NopGestureBinding,
        WidgetsBinding {
  static NopWidgetsFlutterBinding? _instance;
  @override
  void initInstances() {
    _instance = this;
    super.initInstances();
  }

  static WidgetsBinding ensureInitialized() {
    if (_instance == null) NopWidgetsFlutterBinding();
    return WidgetsBinding.instance!;
  }
}
