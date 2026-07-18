/*
 * TqLexer.g4 — the lexer for tq (with TqParser.g4, the executable form of
 * SPECIFICATION.md). ANTLR requires the file name to match the grammar name,
 * hence the CamelCase.
 *
 * tq is the query language of the tsvsheet ecosystem: a `|`-separated pipeline
 * of relational verbs over a TSV/tsvt table. This lexer adds exactly what the
 * verbs need — lowercase verb keywords, the `[column]` reference, braces for
 * `group`, and multi-line whitespace — and imports every expression token from
 * the tsvsheet lexer unmodified, so the expression sublanguage can never drift.
 *
 * Lexing notes:
 *  - Verb keywords are lowercase-only. `select` is a keyword; `SELECT` lexes as
 *    COL and `Select` as NAME (imported rules), so uppercase spellings remain
 *    ordinary names. On an exact lowercase match the keyword wins the tie
 *    (main-grammar rules precede imported rules); maximal munch keeps longer
 *    identifiers (`selection`) lexing as NAME.
 *  - WS here replaces the imported space-only WS: a tq program may span lines.
 *  - The vendored tsvsheet grammar in imports/ is NEVER edited (grammar R5).
 */
lexer grammar TqLexer;

import TsvsheetLexer;

// ---- verb keywords (stage heads; lowercase-only, SPECIFICATION §3) ----------
SELECT   : 'select'   ;
DROP     : 'drop'     ;
WHERE    : 'where'    ;
DERIVE   : 'derive'   ;
RENAME   : 'rename'   ;
SORT     : 'sort'     ;
DISTINCT : 'distinct' ;
LIMIT    : 'limit'    ;
OFFSET   : 'offset'   ;
GROUP    : 'group'    ;
AS       : 'as'       ;

// ---- tq punctuation ---------------------------------------------------------
LBRACE  : '{' ;   // group aggregate block
RBRACE  : '}' ;

// ---- column reference (SPECIFICATION §4) ------------------------------------
// `[` content `]` — digits-only content is a 1-based index, anything else a
// header name. `]` cannot occur in the content (no escape in v1); newlines are
// excluded so an unterminated bracket fails on its own line.
COLUMN  : '[' ~[\]\r\n]* ']' ;

// ---- trivia (replaces the imported space-only WS) ---------------------------
WS      : [ \t\r\n]+ -> skip ;
