/// slex - a simple lexer
/// (c) 2023 by Andreas Schwenk <mailto:contact@compiler-construction.com>
/// License: GPL-3.0-or-later

import 'token.dart';

/// Describes the state of the lexer.
class LexerState {
  /// The current character index.
  int i = 0;

  /// The number of characters.
  int n = -1;

  /// The current row.
  int row = 1;

  /// The current column.
  int col = 1;

  /// The current indentation.
  int indent = 0;

  /// The last indentation.
  int lastIndent = 0;

  /// The tokens that must be put in subsequent next()-calls.
  List<LexerToken> stack = [];

  /// Clones the object.
  LexerState copy() {
    var bak = LexerState();
    bak.i = i;
    bak.n = n;
    bak.row = row;
    bak.col = col;
    bak.indent = indent;
    bak.lastIndent = lastIndent;
    for (var i = 0; i < stack.length; i++) {
      bak.stack.add(stack[i].copy());
    }
    return bak;
  }
}
