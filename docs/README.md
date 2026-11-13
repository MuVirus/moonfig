# moonfig documentation

Documentation entry point. For what the project is and how to install it, see [README](../README.mbt.md).

## Read by situation

| Where you are now | Start here |
|---|---|
| First time here, want to get it running | [Minimal example](../README.mbt.md#minimal-example) → [Layer multiple sources](guides/layer-sources.md) |
| Want to read the configuration into a struct | [Extract into a struct: choose one of three](guides/choose-extraction.md) |
| Look up the complete code for a feature | [Examples](../examples/README.md) |
| Look up an exact error message | [Error reference](reference/errors.md) |
| Changing code, check the module boundaries first | [Code areas and docs](#code-areas-and-docs) |
| Writing or editing docs | [Documentation checks](conventions/docs.md), [Writing rules](AGENTS.md) |

## Core concepts

Configuration comes from **Source**s (in-memory defaults, files, environment variables, the command line), and a **Format** parses it into a uniform **Value** tree; `Config` merges the layers into one configuration according to a **MergeRule**, then reads it by key or into a struct.
Origin tracking records which layer a value came from; hot reload polls files and keeps the old configuration when a reload fails.

The extended explanation and trade-offs are in `design/`; to find docs by code, see [Code areas and docs](#code-areas-and-docs).

## Code areas and docs

| Code | Read first |
|---|---|
| `core/` | [design.md](design/design.md) |
| `core/format/*_format/` | [sources.md](design/sources.md), [format-detect.md](design/format-detect.md) |
| `file_source/`, `env_source/`, `cli_source/` | [sources.md](design/sources.md), [cli-args.md](design/cli-args.md) |
| `format_detect/` | [format-detect.md](design/format-detect.md) |
| `hot_reload/` | [hot-reload.md](design/hot-reload.md) |
| `serde_bridge/`, `FromConfig` | [extract.md](design/extract.md) |
| Validation | [validate.md](design/validate.md) |
| `core/error.mbt`, error messages | [errors.md](reference/errors.md) |
| `examples/` | [examples/README.md](../examples/README.md) |
| `scripts/` | [conventions/docs.md](conventions/docs.md) |

## Directories

- `guides/` — task-oriented steps
- `design/` — why it is designed this way
- `decisions/` — why it was decided that way at the time
- `plan/` — what comes next
- `conventions/` — how contributors work
- `reference/` — lookup tables for concrete shapes
- Subdirectory index and writing rules: [AGENTS.md](AGENTS.md)
