import 'package:flutter/material.dart';

import 'dependences_mixin.dart';

class RouteDependences with GetTypePointers {
  RouteDependences(this._route, this._parent) {
    _init();
  }

  final RouteDependences? _parent;

  @override
  GetTypePointers? get parent => _parent;

  Route _route;
  Route get route => _route;
  set route(Route newRoute) {
    if (_route == newRoute) return;
    _route = newRoute;
    _init();
  }

  void _init() {
    final local = _route;
    _route.popped.whenComplete(() {
      if (local != _route) return;
      _dispose();
    });
  }

  void _dispose() {
    assert(isEmpty, '_pointers 不为空');
  }
}
