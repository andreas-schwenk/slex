/// slex - a simple lexer
/// (c) 2023 by Andreas Schwenk <mailto:contact@compiler-construction.com>
/// License: GPL-3.0-or-later

/// The token type.
enum LexerTokenType { del, ter, int, bigint, real, hex, str, id, end }

/// The token.
class LexerToken {
  /// The tokens string.
  String token = '';

  /// The tokens type.
  LexerTokenType type = LexerTokenType.ter;

  /// The tokens numerical value (if applicable).
  num value = 0;

  /// The tokens big integer value (if applicable).
  BigInt valueBigint = BigInt.from(0);

  /// The tokens file identifier.
  String fileID = '';

  /// The tokens row index in the input file.
  int row = 0;

  /// The tokens column index in the input file.
  int col = 0;

  /// Compares the object by a given token [tk].
  bool compare(LexerToken tk) {
    if (token != tk.token) return false;
    if (type != tk.type) return false;
    if (value != tk.value) return false;
    if (valueBigint != tk.valueBigint) return false;
    if (fileID != tk.fileID) return false;
    if (row != tk.row) return false;
    if (col != tk.col) return false;
    return true;
  }

  // Clones the object.
  LexerToken copy() {
    var bak = LexerToken();
    bak.token = token;
    bak.type = type;
    bak.value = value;
    bak.fileID = fileID;
    bak.row = row;
    bak.col = col;
    return bak;
  }

  // Stringifies the object.
  @override
  String toString() {
    var tk = token;
    tk = tk.replaceAll('\n', '\\n');
    tk = tk.replaceAll('\t', '\\t');
    var s = "$fileID:$row:$col:'$tk'(${type.name})";
    return s;
  }
}
