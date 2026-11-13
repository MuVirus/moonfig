# reference guide

Reference pages are lookup tables, not narrative. They give one authoritative place for concrete shapes that many documents would otherwise copy.

## Files

- [`errors.md`](errors.md) — every `ConfigError` variant: fields, trigger conditions, exact message text

## Rules

- Keep one concrete object per page: an error type, an API signature table, an environment variable list.
- A reference page is normative for the object it describes; the implementation in code is the other half of the pair. Link to the code instead of repeating implementation details.
- Every row must be usable without reading the surrounding prose: name the case, the fields, the trigger and the output.
- When the code changes, update the reference page in the same change; other documents link here instead of copying the table.
- Register new files in this file.
