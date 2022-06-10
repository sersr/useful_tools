// ignore_for_file: unnecessary_overrides

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:nop/nop.dart';

import 'navigator_getter.dart';

class NavigatorBase {
  NavigatorBase(this.getNavigator);
  NavigatorState? Function() getNavigator;

  NavigatorState? get currentState => getNavigator();
}

abstract class NavInterface {}

class NavGlobal extends NavInterface {
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

  final _factorys = HashMap<Type, Either<BuildFactory, BuildContextFactory>>();

  void putFactory<T>(Either<BuildFactory<T>, BuildContextFactory<T>> factory) {
    _factorys[T] = factory;
  }

  void put<T>(BuildFactory<T> factory) {
    _factorys[T] = Left<BuildFactory<T>, BuildContextFactory<T>>(factory);
  }

  void putContext<T>(BuildContextFactory<T> factory) {
    _factorys[T] = Right<BuildFactory<T>, BuildContextFactory<T>>(factory);
  }

  Either<BuildFactory<T>, BuildContextFactory<T>> get<T>() {
    assert(_factorys.containsKey(T), '请先使用 Nav.put<$T>()');
    return _factorys[T] as Either<BuildFactory<T>, BuildContextFactory<T>>;
  }

  Either<BuildFactory, BuildContextFactory> getArg(Type t) {
    assert(_factorys.containsKey(t), '请先使用 Nav.put<$t>()');
    return _factorys[t] as Either<BuildFactory, BuildContextFactory>;
  }

  final _alias = <Type, Type>{};

  void addAliasType(Type parent, Type child) {
    _alias[parent] = child;
  }

  /// 子类可以转化成父类
  void addAlias<P, C extends P>() {
    _alias[P] = C; // 可以根据父类类型获取到子类对象
  }

  Type getAlias(Type t) {
    return _alias[t] ?? t;
  }

  void addAliasAll(Iterable<Type> parents, Type child) {
    for (var item in parents) {
      addAliasType(item, child);
    }
  }
}

class NavObserver extends NavigatorObserver {
  OverlayState? get overlay => navigator?.overlay;

  @override
  void didPop(Route route, Route? previousRoute) {
    assert(Log.i('${route.settings.name}'));
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    assert(Log.i('${route.settings.name}'));
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    assert(Log.i('${route.settings.name}'));
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    assert(Log.i('${newRoute?.settings.name}  ${oldRoute?.settings.name}'));
  }
}

typedef BuildFactory<T> = T Function();
typedef BuildContextFactory<T> = T Function(BuildContext context);

// ignore: non_constant_identifier_names
final Nav = NavGlobal();

extension NavigatorExt on NavInterface {
  Future<T?> push<T extends Object?>(Route<T> route) {
    final push = NavPushAction(route);
    _navDelegate(push);
    return push.result;
  }

  Future<T?> pushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    final action = NavPushNamedAction<T>(routeName, arguments);
    _navDelegate(action);
    return action.result;
  }

  Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    String routeName,
    bool Function(Route<dynamic>) predicate, {
    Object? arguments,
  }) {
    final action = NavPushReplaceUntil<T>(routeName, predicate, arguments);
    _navDelegate(action);
    return action.result;
  }

  Future<T?> pushReplacementNamed<T extends Object?, R extends Object?>(
    String routeName, {
    R? result,
    Object? arguments,
  }) {
    final action =
        NavPushReplacementNamedAction<T, R>(routeName, arguments, result);
    _navDelegate(action);
    return action.result;
  }

  Future<T?> popAndPushNamed<T extends Object?, R extends Object?>(
    String routeName, {
    R? result,
    Object? arguments,
  }) {
    final action = NavPopAndPushNamedAction<T, R>(routeName, arguments, result);
    _navDelegate(action);
    return action.result;
  }

  Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
      Route<T> newRoute,
      {TO? result}) {
    final action = NavPushReplacementdAction(newRoute, result);
    _navDelegate(action);
    return action.result;
  }

  void pop<T extends Object?>([T? result]) {
    final pop = NavPopAction(result);
    _navDelegate(pop);
  }

  Future<bool?> maybePop<T extends Object?>([T? result]) {
    final pop = NavMaybePopAction(result);
    _navDelegate(pop);
    return pop.result;
  }

  void replace<T extends Object?>(
      {required Route<dynamic> oldRoute, required Route<T> newRoute}) {
    final replace = NavReplaceAction(oldRoute, newRoute);
    _navDelegate(replace);
  }

  Future<String?> restorableReplace<T extends Object?>(
      {required Route<dynamic> oldRoute,
      required RestorableRouteBuilder<T> newRouteBuilder,
      Object? arguments}) {
    final action =
        NavRestorableReplaceAction(oldRoute, newRouteBuilder, arguments);
    _navDelegate(action);
    return action.result;
  }

  void replaceRouteBelow<T extends Object?>(
      {required Route<dynamic> anchorRoute, required Route<T> newRoute}) {
    final action = NavReplaceBelowAction(anchorRoute, newRoute);
    _navDelegate(action);
  }

  Future<String?> restorablePushNamed(String routeName, {Object? arguments}) {
    final action = NavRePushNamedAction(routeName, arguments);
    _navDelegate(action);
    return action.result;
  }

  Future<String?> restorablePopAndPushNamed<T extends Object>(
    String routeName, {
    Object? arguments,
    T? result,
  }) {
    final action = NavRePopPushNamedAction(routeName, arguments, result);
    _navDelegate(action);
    return action.result;
  }

  Future<String?> restorablePushNamedAndRemoveUntil<T extends Object?>(
    String routeName,
    bool Function(Route<dynamic>) predicate, {
    Object? arguments,
  }) {
    final action = NavRePushNamedUntilAction(routeName, arguments, predicate);
    _navDelegate(action);
    return action.result;
  }

  Future<String?> restorablePushReplacementNamed<T extends Object>(
    String routeName, {
    T? result,
    Object? arguments,
  }) {
    final action = NavRePushNamedReplaceAction(routeName, arguments, result);
    _navDelegate(action);
    return action.result;
  }
}

void _navDelegate(NavAction action) {
  NavigatorDelegate(action).init();
}
