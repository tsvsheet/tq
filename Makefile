.DEFAULT_GOAL := help

# tq — the one normative grammar for the tq query language, generated to every
# target language so implementations parse from a single source of truth.
#
# TqLexer.g4 + TqParser.g4 are the source of truth (SPECIFICATION.md). They
# import the tsvsheet expression grammar VENDORED in imports/ at a pinned
# tsvsheet commit (recorded in imports/VENDORED.md; refresh with
# `make sync-tsvsheet`), so generation is reproducible offline and the vendored
# files are never edited by hand. This Makefile compiles the grammars to each
# language with ANTLR4, into gen/<lang>/. Lift a generated tree into an
# implementation repo (go-tq lifts gen/go as src/grammar/tq) and run that
# repo's formatter over it — lifted trees are gofumpt-formatted there, so a
# raw re-copy alone produces a formatting-only diff. The Java/ANTLR toolchain
# is isolated in Docker; generated code is committed in each implementation,
# so their normal builds stay toolchain-free.

.DELETE_ON_ERROR:

MAKEFILE_DIR := $(patsubst %/,%,$(dir $(realpath $(lastword $(MAKEFILE_LIST)))))
ANTLR_IMAGE  := tq-antlr
LEXER        := TqLexer.g4
PARSER       := TqParser.g4

RUN := docker run --rm -v "$(MAKEFILE_DIR)":/work -w /work $(ANTLR_IMAGE)

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*## "}{printf "  %-14s %s\n", $$1, $$2}'

.PHONY: image
image: ## Build the pinned ANTLR4 generator image
	docker build -t $(ANTLR_IMAGE) $(MAKEFILE_DIR)/docker/antlr

.PHONY: sync-tsvsheet
sync-tsvsheet: ## Refresh the vendored tsvsheet grammar from the sibling checkout (update imports/VENDORED.md!)
	cp $(MAKEFILE_DIR)/../tsvsheet/TsvsheetLexer.g4 $(MAKEFILE_DIR)/../tsvsheet/TsvsheetParser.g4 $(MAKEFILE_DIR)/imports/

.PHONY: gen
gen: go python js java cpp ## Generate every stock-ANTLR target into gen/<lang>/

# ANTLR accepts a single -lib, and the parser build needs BOTH the vendored
# tsvsheet grammars (imported) and the freshly generated TqLexer.tokens
# (tokenVocab). So each target stages the vendored .g4s into its gen/<lang>/
# output dir (gitignored) and uses that one dir as the parser's -lib.

.PHONY: go
go: image ## Generate the Go parser into gen/go
	$(RUN) -Dlanguage=Go -package tqgrammar -lib imports -o gen/go $(LEXER)
	cp $(MAKEFILE_DIR)/imports/*.g4 $(MAKEFILE_DIR)/gen/go/
	$(RUN) -Dlanguage=Go -visitor -package tqgrammar -lib gen/go -o gen/go $(PARSER)

.PHONY: python
python: image ## Generate the Python 3 parser into gen/python
	$(RUN) -Dlanguage=Python3 -lib imports -o gen/python $(LEXER)
	cp $(MAKEFILE_DIR)/imports/*.g4 $(MAKEFILE_DIR)/gen/python/
	$(RUN) -Dlanguage=Python3 -visitor -lib gen/python -o gen/python $(PARSER)

.PHONY: js
js: image ## Generate the JavaScript parser into gen/js
	$(RUN) -Dlanguage=JavaScript -lib imports -o gen/js $(LEXER)
	cp $(MAKEFILE_DIR)/imports/*.g4 $(MAKEFILE_DIR)/gen/js/
	$(RUN) -Dlanguage=JavaScript -visitor -lib gen/js -o gen/js $(PARSER)

.PHONY: java
java: image ## Generate the Java parser into gen/java
	$(RUN) -Dlanguage=Java -package com.tsvsheet.tqgrammar -lib imports -o gen/java $(LEXER)
	cp $(MAKEFILE_DIR)/imports/*.g4 $(MAKEFILE_DIR)/gen/java/
	$(RUN) -Dlanguage=Java -visitor -package com.tsvsheet.tqgrammar -lib gen/java -o gen/java $(PARSER)

.PHONY: cpp
cpp: image ## Generate the C++ parser into gen/cpp (ANTLR has no plain-C target)
	$(RUN) -Dlanguage=Cpp -lib imports -o gen/cpp $(LEXER)
	cp $(MAKEFILE_DIR)/imports/*.g4 $(MAKEFILE_DIR)/gen/cpp/
	$(RUN) -Dlanguage=Cpp -visitor -lib gen/cpp -o gen/cpp $(PARSER)

.PHONY: clean
clean: ## Remove generated parsers
	rm -rf $(MAKEFILE_DIR)/gen
