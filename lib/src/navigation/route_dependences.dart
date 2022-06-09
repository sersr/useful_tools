import 'package:flutter/material.dart';

import 'dependences_mixin.dart';

class RouteDependences with GetTypePointers {
  RouteDependences(this.route, this._parent);

  final RouteDependences? _parent;

  @override
  GetTypePointers? get parent => _parent;

  Route route;
}

class NopDependences with GetTypePointers {
  @override
  NopDependences? parent;
  NopDependences? child;

  NopDependences? get lastChild {
    return child?.lastChild ?? child;
  }

  NopDependences? get firstParent {
    return parent?.parent ?? parent;
  }

  void updateChild(NopDependences newChild) {
    assert(child == null);
    child?.parent = null;
    child = newChild;
    newChild.parent = this;
  }

  void removeChild() {
    parent?.child = child;
    child?.parent = parent;
    parent = null;
    child = null;
  }
}
