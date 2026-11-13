# conventions guide

Project conventions cover "how to do things" and are aimed at contributors.

## Files

- [`testing.md`](testing.md) — how to write tests: the four kinds of tests, dependency sections, `mbt check`, selection rules
- [`docs.md`](docs.md) — documentation checks: script usage, checks, scan scope, steps for adding a check

## Rules

- Write only practices that are used repeatedly; one-off operations go in `guides/` or a script.
- When a convention changes, the check script and CI must change with it.
- Register new files in this file.
