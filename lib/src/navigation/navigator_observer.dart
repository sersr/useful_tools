// ignore_for_file: unnecessary_overrides

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:nop/nop.dart';

import 'dependences_mixin.dart';
import 'navigator_getter.dart';
import 'route_dependences.dart';

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

  final _factorys = HashMap<Type, Either<BuildFactory, BuildContextFactory>>();

  void putFactory<T>(Either<BuildFactory<T>, BuildContextFactory<T>> factory) {
    _factorys[T] = factory;
  }

  void put<T>(BuildFactory<T> factory) {
    _factorys[T] = Left(factory);
  }

  void putContext<T>(BuildContextFactory<T> factory) {
    _factorys[T] = Right(factory);
  }

  Either<BuildFactory<T>, BuildContextFactory<T>> get<T>() {
    assert(_factorys.containsKey(T), '请先使用 Nav.put<$T>()');
    return _factorys[T] as Either<BuildFactory<T>, BuildContextFactory<T>>;
  }

  RouteDependences? get currentDeps => observer.currentDeps;

  @override
  bool get isGlobal => true;

  @override
  GetTypePointers? get parent => currentDeps;
}

class NavObserver extends NavigatorObserver {
  OverlayState? get overlay => navigator?.overlay;

  RouteDependences? get currentDeps => _routes.isNotEmpty ? _routes.last : null;

  bool containsKey(Route key) => _routes.any((element) => element.route == key);

  RouteDependences? getRoutes(Route key) {
    final it = _routes.reversed;
    for (var item in it) {
      if (item.route == key) return item;
    }
    return null;
  }

  final _routes = <RouteDependences>[];

  void didPopOrRemove(Route route, Route? previousRoute) {
    final current = route.isCurrent ? _routes.removeLast() : getRoutes(route);
    assert(current?.route == route &&
        (previousRoute == null || getRoutes(previousRoute) == current?.parent));
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    didPopOrRemove(route, previousRoute);
    Log.w('pop: ${route.settings.name}');
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    assert(!containsKey(route));
    RouteDependences? parent;
    if (previousRoute != null) {
      parent = getRoutes(previousRoute);
    }
    final currentBucker = RouteDependences(route, parent);
    Log.w('push: ${route.settings.name}');
    _routes.add(currentBucker);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    didPopOrRemove(route, previousRoute);
    Log.w('remove: ${route.settings.name}');
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    assert(newRoute == null || !containsKey(newRoute));
    assert(oldRoute != null && containsKey(oldRoute));
    final current = getRoutes(oldRoute!);
    current?.route = newRoute!;
    Log.w('replace: ${newRoute?.settings.name}  ${oldRoute.settings.name}');
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
}

void _navDelegate(NavAction action) {
  NavigatorDelegate(action).init();
}
