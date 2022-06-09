import 'package:flutter_test/flutter_test.dart';
import 'package:nop/nop.dart';
import 'package:useful_tools/useful_tools.dart';

void main() {
  test('nop dependences test', () {
    final first = create('first');
    final second = create('second');
    final third = create('third');
    first.updateChild(second);
    second.updateChild(third);
    forEach(first);
    final four = create('four');
    first.updateChild(four);
    forEach(first);

    expect(second.parent == null && second.child == null, true);
  });
  test('nop dependences insert', () {
    final first = create('first');
    final second = create('second');
    final third = create('third');
    first.insertChild(second);
    second.insertChild(third);
    forEach(first);
    final four = create('four');
    first.insertChild(four);
    forEach(first);

    second.removeCurrent();
    forEach(first);
  });
}

void forEach(NopDependences root) {
  NopDependences? child = root;
  Log.i('_'.padLeft(50, '_'));
  while (child != null) {
    Log.i('$child parent: ${child.parent}');
    child = child.child;
  }
}

NopDependences create(String name) {
  return NopDependences(debugName: name);
}
