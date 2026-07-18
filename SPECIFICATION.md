# tq — specification

tq ("TSV query") is the query language of the tsvsheet ecosystem: a pipeline of relational verbs over a TSV or tsvt table, with every embedded expression written in the tsvsheet formula language. TSV in, TSV out. It sits between `cut` (columns, no predicates) and `jq` (predicates, no tables).

This document is normative. The executable form of §3–§5 is [TqLexer.g4](TqLexer.g4) + [TqParser.g4](TqParser.g4); the grammar defines syntax only, and everything in §2 and §6–§8 is semantics an implementation layers over the parse tree. The canonical implementation is [tsvsheet/go-tq](https://github.com/tsvsheet/go-tq); design rationale lives in the tsvsheet org's SDD tree (`_projects/specs/tq/`).

## 1. Design rules

1. **Expressions are tsvsheet expressions.** A predicate in tq and a formula in a `.tsvt` cell have identical syntax and semantics — same functions, coercions, and error values. The tq grammar imports the tsvsheet grammar; the implementation evaluates through the tsvsheet engine. tq defines no expression semantics of its own.
2. **`|` always means "next stage".** The tsvsheet pipe sugar is unavailable inside tq expressions (v1). It is pure sugar (`x | f(a)` ≡ `f(x, a)`), so every expression remains writable.
3. **tq queries values, never formulas.** Input containing formula cells is computed first (§6); cell formulas are content, not query text.
4. **Columns, never cells.** tq addresses columns by name or position. Raw A1 references and sheet qualifiers parse (the expression grammar is imported verbatim) but are program errors at plan time (§8).

## 2. The table model

- The input is a TSV grid read with tsvsheet's grid semantics: rows are newline-separated lines, cells are TAB-separated, a leading `#!` first line and any `# ` (hash-space) line are comments that do not occupy a row, and a trailing newline adds no row.
- **The first data row is the header by default.** Header cells name the columns. The header travels through the pipeline — projected by `select`/`drop`, relabeled by `rename`, extended by `derive`, replaced by `group` — and is emitted first in the output.
- **Headerless mode** is an implementation option (`--no-header` in CLIs). All rows are data; column references are positional only (§4); `rename` is a program error (`ErrHeaderless`); `derive` and `group` assignment names are permitted as syntax but no header is emitted, and new columns are referenced by position.
- Rows may be ragged; a reference to a column a given row lacks reads an empty cell.
- Output is written with tsvsheet's grid writer: TAB-separated cells, one newline-terminated line per row, comments not preserved.

## 3. Programs and stages

A program is one or more stages separated by `|`. Whitespace and newlines between tokens are insignificant; there are no comments in the query language (v1).

```
select name, stars | where [stars] > 1000 | sort -stars | limit 10
```

The stages, in their entirety (v1):

| Stage | Syntax | Semantics |
| --- | --- | --- |
| `select` | `select col(, col)*` | Project and reorder to exactly the listed columns, in order. Duplicates allowed. |
| `drop` | `drop col(, col)*` | Remove the listed columns; everything else keeps its order. |
| `where` | `where expr` | Keep rows whose predicate value is exactly TRUE (§6). |
| `derive` | `derive name = expr(, name = expr)*` | Append a computed column, or replace in place when `name` already exists. Assignments apply left to right; later ones see earlier results. |
| `rename` | `rename col as name(, col as name)*` | Relabel without moving. |
| `sort` | `sort key(, key)*` with `key := -?col` | Stable multi-key sort in the §5 total order; `-` reverses that key. |
| `distinct` | `distinct` or `distinct col(, col)*` | Keep the first row per key (whole row when no columns given), comparing raw cell text. |
| `limit` | `limit n` | Keep the first `n` rows of the prior stage's output. |
| `offset` | `offset n` | Skip the first `n` rows. |
| `group` | `group col(, col)* { name = expr(, name = expr)* }` | Partition by key equality on raw cell text; emit one row per group — key columns first, then one column per aggregate assignment — in first-appearance order. Inside an aggregate expression a column reference denotes that column's cells across the whole group (§5). |

`n` is a non-negative integer literal; the grammar admits any tsvsheet NUMBER and an implementation rejects a fractional one as a syntax error at program build. Verb keywords are lowercase-only and are reserved only at stage position: `[select]` names a column, `sort(...)` inside an expression is the tsvsheet function.

## 4. Column references

- In expressions, a column reference is bracketed: `[name]` or `[N]`.
- Digits-only content (`[2]`) is a **1-based column index**, and is the only form allowed in headerless mode.
- Any other content is a **header name**: exact, case-sensitive match, first match winning when headers repeat. `]` cannot appear in the content — there is no escape (v1); a header containing `]` is reachable by position or after `rename`. A digits-only header is likewise reachable by position or after `rename`.
- In stage column positions (`select`, `drop`, `rename`, `sort` keys, `distinct`, `group` keys) brackets may be dropped for a bare identifier (`select name, stars`) and a bare integer is an index; brackets are required for names with spaces or punctuation.
- **Resolution is plan-time.** Every reference in the program resolves against the header (or arity) before any row is processed; an unknown name or out-of-range index is `ErrUnknownColumn` (§8), never a per-row error value. Columns introduced by `derive`/`group` are referenceable in later stages.

## 5. Expressions

The expression sublanguage is tsvsheet's ([SPECIFICATION](https://github.com/tsvsheet/tsvsheet/blob/main/SPECIFICATION.md) §5) with two differences, both syntactic: the pipe alternative is absent (§1 rule 2), and the column reference (§4) is an additional operand. Operator precedence, associativity, literals, function names (case-insensitive), and every function's behavior are tsvsheet's, evaluated by the tsvsheet engine. Cell text coerces (number/boolean/date/string) exactly as a sheet literal does.

**Sort order (total).** Per key: cells that coerce to numbers order before cells that do not; numeric cells order numerically among themselves; non-numeric cells order by byte-wise comparison of raw text among themselves; `-` reverses the entire key order; the sort is stable, so equal keys keep their prior relative order.

**Aggregates.** Inside a `group` aggregate expression, a column reference denotes the column's cells across the group (a range value), so tsvsheet's aggregate functions apply directly: `total = sum([stars])`, `n = counta([name])`, `mean = round(avg([price]), 2)`.

## 6. Computed values, error values, strictness

- **Compute-first.** When the input grid contains formula cells (a `.tsvt`), the implementation computes the sheet with the tsvsheet engine and the query runs over the computed value grid. A raw mode (`--raw`) skips this pass and treats every cell as verbatim text.
- A computed **error value** (`#DIV/0!`, `#REF!`, …) is data: it flows through projections, sorts among the non-numeric texts, and groups by its text.
- A `where` predicate keeps a row only when its value is exactly TRUE. Any other value — FALSE, a number, text, an error value — drops the row.
- A `derive` or aggregate expression that evaluates to an error value writes that error value as the cell text. A 2-D (spilling) result reduces to its scalar-context value.
- **Strict mode** (`--strict`): the first expression evaluation producing an error value aborts the run with `ErrStrict`, naming the value, the column, and the row's 1-based position in the failing stage's input.

## 7. Whitespace, form, and reserved words

A program may be a single shell argument or formatted across lines. Verb keywords (`select`, `drop`, `where`, `derive`, `rename`, `sort`, `distinct`, `limit`, `offset`, `group`, `as`) are lowercase-only tokens, reserved at stage position and admitted as ordinary names everywhere a name may appear.

## 8. Program errors (closed set)

An implementation reports exactly these failure classes, distinctly:

| Error | When |
| --- | --- |
| `ErrSyntax` | The program does not parse, with line/column — including a fractional `limit`/`offset` and an embedded-expression failure at compile. |
| `ErrUnknownColumn` | Plan-time: a reference names no column or an index is out of range. |
| `ErrCellRef` | Plan-time: an expression contains a raw A1 reference or sheet qualifier. |
| `ErrHeaderless` | Plan-time: `rename` (or another name-requiring form) in headerless mode. |
| `ErrStrict` | Run-time under strict mode: an expression produced an error value. |
| `ErrLimit` | The input exceeded the implementation's configured input ceiling. |

Everything else — coercion surprises, lookup misses, division by zero — is an error **value** in the data, per §6, exactly as in a sheet.
