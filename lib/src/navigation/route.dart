import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:nop/nop.dart';
import 'package:useful_tools/useful_tools.dart';

class NopRouteActionEntry<T> with NopRouteAction<T> {
  NopRouteActionEntry({
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

mixin NopRouteAction<T> {
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

  static late final NavigationActions navigationActions =
      NavigationNativeActions(
    pushNamedCallabck: Navigator.pushNamed,
    popAndPushNamedCallabck: Navigator.popAndPushNamed,
    pushReplacementNamedCallabck: Navigator.pushReplacementNamed,
  );
  static late NavigationActions navigationWithoutContext = NavigationNavActions(
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
    var args = settings.arguments ?? query ?? const {};
    if (pathName == fullName) {
      return NopRouteBuilder(
          route: this,
          settings: settings.copyWith(name: pathName, arguments: args));
    }

    for (var child in children) {
      assert(child != this);
      final route = child.onMatch(settings, pathName: pathName, query: query);
      if (route != null) return route;
    }

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

class NopPageRoute<T> extends MaterialPageRoute<T> {
  NopPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) : super(
          builder: builder,
          settings: settings,
          maintainState: maintainState,
          fullscreenDialog: fullscreenDialog,
        );

  static final rootS = Expando();
  final currentRoute = <Type, dynamic>{};

  D? getType<D extends Object>() =>
      currentRoute[D] as D? ?? (currentRoute[D] = rootS[D] as D?);
  D? getCurrentType<D>() => currentRoute[D] as D?;

  void setType<D>(D value, {bool root = true}) {
    currentRoute[D] = value;
    if (root) {
      rootS[D] = true;
    }
  }
}

class NavObserver extends NavigatorObserver {
  OverlayState? get overlay => navigator?.overlay;

  RouteDependences? get currentDeps => _routes.isNotEmpty ? _routes.last : null;

  bool containsKey(Route key) =>
      _routes.any((element) => element._route == key);

  RouteDependences? getRoutes(Route key) {
    final it = _routes.reversed;
    for (var item in it) {
      if (item._route == key) return item;
    }
    return null;
  }

  final _routes = <RouteDependences>[];

  void didPopOrRemove(Route route, Route? previousRoute) {
    final current = route.isCurrent ? _routes.removeLast() : getRoutes(route);
    assert(current?._route == route &&
        (previousRoute == null ||
            getRoutes(previousRoute) == current?._parent));
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
    current?._setRoute(newRoute!);
    Log.w('replace: ${newRoute?.settings.name}  ${oldRoute.settings.name}');
  }
}

mixin GetTypePointers {
  final _pointers = HashMap<Type, NopListener>();
  NopListener? getParentType<T>({bool shared = true});
  bool get isGlobal => false;

  NopListener getType<T>({bool shared = true}) {
    var listener = _pointers[T];
    if (listener == null && (shared || isGlobal)) {
      listener = getParentType<T>(shared: shared);
    }

    if (listener != null) {
      return listener;
    }
    final data = Nav.get<T>()();
    if (data is NopLifeCycle) {
      data.init();
    }
    return _pointers[T] = NopListener(data, () => _pointers.remove(T));
  }
}

class RouteDependences with GetTypePointers {
  RouteDependences(this._route, this._parent) {
    _init();
  }

  Route _route;
  final RouteDependences? _parent;

  void _setRoute(Route newRoute) {
    if (_route == newRoute) return;
    _route = newRoute;
    _init();
  }

  Route get route => _route;

  void _init() {
    final local = _route;
    _route.popped.then((value) {
      if (local != _route) return;
      _dispose();
    });
  }

  void _dispose() {
    assert(_pointers.isEmpty, '_pointers 不为空');
  }

  @override
  NopListener? getParentType<T>({bool shared = true}) =>
      _parent?.getType<T>(shared: shared);
}

class NopListener {
  NopListener(this.data, this.onRemove);
  final dynamic data;
  final Set<Object> listener = {};
  late final isNopLife = data is NopLifeCycle;

  final void Function() onRemove;

  bool _secheduled = false;

  void remove(Object key) {
    listener.remove(key);
    if (listener.isEmpty && isNopLife) {
      if (_secheduled) return;
      scheduleMicrotask(() {
        _secheduled = false;
        if (listener.isEmpty) {
          onRemove();
          (data as NopLifeCycle).dispose();
        }
      });
      _secheduled = true;
    }
  }

  void add(Object key) {
    listener.add(key);
  }
}

typedef NopWidgetBuilder = Widget Function(BuildContext context, Widget? child);

class Nop extends StatefulWidget {
  const Nop({
    Key? key,
    this.child,
    this.builder,
    this.preRun,
    this.builders,
  })  : assert(child != null || builder != null),
        super(key: key);

  final Widget? child;
  final void Function(T? Function<T>() preInit)? preRun;
  final NopWidgetBuilder? builder;
  final List<NopWidgetBuilder>? builders;

  @override
  State<Nop> createState() => _NopState();

  static T of<T>(BuildContext context) {
    return maybyOf(context)!;
  }

  static T? maybyOf<T>(BuildContext context) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>();
    return nop?.state.getType<T>();
  }
}

mixin NopLifeCycle {
  void init();
  void dispose();
}

class _NopState extends State<Nop> {
  final _caches = HashMap<Type, NopListener>();

  T getType<T>({bool shared = true}) {
    var listener = _caches[T];
    if (listener == null) {
      listener = Nav.getType<T>(shared: shared);

      listener.add(this);
      _caches[T] = listener;
    }
    return listener.data;
  }

  @override
  void dispose() {
    for (var item in _caches.values) {
      item.remove(this);
    }
    _caches.clear();
    super.dispose();
  }

  @override
  void initState() {
    if (widget.preRun != null) {
      widget.preRun!(getType);
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Widget? child = widget.child;
    if (widget.builder != null) {
      child = widget.builder!(context, child);
    }
    final builders = widget.builders;
    if (builders != null && builders.isNotEmpty) {
      for (var build in builders) {
        child = build(context, child);
      }
    }
    return _NopScoop(child: child!, state: this);
  }
}

class _NopScoop extends InheritedWidget {
  const _NopScoop({
    Key? key,
    required Widget child,
    required this.state,
  }) : super(key: key, child: child);
  final _NopState state;

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }
}
