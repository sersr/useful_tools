import 'package:flutter/services.dart';

import '../../image_ref_cache.dart';
import '../../text_cache.dart';

mixin CacheBinding on ServicesBinding {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
    _textCache = TextCache();
    _imageCacheLoop = ImageCacheLoop();
  }

  TextCache? _textCache;

  TextCache? get textCache => _textCache;

  ImageCacheLoop? _imageCacheLoop;
  ImageCacheLoop? get imageCacheLoop => _imageCacheLoop;

  static CacheBinding? get instance => _instance;
  static CacheBinding? _instance;

  @override
  void handleMemoryPressure() {
    super.handleMemoryPressure();
    _imageCacheLoop?.clear();
    _textCache?.clear();
  }
}
TextCache? get textCache => CacheBinding.instance?.textCache;
ImageCacheLoop? get imageCacheLoop =>
    CacheBinding.instance?.imageCacheLoop;
