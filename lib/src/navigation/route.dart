import 'dart:async';

import 'package:flutter/material.dart';

import 'navigator_observer.dart';

class NopRouteAction<T> with NopRouteActionMixin<T> {
  NopRouteAction({
    this.arguments,
    required this.context,
    required this.route,
  });
  @override
  final Object? arguments;

  @override
  final BuildContext? context;

  @override
  final NopRoute route;
}

mixin NopRouteActionMixin<T> {
  NopRoute get route;
  Object? get arguments;
  BuildContext? get context;
  Object? result;
  Future<T?> get go {
    return route.pushNamed(context: context, arguments: arguments);
  }

  Future<T?> get goBack {
    return route.popAndPushNamed(
        context: context, result: result, arguments: arguments);
  }

  Future<T?> get goReplace {
    return route.pushReplacementNamed(
        context: context, result: result, arguments: arguments);
  }
}

class NopRoute {
  final String name;
  final String fullName;
  final List<NopRoute> children;
  final Widget Function(BuildContext context, dynamic arguments) builder;
  final String desc;

  const NopRoute({
    required this.name,
    required this.fullName,
    required this.builder,
    this.children = const [],
    this.desc = '',
  });

  static final NavigationActions navigationActions = NavigationNativeActions(
    pushNamedCallabck: Navigator.pushNamed,
    popAndPushNamedCallabck: Navigator.popAndPushNamed,
    pushReplacementNamedCallabck: Navigator.pushReplacementNamed,
  );
  static NavigationActions navigationWithoutContext = NavigationNavActions(
    pushNamedCallabck: Nav.pushNamed,
    popAndPushNamedCallabck: Nav.popAndPushNamed,
    pushReplacementNamedCallabck: Nav.pushReplacementNamed,
  );

  Future<T?> pushNamed<T extends Object?>(
      {BuildContext? context, Object? arguments}) {
    NavigationActions action = navigationActions;
    if (context == null) {
      action = navigationWithoutContext;
    }
    return action.pushNamed(context, fullName, arguments: arguments);
  }

  Future<T?> popAndPushNamed<T extends Object?, R extends Object?>(
      {BuildContext? context, R? result, Object? arguments}) {
    NavigationActions action = navigationActions;
    if (context == null) {
      action = navigationWithoutContext;
    }
    return action.popAndPushNamed(context, fullName,
        result: result, arguments: arguments);
  }

  Future<T?> pushReplacementNamed<T extends Object?, R extends Object?>(
      {BuildContext? context, R? result, Object? arguments}) {
    NavigationActions action = navigationActions;
    if (context == null) {
      action = navigationWithoutContext;
    }
    return action.pushReplacementNamed(context, fullName,
        result: result, arguments: arguments);
  }

  static final _reg = RegExp(r'\?(.*)');
  static final _regKV = RegExp(r'(.*?)=([^&]*)');

  NopRouteBuilder? onMatch(RouteSettings settings,
      {String? pathName, Map<String, dynamic>? query}) {
    if (pathName == null) {
      pathName = settings.name ?? '';
      if (_reg.hasMatch(pathName)) {
        pathName = pathName.replaceAll(_reg, '');
        final ms = _reg.allMatches(settings.name ?? '');
        for (var item in ms) {
          query ??= <String, dynamic>{};
          final entry = _regKV.allMatches(item[1]!);
          for (var kv in entry) {
            query[kv[1]!] = kv[2]!;
          }
        }
      }
    }
    if (!pathName.contains(fullName)) return null;
    if (pathName == fullName) {
      var args = settings.arguments ?? query ?? const {};
      return NopRouteBuilder(
          route: this,
          settings: settings.copyWith(name: pathName, arguments: args));
    }

    for (var child in children) {
      assert(child != this);
      final route = child.onMatch(settings, pathName: pathName, query: query);
      if (route != null) return route;
    }

    var args = settings.arguments ?? query ?? const {};
    return NopRouteBuilder(
        route: this,
        settings: settings.copyWith(name: pathName, arguments: args));
  }
}

class NopRouteBuilder {
  final NopRoute route;
  final RouteSettings settings;
  NopRouteBuilder({required this.route, required this.settings});

  Widget builder(BuildContext context) {
    return route.builder(context, settings.arguments);
  }

  MaterialPageRoute? get wrapMaterial {
    return MaterialPageRoute(builder: builder, settings: settings);
  }
}

class NavigationNativeActions extends NavigationActions {
  NavigationNativeActions({
    required this.pushNamedCallabck,
    required this.popAndPushNamedCallabck,
    required this.pushReplacementNamedCallabck,
  });
  final Future<T?> Function<T extends Object?>(
      BuildContext context, String name,
      {Object? arguments}) pushNamedCallabck;
  final Future<T?> Function<T extends Object?, R extends Object?>(
          BuildContext context, String name, {Object? arguments, R? result})
      popAndPushNamedCallabck;
  final Future<T?> Function<T extends Object?, R extends Object?>(
          BuildContext contxt, String name, {Object? arguments, R? result})
      pushReplacementNamedCallabck;
  @override
  Future<T?> pushNamed<T>(BuildContext? context, String name,
      {Object? arguments}) {
    return pushNamedCallabck(context!, name, arguments: arguments);
  }

  @override
  Future<T?> popAndPushNamed<T, R>(BuildContext? context, String name,
      {Object? arguments, R? result}) {
    return popAndPushNamedCallabck(context!, name,
        arguments: arguments, result: result);
  }

  @override
  Future<T?> pushReplacementNamed<T, R>(BuildContext? context, String name,
      {Object? arguments, R? result}) {
    return pushReplacementNamedCallabck(context!, name,
        arguments: arguments, result: result);
  }
}

class NavigationNavActions extends NavigationActions {
  NavigationNavActions({
    required this.pushNamedCallabck,
    required this.popAndPushNamedCallabck,
    required this.pushReplacementNamedCallabck,
  });
  final Future<T?> Function<T>(String name, {Object? arguments})
      pushNamedCallabck;
  final Future<T?> Function<T, R>(String name, {Object? arguments, R? result})
      popAndPushNamedCallabck;
  final Future<T?> Function<T, R>(String name, {Object? arguments, R? result})
      pushReplacementNamedCallabck;
  @override
  Future<T?> pushNamed<T>(BuildContext? context, String name,
      {Object? arguments}) {
    return pushNamedCallabck(name, arguments: arguments);
  }

  @override
  Future<T?> popAndPushNamed<T, R>(BuildContext? context, String name,
      {Object? arguments, R? result}) {
    return popAndPushNamedCallabck(name, arguments: arguments, result: result);
  }

  @override
  Future<T?> pushReplacementNamed<T, R>(BuildContext? context, String name,
      {Object? arguments, R? result}) {
    return pushReplacementNamedCallabck(name,
        arguments: arguments, result: result);
  }
}

abstract class NavigationActions {
  Future<T?> pushNamed<T>(BuildContext? context, String name,
      {Object? arguments});
  Future<T?> popAndPushNamed<T, R>(BuildContext? context, String name,
      {Object? arguments, R? result});
  Future<T?> pushReplacementNamed<T, R>(BuildContext? context, String name,
      {Object? arguments, R? result});
}
