# guides guide

`guides/` covers "the steps to accomplish X", one task per article. Design trade-offs go in `design/`, runnable proof goes in `examples/`.

## Files

- [`layer-sources.md`](layer-sources.md) — layer defaults, files, environment variables and the command line into one configuration
- [`choose-extraction.md`](choose-extraction.md) — choose one of `FromConfig` / serde / `derive(FromJson)`

## Rules

- Five fixed sections, in this order: when to use it, prerequisites, completion criteria, steps, common pitfalls and next steps.
- Keep one article to about 80 lines; content that cannot state "completion criteria" is not a task, put it in `design/`.
- Use numbered steps; code snippets are illustrative only, link to `examples/` for the complete code.
- Explain terminology that affects following along (such as `Getter`, `Int64Text`) in one sentence where it first appears; link background terms to `design/`, do not copy the whole glossary.
- Do not copy API tables, error tables or design trade-offs; link to `design/` when needed.
- When this file conflicts with `design/`, `design/` wins, and fix the guide.
- Register new files in this file.
