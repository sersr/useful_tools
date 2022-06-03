// ignore_for_file: unnecessary_overrides

import 'dart:collection';

import 'package:flutter/material.dart';

import 'route.dart';

class NavigatorBase {
  NavigatorBase(this.getNavigator);
  NavigatorState? Function() getNavigator;

  NavigatorState? get currentState => getNavigator();
}

abstract class NavInterface {}

class NavGlobal extends NavInterface with GetTypePointers {
  NavGlobal._();
  static final _instance = NavGlobal._();
  factory NavGlobal() => _instance;

  final NavObserver observer = NavObserver();

  OverlayState? getOverlay() {
    return observer.overlay;
  }

  NavigatorState? getNavigator() {
    return observer.navigator;
  }

  final _factorys = HashMap<Type, BuildFactory>();

  void put<T>(BuildFactory<T> factory) {
    _factorys[T] = factory;
  }

  BuildFactory<T> get<T>() {
    assert(_factorys.containsKey(T), '请先使用 Nav.put<$T>()');
    return _factorys[T] as BuildFactory<T>;
  }

  RouteDependences? get currentDeps => observer.currentDeps;

  @override
  bool get isGlobal => true;

  @override
  NopListener? getParentType<T>({bool shared = true}) =>
      currentDeps?.getType<T>(shared: shared);
}

typedef BuildFactory<T> = T Function();

// ignore: non_constant_identifier_names
final Nav = NavGlobal();
