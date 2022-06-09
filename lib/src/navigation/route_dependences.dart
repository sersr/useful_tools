import 'dependences_mixin.dart';

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

  NopDependences? get lastChildOrSelf {
    return lastChild ?? this;
  }

  NopDependences? get firstParentOrSelf {
    return firstParent ?? this;
  }

  void updateChild(NopDependences newChild) {
    assert(child == null || child!.parent == this);
    newChild.child = child?.child;
    child?._remove();
    newChild.parent = this;
    child = newChild;
  }

  void removeCurrent() {
    parent?.child = child;
    child?.parent = parent;
    _remove();
  }

  void _remove() {
    parent = null;
    child = null;
  }
}
