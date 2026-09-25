/// Splits sentences into words, spaces and punctuation, in every script.
///
/// Combining marks belong to the letter before them, so Hebrew nikkud,
/// Arabic harakat, Greek accents in decomposed form and Devanagari vowel signs
/// never split a word.
library;

import 'script.dart';

enum TokenKind { word, space, punct }

class Token {
  const Token(this.text, this.kind, this.start);
  final String text;
  final TokenKind kind;

  /// Offset in UTF-16 code units within the source string.
  final int start;

  bool get isWord => kind == TokenKind.word;

  @override
  String toString() => '${kind.name}:$text';
}

final _letter = RegExp(r'[\p{L}\p{M}\p{N}‌‍]', unicode: true);
final _space = RegExp(r'\s', unicode: true);

bool _isLetter(String ch) => _letter.hasMatch(ch);

/// Characters that stay inside a word when a letter sits on both sides:
/// apostrophes, hyphens, Hebrew geresh and gershayim, and the ASCII quotes
/// people type in place of them in Hebrew abbreviations such as צה"ל.
const _joiners = {"'", '’', '-', '‐', '׳', '״', '"', '·'};

List<Token> tokenize(String s) {
  final chars = s.runes.map(String.fromCharCode).toList();
  final tokens = <Token>[];
  var offset = 0;
  var i = 0;
  while (i < chars.length) {
    final ch = chars[i];
    final start = offset;
    if (_isLetter(ch)) {
      final script = scriptOfRune(ch.runes.first);
      final buf = StringBuffer(ch);
      offset += ch.length;
      i++;
      // Each Han character is its own word; kana and Thai stay in runs.
      if (script != Script.han) {
        while (i < chars.length) {
          final c = chars[i];
          if (_isLetter(c)) {
            final sc = scriptOfRune(c.runes.first);
            if (sc == Script.han && script != Script.han) break;
            if (sc == Script.kana && script != Script.kana) break;
            buf.write(c);
            offset += c.length;
            i++;
            continue;
          }
          final canJoin =
              _joiners.contains(c) &&
              i + 1 < chars.length &&
              _isLetter(chars[i + 1]) &&
              (c != '"' || script == Script.hebrew);
          if (canJoin) {
            buf.write(c);
            offset += c.length;
            i++;
            continue;
          }
          break;
        }
      }
      tokens.add(Token(buf.toString(), TokenKind.word, start));
      continue;
    }
    final isSpace = _space.hasMatch(ch);
    final buf = StringBuffer(ch);
    offset += ch.length;
    i++;
    while (i < chars.length &&
        !_isLetter(chars[i]) &&
        _space.hasMatch(chars[i]) == isSpace) {
      buf.write(chars[i]);
      offset += chars[i].length;
      i++;
    }
    tokens.add(
      Token(buf.toString(), isSpace ? TokenKind.space : TokenKind.punct, start),
    );
  }
  return tokens;
}

/// The words of [s], in order.
List<String> words(String s) =>
    tokenize(s).where((t) => t.isWord).map((t) => t.text).toList();

/// Latin-style stops need a following space; full-width CJK stops don't.
final _sentenceEnd = RegExp(
  r'([.!?…؟۔।॥‼⁇⁈⁉]+["»”’)\]]*)(\s+|$)|([。！？]+[」』”’）]*)\s*',
  unicode: true,
);

/// Splits a paragraph into sentences after terminal punctuation in any script.
/// Closing quotes and brackets stay with the sentence they close.
List<String> splitSentences(String paragraph) {
  final text = paragraph.trim();
  if (text.isEmpty) return const [];
  final out = <String>[];
  var last = 0;
  for (final m in _sentenceEnd.allMatches(text)) {
    final end = m.start + (m.group(1) ?? m.group(3)!).length;
    final piece = text.substring(last, end).trim();
    if (piece.isNotEmpty) out.add(piece);
    last = m.end;
  }
  if (last < text.length) {
    final rest = text.substring(last).trim();
    if (rest.isNotEmpty) out.add(rest);
  }
  return out;
}

final _lineEnd = RegExp(r'[.!?…。！？؟۔।:;»"”’)\]]$', unicode: true);

/// Splits plain text into paragraphs on blank lines.
///
/// Inside a block, line breaks are kept as paragraph breaks when the lines
/// look intentional (short lines such as poetry, or lines that end sentences
/// such as dialogue). Hard-wrapped prose is joined back into one paragraph.
List<String> splitParagraphs(String text) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final out = <String>[];
  for (final block in normalized.split(RegExp(r'\n\s*\n'))) {
    final lines = block
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) continue;
    if (lines.length == 1) {
      out.add(lines.first);
      continue;
    }
    final maxLen = lines.map((l) => l.length).reduce((a, b) => a > b ? a : b);
    final ended = lines.where(_lineEnd.hasMatch).length;
    if (maxLen < 48 || ended >= lines.length * 0.6) {
      out.addAll(lines);
    } else {
      out.add(lines.join(' '));
    }
  }
  return out;
}
