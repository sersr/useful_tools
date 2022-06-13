import 'dependences_mixin.dart';

class NopDependences with GetTypePointers {
  NopDependences({this.debugName});
  final String? debugName;
  @override
  NopDependences? parent;
  @override
  NopDependences? child;

  NopDependences? get lastChild {
    NopDependences? last = child;
    while (last != null) {
      final child = last.child;
      if (child == null) break;
      last = child;
    }

    return last;
  }

  bool get isFirst => parent == null;
  bool get isLast => child == null;

  NopDependences? get firstParent {
    NopDependences? first = parent;
    while (first != null) {
      final parent = first.parent;
      if (parent == null) break;
      first = parent;
    }
    return first;
  }

  NopDependences get lastChildOrSelf {
    return lastChild ?? this;
  }

  NopDependences get firstParentOrSelf {
    return firstParent ?? this;
  }

  void updateChild(NopDependences newChild) {
    assert(child == null || child!.parent == this);
    newChild.child = child?.child;
    newChild.child?.parent = newChild;
    child?._remove();
    newChild.parent = this;
    child = newChild;
  }

  void insertChild(NopDependences newChild) {
    newChild.child = child;
    child?.parent = newChild;
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

  @override
  String toString() {
    return 'NopDependences#${debugName ?? hashCode}';
  }
}
