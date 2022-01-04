import 'dart:async';

import 'package:flutter/material.dart';
import 'navigator_observer.dart';
import 'state_getter.dart';

final _navToken = Object();

abstract class NavAction {
  void action(NavigatorState state);
}

mixin NaviActionResult<T> on NavAction {
  Future<T?> get result => _completer.future;
  final _completer = Completer<T?>();

  @protected
  void complete([T? value]) {
    if (!_completer.isCompleted) {
      _completer.complete(value);
    }
  }

  void completeError([_]) {
    complete();
  }
}

class NavPushAction<T> extends NavAction with NaviActionResult<T> {
  NavPushAction(this.route);
  Route<T> route;

  @override
  void action(NavigatorState state) {
    state.push(route).then(complete, onError: completeError);
  }
}

class NavPushNamedAction<T> extends NavAction with NaviActionResult<T> {
  NavPushNamedAction(this.routeName, this.arguments);
  final String routeName;
  final Object? arguments;
  @override
  void action(NavigatorState state) {
    state
        .pushNamed<T>(routeName, arguments: arguments)
        .then(complete, onError: completeError);
  }
}

class NavPushReplacementdAction<T, TO> extends NavAction
    with NaviActionResult<T> {
  NavPushReplacementdAction(this.route, this.pushResult);
  Route<T> route;
  TO pushResult;

  @override
  void action(NavigatorState state) {
    state
        .pushReplacement<T, TO>(route, result: pushResult)
        .then(complete, onError: completeError);
  }
}

class NavPopAction<R> extends NavAction {
  NavPopAction(this.value);
  final R value;
  @override
  void action(NavigatorState state) {
    state.pop(value);
  }
}

class NavMaybePopAction<R> extends NavAction with NaviActionResult<bool> {
  NavMaybePopAction(this.value);
  final R value;
  @override
  void action(NavigatorState state) {
    state.maybePop(value).then(complete, onError: completeError);
  }
}

class NavReplaceAction<T> extends NavAction {
  NavReplaceAction(this.oldRoute, this.newRoute);
  Route<T> newRoute;
  Route<dynamic> oldRoute;

  @override
  void action(NavigatorState state) {
    state.replace(oldRoute: oldRoute, newRoute: newRoute);
  }
}

class NavRestorableReplaceAction<T> extends NavAction
    with NaviActionResult<String> {
  NavRestorableReplaceAction(
      this.oldRoute, this.newRouteBuilder, this.arguments);
  final Route<dynamic> oldRoute;
  final RestorableRouteBuilder<T> newRouteBuilder;
  final Object? arguments;
  @override
  void action(NavigatorState state) {
    final result = state.restorableReplace(
        oldRoute: oldRoute,
        newRouteBuilder: newRouteBuilder,
        arguments: arguments);
    complete(result);
  }
}

class NavReplaceBelowAction<T> extends NavAction {
  NavReplaceBelowAction(this.anchorRoute, this.newRoute);
  Route<T> newRoute;
  Route<dynamic> anchorRoute;

  @override
  void action(NavigatorState state) {
    state.replaceRouteBelow(anchorRoute: anchorRoute, newRoute: newRoute);
  }
}

class NavCanPopAction<T> extends NavAction with NaviActionResult<bool> {
  NavCanPopAction();

  @override
  void action(NavigatorState state) {
    complete(state.canPop());
  }
}

class NavigatorDelegate<T> with StateAsyncGetter<NavigatorState> {
  NavigatorDelegate(this.action);
  NavAction action;
  @override
  Object get key => _navToken;

  NavigatorState? Function()? navigatorStateGetter;

  @override
  NavigatorState? getState() {
    return navigatorStateGetter?.call() ?? Nav.getNavigator();
  }

  @override
  FutureOr<void> initRun(NavigatorState state) {
    assert(state.mounted);
    action.action(state);
  }
}
