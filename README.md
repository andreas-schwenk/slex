`slex` is a simple lexer (also called scanner, or lexical analyzer).

## Features

- Indentation based scanning (similar to Python)
- C like scanning
- scanning of nested source files.
- configuration options: single line comments, multiline comments, enable/disable emitting of newline / hex numbers / integers / real numbers / big integers / single quotes / double quotes / indentation / backslash line breaks for indented code / umlaute / underscores in identifiers

## Getting started

Add the package into your package's `pubspec.yaml` file:

```yaml
dependencies:
  slex: ^0.9.1
```

Make sure to use the latest version!

## Usage

The example writes a parser for for following formal grammar specified in EBNF:

```
program = { assignment };
assignment = IDENTIFIER ":=" add ";";
add = mul { "+" mul };
mul = unary { "*" unary };
unary = IDENTIFIER | INTEGER | "(" add ")";
```

A valid example program is for example:

```
# comment
x := 3 * (4+5);
```

Implementation:

```dart
import 'package:slex/slex.dart';

void main() {
  var src = '# comment\nx := 3 * (4+5);\n';
  parse(src);
}

void parse(String src) {
  // create a new lexer instance
  var lexer = Lexer();

  // configuration
  lexer.configureSingleLineComments('#');

  // must add operators with two or more chars
  lexer.setTerminals([':=']);

  // source code to be parsed
  lexer.pushSource('mySource', src);
  parseProgram(lexer);
}

//G program = { assignment };
void parseProgram(Lexer lexer) {
  while (lexer.isNotEnd()) {
    parseAssignment(lexer);
  }
}

//G assignment = ID ":=" add ";";
void parseAssignment(Lexer lexer) {
  var id = lexer.identifier();
  print(id);
  lexer.terminal(':=');
  parseAdd(lexer);
  lexer.terminal(';');
  print('assign');
}

//G add = mul { "+" mul };
void parseAdd(Lexer lexer) {
  parseMul(lexer);
  while (lexer.isTerminal('+')) {
    lexer.next();
    parseMul(lexer);
    print('add');
  }
}

//G mul = unary { "*" unary };
void parseMul(Lexer lexer) {
  parseUnary(lexer);
  while (lexer.isTerminal('*')) {
    lexer.next();
    parseUnary(lexer);
    print('mul');
  }
}

//G unary = ID | INT | "(" add ")";
void parseUnary(Lexer lexer) {
  if (lexer.isIdentifier()) {
    var id = lexer.identifier();
    print(id);
  } else if (lexer.isInteger()) {
    var value = lexer.integer();
    print(value);
  } else if (lexer.isTerminal('(')) {
    lexer.next();
    parseAdd(lexer);
    lexer.terminal(')');
  } else {
    lexer.error('expected ID or INT');
  }
}
```
