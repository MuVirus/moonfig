# Documentation system plan

Records how the documentation system changes step by step. Not a contract; it can
change at any time. Change one step at a time, and move to the next step only
after acceptance passes.

Source: two rounds of discussion in 2026-11 — a review of the existing
documentation system, and whether to add `guides/`.

Status has three levels: ✅ done, 🚧 in progress, ⬜ not started.

## Conclusion

The existing structure (`design/` / `decisions/` / `plan/` / `conventions/` +
skills, plus `reference/` added in Step 4) is right; the problem is governance: principles never became checks, and
drift has already started. The fix has three layers:

1. First make documentation checkable: links, indexes, examples, statuses.
2. Then add a task-organized `guides/` layer.
3. Finally reduce duplicated content that goes stale: snippets, tables. Bilingual
   copies are a deliberate exception: English is authoritative, and the checker
   keeps the structure aligned.

## The four goals

| Goal | What it needs | Corresponding steps |
|---|---|---|
| Continuous development | Documentation checks and "code change → documentation impact" | 1, 4 |
| AI recommendation | Stable indexes, authority boundaries, decision status | 0, 3 |
| Human review | Conclusion first, evidence links, small diffs | 3, 4 |
| Human reading | Human-facing entry, task guides, core concepts | 2 |

## Current state and problems

| Symptom | Impact | Handling |
|---|---|---|
| The roadmap in `README.mbt.md` and the statuses in `plan/roadmap.md` disagree, and the README has three extra directions | People and AI get two facts | Step 0 (README is authoritative, done) |
| `decisions/` has no standalone index, and the decision summary in `docs/AGENTS.md` stops at #9 | AI cannot find the authoritative location | Step 0 (done) |
| `docs/AGENTS.md` mixes subdirectory responsibilities and file indexes | Every new file means changing the root index | Step 0 (done) |
| `decisions.md` #11 and #13 reach opposite conclusions, supported only by a revision sentence at the end | AI retrieves the old conclusion | Step 3 (done) |
| README snippets are all `nocheck`, and some lack `import` | Users copy them and they do not compile; CI cannot catch it | Step 4 |
| The CI examples list is missing `examples/from_config` | New examples are not continuously verified | Step 0 (done) |
| There is no layer for "steps to accomplish X" | Users can only read a 470-line README or the design docs | Step 2 (done) |
| Design docs mix normative and overview material | Reviewers do not know which one is authoritative | Step 3 (done) |

Relative links are now checked automatically by `scripts/check-docs.mbtx` and no
longer depend on manual work.

## Target structure

```text
docs/
  AGENTS.md          # subdirectory responsibilities + navigation
  README.md          # human-facing entry: reading paths, core concepts, code → docs
  guides/            # by task: steps to accomplish X
  design/            # why it is decided this way
  decisions/         # why it was decided this way at the time
  plan/              # what to do next
  conventions/       # how contributors do things
  reference/         # later: stable lookup tables such as the error catalog
```

Each subdirectory has its own `AGENTS.md` listing the files in that directory;
`docs/AGENTS.md` lists only subdirectories.

`docs/README.md` and `reference/` are candidates, not mandated in this round.

## Layer boundaries

| Layer | The question it answers | What it should not contain |
|---|---|---|
| `README` | What this is, how to start | Full task steps, design trade-offs |
| `guides/` | Steps to accomplish X, order, pitfalls | API semantics tables, error catalog, why it is decided this way |
| `examples/` | Minimal runnable proof | Full task orchestration |
| `design/` | Why it is decided this way | Operational steps |
| `decisions/` | Why it was decided this way at the time | Current conclusions |

## Overview

| Step | Content | Status | Acceptance |
|---|---|---|---|
| 0 | Fix drift | ✅ | One fact has only one status or conclusion |
| 1 | Documentation checks | ✅ | Deliberately breaking a link turns CI red |
| 2 | Human entry + guides | ✅ | Two clicks from the README to a task page |
| 3 | Decision status + authority boundaries | ✅ | Reading only the index shows which decisions are still active |
| 4 | Reduce stale content | 🚧 | README snippets are verifiable, errors have one authority |

Suggested order: 0 → 1 → 2 → 3 → 4. 0 and 1 are governance, 2 is a new layer; 3
and 4 can run in parallel with 2. If you want guides to get a trial run first,
you can also do 0 → 2 (write only two articles) → 1 → 3 → 4, with the check
script covering those two articles afterwards.

## Step 0: Fix drift　✅

Goal: do not change the structure, only make existing documents consistent with
each other.

- [x] Take the README's public status as authoritative and update `plan/roadmap.md` (the README is unchanged)
- [x] `docs/AGENTS.md` keeps only subdirectory responsibilities; file indexes move down into each directory's `AGENTS.md`
- [x] `decisions/AGENTS.md` gains the #1–#13 index (step 3 moves the index to the top of `decisions.md`)
- [x] `decisions.md` #11 gains the status line "superseded by #13"
- [x] The CI examples list gains `examples/from_config`
- [x] README snippets get the missing `import`s, or are changed to link to an example (detailed snippets have been changed to example links)

Acceptance: one fact has only one status or conclusion; `moon test` and CI still
pass.

## Step 1: Documentation checks　✅

Goal: turn principles into executable checks.

- [x] `scripts/check-docs.mbtx` (MoonBit, `moonx` runs Wasm, no Node) checks:
  - Whether each directory's `AGENTS.md` lists the files in that directory; whether `docs/AGENTS.md` lists all subdirectories
  - Whether relative links and anchors exist
  - Whether decision numbers are unique and consecutive (status lines are added in step 3)
  - Whether `README.mbt.md` / `README_ZH.md`, `AGENTS.md` / `AGENTS_ZH.md` and each English / `.zh.md` pair are structurally paired
  - Whether every code block declares a language
  - Whether `examples/README.md`, the CI list and the actual directory agree
  - Whether the README roadmap and the statuses in `roadmap.md` agree
- [x] Wired into CI and `.githooks/pre-commit`
- [x] Deliberately broke a link and confirmed the check fails

Usage and each check: [conventions/docs.md](../conventions/docs.md).

Acceptance: CI turns red on documentation drift; the checks themselves finish in
a few seconds.

## Step 2: Human entry + guides　✅

Goal: human readers get task-based entry points.

- [x] `docs/README.md`: reading paths, core concepts, a `code area → docs` table
- [x] `docs/guides/` plus an index; two articles first:
  - [x] `layer-sources.md`: how defaults, files, environment variables and the command line stack
  - [x] `choose-extraction.md`: choosing one of `FromConfig` / serde / `derive(FromJson)`
- [x] Every article has the same five sections: when to use, prerequisites, done criteria, steps, common pitfalls + next steps
- [x] The `write-docs` skill gains `references/guide.md`, and `SKILL.md` links it under "by document type"
- [x] `docs/AGENTS.md` gains `guides/`; `guides/AGENTS.md` states the task-step rules

Constraints:

- One task per article, kept under 80 lines; content that cannot state "done criteria" is not a guide.
- Do not copy API tables, error tables or design trade-offs; link to `design/` or `reference/`.
- Each article links at least one runnable example; code snippets are illustrative only.
- When a guide and a design conflict, the design is authoritative.

Acceptance: a new reader reaches a task page from the README in two clicks; every
guide has done criteria and an example link.

## Step 3: Decision status + authority boundaries　✅

Goal: both humans and AI can quickly tell "which conclusions are still active".

- [x] Add an index table at the top of the decision records: ID / Decision / Status / Affected docs
- [x] Add a status line to each decision, e.g.:
  `Status: active (supersedes #11) | Affects: design/extract.md, guides/choose-extraction.md`
- [x] Superseded decisions state the relation in the status line, not in a parenthesis at the end
- [x] Every design doc opens with three lines: conclusion, authority boundary (whether this doc/table is normative or an overview), out of scope
- [x] Design docs use the present tense throughout; history stays only in `decisions/`
- [x] The check script validates status lines, the top index, supersession relations and the openings of design docs

Constraints:

- The index goes at the top of `decisions.md`; `decisions/AGENTS.md` only lists files and no longer maintains a second numbering table.
- Status is only `active` / `partially superseded` / `superseded` / `withdrawn`; supersession relations must be written on both sides.
- `Affected docs` writes paths relative to `docs/`; the script verifies the files exist; pure implementation conventions write `none (implementation only)`.

Acceptance: reading only the index shows which decisions are still active; a
reviewer can tell whether a table is normative or an overview.

## Step 4: Reduce stale content　✅

Goal: things that change are not copied by hand.

- [x] The README's basic usage keeps only the core path, with details linked to `examples/`
- [x] Move the README's runnable snippets to `examples/` or doc comments; `examples/quick_start` is the complete program, and CI runs all examples and compares their output with `scripts/check-examples.sh`
- [x] `docs/reference/errors.md`: each `ConfigError` variant, trigger conditions, message examples (generated or hand-maintained)
- [x] English strategy: English is authoritative. Every document under `docs/` has a `foo.zh.md` Chinese copy,
  and the root pair is `README.mbt.md` (English) / `README_ZH.md` (Chinese). The checker validates pairing,
  heading levels and code-fence counts; semantic sync stays with review.
- [x] Add **Doc impact** to the PR / commit template: when public APIs, error messages or user-visible behavior change, state which docs were updated

Acceptance: README snippets no longer depend on invisible `import`s; error
messages have exactly one authoritative location.

## Not doing now

- Rewriting all documentation from scratch.
- Machine-translating the Chinese copies; they are maintained by hand.
- Introducing a documentation site generator.
- Adding a changelog to every document (git already has it).

## Undecided

- How to keep the Chinese copies from drifting in meaning beyond the structural checks; currently review.


## Discussion log

- 2026-11-13: Reviewed the existing documentation system; the conclusion was that the structure is right and governance is missing; proposed adding a `guides/` layer; split into steps 0–4.
- 2026-11-13: `docs/AGENTS.md` changed to list only subdirectories, with file indexes moving down into each directory's `AGENTS.md`.
- 2026-11-13: The README roadmap is not changed; the README's public status is authoritative, and `roadmap.md` gains follow-up directions and statuses.
- 2026-11-13: The check script switched to MoonBit `.mbtx` (`scripts/check-docs.mbtx`, `moonx` runs Wasm, file IO via `moonbitlang/x/fs`); wired into CI and pre-commit, and verified to fail with a broken link.
- 2026-11-13: Step 2 landed: added `docs/README.md` and two `guides/` articles (`layer-sources`, `choose-extraction`), with an entry added to the README's documentation section; `write-docs` gains `references/guide.md`, and the README conventions add "task steps go in guides".
- 2026-11-13: The glossary in `docs/README.md` became "core concepts": the entry page only covers the models it actually references (Source / Format / Value / MergeRule) and does not spread out an API vocabulary; deep terms link to `design/` where they first appear.
- 2026-11-13: guides have no separate terminology section; operationally relevant terms (`Getter`, `Int64Text`, `ByKind`) get a one-sentence explanation where they first appear, and the rest link to `design/`.
- 2026-11-13: Step 3 landed: `decisions.md` gains an ID / Decision / Status / Affected docs index at the top, each decision gains a status line, `#11` and `#13` state their supersession relation on both sides; the index moved out of `decisions/AGENTS.md` to avoid two drifting tables.
- 2026-11-13: Design docs uniformly open with three lines "conclusion / authority boundary / out of scope"; the check script validates status lines, index consistency, supersession relations and those three lines.
- 2026-11-13: English becomes authoritative. Every document under `docs/` gets a `foo.zh.md` Chinese copy; the root pair flips to `README.mbt.md` (English) / `README_ZH.md` (Chinese). The checker validates pairing, heading levels and code-fence counts; semantic sync stays with review.
- 2026-11-13: Removed the visible translation pointer from the top of every document; it hurt the first screen and duplicated the language switcher. Pairing still follows the file names, and English remains authoritative.
- 2026-11-13: Step 4 landed: `examples/quick_start` became the complete README minimal program; `scripts/check-examples.sh` compares every example's stdout with its README output block; `docs/reference/errors.md` became the single authority for `ConfigError` messages; PR / commit templates gained a **Doc impact** line.
