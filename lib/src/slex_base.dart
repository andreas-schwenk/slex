/// slex - a simple lexer
/// (c) 2023 by Andreas Schwenk <mailto:contact@compiler-construction.com>
/// License: GPL-3.0-or-later

import 'lang.dart';
import 'state.dart';
import 'token.dart';

class LexerFile {
  LexerState? stateBackup;
  LexerToken? tokenBackup;
  String id = '';
  String sourceCode = '';
}

class LexerBackup {
  LexerState state;
  LexerToken token;

  LexerBackup(this.state, this.token);
}

class Lexer {
  final Set<String> _terminals = {};

  final List<LexerFile> _fileStack = [];
  LexerToken _token = LexerToken();
  LexerToken? _lastToken;
  LexerState _state = LexerState();

  String _singleLineCommentStart = '//';
  String _multiLineCommentStart = '/*';
  String _multilineCommentEnd = '*/';
  bool _emitNewline = false;
  bool _emitHex = true;
  bool _emitInt = true;
  bool _emitReal = true;
  bool _emitBigint = true;
  bool _emitSingleQuotes = true;
  bool _emitDoubleQuotes = true;
  bool _emitIndentation = false;
  String _lexerFilePositionPrefix = '!>';
  bool _allowBackslashLineBreaks = false;

  bool _allowUmlautInID = false;
  bool _allowHyphenInID = false;
  bool _allowUnderscoreInID = true;

  final List<LexerToken> _putTrailingSemicolon = [];
  List<String> _multicharDelimiters = [];

  void configureSingleLineComments([pattern = '//']) {
    _singleLineCommentStart = pattern;
  }

  void configureMultiLineComments([startPattern = '/*', endPattern = '*/']) {
    _multiLineCommentStart = startPattern;
    _multilineCommentEnd = endPattern;
  }

  void configureLexerFilePositionPrefix([pattern = '!>']) {
    _lexerFilePositionPrefix = pattern;
  }

  enableEmitNewlines(bool value) {
    _emitNewline = value;
  }

  enableEmitHex(bool value) {
    _emitHex = value;
  }

  enableEmitInt(bool value) {
    _emitInt = value;
  }

  enableEmitReal(bool value) {
    _emitReal = value;
  }

  enableEmitBigint(bool value) {
    _emitBigint = value;
  }

  enableEmitSingleQuotes(bool value) {
    _emitSingleQuotes = value;
  }

  enableEmitDoubleQuotes(bool value) {
    _emitDoubleQuotes = value;
  }

  enableEmitIndentation(bool value) {
    _emitIndentation = value;
  }

  enableBackslashLineBreaks(bool value) {
    _allowBackslashLineBreaks = value;
  }

  enableUmlautInID(bool value) {
    _allowUmlautInID = value;
  }

  enableHyphenInID(bool value) {
    _allowHyphenInID = value;
  }

  enableUnderscoreInID(bool value) {
    _allowUnderscoreInID = value;
  }

  bool isEnd() {
    return _token.type == LexerTokenType.end;
  }

  bool isNotEnd() {
    return _token.type != LexerTokenType.end;
  }

  end() {
    if (_token.type == LexerTokenType.end) {
      next();
    } else {
      throw Exception(
        '${_errorPosition()}${getStr(LanguageText.expected)} END',
      );
    }
  }

  bool isIdentifier() {
    return _token.type == LexerTokenType.id;
  }

  String identifier() {
    var res = '';
    if (_token.type == LexerTokenType.id) {
      res = _token.token;
      next();
    } else {
      throw Exception(
        '${_errorPosition()}${getStr(LanguageText.expected)} ID',
      );
    }
    return res;
  }

  /// Weather next token is a lower case identifier.
  bool isLowercaseIdentifier() {
    return (_token.type == LexerTokenType.id &&
        _token.token == _token.token.toLowerCase());
  }

  /// Get next token as lower case identifier, or throw an error, if not.
  String lowercaseIdentifier() {
    var res = '';
    if (_token.type == LexerTokenType.id &&
        _token.token == _token.token.toLowerCase()) {
      res = _token.token;
      next();
    } else {
      throw Exception(
        '${_errorPosition()}${getStr(LanguageText.expected)} LowerCaseID',
      );
    }
    return res;
  }

  /// Weather next token is an upper case identifier.
  bool isUppercaseIdentifier() {
    return (_token.type == LexerTokenType.id &&
        _token.token == _token.token.toUpperCase());
  }

  /// Get next token as upper case identifier, or throw an error, if not.
  String uppercaseIdentifier() {
    var res = '';
    if (_token.type == LexerTokenType.id &&
        _token.token == _token.token.toUpperCase()) {
      res = _token.token;
      next();
    } else {
      throw Exception(
        '${_errorPosition()}${getStr(LanguageText.expected)} UpperCaseID',
      );
    }
    return res;
  }

  bool isInteger() {
    return _token.type == LexerTokenType.int;
  }

  int integer() {
    int res = 0;
    if (_token.type == LexerTokenType.int) {
      res = _token.value as int;
      next();
    } else {
      throw Exception(
        '${_errorPosition()}${getStr(LanguageText.expected)} INT',
      );
    }
    return res;
  }

  bool isBigInteger() {
    return _token.type == LexerTokenType.bigint;
  }

  BigInt bigInteger() {
    var res = BigInt.from(0);
    if (_token.type == LexerTokenType.bigint) {
      res = _token.valueBigint;
      next();
    } else {
      throw Exception(
        '${_errorPosition()}${getStr(LanguageText.expected)} BIGINT',
      );
    }
    return res;
  }

  bool isRealNumber() {
    return _token.type == LexerTokenType.real;
  }

  num realNumber() {
    num res = 0.0;
    if (_token.type == LexerTokenType.real) {
      res = _token.value;
      next();
    } else {
      throw Exception(
        '${_errorPosition()}${getStr(LanguageText.expected)} REAL',
      );
    }
    return res;
  }

  bool isHexadecimal() {
    return _token.type == LexerTokenType.hex;
  }

  String hexadecimal() {
    var res = '';
    if (_token.type == LexerTokenType.hex) {
      res = _token.token;
      next();
    } else {
      throw Exception(
        '${_errorPosition()}${getStr(LanguageText.expected)} HEX',
      );
    }
    return res;
  }

  bool isString() {
    return _token.type == LexerTokenType.str;
  }

  String string() {
    var res = '';
    if (_token.type == LexerTokenType.str) {
      res = _token.token;
      next();
    } else {
      throw Exception(
        '${_errorPosition()}${getStr(LanguageText.expected)} STR',
      );
    }
    return res;
  }

  bool isTerminal(String t) {
    return ((_token.type == LexerTokenType.del && _token.token == t) ||
        (_token.type == LexerTokenType.id && _token.token == t));
  }

  bool isNotTerminal(String t) {
    return isTerminal(t) == false && _token.type != LexerTokenType.end;
  }

  terminal(String t) {
    if ((_token.type == LexerTokenType.del && _token.token == t) ||
        (_token.type == LexerTokenType.id && _token.token == t)) {
      next();
    } else {
      throw Exception(
        '${_errorPosition()}${getStr(LanguageText.expected)} "$t"',
      );
    }
  }

  // end of statement
  bool isEndOfStatement() {
    // TODO: ';' OR newline
    // TODO: configure ';'
    return _token.token == ';';
  }

  // end of statement
  endOfStatement() {
    // TODO: ';' OR newline
    if (_token.token == ';') {
      next();
    } else {
      throw Exception(
        '${_errorPosition()}${getStr(LanguageText.expected)} ";"',
      );
    }
  }

  bool isIndentation() {
    return _token.type == LexerTokenType.del && _token.token == '\t+';
  }

  bool isNotIndentation() {
    return !(_token.type == LexerTokenType.del && _token.token == '\t+');
  }

  indentation() {
    if (_token.type == LexerTokenType.del && _token.token == '\t+') {
      next();
    } else {
      throw Exception(
        '${_errorPosition()}${getStr(LanguageText.expected)} INDENT',
      );
    }
  }

  bool isOutdentation() {
    return _token.type == LexerTokenType.del && _token.token == '\t-';
  }

  bool isNotOutdentation() {
    if (_token.type == LexerTokenType.end) {
      return false; // TODO: must do this for ALL "not" methods
    }
    return !(_token.type == LexerTokenType.del && _token.token == '\t-');
  }

  outdentation() {
    if (_token.type == LexerTokenType.del && _token.token == '\t-') {
      next();
    } else {
      throw Exception(
        '${_errorPosition()}${getStr(LanguageText.expected)} outdentation',
      );
    }
  }

  bool isNewline() {
    return (isOutdentation() ||
        (_token.type == LexerTokenType.del && _token.token == '\n'));
  }

  bool isNotNewline() {
    return (!isOutdentation() &&
        !(_token.type == LexerTokenType.del && _token.token == '\n'));
  }

  newline() {
    if (isOutdentation()) return;
    if (_token.type == LexerTokenType.del && _token.token == '\n') {
      next();
    } else {
      throw Exception(
        '${_errorPosition()}${getStr(LanguageText.expected)} NEWLINE',
      );
    }
  }

  error(String s, [LexerToken? tk]) {
    throw Exception(_errorPosition(tk) + s);
  }

  errorExpected(List<String> terminals) {
    var s = '${getStr(LanguageText.expectedOneOf)} ';
    for (var i = 0; i < terminals.length; i++) {
      if (i > 0) s += ', ';
      s += terminals[i];
    }
    s += '.';
    error(s);
  }

  errorConditionNotBool() {
    error(getStr(LanguageText.conditionNotBoolean));
  }

  errorUnknownSymbol(String symId) {
    error('${getStr(LanguageText.unknownSymbol)} $symId');
  }

  errorNotAFunction() {
    error(getStr(LanguageText.symbolIsNotAFunction));
  }

  errorTypesInBinaryOperation(String op, String t1, String t2) {
    error(
      getStr(LanguageText.binaryOperatorIncompatibleTypes)
          .replaceAll('\$OP', op)
          .replaceAll('\$T1', t1)
          .replaceAll('\$T2', t2),
    );
  }

  String _errorPosition([LexerToken? tk]) {
    tk ??= _token;
    return '${tk.fileID}:${tk.row.toString()}:${tk.col.toString()}: ';
  }

  addPutTrailingSemicolon(LexerTokenType type, [terminal = '']) {
    var tk = LexerToken();
    tk.type = type;
    tk.token = terminal;
    _putTrailingSemicolon.add(tk);
  }

  /// Sets a set of terminals consisting of identifiers and delimiters.
  setTerminals(List<String> terminals) {
    _terminals.clear();
    _multicharDelimiters = [];
    for (var ter in terminals) {
      if (ter.isEmpty) {
        continue;
      }
      if ((ter.codeUnitAt(0) >= 'A'.codeUnitAt(0) &&
              ter.codeUnitAt(0) <= 'Z'.codeUnitAt(0)) ||
          (ter.codeUnitAt(0) >= 'a'.codeUnitAt(0) &&
              ter.codeUnitAt(0) <= 'z'.codeUnitAt(0)) ||
          ter[0] == '_') {
        _terminals.add(ter);
      } else {
        _multicharDelimiters.add(ter);
      }
    }
    // must sort delimiters by descending length (e.g. "==" must NOT be tokenized to "=", "=")
    _multicharDelimiters.sort((a, b) => b.length - a.length);
  }

  List<String> getTerminals() {
    return _terminals.toList();
  }

  List<String> getMulticharDelimiters() {
    return _multicharDelimiters;
  }

  LexerToken getToken() {
    return _token;
  }

  next() {
    _lastToken = _token;
    var src = _fileStack.last.sourceCode;
    var fileId = _fileStack.last.id;
    var s = _state;
    if (s.stack.isNotEmpty) {
      _token = s.stack[0];
      s.stack.removeAt(0); // remove first element
      return;
    }
    _token = LexerToken();
    _token.fileID = fileId;
    // white spaces and comments
    s.indent = -1; // indents are disallowed, until a newline-character is read
    var outputLinefeed = false; // token == "\n"?
    for (;;) {
      // newline
      if (s.i < s.n && src[s.i] == '\n') {
        s.indent = 0;
        outputLinefeed = _nextTokenLinefeed(s);
      }
      // space
      else if (s.i < s.n && src[s.i] == ' ') {
        s.i++;
        s.col++;
        if (s.indent >= 0) s.indent++;
      }
      // tab
      else if (s.i < s.n && src[s.i] == '\t') {
        s.i++;
        s.col += 4;
        if (s.indent >= 0) s.indent += 4;
      }
      // backslash line break -> consume all following whitespace
      else if (_allowBackslashLineBreaks && s.i < s.n && src[s.i] == '\\') {
        s.i++;
        while (s.i < s.n) {
          if (src[s.i] == ' ') {
            s.col++;
          } else if (src[s.i] == '\t') {
            s.col += 4;
          } else if (src[s.i] == '\n') {
            s.row++;
            s.col = 1;
          } else {
            break;
          }
          s.i++;
        }
      }
      // single line comment (slc)
      else if (_singleLineCommentStart.isNotEmpty &&
          _isNext(_singleLineCommentStart)) {
        if (_emitIndentation && s.indent >= 0) break;
        var n = _singleLineCommentStart.length;
        s.i += n;
        s.col += n;
        while (s.i < s.n && src[s.i] != '\n') {
          s.i++;
          s.col++;
        }
        if (s.i < s.n && src[s.i] == '\n') {
          //if (nextTokenLinefeed(s)) return;
          outputLinefeed = _nextTokenLinefeed(s);
        }
        s.indent = 0;
      }
      // multiline comment (mlc)
      else if (_multiLineCommentStart.isNotEmpty &&
          _isNext(_multiLineCommentStart)) {
        if (_emitIndentation && s.indent >= 0) break;
        var n = _multiLineCommentStart.length;
        s.i += n;
        s.col += n;
        while (s.i < s.n && !_isNext(_multilineCommentEnd)) {
          if (src[s.i] == '\n') {
            // TODO: nextTokenLinefeed(s)!!
            s.row++;
            s.col = 1;
            s.indent = 0;
          } else {
            s.col++;
          }
          s.i++;
        }
        n = _multilineCommentEnd.length;
        s.i += n;
        s.col += n;
      }
      // FILEPOS = PREFIX ":" STR ":" INT ":" "INT";
      else if (_lexerFilePositionPrefix.isNotEmpty &&
          src.substring(s.i).startsWith(_lexerFilePositionPrefix)) {
        s.i += _lexerFilePositionPrefix.length;
        // path
        var path = '';
        while (s.i < s.n && src[s.i] != ':') {
          path += src[s.i];
          s.i++;
        }
        s.i++;
        _fileStack.last.id = path;
        _token.fileID = path;
        // row
        var rowStr = '';
        while (s.i < s.n && src[s.i] != ':') {
          rowStr += src[s.i];
          s.i++;
        }
        s.i++;
        _token.row = int.parse(rowStr);
        // column
        var colStr = '';
        while (s.i < s.n && src[s.i] != ':') {
          colStr += src[s.i];
          s.i++;
        }
        s.i++;
        _token.col = int.parse(colStr);
      } else {
        break;
      }
    }
    // indentation
    if (_emitIndentation && s.indent >= 0) {
      var diff = s.indent - s.lastIndent;
      s.lastIndent = s.indent;
      if (diff != 0) {
        if (diff % 4 == 0) {
          var isPlus = diff > 0;
          var n = (diff.abs() / 4).floor();
          for (var k = 0; k < n; k++) {
            _token = LexerToken();
            _token.fileID = fileId;
            _token.row = s.row;
            if (isPlus) {
              _token.col = s.col - diff + 4 * k;
            } else {
              _token.col = s.col;
            }
            _token.type = LexerTokenType.del;
            _token.token = isPlus ? '\t+' : '\t-';
            s.stack.add(_token);
          }
          _token = s.stack[0];
          s.stack.removeAt(0); // remove first
          return;
        } else {
          _token.row = s.row;
          _token.col = s.col - diff;
          _token.type = LexerTokenType.ter;
          _token.token = '\terr';
          return;
        }
      }
    }
    // in case that _parseNewLineEnabled == true, we must stop here
    // if "\n" was actually read
    if (outputLinefeed) return;
    // backup current state
    var sBak = s.copy();
    _token.row = s.row;
    _token.col = s.col;
    s.indent = 0;
    // end?
    if (s.i >= s.n) {
      _token.token = '\$end';
      _token.type = LexerTokenType.end;
      return;
    }
    // ID = ( "A".."Z" | "a".."z" | underscore&&"_" | hyphen&&"-" | umlaut&&("ä".."ß") )
    //   { "A".."Z" | "a".."z" | "0".."9" | underscore&&"_" | hyphen&&"-" | umlaut&&("ä".."ß") };
    _token.type = LexerTokenType.id;
    _token.token = '';
    if (s.i < s.n &&
        ((src.codeUnitAt(s.i) >= 'A'.codeUnitAt(0) &&
                src.codeUnitAt(s.i) <= 'Z'.codeUnitAt(0)) ||
            (src.codeUnitAt(s.i) >= 'a'.codeUnitAt(0) &&
                src.codeUnitAt(s.i) <= 'z'.codeUnitAt(0)) ||
            (_allowUnderscoreInID && src[s.i] == '_') ||
            (_allowHyphenInID && src[s.i] == '-') ||
            (_allowUmlautInID && 'ÄÖÜäöüß'.contains(src[s.i])))) {
      _token.token += src[s.i];
      s.i++;
      s.col++;
      while (s.i < s.n &&
          ((src.codeUnitAt(s.i) >= 'A'.codeUnitAt(0) &&
                  src.codeUnitAt(s.i) <= 'Z'.codeUnitAt(0)) ||
              (src.codeUnitAt(s.i) >= 'a'.codeUnitAt(0) &&
                  src.codeUnitAt(s.i) <= 'z'.codeUnitAt(0)) ||
              (src.codeUnitAt(s.i) >= '0'.codeUnitAt(0) &&
                  src.codeUnitAt(s.i) <= '9'.codeUnitAt(0)) ||
              (_allowUnderscoreInID && src[s.i] == '_') ||
              (_allowHyphenInID && src[s.i] == '-') ||
              (_allowUmlautInID && 'ÄÖÜäöüß'.contains(src[s.i])))) {
        _token.token += src[s.i];
        s.i++;
        s.col++;
      }
    }
    if (_token.token.isNotEmpty) {
      if (_terminals.contains(_token.token)) _token.type = LexerTokenType.ter;
      _state = s;
      return;
    }
    // STR = '"' { any except '"' and '\n' } '"'
    s = sBak.copy();
    if (_emitDoubleQuotes) {
      _token.type = LexerTokenType.str;
      if (s.i < s.n && src[s.i] == '"') {
        _token.token = '';
        s.i++;
        s.col++;
        while (s.i < s.n && src[s.i] != '"' && src[s.i] != '\n') {
          _token.token += src[s.i];
          s.i++;
          s.col++;
        }
        if (s.i < s.n && src[s.i] == '"') {
          s.i++;
          s.col++;
          _state = s;
          return;
        }
      }
    }
    // STR = '\'' { any except '\'' and '\n' } '\''
    s = sBak.copy();
    if (_emitSingleQuotes) {
      _token.type = LexerTokenType.str;
      if (s.i < s.n && src[s.i] == "'") {
        _token.token = '';
        s.i++;
        s.col++;
        while (s.i < s.n && src[s.i] != "'" && src[s.i] != '\n') {
          _token.token += src[s.i];
          s.i++;
          s.col++;
        }
        if (s.i < s.n && src[s.i] == "'") {
          s.i++;
          s.col++;
          _state = s;
          return;
        }
      }
    }
    // HEX = "0" "x" { "0".."9" | "A".."F" | "a".."f" }+;
    s = sBak.copy();
    if (_emitHex) {
      _token.type = LexerTokenType.hex;
      _token.token = '';
      if (s.i < s.n && src[s.i] == '0') {
        s.i++;
        s.col++;
        if (s.i < s.n && src[s.i] == 'x') {
          s.i++;
          s.col++;
          var k = 0;
          while (s.i < s.n &&
              ((src.codeUnitAt(s.i) >= '0'.codeUnitAt(0) &&
                      src.codeUnitAt(s.i) <= '9'.codeUnitAt(0)) ||
                  (src.codeUnitAt(s.i) >= 'A'.codeUnitAt(0) &&
                      src.codeUnitAt(s.i) <= 'F'.codeUnitAt(0)) ||
                  (src.codeUnitAt(s.i) >= 'a'.codeUnitAt(0) &&
                      src.codeUnitAt(s.i) <= 'f'.codeUnitAt(0)))) {
            _token.token += src[s.i];
            s.i++;
            s.col++;
            k++;
          }
          if (k > 0) {
            _token.value = int.parse(_token.token, radix: 16);
            _token.token = '0x${_token.token}';
            _token.valueBigint = BigInt.parse(_token.token);
            _state = s;
            return;
          }
        }
      }
    }
    // INT|BIGINT|REAL = "0" | "1".."9" { "0".."9" } [ "." { "0".."9" } ];
    s = sBak.copy();
    if (_emitInt) {
      _token.type = LexerTokenType.int;
      _token.token = '';
      if (s.i < s.n && src[s.i] == '0') {
        _token.token = '0';
        s.i++;
        s.col++;
      } else if (s.i < s.n &&
          src.codeUnitAt(s.i) >= '1'.codeUnitAt(0) &&
          src.codeUnitAt(s.i) <= '9'.codeUnitAt(0)) {
        _token.token = src[s.i];
        s.i++;
        s.col++;
        while (s.i < s.n &&
            src.codeUnitAt(s.i) >= '0'.codeUnitAt(0) &&
            src.codeUnitAt(s.i) <= '9'.codeUnitAt(0)) {
          _token.token += src[s.i];
          s.i++;
          s.col++;
        }
      }
      if (_token.token.isNotEmpty &&
          _emitBigint &&
          s.i < s.n &&
          src[s.i] == 'n') {
        s.i++;
        s.col++;
        _token.type = LexerTokenType.bigint;
      } else if (_token.token.isNotEmpty &&
          _emitReal &&
          s.i < s.n &&
          src[s.i] == '.') {
        _token.type = LexerTokenType.real;
        _token.token += '.';
        s.i++;
        s.col++;
        while (s.i < s.n &&
            src.codeUnitAt(s.i) >= '0'.codeUnitAt(0) &&
            src.codeUnitAt(s.i) <= '9'.codeUnitAt(0)) {
          _token.token += src[s.i];
          s.i++;
          s.col++;
        }
      }
      if (_token.token.isNotEmpty) {
        if (_token.type == LexerTokenType.int) {
          _token.value = int.parse(_token.token);
        } else if (_token.type == LexerTokenType.bigint) {
          _token.valueBigint = BigInt.parse(_token.token);
        } else {
          _token.value = num.parse(_token.token);
        }
        _state = s;
        return;
      }
    }
    // DEL = /* element of _multichar_delimiters */;
    _token.type = LexerTokenType.del;
    _token.token = '';
    for (var k = 0; k < _multicharDelimiters.length; k++) {
      var d = _multicharDelimiters[k];
      var match = true;
      s = sBak.copy();
      for (var l = 0; l < d.length; l++) {
        var ch = d[l];
        if (s.i < s.n && src[s.i] == ch) {
          s.i++;
          s.col++;
        } else {
          match = false;
          break;
        }
      }
      if (match) {
        _state = s;
        _token.token = d;
        return;
      }
    }
    // unexpected
    s = sBak.copy();
    _token.type = LexerTokenType.del;
    _token.token = '';
    if (s.i < s.n) {
      _token.token = src[s.i];
      s.i++;
      s.col++;
      _state = s;
    }
  }

  bool _nextTokenLinefeed(LexerState s) {
    var insertedSemicolon = false;
    if (_emitNewline) {
      _token.row = s.row;
      _token.col = s.col;
      _token.token = '\n';
      _token.type = LexerTokenType.del;
    } else if (_putTrailingSemicolon.isNotEmpty) {
      var match = false;
      for (var i = 0; i < _putTrailingSemicolon.length; i++) {
        var pts = _putTrailingSemicolon[i];
        if (pts.type == _lastToken?.type) {
          if (pts.type == LexerTokenType.del) {
            match = pts.token == _lastToken?.token;
          } else {
            match = true;
          }
          if (match) break;
        }
      }
      if (match) {
        insertedSemicolon = true;
        _token.row = s.row;
        _token.col = s.col;
        _token.token = ';';
        _token.type = LexerTokenType.del;
      }
    }
    s.row++;
    s.col = 1;
    s.indent = 0;
    s.i++;
    return _emitNewline || insertedSemicolon;
  }

  bool _isNext(String str) {
    var src = _fileStack.last.sourceCode;
    var s = _state;
    var n = str.length;
    if (s.i + n >= s.n) return false;
    for (var k = 0; k < n; k++) {
      var ch = str[k];
      if (src[s.i + k] != ch) return false;
    }
    return true;
  }

  pushSource(String id, String src, [int initialRowIdx = 1]) {
    if (_fileStack.isNotEmpty) {
      _fileStack.last.stateBackup = _state.copy();
      _fileStack.last.tokenBackup = _token.copy();
    }
    var f = LexerFile();
    f.id = id;
    f.sourceCode = src;
    _fileStack.add(f);
    _state = LexerState();
    _state.row = initialRowIdx;
    _state.n = src.length;
    next();
  }

  popSource() {
    _fileStack.removeLast();
    if (_fileStack.isNotEmpty) {
      _state = _fileStack.last.stateBackup as LexerState;
      _token = _fileStack.last.tokenBackup as LexerToken;
    }
  }

  LexerBackup backupState() {
    return LexerBackup(_state.copy(), _token.copy());
  }

  void replayState(LexerBackup backup) {
    _state = backup.state;
    _token = backup.token;
  }
}
