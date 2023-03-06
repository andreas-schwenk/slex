/// slex - a simple lexer
/// (c) 2023 by Andreas Schwenk <mailto:contact@compiler-construction.com>
/// License: GPL-3.0-or-later

import 'lang.dart';
import 'state.dart';
import 'token.dart';

/// An input file.
class LexerFile {
  LexerState? stateBackup;
  LexerToken? tokenBackup;

  /// The identifier of the file.
  String id = '';

  /// The source code to be scanned.
  String sourceCode = '';
}

/// A backup of the current lexer state.
class LexerBackup {
  /// The state.
  LexerState state;

  /// The token.
  LexerToken token;

  LexerBackup(this.state, this.token);
}

/// Main class of slex package.
class Lexer {
  /// The set of terminals.
  final Set<String> _terminals = {};

  /// The file stack. In case of imports/includes, a new file is pushed on it.
  final List<LexerFile> _fileStack = [];

  /// The current token.
  LexerToken _token = LexerToken();

  /// The last token.
  LexerToken? _lastToken;

  /// The current state of the lexer (current position, row, column, ...).
  LexerState _state = LexerState();

  /// The prefix of a single line comment.
  String _singleLineCommentStart = '//';

  /// The prefix of a multiple line comment.
  String _multiLineCommentStart = '/*';

  /// The postfix of a multiple line comment.
  String _multilineCommentEnd = '*/';

  /// Whether new line ("\n") is emitted as token.
  bool _emitNewline = false;

  /// Whether a hexadecimal number (e.g. "0xAFFE") is emitted as token.
  bool _emitHex = true;

  /// Whether an integer number (e.g "1337") is emitted as token.
  bool _emitInt = true;

  /// Whether a real  number (e.g "3.14") is emitted as token.
  bool _emitReal = true;

  /// Whether a big integer number (e.g. "1000n") is emitted as token.
  bool _emitBigint = true;

  /// Whether a single quote ("'") is emitted as token.
  bool _emitSingleQuotes = true;

  /// Whether a double quote ("\"") is emitted as token.
  bool _emitDoubleQuotes = true;

  /// Whether indentations are emitted as tokens.
  bool _emitIndentation = false;

  /// The prefix that changes the lexer state in the following form:
  /// 'PREFIX ":" STR ":" INT ":" "INT";'
  String _lexerFilePositionPrefix = '!>';

  /// Whether backslashes are allowed to continue a line when indentation is
  /// emitted.
  bool _allowBackslashLineBreaks = false;

  /// Whether umlaute (e.g. "ä", "ü") are allowed to be part of identifiers.
  bool _allowUmlautInID = false;

  /// Whether hyphens ("-") are allowed to be part of identifiers.
  bool _allowHyphenInID = false;

  /// Whether underscores ("-") are allowed to be part of identifiers.
  bool _allowUnderscoreInID = true;

  /// The list of tokens that force the lexer to insert a semicolon (";") if
  /// that token stands before a line break ("\n").
  final List<LexerToken> _putTrailingSemicolon = [];

  /// The list of delimiters that are longer than one character (e.g. ">=").
  List<String> _multicharDelimiters = [];

  /// Configures the prefix of line comments.
  void configureSingleLineComments([pattern = '//']) {
    _singleLineCommentStart = pattern;
  }

  /// Configures the prefix and postfix multiline comments.
  void configureMultiLineComments([startPattern = '/*', endPattern = '*/']) {
    _multiLineCommentStart = startPattern;
    _multilineCommentEnd = endPattern;
  }

  /// Configures the prefix that changes the lexer state in the following form:
  /// 'PREFIX ":" STR ":" INT ":" "INT";'
  void configureLexerFilePositionPrefix([pattern = '!>']) {
    _lexerFilePositionPrefix = pattern;
  }

  /// Configures whether to emit newline characters ("\n") as tokens.
  enableEmitNewlines(bool value) {
    _emitNewline = value;
  }

  /// Configures whether to emit hexadecimal numbers (e.g. "0xAFFE"") as tokens.
  enableEmitHex(bool value) {
    _emitHex = value;
  }

  /// Configures whether to emit integer numbers (e.g. "1337") as tokens.
  enableEmitInt(bool value) {
    _emitInt = value;
  }

  /// Configures whether to emit real numbers (e.g. "3.14") as tokens.
  enableEmitReal(bool value) {
    _emitReal = value;
  }

  /// Configures whether to emit big integers (e.g. "100n") as tokens.
  enableEmitBigint(bool value) {
    _emitBigint = value;
  }

  /// Configures whether to emit single quote characters ("'") as tokens.
  enableEmitSingleQuotes(bool value) {
    _emitSingleQuotes = value;
  }

  /// Configures whether to emit double quote characters ("\"") as tokens.
  enableEmitDoubleQuotes(bool value) {
    _emitDoubleQuotes = value;
  }

  /// Configures whether to emit indentation by spaces or tabs as tokens.
  enableEmitIndentation(bool value) {
    _emitIndentation = value;
  }

  /// Configures whether backslashes in indentation mode allow to break a line.
  enableBackslashLineBreaks(bool value) {
    _allowBackslashLineBreaks = value;
  }

  /// Configures whether umlaute (e.g. "ä", "ü") are allowed to be part of
  /// identifiers.
  enableUmlautInID(bool value) {
    _allowUmlautInID = value;
  }

  /// Configures whether hyphens ("-") are allowed to be part of identifiers.
  enableHyphenInID(bool value) {
    _allowHyphenInID = value;
  }

  /// Configures whether underscores ("_") are allowed to be part of identifiers.
  enableUnderscoreInID(bool value) {
    _allowUnderscoreInID = value;
  }

  /// Whether the current token is the last token of the input stream.
  bool isEnd() {
    return _token.type == LexerTokenType.end;
  }

  /// Whether the current token is NOT the last token of the input stream.
  bool isNotEnd() {
    return _token.type != LexerTokenType.end;
  }

  /// Consumes the end token, or throws an exception otherwise.
  end() {
    if (_token.type == LexerTokenType.end) {
      next();
    } else {
      throw Exception(
        '${_errorPosition()}${getStr(LanguageText.expected)} END',
      );
    }
  }

  /// Whether the current token is an identifier (e.g. "slex1337").
  bool isIdentifier() {
    return _token.type == LexerTokenType.id;
  }

  /// Consumes and returns an identifier, or throws an exception otherwise.
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

  /// Whether the current token is a lower case identifier (e.g. "SLEX42").
  bool isLowercaseIdentifier() {
    return (_token.type == LexerTokenType.id &&
        _token.token == _token.token.toLowerCase());
  }

  /// Consumes and returns a lowercase identifier, or throws an exception
  /// otherwise.
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

  /// Whether the current token is an upper case identifier (e.g. "SLEX42").
  bool isUppercaseIdentifier() {
    return (_token.type == LexerTokenType.id &&
        _token.token == _token.token.toUpperCase());
  }

  /// Consumes and returns an uppercase identifier, or throws an exception
  /// otherwise.
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

  /// Whether the current token is an integer number (e.g. "1337").
  bool isInteger() {
    return _token.type == LexerTokenType.int;
  }

  /// Consumes and returns an integer number, or throws an exception otherwise.
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

  /// Whether the current token is a big integer number (e.g. "100n").
  bool isBigInteger() {
    return _token.type == LexerTokenType.bigint;
  }

  /// Consumes and returns an big integer number, or throws an exception
  /// otherwise.
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

  /// Whether the current token is a real number (e.g. "3.14").
  bool isRealNumber() {
    return _token.type == LexerTokenType.real;
  }

  /// Consumes and returns a real number, or throws an exception otherwise.
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

  /// Whether the current token is a hexadecimal number (e.g. "0xAFFE").
  bool isHexadecimal() {
    return _token.type == LexerTokenType.hex;
  }

  /// Consumes and returns a hexadecimal number, or throws an exception
  /// otherwise.
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

  /// Whether the current token is a quoted string (e.g. "'hello, world!'" or
  /// "\"hello, world!\"", depending on the allowed quotes).
  bool isString() {
    return _token.type == LexerTokenType.str;
  }

  /// Consumes and returns a quoted string, or throws an exception otherwise.
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

  /// Whether the current token equals terminal "t".
  bool isTerminal(String t) {
    return ((_token.type == LexerTokenType.del && _token.token == t) ||
        (_token.type == LexerTokenType.id && _token.token == t));
  }

  /// Whether the current token NOT equals terminal "t".
  bool isNotTerminal(String t) {
    return isTerminal(t) == false && _token.type != LexerTokenType.end;
  }

  /// Consumes a terminal [t], or throws an exception otherwise.
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

  /// Whether the current token is ";" or "\n".
  bool isEndOfStatement() {
    // TODO: ';' OR newline
    // TODO: configure ';'
    return _token.token == ';';
  }

  /// Consumes ";" or "\n", or throws an exception otherwise.
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

  /// Whether the current token indents the code.
  bool isIndentation() {
    return _token.type == LexerTokenType.del && _token.token == '\t+';
  }

  /// Whether the current token NOT indents the code.
  bool isNotIndentation() {
    return !(_token.type == LexerTokenType.del && _token.token == '\t+');
  }

  /// Consumes an indentation, or throws an exception otherwise.
  indentation() {
    if (_token.type == LexerTokenType.del && _token.token == '\t+') {
      next();
    } else {
      throw Exception(
        '${_errorPosition()}${getStr(LanguageText.expected)} INDENT',
      );
    }
  }

  /// Whether the current token outdents (inverse indents) the code.
  bool isOutdentation() {
    return _token.type == LexerTokenType.del && _token.token == '\t-';
  }

  /// Whether the current token NOT outdents (inverse indents) the code.
  bool isNotOutdentation() {
    if (_token.type == LexerTokenType.end) {
      return false; // TODO: must do this for ALL "not" methods
    }
    return !(_token.type == LexerTokenType.del && _token.token == '\t-');
  }

  /// Consumes an outdentation, or throws an exception otherwise.
  outdentation() {
    if (_token.type == LexerTokenType.del && _token.token == '\t-') {
      next();
    } else {
      throw Exception(
        '${_errorPosition()}${getStr(LanguageText.expected)} outdentation',
      );
    }
  }

  /// Whether the current token is a line break ("\n").
  bool isNewline() {
    return (isOutdentation() ||
        (_token.type == LexerTokenType.del && _token.token == '\n'));
  }

  /// Whether the current token is NOT a line break ("\n").
  bool isNotNewline() {
    return (!isOutdentation() &&
        !(_token.type == LexerTokenType.del && _token.token == '\n'));
  }

  /// Consumes a newline, or throws an exception otherwise.
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

  /// Throws an exception given a [message]. Also the current file, the current
  /// row and the current column is added as prefix to the message in form
  /// "FILE:ROW:COL:MESSAGE". If a token [tk] is given, the file position will
  /// be taken from that token.
  error(String message, [LexerToken? tk]) {
    throw Exception(_errorPosition(tk) + message);
  }

  /// Throws an exception with a message text that lists a set of expected
  /// tokens.
  errorExpected(List<String> terminals) {
    var s = '${getStr(LanguageText.expectedOneOf)} ';
    for (var i = 0; i < terminals.length; i++) {
      if (i > 0) s += ', ';
      s += terminals[i];
    }
    s += '.';
    error(s);
  }

  /// Throws an exception with message text that states that a condition is not
  /// boolean.
  errorConditionNotBool() {
    error(getStr(LanguageText.conditionNotBoolean));
  }

  /// Throws an exception with message text that stats that the symbol [symId]
  /// is unknown.
  errorUnknownSymbol(String symId) {
    error('${getStr(LanguageText.unknownSymbol)} $symId');
  }

  /// Throws an exception with message text that stats that a symbol is not
  /// a function.
  errorNotAFunction() {
    error(getStr(LanguageText.symbolIsNotAFunction));
  }

  /// Throws an exception with message text that stats that a binary operation
  /// [op] is not compatible to types [t1] and [t2].
  errorTypesInBinaryOperation(String op, String t1, String t2) {
    error(
      getStr(LanguageText.binaryOperatorIncompatibleTypes)
          .replaceAll('\$OP', op)
          .replaceAll('\$T1', t1)
          .replaceAll('\$T2', t2),
    );
  }

  /// Adds a token type that conditions to auto-include a semicolon before a
  /// line feed.
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

  /// Gets the list terminal symbols.
  List<String> getTerminals() {
    return _terminals.toList();
  }

  /// Gets the list of multi-character terminals.
  List<String> getMulticharDelimiters() {
    return _multicharDelimiters;
  }

  /// Gets the current token.
  LexerToken getToken() {
    return _token;
  }

  /// Advances to the next token of the current input.
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

  /// Pushes source code [src] onto the lexer file stack. Parameter [id] may be
  /// the file name of the source code. Optionally [initialRowIdx] indicates
  /// the number of the first row.
  ///
  /// Methods [pushSource] and [popSource] allow to implement a multi-file
  /// lexing. For example on include/import statements, the contents of the
  /// referenced file can be pushed onto the lexer file stack.
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

  /// Pops source code from the stack. Refer to method [pushSource] for a
  /// detailed description.
  popSource() {
    _fileStack.removeLast();
    if (_fileStack.isNotEmpty) {
      _state = _fileStack.last.stateBackup as LexerState;
      _token = _fileStack.last.tokenBackup as LexerToken;
    }
  }

  /// Backups and returns the current state () of the lexer.
  LexerBackup backupState() {
    return LexerBackup(_state.copy(), _token.copy());
  }

  /// Replays a backup, i.e. replaces the current state of the lexer by a
  /// backup state.
  void replayState(LexerBackup backup) {
    _state = backup.state;
    _token = backup.token;
  }

  /// Whether the next token is a linefeed ("\n").
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

  /// Weather the string [str] is the lookahead in the input stream.
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

  /// Stringifies the file, row and column of a token to format "FILE:ROW:COL".
  String _errorPosition([LexerToken? tk]) {
    tk ??= _token;
    return '${tk.fileID}:${tk.row.toString()}:${tk.col.toString()}: ';
  }
}
