// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:utils/utils.dart';

void main() {
  test('list_key test', () {
    final o1 = Object();
    final o2 = Object();

    final left = [
      [1, o1, 3],
      o2
    ];
    final right = [
      [1, o1, 3],
      o2
    ];
    final l = ListKey(left);
    final r = ListKey(right);
    // 验证相等性，hashCode，确保在[Map]中一致
    expect(l == r, true);
    expect(l.hashCode, r.hashCode);
  });
}
