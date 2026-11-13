# docs guide

`docs/` holds the project's documentation. For how to write code, see the root `AGENTS.md`; for writing and review rules, see the `write-docs` skill.

## Directories

- `guides/` — task-oriented steps, covering "how to accomplish X". For the file index, see
  [`guides/AGENTS.md`](guides/AGENTS.md).
- `design/` — design documents, covering "why it is designed this way". For the file index, see
  [`design/AGENTS.md`](design/AGENTS.md).
- `decisions/` — decision records, covering "why it was decided that way at the time". For the file index, see
  [`decisions/AGENTS.md`](decisions/AGENTS.md).
- `plan/` — planning documents, covering "what comes next". For the file index, see
  [`plan/AGENTS.md`](plan/AGENTS.md).
- `conventions/` — project conventions, covering "how to do things". For the file index, see
  [`conventions/AGENTS.md`](conventions/AGENTS.md).
- `reference/` — lookup tables for concrete shapes, covering "what exactly is it". For the file index, see
  [`reference/AGENTS.md`](reference/AGENTS.md).

## Rules

- This file registers only direct subdirectories and their responsibilities; individual files are registered in the `AGENTS.md` of the directory they belong to.
- Adding a subdirectory: add a line in this file, and create an `AGENTS.md` in that directory.
- Adding a file: register it in the `AGENTS.md` of its directory first, then write the content.
- User-facing usage goes in `README.mbt.md` / `README_ZH.md`; task steps go in `guides/`; design trade-offs go in
  `design/`.
- The human-facing entry point is [`README.md`](README.md): reading paths, core concepts, and the mapping from code areas to docs.
- English is authoritative. Every primary `.md` under `docs/` has a Chinese `.zh.md` copy next to it; `.zh.md` copies are not registered in the per-directory index.
- A change that alters a public API, an error message or user-visible behavior updates the affected docs in the same change, and the PR / commit says which ones. Error message text lives only in [`reference/errors.md`](reference/errors.md).
