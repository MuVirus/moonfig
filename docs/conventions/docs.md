# Documentation checks

[`scripts/check-docs.mbtx`](../../scripts/check-docs.mbtx) turns the documentation maintenance rules into executable checks.
CI and pre-commit both run it, and you can also run it by hand locally.

## Running

```sh
moonx scripts/check-docs.mbtx
moonx scripts/check-docs.mbtx --help
```

Run it from the repository root. `moonx` uses the Wasm backend, file IO is provided by `moonbitlang/x/fs`,
and no native toolchain is needed.

## What it checks

| Check | Rule | When it fails |
|---|---|---|
| Directory index | `docs/AGENTS.md` registers every direct subdirectory; each subdirectory's `AGENTS.md` registers the primary `.md` files of that directory (`.zh.md` copies are exempt) | Add a line to the corresponding `AGENTS.md` |
| Links and anchors | Relative links exist; `#anchor` matches a heading in the target file | Fix the link or the heading; external URLs are not checked |
| Decision status | The level-2 headings in `decisions.md` increase consecutively from `## 1.`; the ID / decision / status / affected docs in the top index match the heading and the `Status: ... | Affects: ...` line of each decision | Add the status line or the index |
| Supersession | A superseded decision writes `#N` in its status; the status of `#N` must be `active` or `partially superseded`, and it must name the other decision back in its own status | Complete the status lines on both sides |
| Design doc opening | The first 12 lines of `docs/design/*.md` (except `AGENTS.md` and `.zh.md`) contain `> **Conclusion**:`, `> **Authority**:` and `> **Out of scope**:` | Add the three opening lines |
| Translation pairing | Every English primary under `docs/` has a `foo.zh.md` sibling, and every `.zh.md` has an English source; root pairs are `README.mbt.md` / `README_ZH.md` and `AGENTS.md` / `AGENTS_ZH.md` | Add the missing copy or rename it |
| Structure pairing | Each translation pair has the same heading-level sequence and the same number of code blocks | Add the missing sections or code blocks |
| Code blocks | Every code block declares a language on its opening fence; there are no unclosed blocks | Add a label such as `sh` / `moonbit` / `text` |
| Example consistency | `examples/README.md`, the CI's `moon run examples/...` and the actual directories under `examples/` are the same set | Add the README line, the CI command or the directory |
| Roadmap | The status of each row in the README roadmap equals the status of the corresponding section in `roadmap.md` | Change the status, or add a mapping in `roadmap_aliases()` |

## Scan scope

- Scans every `.md` file in the repository that is not ignored by `.gitignore`, including `*.zh.md` translations.
- `.gitignore` only parses simple `name/` directory rules; complex globs are not handled, better to check too much.
- `.git` and `node_modules` are always skipped.
- The `AGENTS.md` traversal under `docs/` has no directory exemptions: every subdirectory under `docs/` must be registered. `.zh.md` files are not listed in the index.

## What it does not check

- Whether external links are reachable.
- Writing quality, API semantics, whether examples run; review and `moon test` cover the first two, and CI runs the examples and compares their output with `scripts/check-examples.sh`.
- Whether design docs consistently use the present tense, and whether history is kept only in `decisions/`; review covers these.
- Whether Chinese and English content correspond sentence by sentence; only structure is compared. English is authoritative.
- Whether the Chinese copy is up to date in meaning; review covers that.
- Whether a code change updated the docs it affects; the **Doc impact** line in the PR / commit and review cover that.

## Adding a check

1. Write a `check_*` function in `scripts/check-docs.mbtx`, and record problems with `fail(file, message)`.
2. Call it in `main`; when you need the file list, reuse `collect_markdown` and `docs`.
3. Verify with `moonx scripts/check-docs.mbtx`: the exit code is 0 when there is no problem, and 1 when you deliberately break something.
4. Update the check table in this file and the `--help` text.

A normal `moon check` / `moon test` does not check `.mbtx`, so run the script directly after changing it.

## Doc impact

A change that alters a public API, an error message or user-visible behaviour updates the affected docs in the same change, and the PR / commit says what moved:

- Public API or behaviour: `docs/design/` and the `.mbti` diff.
- Error text: `docs/reference/errors.md` and `errors.zh.md`.
- Usage: `README.mbt.md` / `README_ZH.md`, `docs/guides/` and `examples/`.

Write `Doc impact: ...` in the commit body and fill the PR template. The checker cannot detect a missing doc update; review is the guard.

## Related

- Directory hierarchy: [docs/AGENTS.md](../AGENTS.md)
- Documentation system plan: [doc-system.md](../plan/doc-system.md)
- Example output check: [scripts/check-examples.sh](../../scripts/check-examples.sh)
- Commit hook: [.githooks/pre-commit](../../.githooks/pre-commit)
- CI: [.github/workflows/ci.yml](../../.github/workflows/ci.yml)
