/// slex - a simple lexer
/// (c) 2023 by Andreas Schwenk <mailto:contact@compiler-construction.com>
/// License: GPL-3.0-or-later

enum LexerTokenType { del, ter, int, bigint, real, hex, str, id, end }

class LexerToken {
  String token = '';
  LexerTokenType type = LexerTokenType.ter;
  num value = 0;
  BigInt valueBigint = BigInt.from(0);
  String fileID = '';
  int row = 0;
  int col = 0;

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

  @override
  String toString() {
    var tk = token;
    tk = tk.replaceAll('\n', '\\n');
    tk = tk.replaceAll('\t', '\\t');
    var s = "$fileID:$row:$col:'$tk'(${type.name})";
    return s;
  }
}
