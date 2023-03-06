/// slex - a simple lexer
/// (c) 2023 by Andreas Schwenk <mailto:contact@compiler-construction.com>
/// License: GPL-3.0-or-later

/// The available languages for error messages.
enum Language { english, german }

/// The available predefined error message types.
enum LanguageText {
  expected,
  expectedOneOf,
  conditionNotBoolean,
  unknownSymbol,
  symbolIsNotAFunction,
  binaryOperatorIncompatibleTypes
}

/// The currently selected language for error messages.
var lang = Language.english;

/// Sets the currently selected language for error messages.
void setLanguage(Language l) {
  lang = l;
}

/// Gest an error messgage string, defined in the current language [lang].
String getStr(LanguageText str) {
  switch (lang) {
    case Language.english:
      {
        switch (str) {
          case LanguageText.expected:
            return 'expected';
          case LanguageText.expectedOneOf:
            return 'expected one of';
          case LanguageText.conditionNotBoolean:
            return 'condition must be boolean';
          case LanguageText.unknownSymbol:
            return 'unknown symbol';
          case LanguageText.symbolIsNotAFunction:
            return 'symbol is not a function';
          case LanguageText.binaryOperatorIncompatibleTypes:
            return 'Operator \$OP is incompatible for types \$T1 and \$T2';
        }
      }
    case Language.german:
      {
        switch (str) {
          case LanguageText.expected:
            return 'erwarte';
          case LanguageText.expectedOneOf:
            return 'erwarte Token aus Liste';
          case LanguageText.conditionNotBoolean:
            return 'Bedingung muss bool\'sch sein';
          case LanguageText.unknownSymbol:
            return 'unbekanntes Symbol';
          case LanguageText.symbolIsNotAFunction:
            return 'Symbol ist keine Funktion';
          case LanguageText.binaryOperatorIncompatibleTypes:
            return 'Operator \$OP ist inkompatibel mit den Typen \$T1 und \$T2';
        }
      }
  }
}
