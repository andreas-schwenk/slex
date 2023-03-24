/// slex - a simple lexer
/// (c) 2023 by Andreas Schwenk <mailto:contact@compiler-construction.com>
/// License: GPL-3.0-or-later

import 'package:slex/slex.dart';
//import 'package:test/test.dart';

void main() {
  // TODO: migrate code from https://github.com/multila/multila-lexer/blob/main/test/lex_TESTS.dart

  var src = '''
Hello,
  world!
''';
  var lex = Lexer();
  lex.pushSource('', src);
  while (lex.isNotEnd()) {
    print(lex.getToken());
    lex.next();
  }

  /*group('A group of tests', () {
    final awesome = Awesome();

    setUp(() {
      // Additional setup goes here.
    });

    test('First Test', () {
      expect(awesome.isAwesome, isTrue);
    });
  });*/
}
