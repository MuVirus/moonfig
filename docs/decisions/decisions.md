# Decision records

Things already hit and settled. Measured data states its source; conclusions state
their cost.

## Index

There are only four statuses: **active**, **partially superseded**,
**superseded**, **withdrawn**. The supersession relation goes in parentheses in
the status, e.g. `active (supersedes #11)`; the body only records the reasoning
and cost at the time. `Affected docs` lists the documents that still cite this
conclusion, with paths relative to `docs/`; pure implementation conventions write
`none (implementation only)`.

| ID | Decision | Status | Affected docs |
|---|---|---|---|
| #1 | Package names cannot collide with MoonBit standard library package names | active | design/sources.md |
| #2 | Methods cannot cross packages | active | design/sources.md, design/extract.md |
| #3 | Add a `Bytes` branch to `Value` | active | design/design.md, design/sources.md |
| #4 | Boundaries of JSON numbers | active | design/extract.md |
| #5 | Choosing a CBOR library | active | design/sources.md |
| #6 | Origin tracking and merge rules | active | design/design.md, design/sources.md, guides/layer-sources.md |
| #7 | The three sources: file, environment variables, command line | active | design/sources.md, design/cli-args.md, guides/layer-sources.md |
| #8 | `String::compare` compares length first | active | none (implementation only) |
| #9 | Validation | active | design/validate.md |
| #10 | Float widening and snapshots with origins | active | design/design.md, design/sources.md |
| #11 | Hand-written `FromConfig` instead of derive labels | partially superseded (#13 changes the default extraction order) | design/from_config.md, design/extract.md, guides/choose-extraction.md |
| #12 | serde integration in its own package, not in core | partially superseded (#15 moves `serde_bridge` into its own module) | design/extract.md |
| #13 | Default order of extraction paths | active (supersedes #11's default order) | design/from_config.md, design/extract.md, guides/choose-extraction.md |
| #14 | `derive(FromJson)` extraction is experimental | active | design/extract.md, design/from_config.md, guides/choose-extraction.md |
| #15 | Third-party parsers live in separate modules, not packages | active (supersedes #12's package placement) | design/sources.md, design/extract.md, plan/roadmap.md |

## 1. Package names cannot collide with MoonBit standard library package names

Status: active | Affects: design/sources.md

> **Measured 2026-09: a package name cannot collide with a MoonBit standard
> library package, and changing the import alias does not save it.**
> The format package was originally called `json/`, and when it later moved into
> `core/source/` it was tried as `json/` again; both attempts failed. The package
> name itself occupies a global name: when your own package is called `json`,
> `moonbitlang/core/json` cannot be loaded at all
> (`Package "json" not found in the loaded packages`), and its self-references
> such as `@json.JsonPath` in its `.mbti` break with it. Writing the standard
> library import as `@corejson` does not help either — the conflict happens at
> the package name, not at the alias. Conclusion: always suffix package names to
> avoid collisions (`env` would collide with `moonbitlang/core/env`, and `file`
> will collide with something eventually). The suffix states what the package
> provides: `_format` for format packages, `_source` for Source packages.
> In 2026-10 the format packages changed to provide only `Format`, so the suffix
> moved from `_source` to `_format`; the collision conclusion is unchanged.

## 2. Methods cannot cross packages

Status: active | Affects: design/sources.md, design/extract.md

> **Measured 2026-09: methods cannot cross packages.**
> Adding a method for another package's type across a package boundary reports
> `4059: Cannot define method for foreign type`.
> So `Value::to_json` → `to_json(v)`, `Config::extract` → `extract_from(cfg, path)`.
> Free functions are unaffected (`extract(v)` was a free function all along).
> When designing new APIs, think ahead about which functions may need to cross
> packages later — **if a free function works, do not use a method**.

## 3. Add a `Bytes` branch to `Value`

Status: active | Affects: design/design.md, design/sources.md

> **Decided 2026-10: add a `Bytes` branch to `Value`.**
> CBOR is the first format that produces byte strings, and `Value` had nowhere to
> put a byte string. The mechanical cost of adding the branch is low: only two
> places in the whole library match exhaustively on `ValueKind`
> (`ValueKind::name` and `to_json`); `merge` / `get_path` / the various `get_*`
> only match the shapes they care about and need no change. Only with it does
> `Value` really cover the values of every format, and the main line "extract
> into a struct" is not broken — a `Bytes` field in a struct can be extracted
> as-is.

## 4. Boundaries of JSON numbers

Status: active | Affects: design/extract.md

| Measured | Result | Impact |
|---|---|---|
| `@json.parse("9007199254740993")` | `Number(9007199254740992, repr=Some(9007199254740993))` | outside the exact integer range, `repr` keeps the original text, and large integers are restored from it |
| `@json.parse("30")` / `@json.parse("1.5")` (default) | `repr` is `None` for both | by default the original text is not kept, so integer and float cannot be told apart by spelling |
| `@json.parse("1.0", preserve_number_repr=true)` | `Number(1.0, repr=Some("1.0"))` | with the option on, every number has its original text, so routing by spelling works |
| `@json.from_json(@json.parse("\"1.5\""))` to `Double` | fails with `Double::from_json: expected number` | the Json layer cannot convert strings to numbers automatically |
| `@json.from_json(@json.parse("\"true\""))` to `Bool` | fails with `Bool::from_json: expected boolean` | same as above |
| `@json.from_json(@json.parse("5432.7"))` to `Int` | the standard library succeeds, yielding `5432` | **the standard library truncates silently**; `extract` uses a `"NaN"` probe to turn this into `TypeMismatch` |

> **Correction 2026-10: use `preserve_number_repr=true` to keep the spelling of
> every number**
>
> The core library used to fill `repr` only when a value went beyond `Double`'s
> exact range, so numbers such as `1.0` and `1e2` — integer in value, float in
> spelling — had no original text and could only be inferred back as `Int` from
> the value. `@json.parse` now supports `preserve_number_repr=true`, and
> `JsonFormat::decode` turns it on directly, so the original text of every number
> is in `repr`:
>
> - `repr` has integer shape (no decimal point, no `e` / `E`) → parse exactly as `Int64`
> - any other shape → `Float`, including `1.0`, `1e2`, `-0.0`
> - `repr` missing (only possible for a hand-built `Json`) → treat as `Float`
>
> This way float sources no longer leak into `Int` / `Int64Text` fields, at the
> cost of storing the original text of every number while parsing. `5432` is
> still `Int`, and `get_int` is unaffected.

## 5. Choosing a CBOR library

Status: active | Affects: design/sources.md

| Measured | Result | Impact |
|---|---|---|
| CBOR library in the registry | `mizchi/cbor` (most downloads) uses the old `moon.mod.json`, and the current toolchain refuses to install it | the choice is limited to `2515050242/cbor` (pure MoonBit, zero transitive dependencies, complete RFC 8949) and `f4ah6o/simple-webauthn/cbor` (also zero dependencies, but a subset: no half or single precision floats, no indefinite-length containers, and it **silently ignores trailing bytes**) |

## 6. Origin tracking and merge rules

Status: active | Affects: design/design.md, design/sources.md, guides/layer-sources.md

> **Finalized 2026-10: store origin objects, not label strings**
>
> - `Value.origin` has type `&OriginSite?`: each node carries one extra reference
>   and no label. `Value`'s `Eq` / `Debug` only look at `kind`, otherwise values
>   with the same content but different origins would not be equal.
> - `OriginSite` is a core `pub(open) trait`: `kind`, `describe(KeyPath)`,
>   `locator` (default None). `label` is generated on demand only in
>   `Origin::label()`; nothing is parsed back.
> - `KeyPath` is a structured array of segments (`["db", "port"]`); a dotted
>   string is parsed once, only at the API boundary of `origin_of` / `get_path`;
>   `origins()` joins paths directly while traversing.
> - `Source::collect` returns `Layer { value, origin }`, so a layer's value and
>   its site are produced together; `Source::kind` feeds `ByKind` ordering
>   without needing `collect` first.
> - Environment variables and the command line share one site per layer, and the
>   site holds an index "path → original variable/argument name"; `describe(path)`
>   looks it up. `Value` no longer stores a string per leaf.
> - `MemorySource` returns a separate `MemorySite` rather than itself: native's
>   default reference counting (`MOONBIT_TRIAL_DELETION=0`) does not collect
>   cycles, so `MemorySource → Value → &MemorySource` would leak. JS / wasm-gc
>   tracing GC is unaffected.
> - `Value::with_origin(&OriginSite)` is for composite sources (one source reading
>   several files), labelling subtrees with different sites; `attach_origin` only
>   fills in `None` and never overwrites an existing origin.
> - `&T` in MoonBit is a trait object and can only be used for traits; it is not
>   a Rust borrow: there is no lifetime checking, and trait objects are kept alive
>   by GC/RC. `&Path` does not work, since `Path` is a struct.
> - The `SourceId` enum option was not adopted: each variant would still have to
>   store a String, and Env/Cli would still look names up by path; a trait-object
>   site solves both at once.
> - `ConfigError::MergeConflict` currently has no code path that throws it: all
>   three merge rules overwrite and do no type-conflict detection. The variant is
>   kept for validation work later.
> - `StringSource` / `BytesSource` map to `SourceKind::Custom` with labels
>   `string` / `bytes`. They are neither files nor environment variables; giving
>   `ByKind` an explicit tier is clearer than forcing them into `Memory`.
> - `ByKind(order)` arrays list kinds from highest to lowest priority; unlisted
>   kinds come last. The implementation processes sources from **lowest to
>   highest** priority and then merges with `LastWins` — within one tier, later
>   still wins.
> - `Custom(fn)` receives "the already merged part" and "the next layer" and
>   returns a new part. Origins are already attached to values, and a custom
>   function is responsible for keeping them.
> - `Config::origin_of` / `origins` keep `raise ConfigError`: without `build()`
>   they merge on the spot, and a source resolution failure must be reported, not
>   swallowed. A missing path returns `None`.
> - Value errors do not carry origins yet (`TypeMismatch` still has three fields);
>   that comes after the error types are extended. For now use `origin_of` to
>   look it up.

## 7. The three sources: file, environment variables, command line

Status: active | Affects: design/sources.md, design/cli-args.md, guides/layer-sources.md

> **Details settled during the 2026-10 implementation**
>
> - New `ConfigError::IoError(String)`: failing to read external data (files,
>   environment variables) is a different thing from "read it but failed to parse
>   it"; mixing the former into `ParseError` would send users to inspect the
>   format. The message starts with `read error:` and names the path or variable.
> - `FileSource`'s path is just `String`, matching the `moonbitlang/x/fs`
>   interface; `FileSource` implements both `OriginSite` and `Locator`:
>   `describe` gives the file path, `locator` is itself, and a `locator` obtained
>   from `origin_of` can call `read()` to read back the same bytes. No separate
>   platform `Path` type was invented — that would drag platform types into core.
> - `@path` can technically go into core (`moon test` and `js` / `wasm-gc` all
>   passed), but `x/path` ships a native stub and platform cfg, which would drag
>   platform dispatch into core; `Path` is only a wrapper around `String`, and
>   `@fs` accepts only `String`. So core keeps `String`; if `FileSource` later
>   really needs `join` / `normalize`, it can use `Path` inside its own package.
> - Environment variables and the command line are not "bytes + format", so type
>   inference cannot be delegated to `Format`. The inference rules live in core's
>   `Value::from_literal`, shared by both packages: `true` / `false` → `Bool`,
>   integers → `Int64` (error when out of range), decimal point or exponent →
>   `Float`, everything else → string. dotenv's inference was not folded in,
>   because it reports errors by line number and merging would lose the line
>   numbers.
> - `Config::attach_origin` only fills nodes without a site. `EnvSite` /
>   `CliSite` build the "path → original name" index in `collect()`, sharing one
>   site per layer; table nodes land on that site too, and `describe` falls back
>   to `env:<prefix>*` / `cli:args` when the lookup fails.
> - `EnvSource` reads only the given prefix; both `_` and `.` count as levels,
>   and names are lowercased. A scalar occupying a level name, or two variables
>   landing on the same path, reports `ParseError` naming both variables —
>   guessing the winner by Map iteration order would make the result depend on
>   the platform. Variables are sorted before processing, so the same environment
>   gives the same result every time.
> - Environment variable case collisions cannot be tested on Windows: the OS is
>   itself case-insensitive, and `set_env_var` simply overwrites the variable of
>   the same name. Collision detection stays in the code and is verified by
>   white-box tests that feed `assign` directly.
> - `CliSource`'s value style must be one of two: `Equals` only accepts
>   `--key=value`, `Separate` only accepts `--key value`, never mixed in one
>   source — supporting both would make `--flag positional` impossible to
>   interpret. Short options must be registered first, repeated arguments are
>   declared explicitly with `with_array`, and positional arguments are mapped
>   with `with_positional` in the order of "non-option arguments"; parsing rules
>   and error boundaries are in [cli-args.md](../design/cli-args.md).
> - Command-line labels contain only the argument name (`cli:--db-password`),
>   never the value: passwords should not leak into logs just because of origin
>   tracking.
> - The new dependency `moonbitlang/x` is written into `moon.mod` by hand rather
>   than via `moon add` (this repository's convention).

## 8. `String::compare` compares length first

Status: active | Affects: none (implementation only)

> **Measured 2026-10: MoonBit's `String::compare` is not lexicographic; strings
> of different lengths are compared by length first.**
> `String::compare("z", "aa") < 0` is true; `["db.host", "log.level",
> "feature.debug"].sort()` yields increasing length order, not alphabetical.
> Impact: any display that "sorts by name" cannot rely on `sort()` directly and
> must compare character by character when lexicographic order is needed. The
> environment variable processing order uses it only to guarantee determinism,
> not as a display order.

## 9. Validation

Status: active | Affects: design/validate.md

> **Details settled during the 2026-10 implementation**
>
> - Two paths: a `Rule` table for keys, a `Validate` trait for structs. Both
>   share `ConfigError` and `check_int_range` / `check_string_len`, instead of
>   each writing its own set.
> - `validate` stops at the first error, consistent with `get_*`; `validate_all`
>   returns `Array[ConfigError]` in the same order as the rule table.
> - Required fields get no separate rule: any rule that cannot get a path reports
>   `MissingKey`, and `get_*` / `extract_from` report it as well.
> - Unknown keys can only be checked by key. `derive(FromJson)` ignores fields the
>   struct does not have and offers no hook, because the struct does not know what
>   is extra outside; `Rule::allowed_keys` checks only when written, so the switch
>   defaults to off. Recursive strict schemas are out of scope for now.
> - New `InvalidValue(path, expected constraint, actual)` and `UnknownKey(path)`.
>   `actual` is supplied by the rule: a type mismatch writes the shape name, a
>   length mismatch writes the length, and custom rules decide for themselves.
>   Rules are responsible for redacting password-like fields; error types do not
>   print the original value.
> - No range variants are added to `get_*`, and no automatic validation via
>   `derive(FromJson)`: the former bloats the API, the latter cannot get field
>   names, constraints and unknown keys. Validation is an explicit step, and the
>   caller decides when to run it and what to do on failure.
> - `Rule` internally stores `(KeyPath, Value) -> ConfigError?`: composite rules
>   (`allowed_keys`) need to append another segment below the path, and returning
>   only a string would not locate the specific key. `Rule::custom` still only
>   lets users return `String?`.

## 10. Float widening and snapshots with origins

Status: active | Affects: design/design.md, design/sources.md

> **Finalized 2026-10: widen integers by default, offer strict mode separately;
> snapshots and `origins()` share the same leaf definition.**
>
> - `get_float` accepts `Int` and calls `to_double()`: an integer can widen to
>   the numeric value of a float field, approximated at float precision beyond
>   2^53. The reverse direction (`Float` → integer) still reports `TypeMismatch`
>   and does not truncate.
> - Callers that need "`Float` only" use `get_float_strict`. Strictness is not
>   the default because `1` in JSON is a legitimate integer, and rejecting it by
>   default would be surprising; widening happens only in the `Int → Float`
>   direction.
> - `Config::snapshot()` returns `Array[Entry]`, each with `path` / `value` /
>   `origin`. Table nodes recurse, arrays count as leaves, using the same
>   traversal as `origins()`, so there are not two definitions of "what counts as
>   a leaf".
> - `origin` is `Origin?`: layers from `Layer::untracked` have no reportable
>   object, so the export keeps `None` instead of faking a label. `origins()`
>   still returns only leaves that have an origin.

## 11. Hand-written `FromConfig` instead of derive labels

Status: partially superseded (#13 changes the default extraction order) | Affects: design/from_config.md, design/extract.md, guides/choose-extraction.md

> **Finalized 2026-11: the second struct extraction path is a hand-written trait
> + `Getter`; neither derive nor external generation.**
>
> - derive(FromJson) has no field-level customization: key names are locked to
>   field names, there are no defaults, and 64-bit values must be wrapped in
>   `Int64Text`. MoonBit supports neither custom derive nor macros (`#derive` is
>   limited to built-in traits; user attributes `#tool.attr(...)` are ignored by
>   the compiler and only feed external code generators that parse the source),
>   and the built-in derive's `fields(x(rename="..."))` is officially marked
>   unstable and has no default values — none of these is a foundation to rely
>   on.
> - So it adopts the `Validate` pattern the repository already has: `pub(open)
>   trait FromConfig` (`from_config(Getter)`), with labels as ordinary string
>   arguments at the call site. Hand-written impls trade boilerplate for
>   per-field control; MoonBit has no reflection, so the field-to-label mapping
>   can only be established at the call site, and the label is written out even
>   when it equals the field name.
> - `Getter` uses the same rules as `get_*` (strict types, errors with the full
>   prefix, `MissingKey` / `TypeMismatch` / range `ParseError`). Defaults apply
>   only when the **key is missing**; an existing key of the wrong type still
>   errors — silently falling back to a default would hide configuration errors.
>   `opt_*` treats both missing and `null` as `None`.
> - `Getter` reads `Value` directly, with no Json round trip and no probe, so it
>   is faster than the derive path; 64-bit fields are natively readable, and
>   `Int64Text` belongs only to the derive path.
> - The two paths mix at the field level via `json_format.json_field`: one field
>   of a hand-written struct can delegate in one line to a sub-struct using
>   derive(FromJson), with the strict probe still in effect. According to the
>   plan at the time, derive(FromJson) was the default and hand-writing was for
>   control; that default order has been adjusted by #13.

## 12. serde integration in its own package, not in core

Status: partially superseded (#15 moves `serde_bridge` into its own module) | Affects: design/extract.md

> **Finalized 2026-11: `serde_bridge` is a root package, and moonfig core does
> not depend on serde.**
>
> - serde (`moonbit-community/serde.mbt@0.3.1`)'s `Deserializer` is a format
>   backend trait, and moonfig's `Value` tree is naturally a self-describing
>   format — write one backend for `Value` and any serde type can be extracted
>   from configuration with zero type-side changes (both hand-written and
>   serde-generator-produced `Deserialize` can be consumed).
> - It lives at the root package rather than `core/format/serde`: it is not a
>   text format (it does not produce `Value`) but an extraction backend; and it
>   avoids adding a third-party dependency to core — core stays dependency-free,
>   and users who do not use serde are not dragged in. Once serde is in
>   moon.mod, every moonfig consumer's dependency tree gains serde and its derive
>   generator's dependencies (parser/async), which is the inherent cost of the
>   feature.
> - Semantics align with serde's own `Value` backend plus moonfig strictness: no
>   string→number conversion at all, bytes accept only `Bytes` nodes, doubles
>   widen integers. Unknown fields are skipped (consistent with serde and the
>   derive path; for strict unknown keys use `Rule::allowed_keys`).
> - `DeError` → `ConfigError` is translated at the entry: `MissingField`→
>   `MissingKey`, `InvalidType`→`TypeMismatch`, `InvalidValue`→`InvalidValue`,
>   with key names prefixed; no new error variants are introduced.
> - serde's field protocol snapshots the Table by cursor: `skip_value` only
>   advances the cursor without parsing, so unknown keys are skipped at zero cost.

## 13. Default order of extraction paths

Status: active (supersedes #11's default order) | Affects: design/from_config.md, design/extract.md, guides/choose-extraction.md

> **Revised 2026-11: `FromConfig` is the default extraction path, and
> `derive(FromJson)` drops to an optional adapter.**
>
> - The core of a general configuration library is multiple sources, merging,
>   validation and origin tracking; extraction is only one exit on the output
>   side and should not let three parallel paths define the library's identity.
> - `FromConfig` lives in core, has zero dependencies, reads `Value` directly, and
>   shares the same semantics as `get_*`; the derive path goes through
>   `Value → Json` and the standard library's `FromJson`, with strictness
>   simulated by probes, so it is not the same set of rules as the other paths
>   and is therefore no longer the default recommendation.
> - The derive path is kept: for types that already implement `FromJson` it is a
>   zero-boilerplate entry, and its cost is isolated by the `json_format` package
>   boundary. Documentation no longer puts it on par with `FromConfig`.

## 14. `derive(FromJson)` extraction is experimental

Status: active | Affects: design/extract.md, design/from_config.md, guides/choose-extraction.md

> **2026-11: keep `derive(FromJson)` extraction, but mark it experimental.**
>
> - The path goes `Value → Json → FromJson`, so strictness has to be rebuilt with
>   probes: floats become `"NaN"` to catch truncation, strings become markers to
>   catch implicit number parsing, and `Bytes` needs a reverse probe. 64-bit
>   fields also need the `Int64Text` wrapper.
> - The probes and the type mapping are measured in
>   `core/format/json_format/extract.mbt` and `benchmarks/README.md`; they may
>   change while the rules settle. The entry points carry
>   `#alert(experimental, ...)`, so users see `alert_experimental` and can
>   disable it with `warnings = "-alert_experimental"` in `moon.pkg`.
> - The default stays `FromConfig` (#13); the experimental label does not remove
>   the path.

## 15. Third-party parsers live in separate modules, not packages

Status: active (supersedes #12's package placement) | Affects: design/sources.md, design/extract.md, plan/roadmap.md

> **2026-11: TOML, YAML, XML, CBOR and serde move to `MuVirus/moonfig-*`
> modules; the root module keeps only `moonbitlang/x`.**
>
> - A MoonBit module's dependencies are the union of the imports of all its
>   packages; there are no optional or feature-gated dependencies. Keeping the
>   adapters as packages under `MuVirus/moonfig` therefore made every consumer
>   download every parser, however little of it they used. Measured with
>   `moon tree` after the split: the root module resolves to `moonbitlang/x`
>   only, while `MuVirus/moonfig-toml` pulls `moonbit-community/toml` and
>   `bobzhang/lexer` — the isolation is real, not a package rename.
> - Layout follows `Milky2018/wasmoon`: the repository root is a pure
>   `moon.work` workspace with no module of its own, and every module lives in
>   `modules/` — `modules/moonfig` (`MuVirus/moonfig`), one
>   `modules/moonfig-<name>/` per adapter (`-toml`, `-yaml`, `-xml`, `-cbor`,
>   `-serde`), plus `examples/` and `benchmarks/` as workspace members for
>   runnable code. Because there is no root module, no member source can leak
>   into the main module's tarball, and no `.moonignore` is needed; package paths
>   are module-relative, so moving a module into `modules/` changes no import.
> - serde is not a format — it consumes `Value` instead of producing it — so
>   `serde_bridge` sits in `modules/moonfig-serde/` next to, not inside, the
>   four format modules. The root README stays at the repository root as the
>   GitHub landing page; the main module carries its own `README.mbt.md` for the
>   mooncakes page.
> - Cost: the import paths break. `MuVirus/moonfig/core/format/toml_format`
>   becomes `MuVirus/moonfig-toml/toml_format` (likewise yaml, xml, cbor), and
>   `MuVirus/moonfig/serde_bridge` becomes
>   `MuVirus/moonfig-serde/serde_bridge`; users must `moon add` the adapter
>   module. CI still runs the serde generator over `examples/serde_extract`
>   unchanged.
