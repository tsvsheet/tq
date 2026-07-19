# tq

> **The query language of the tsvsheet ecosystem.** A `|`-separated pipeline of relational verbs — `select`, `where`, `derive`, `sort`, `group`, … — over a TSV or [tsvt](https://github.com/tsvsheet/tsvsheet) table, with every embedded expression written in the tsvsheet formula language so the two languages can never drift apart. TSV in, TSV out; between `cut` and `jq`.

```text
where and([stars] > 1000, [lang] = "go") | derive ratio = round([stars] / [forks], 2) | select name, stars, ratio | sort -stars | limit 10
```

Grammar-first, exactly like [tsvsheet](https://github.com/tsvsheet/tsvsheet) and [isnow](https://github.com/tsvsheet/isnow): [TqLexer.g4](TqLexer.g4) + [TqParser.g4](TqParser.g4) are the source of truth, importing the tsvsheet expression grammar vendored at a pinned commit ([imports/VENDORED.md](imports/VENDORED.md)). [SPECIFICATION.md](SPECIFICATION.md) is normative. Every implementation is generated from the grammars (`make gen`, Docker-isolated ANTLR — [docker/antlr](docker/antlr/Dockerfile)); generated parsers are never committed here.

- Canonical engine: [tsvsheet/go-tq](https://github.com/tsvsheet/go-tq) — the single implementation of tq semantics.
- CLI: [tsvsheet/tq.go](https://github.com/tsvsheet/tq.go) — the `tq` binary.
