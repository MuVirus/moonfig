# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## What this project is

`moonfig` is a general-purpose configuration library for MoonBit. It reads
configuration from many sources and formats, normalizes everything into one
intermediate representation, merges the layers (later sources win), and returns
the result by key or as a struct.

- **Sources.** In-memory tables, config files, environment variables and
  command-line arguments.
- **Formats.** JSON, INI, `.env`, YAML, TOML, XML, CBOR and a plain `Value`
  tree, detected from the file extension or the content.
- **Read paths.** `get_*` by key, or extraction into your own struct.
- **Beyond reading.** Hot reload, origin tracking and validation.

### Design constraints

- **Platform.** `core/` compiles on every target; anything platform-specific
  lives in its own package at the module root.
- **Packages.** Never reuse a core package name; format packages end in
  `_format`, source packages in `_source`.
- **Cross-package calls.** Methods cannot cross packages (`4059`); use free
  functions such as `to_json(v)`.

### Documentation

Documents live in `docs/`. English is authoritative; every document has a Chinese
copy named `foo.zh.md` next to it. Root pairs are `README.mbt.md` /
`README_ZH.md` and `AGENTS.md` / `AGENTS_ZH.md`.
[`docs/AGENTS.md`](docs/AGENTS.md) lists the subdirectories; each subdirectory
has its own `AGENTS.md` for the files inside. When the two languages disagree,
fix the Chinese copy.

A change that alters a public API, an error message or user-visible behavior
updates the affected docs in the same change, and the PR / commit states it with
a `Doc impact:` line. Error message text lives only in
[`docs/reference/errors.md`](docs/reference/errors.md).

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- Each module directory has a `moon.mod` file listing module metadata.

- The repository root is a `moon.work` workspace and has no `moon.mod` of its
  own. Every module lives under `modules/`: `modules/moonfig` is
  `MuVirus/moonfig`, and each adapter gets `modules/moonfig-<name>/`
  (`-toml`, `-yaml`, `-xml`, `-cbor`, `-serde`). `examples/` and `benchmarks/`
  are workspace members too, but are not published. `moon check` and
  `moon test` at the root cover every member; member-scoped commands such as
  `moon package` and `moon publish` run from the module directory
  (`moon -C modules/moonfig publish`).

- Inside `modules/moonfig`, the core package sits in `core/`; the format
  packages that need no third-party parser (`json_format`, `ini_format`,
  `dotenv_format`) sit in `core/format/`; the file, environment and
  command-line sources sit in `file_source/`, `env_source/` and `cli_source/`.
  Formats that do need a parser are separate modules, not packages: a module's
  dependencies are shared by every package in it, and from there reach every
  consumer. The documents live at the repository root in `docs/`; see
  [`docs/AGENTS.md`](docs/AGENTS.md).

- Tests follow `docs/conventions/testing.md`: examples for public API live in `///` doc
  comments as ` ```mbt check ` blocks, private logic goes into `_wbtest.mbt`,
  public API behaviour goes into `_test.mbt`. This project does not use inline
  tests.

- A pre-commit hook lives in `.githooks/pre-commit`; enable it once per clone
  with `git config core.hooksPath .githooks`.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

- Write import aliases explicitly (`@config`, `@jsonfmt`).

## Tooling

- `moon fmt` is used to format your code properly.

- `moonx scripts/check-docs.mbtx` checks the Markdown tree: indexes, links and
  anchors, decision statuses and their index, design-doc opening lines, English /
  Chinese pairing, code fence languages, examples and the roadmap. It runs on the
  Wasm backend; CI and the pre-commit hook run it too. Usage and each check:
  [docs/conventions/docs.md](docs/conventions/docs.md).

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when
  changes affect outputs, run `moon test --update` to refresh snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. For snapshot tests that record
  structured debugging output, derive `Debug` and use `debug_inspect`, rather
  than deriving `Show` for debugging. For solid, well-defined results (e.g.
  scientific computations), prefer assertion tests. You can use
  `moon coverage analyze > uncovered.log` to see which parts of your code are
  not covered by tests.
