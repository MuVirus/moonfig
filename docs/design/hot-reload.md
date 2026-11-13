# Hot reload

> **Conclusion**: the complete new tree from a reread replaces `current` as a whole; if any step fails, the old config stays in use.
> **Authority**: Normative — snapshot replacement, change detection and failure semantics follow this document; signatures follow `.mbti`.
> **Out of scope**: Full code is in [examples/hot_reload](../../examples/hot_reload/README.md); history is in [decisions.md](../decisions/decisions.md).

## Snapshot

`Config::build` merges all sources into one tree, and later file changes never affect it. `Config::build_live` keeps an extra copy of the source list and merge rule and returns `LiveConfig`; each reread runs `collect` + merge again, producing a complete new tree before replacing `current` as a whole.

Readers always get a complete snapshot and never see a half-merged state. Origin information on the old snapshot is intact too, and is not changed by the new snapshot.

## What counts as a change

`LiveConfig` tracks file sources only:

- A re-readable `Locator` comes from `Source::raw_locator`; what is tracked is the source list, not the final merged tree. Files overwritten by later sources must also be able to trigger a reread, otherwise editing an underlying file would have no effect. See [sources.md](sources.md#origin-tracking).
- Compare the bytes read by `Locator::read`, not mtime. Configs are tiny, and comparing content directly is the most robust; an editor's "write a temp file then rename" does not cause false positives either.
- Environment variables, the command line and in-memory sources have no reliable change events, so they can only be reloaded manually with `reload()`.

`build_live` records the file baseline before merging the first snapshot. So if a file changes during construction, the next `poll` still sees the difference, and there is no window where "the snapshot is already the new content while `current` is still the old content".

## One reload

1. Reread the snapshot bytes of all sources.
2. Run `collect` again and merge with the original `MergeRule`.
3. If the caller supplied a rule table, validate first.
4. Only when everything succeeds, replace `current` and advance the snapshot baseline.

If any step fails, `current` stays put and the old config keeps working; the snapshot baseline does not advance either, so the next `poll()` keeps trying. `reload()` throws the error to the caller, and `Watcher` hands it to `on_error`.

The caller passes validation rules as needed, e.g. `live.reload(rules=[Rule::int_range("db.port", 1L, 65535L)])`. Without them only reading and merging happen.

## Who polls

`watch` in `hot_reload/` only registers the `LiveConfig`, callbacks and suggested interval, and returns a `Watcher`. The actual round of detection is driven by the caller through `Watcher::poll()`:

- Returns `true` when a change was detected and a reload attempted; returns `false` when the reload failed, with the error going to `on_error`.
- `false` also means the files did not change, the watcher has stopped, or the reload failed.
- The snapshot is replaced before callbacks run, so `live.current()` inside `on_change` is already the new value.
- A callback's own error is only reported and never rolls the new snapshot back.
- After `stop()` there is no more detection and no more callbacks.

The library builds in no timer: putting one in would mean choosing an async runtime on the caller's behalf, and runtimes differ per target. `interval` is only a suggestion; the caller can use its own timer, event loop or manual trigger. When OS file events are added later, `watch` usage can stay the same.

## Failures and boundaries

- Only the current snapshot is kept, with no history; on failure it is "keep using the old one", not "roll back to the previous version".
- No multi-file transactional rollback: each file source is reread through its own `Locator`, and the switch happens only when merging succeeds.
- Environment variables and the command line are not watched, because there are no reliable change events.
- Validation is not forced when a change is detected; rules come from the caller.

## Location

| Thing | Location | Reason |
|---|---|---|
| `LiveConfig`, `build_live`, `reload`, `poll` | [`core/live.mbt`](../../core/live.mbt) | needs `Config`'s private fields; file reads go through `Locator`, never platform APIs directly |
| `Watcher`, `watch` | [`hot_reload/`](../../hot_reload/) | callback and polling handle, bound to no runtime |
| OS file events | a future native subpackage | inotify / kqueue / ReadDirectoryChangesW need platform FFI |

`core/` stays free of platform code; `hot_reload/` depends only on `core` and the standard library and compiles on every target.

## Example

[examples/hot_reload](../../examples/hot_reload/README.md) walks through the four steps "unchanged → updated → broken config → fixed" with one manual `poll`. Related: [design.md](design.md#3-config-object-and-getters) explains merging and getters, [sources.md](sources.md) explains `Source` / `Locator`.
