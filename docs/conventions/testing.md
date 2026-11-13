# Testing conventions

## 1. Four ways to write MoonBit tests

| Name | How it is written | What it can see | Purpose |
|---|---|---|---|
| Inline test | Written in a normal `.mbt` file, right next to the function under test | Every member in the package, including private ones | Lives in the same file as the code under test, no file switching while changing it |
| White-box test | Written in `_wbtest.mbt` | Every member in the package, including private ones | Tests internal implementation, uses private functions or fields |
| Black-box test | Written in `_test.mbt` | Only the `pub` public API | Tests the public API from a user's point of view |
| Doc example | Written in the `///` comment of a public function | Every member in the package, including private ones | Both an example in the docs and a test that runs |

The first three all use the `test { }` syntax; the only difference is where they live. The fourth (doc example) is covered in section 3.

---

## 2. Test package dependency configuration in `moon.pkg`

`_test.mbt` and `_wbtest.mbt` are two separate packages, each with its own `import` section. Dependencies used by test code must be written in the matching section:

```text
import {
  "MuVirus/moonfig/core" @config,
} for "test"

import {
  "moonbitlang/core/double",
} for "wbtest"
```

- Dependencies in the `for "test"` section can be used by `_test.mbt`
- Dependencies in the `for "wbtest"` section can be used by `_wbtest.mbt`
- Dependencies used by normal `.mbt` files go in the top `import` block without `for`

Writing a dependency in the wrong section reports the `0071` not-imported error.

---

## 3. `mbt check` examples in doc comments

A code block in a doc comment can be marked `mbt check`, meaning the code takes part in compilation and execution.

````moonbit
///|
/// Builds a `MemorySource` from a `Value`
///
/// Example:
///
/// ```mbt check
/// test {
///   let cfg = Config::new()
///     .add(MemorySource::new(Value::table({ "debug": Value::bool(false) })))
///     .build()
///   assert_false(cfg.get_bool("debug"))
/// }
/// ```
pub fn MemorySource::new(table : Value) -> MemorySource {
````

It is written as `test { }`, so it does three things at once:

1. **It renders into the generated docs** — users see a runnable usage directly on the API page
2. **It is type-checked** — when the API signature changes, the example immediately reports `4014`
3. **It is actually executed** — when an assertion in the example breaks, `moon test` immediately reports FAILED

Items 2 and 3 are what a plain prose comment cannot do. **Prose examples written in docs go stale**: after the API changes, that code is still old and nobody notices. An `mbt check` example does not go stale, because it is checked by the same mechanism as real tests.

### 3.1 `mbt nocheck`

`mbt nocheck` is another marker, meaning this doc code **takes no part in validation** and is shown only as an example.

Use it when the code does not compile in the context of the current package. The typical case is a user-side snippet that carries `import` — the library's own package does not have those dependencies:

````moonbit
/// ```mbt nocheck
/// import {
///   "MuVirus/moonfig/core" @config,
/// }
/// ```
````

The snippets in the README fall into this case, so the README uses `nocheck`.

---

## 4. Selection rules

```text
What is this code about?
│
├─ How to use this public API ────────► doc comment + ```mbt check
│                                      (both example and test, and it goes into the docs)
│
├─ Is the internal logic correct (involves private functions) ──► _wbtest.mbt
│                                      (grouped scenarios: error branches, boundaries, regressions)
│
├─ Can users use it (touches only pub API) ──► _test.mbt
│                                      (complete usage from the user's point of view)
│
└─ Add a test for a small function ───► inline in .mbt
                                       (rare, not used in this project)
```

**Always use doc examples for public API, never inline tests.** Because a doc example can do everything an inline test can, and it is additionally visible in the docs. Inline tests do not have this advantage.

---

## Appendix

### Black box and white box

Black-box testing: treat the code under test as an opaque box and test it only through its public interface, without looking at the internal implementation.
White-box testing: open the box and look at the internal implementation, with direct access to private functions and private fields.

MoonBit compiles these two kinds of tests into two separate packages:

- `_wbtest.mbt` → the white-box test package, which can see everything in the package, including private functions and private fields
- `_test.mbt` → the black-box test package, which can see only `pub` things

The point of the distinction is that black-box tests catch a class of problem: once you change the function under test from `pub` to `priv`, or rename it, a test that only runs in `_wbtest.mbt` does not report an error, but users can no longer use that API. Black-box tests use the public API, so they catch this kind of breakage early.
