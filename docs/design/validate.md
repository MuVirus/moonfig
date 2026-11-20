# Validation

> **Conclusion**: validation is one explicit step after the config is read: a `Rule` states a constraint on one key, a `Validate` impl states the constraints of a struct's fields, and both raise the same `ConfigError` with the same message format.
> **Authority**: Normative — rules, unknown keys and error shapes follow this document; signatures follow `.mbti`.
> **Out of scope**: Full code is in [examples/validate](../../examples/validate/README.md); history is in [decisions.md](../decisions/decisions.md).

Nothing in the type system stops a config from being wrong. `70000` is a perfectly good integer, `"verbose"` is a perfectly good string, and a key nobody reads parses fine. Unchecked, such mistakes show up late: the listener fails to bind, the log level silently falls back, an `extra` key sits there forever. Validation moves that discovery to startup, where "refuse to start" is still a choice.

## Reading is not checking

`get_int("db.port")` answers "what is it", and it is called wherever the value is needed. If it also enforced the range, the same config would be checked again at every call site, and the rule would live wherever the last caller put it. Checking is therefore its own step: the caller decides when it runs, and runs it once.

A constraint can be stated in two ways, because there are two situations: before a struct exists, and after.

## Rule: a constraint as data

`Rule` answers one question: is the value at this path acceptable? A rule is a small value holding a path and a check. It is not a trait and nothing implements it; you build rules with `Rule::int_range`, `Rule::string_len`, `Rule::one_of`, `Rule::allowed_keys` or `Rule::custom`, and hand an array to `Config::validate`:

```moonbit
cfg.validate([
  Rule::int_range("db.port", 1L, 65535L),
  Rule::string_len("db.user", 1, 64),
  Rule::one_of("log.level", ["debug", "info", "warn", "error"]),
  Rule::allowed_keys("db", ["host", "port", "user"]),
])
```

This is the shape for a config nobody has typed: `Config` carries no field declarations, so there is no place to hang a constraint and no place to derive a path from. The rule table is that missing declaration. Being data, it can be a literal, assembled at runtime, or handed to hot reload.

A rule only ever sees the value at its own path. The executor resolves the path against the merged result and hands the value to the check: a missing path raises `MissingKey` before the check runs, so required fields need no separate rule. The rule itself only compares. `Rule::allowed_keys` is the same value applied to a table's key set instead of a single value, which is how unknown keys get caught.

`validate` stops at the first error, the same as `get_*`; `validate_all` returns `Array[ConfigError]` in rule-table order. Both carry `raise`: without `build()` they merge on the spot, and read or parse failures must be reported.

`Rule::custom(path, expected, check)` is the escape hatch: `check : (Value) -> String?` returns `None` to pass or `Some(actual)` to fail, `expected` is the constraint text the message shows, and `actual` lands in the message. For fields such as passwords, return the length or the type, never the value.

## Validate: constraints that follow the type

Once the config is extracted into a struct, the struct is the declaration the rule table had to spell out: names and types are written down, and paths derive from `prefix`. `Validate` is the trait for that case, one method implemented next to the fields:

```moonbit
impl @config.Validate for DbCfg with fn validate(self, prefix) {
  @config.check_int_range(prefix.add("port"), self.port.to_int64(), 1L, 65535L)
  @config.check_string_len(prefix.add("user"), self.user, 1, 64)
}

let db : DbCfg = cfg.get_struct_validated("db")
```

`get_struct_validated` runs `get_struct` first, so the struct is a `FromConfig` type; on the derive path `extract_validated_from(cfg, "db")` runs `extract_from` first. Both then call the struct's own `Validate`, with `prefix` set to where extraction started; appending the field name gives the full path, so messages match key-based validation. `check_int_range` and `check_string_len` are the comparison half of the matching rules — the lookup already happened.

`Validate` is code owned by the type rather than data passed in, and that buys what a rule cannot: the constraint moves with the field when it is renamed, and it can compare fields with each other, because it holds the whole struct.

The two names are close enough to confuse: `Config::validate` takes a rule table, `Validate::validate` is the method on a struct.

## Choosing

A constraint on one key → `Rule`; constraints tied to a struct's fields, or relating two fields → `Validate`. Neither replaces the other: unknown keys are only visible to a rule, and a field-to-field comparison belongs in `Validate`, which already holds both.

## Unknown keys

`derive(FromJson)` ignores fields the struct does not have and offers no unknown-field hook, so a struct cannot know what extra keys exist around it. Unknown keys can only be checked by key:

```moonbit
Rule::allowed_keys("db", ["host", "port", "user"])
```

`allowed_keys` is a `Rule` like the others, so it goes through the same path resolution; if it is not written, no check happens. Nested structures need `allowed_keys` layer by layer; recursive strict schema is not done yet.

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
