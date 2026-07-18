/*
 * TqParser.g4 — the parser for tq (with TqLexer.g4); the executable form of
 * SPECIFICATION.md.
 *
 * A tq program is `stage ('|' stage)*` — a pipeline of relational verbs over a
 * TSV/tsvt table. `|` ALWAYS means "next stage": the tsvsheet pipe sugar is
 * unavailable anywhere in a tq expression (ADR 0002 — it is pure sugar, so
 * nothing is lost).
 *
 * THE RESTATED LADDER (ADR 0002). tsvsheet's expression grammar is one
 * left-recursive precedence ladder with pipe as an internal alternative, and
 * ANTLR import-override replaces whole rules — it cannot remove one
 * alternative. So this grammar restates the mutually recursive expression
 * island ONCE — tqExpr / tqFunctionCall / tqArgList, which is the imported
 * expression / functionCall / argList set verbatim, minus the pipe
 * alternative, plus the COLUMN operand and keyword-as-name admission. The
 * reference rules (reference, sheetQualifier, cellRef) and every lexer token
 * are imported unmodified. The drift guard is the corpus: every pipe-free
 * tsvsheet expression must parse inside `where`, every pipe-bearing one must
 * fail (grammar capability AC).
 *
 * WHAT THE GRAMMAR DOES vs DOES NOT do (grammar-first, semantics layered):
 *  - It recognizes stage syntax and the expression sublanguage precisely.
 *  - It does NOT resolve column names, reject raw A1 references (plan-time
 *    ErrCellRef — they parse here by construction), require limit/offset
 *    integrality, evaluate expressions, or order execution — all layered by an
 *    implementation over this parse tree (SPECIFICATION.md §6–§8).
 */
parser grammar TqParser;

import TsvsheetParser;

options { tokenVocab=TqLexer; }

// ===== Program (SPECIFICATION §3) =========================================

program : stage (PIPE stage)* EOF ;

stage
    : SELECT columnList                                        # selectStage
    | DROP columnList                                          # dropStage
    | WHERE tqExpr                                             # whereStage
    | DERIVE assignment (COMMA assignment)*                    # deriveStage
    | RENAME renamePair (COMMA renamePair)*                    # renameStage
    | SORT sortKey (COMMA sortKey)*                            # sortStage
    | DISTINCT columnList?                                     # distinctStage
    | LIMIT NUMBER                                             # limitStage
    | OFFSET NUMBER                                            # offsetStage
    | GROUP columnList LBRACE assignment (COMMA assignment)* RBRACE # groupStage
    ;

assignment : columnName EQ tqExpr ;

renamePair : columnItem AS columnName ;

sortKey : DASH? columnItem ;

columnList : columnItem (COMMA columnItem)* ;

// A column in a stage position: bracketed form, bare identifier, or bare
// 1-based index. Verb keywords are admitted back as bare names (R4a).
columnItem : COLUMN | bareName | NUMBER ;

// A column name being introduced (derive / rename-target / group aggregate).
columnName : COLUMN | bareName ;

bareName : NAME | COL | verbKeyword ;

verbKeyword
    : SELECT | DROP | WHERE | DERIVE | RENAME | SORT | DISTINCT | LIMIT | OFFSET | GROUP | AS ;

// ===== The restated expression ladder (ADR 0002) ==========================
//
// The imported tsvsheet `expression` rule verbatim, with exactly three edits:
// the pipeExpr alternative is REMOVED, the COLUMN operand is ADDED, and the
// call/arg rules are restated so arguments recurse into THIS ladder (the
// island is mutually recursive). Precedence and associativity are otherwise
// identical, tightest first: grouping, postfix percent, power (right-assoc),
// unary sign, multiplicative, additive, text concatenation, comparison.
tqExpr
    : LPAREN tqExpr RPAREN                               # tqParenExpr
    | tqExpr PERCENT                                     # tqPercentExpr
    | <assoc=right> tqExpr CARET tqExpr                  # tqPowExpr
    | op=(PLUS | DASH) tqExpr                            # tqUnaryExpr
    | tqExpr op=(STAR | SLASH) tqExpr                    # tqMulExpr
    | tqExpr op=(PLUS | DASH) tqExpr                     # tqAddExpr
    | tqExpr AMP tqExpr                                  # tqConcatExpr
    | tqExpr op=(EQ | NE | LT | LE | GT | GE) tqExpr     # tqCompareExpr
    | tqFunctionCall                                     # tqCallExpr
    | COLUMN                                             # tqColumnExpr
    | reference                                          # tqRefExpr
    | NUMBER                                             # tqNumberExpr
    | STRING                                             # tqStringExpr
    | (TRUE | FALSE)                                     # tqBoolExpr
    | ERRORCONST                                         # tqErrorExpr
    ;

// A call, as imported functionCall but admitting verb keywords as names
// (tsvsheet has functions named `sort`, `filter`, `unique`) and recursing into
// the restated ladder for arguments.
tqFunctionCall : (NAME | COL | verbKeyword) NUMBER? LPAREN tqArgList? RPAREN ;

tqArgList : tqExpr (COMMA tqExpr)* ;
