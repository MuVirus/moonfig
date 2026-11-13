# decisions guide

Decision records explain "why it was decided this way at the time". They record
things already hit and settled; long-lived design narrative goes in `design/`.

## Files

- [`decisions.md`](decisions.md) — numbered decision records, the status index at
  the top, and the status line of each decision.

Numbering, status and affected docs follow the index at the top of
[`decisions.md`](decisions.md); this file does not keep a second copy.

## Rules

- Under each numbered heading write one `Status: <status> | Affects: <paths>`
  line; the same row in the top index must match.
- Status is only `active` / `partially superseded` / `superseded` / `withdrawn`;
  the supersession relation goes in parentheses, e.g. `active (supersedes #11)`.
- When a decision is superseded, write `#N` on both sides: the old entry says
  `partially superseded (#N ...)`, the new one says `active (supersedes #N ...)`.
- `Affects` writes paths relative to `docs/`, separated by `,`; pure
  implementation conventions write `none (implementation only)`.
- State the date, the measurement or evidence, and the cost of the conclusion;
  preferences without evidence do not belong here.
- One decision per entry; update the top index after adding an entry.
