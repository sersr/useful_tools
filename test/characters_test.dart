import 'package:flutter_test/flutter_test.dart';
import 'package:characters/characters.dart';

void main() {
  test('characters', () {
    const str = "🤣❤️😁";
    final pc = str.characters;
    expect(str.length, 6);
    expect(pc.length, 3);
  });
}
