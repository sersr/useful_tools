import 'package:flutter/services.dart';

import '../../image_ref_cache.dart';
import '../../text_cache.dart';

mixin CacheBinding on ServicesBinding {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
    _textCache = createTextCache();
    _imageRefCache = createImageRefCache();
  }

  TextCache? _textCache;

  TextCache? get textCache => _textCache;

  ImageRefCache? createImageRefCache() {
    return ImageRefCache();
  }

  TextCache? createTextCache() {
    return TextCache();
  }

  ImageRefCache? _imageRefCache;
  ImageRefCache? get imageRefCache => _imageRefCache;

  static CacheBinding? get instance => _instance;
  static CacheBinding? _instance;

  @override
  void handleMemoryPressure() {
    super.handleMemoryPressure();
    _imageRefCache?.clear();
    _textCache?.clear();
  }
}
TextCache? get textCache => CacheBinding.instance?.textCache;
ImageRefCache? get imageRefCache => CacheBinding.instance?.imageRefCache;
