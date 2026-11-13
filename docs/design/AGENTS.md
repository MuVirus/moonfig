# design guide

Design documents explain "why it is defined this way": trade-offs, boundaries, pitfalls. Operational steps go in `guides/`; runnable proof goes in
`examples/`.

## Files

- [`design.md`](design.md) —— the main line and the core data model
- [`sources.md`](sources.md) —— Source / Format interfaces, core boundary, package layout, origin tracking, trade-offs of third-party parsers
- [`cli-args.md`](cli-args.md) —— command-line arguments: value style, short option registration, array declaration, positional mapping, conflicts and origin labels
- [`extract.md`](extract.md) —— extraction into structs, integer mapping, standard-library error mapping
- [`validate.md`](validate.md) —— validation: per-key rule table, struct `Validate`, unknown keys, errors
- [`format-detect.md`](format-detect.md) —— automatic format detection: suffix first, content sniffing, candidate order
- [`hot-reload.md`](hot-reload.md) —— hot reload: snapshot replacement, file polling, keep the old config on failure

## Rules

- One design per file, named by topic.
- Write "why it is defined this way": conclusion first, then trade-offs, boundaries and costs.
- The opening three lines always write `Conclusion`, `Authority` (whether this document is normative or an overview) and `Out of scope`; the check script verifies them.
- Normative conclusions state who decides: signatures follow `.mbti`, behaviour follows this document.
- History stays only in `decisions/`; design documents use the present tense, never "it used to be... and later...".
- Register new files in the index of this file.
