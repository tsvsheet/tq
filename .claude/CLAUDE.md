# tq

> **The query language of the tsvsheet ecosystem** — a `|`-separated pipeline of relational verbs over a TSV/tsvt table, every embedded expression written in the tsvsheet formula language. This repo is grammar-only and normative: [TqLexer.g4](../TqLexer.g4) + [TqParser.g4](../TqParser.g4) with [SPECIFICATION.md](../SPECIFICATION.md); no committed implementations, `gen/` is ignored.

- The tsvsheet expression grammar is **vendored** in [imports/](../imports/) at a pinned commit ([imports/VENDORED.md](../imports/VENDORED.md)) and never edited here; refresh with `make sync-tsvsheet` and update the pin in the same commit.
- The expression ladder is **restated once** in TqParser (`tqExpr`/`tqFunctionCall`/`tqArgList`): the imported ladder minus the pipe alternative plus the `[column]` operand — ANTLR cannot remove a single alternative by override. Any change to the vendored grammar must be reconciled into the restated ladder; the corpus in [testdata/](../testdata/) is the drift guard (pipe-free tsvsheet expressions parse inside `where`, pipe-bearing ones must fail).
- `|` always means "next stage"; the pipe sugar is unavailable in tq expressions (v1). Verb keywords are lowercase-only and reserved only at stage position.
- Semantics (column resolution, plan-time `ErrCellRef` for raw A1 refs, compute-first, the §5 total sort order) are layered by implementations — the canonical one is [tsvsheet/go-tq](https://github.com/tsvsheet/go-tq); design decisions live in the org's `_projects/specs/tq/`.
- ANTLR runs only via the pinned Docker image ([docker/antlr](../docker/antlr/Dockerfile)); `make gen` targets `gen/<lang>/`, lifted into implementation repos, never committed here.
