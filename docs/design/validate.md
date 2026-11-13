# Validation

> **Conclusion**: validation is an explicit step: by key use the `Rule` rule table, by struct use `Validate`, and both share `ConfigError`.
> **Authority**: Normative — rules, unknown keys and error shapes follow this document; signatures follow `.mbti`.
> **Out of scope**: Full code is in [examples/validate](../../examples/validate/README.md); history is in [decisions.md](../decisions/decisions.md).

Read the config in and verify it once, so problems surface at startup instead of halfway through business code.

Two paths share the same rules and errors:

- **By key**: `Config` has no field declarations, so a rule table lists paths and constraints explicitly.
- **By struct**: the fields are already in the struct, constraints go in the `Validate` impl, and run right after extraction.

The two paths do not replace each other: a handful of keys to check → by key; constraints mapping one-to-one to fields → `Validate`.

## By key

```moonbit
cfg.validate([
  Rule::int_range("db.port", 1L, 65535L),
  Rule::string_len("db.user", 1, 64),
  Rule::one_of("log.level", ["debug", "info", "warn", "error"]),
  Rule::allowed_keys("db", ["host", "port", "user"]),
])
```

`validate` stops at the first error, the same as `get_*`; use `validate_all` to list them all, returning
`Array[ConfigError]` in rule-table order. Both carry `raise`: without `build()` they merge on the spot, and read or parse failures must be reported.

Required fields need no separate rule: any rule that cannot find its path raises `MissingKey`. `get_*` and `extract_from`
report it too.

Beyond built-in rules, use `Rule::custom`: returning `None` passes, `Some(actual value)` fails. The `actual value` goes into the error message;
for fields such as passwords write only the length or type, never return the value verbatim.

## Structs

```moonbit
impl @config.Validate for DbCfg with fn validate(self, prefix) {
  @config.check_int_range(prefix.add("port"), self.port.to_int64(), 1L, 65535L)
  @config.check_string_len(prefix.add("user"), self.user, 1, 64)
}

let db : DbCfg = extract_validated_from(cfg, "db")
```

`extract_validated_from` first goes through `extract_from`, then calls the struct's own `Validate`. `prefix` is the
starting path at extraction time; appending the field name gives the full path, so error messages match key-based validation.

## Unknown keys

`derive(FromJson)` ignores fields the struct does not have and offers no unknown-field hook, so a struct cannot know what extra
keys exist around it. Unknown keys can only be checked by key:

```moonbit
Rule::allowed_keys("db", ["host", "port", "user"])
```

If omitted, no check happens: the switch defaults to off. Nested structures need `allowed_keys` layer by layer; recursive strict schema is not done yet.

## Errors

Validation raises two variants: `InvalidValue(path, expected, actual)` when a value violates a constraint, and `UnknownKey(path)` when a key outside the allowed list appears. Fields, trigger conditions and exact messages are in [errors.md](../reference/errors.md#invalidvalue) and [errors.md](../reference/errors.md#unknownkey).

`actual` is supplied by the rule: the shape name (`Str`) on type mismatch, the length on length mismatch, and custom rules decide for themselves.
Error messages never print the original value of password-like fields.

## Boundaries

- Validation reads only the merged result and does not change values; fixing values belongs at the Source layer.
- A validation failure does not automatically fall back to the old config; on hot reload whether to keep the old config is up to the caller.
- No `get_int_range`-style variants on each `get_*`: the API would bloat, and the same config would be checked over and over.
- No automatic validation through `derive(FromJson)`: it derives a standard-library trait with no access to field names, constraints or unknown keys.
- No reflection / schema auto-mapping: MoonBit has no macros, so a field list must still be written by hand; writing `Validate` directly is better.

A complete runnable example is in [`examples/validate`](../../examples/validate/README.md).
