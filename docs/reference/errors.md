# Error reference

> **Conclusion**: `ConfigError` has eight variants. Every message names the key and, where it applies, the expected and actual values.
> **Authority**: Normative — variant fields and `Show` text follow this document; the enum and its implementation are in `core/error.mbt`.
> **Out of scope**: How extraction maps standard-library JSON errors is in [extract.md](../design/extract.md#error-messages); validation rules are in [validate.md](../design/validate.md).

`ConfigError` is the only error type that crosses the library boundary. Getters, extraction, sources, formats and validation all raise it, so callers catch one type.

`to_string()` / `Show` is the only supported message format. The table is the index; the sections below give the exact fields, trigger conditions and message text.

| Variant | Fields | Raised when |
|---|---|---|
| [`MissingKey`](#missingkey) | `path` | No source provides the path |
| [`TypeMismatch`](#typemismatch) | `path`, `expected`, `actual` | The value exists but its shape differs from the requested type |
| [`ParseError`](#parseerror) | `message` | A format cannot parse the bytes, or a literal is invalid |
| [`IoError`](#ioerror) | `message` | External data cannot be read |
| [`MergeConflict`](#mergeconflict) | `path`, `left`, `right` | A merge would combine incompatible types; reserved |
| [`InvalidValue`](#invalidvalue) | `path`, `expected`, `actual` | A validation rule fails |
| [`UnknownKey`](#unknownkey) | `path` | Validation finds a key outside the allowed list |
| [`UnknownFormat`](#unknownformat) | `name`, `suffixes` | Format detection recognizes neither the suffix nor the content |

## MissingKey

Fields: `path` (the dotted key path).

No source provides the path. `get_*`, the `FromConfig` getters, validation rules and extraction all report it; none of them substitutes a default. Defaults belong to a `MemorySource`.

```text
missing key 'db.host': no source provides it
```

## TypeMismatch

Fields: `path`, `expected`, `actual`.

The path exists, but the value's shape differs from the requested type. `expected` and `actual` are shape names: `Str`, `Int`, `Bool`, `Float`, `Bytes`, `Array` or `Table`. The library never converts a string to a number or the reverse.

```text
key 'db.port': expected Int, got Str
```

## ParseError

Fields: `message` (the underlying detail, already formatted).

A format cannot parse the bytes, type inference fails, an integer exceeds its range, or a command-line / environment literal is invalid. Sources may prefix the message with the argument or file they were reading; `ParseError` stays the variant.

```text
parse error: Invalid character 'o' at line 1, column 1
parse error: integer 99999999999999999999 exceeds Int64 range
```

## IoError

Fields: `message` (the path and the underlying reason).

External data cannot be read: a missing file, a permission problem, or a failed environment read. A read that succeeds but whose bytes cannot be parsed is a `ParseError`, not an `IoError`. The `read error:` prefix and the quoted path are the library's; the reason after the path comes from the platform's IO error.

```text
read error: file 'config/app.json': No such file or directory
```

## MergeConflict

Fields: `path`, `left`, `right` (the two type names).

Reserved variant. Current merge rules overwrite values instead of detecting type conflicts, so no code path raises it. It stays in the enum so a future strict merge rule has a stable shape.

```text
merge conflict at key 'db': Table vs Str
```

## InvalidValue

Fields: `path`, `expected` (the constraint), `actual` (the supplied value or shape).

A validation rule fails. Built-in rules supply `1..65535`, `1..64 characters`, `debug / info / warn / error`, or a shape name on type mismatch. A custom rule supplies its own `actual`; password-like fields should return a length or shape, never the original value.

```text
invalid value for key 'db.port': expected 1..65535, got 70000
invalid value for key 'db.user': expected 1..64 characters, got 0 characters
invalid value for key 'log.level': expected debug / info / warn / error, got verbose
```

## UnknownKey

Fields: `path` (the full path of the unexpected key).

Validation finds a key that is not in the list passed to `Rule::allowed_keys`. The check is per path, not a global scan; nested tables need one rule per level.

```text
key 'db.extra' is not allowed
```

## UnknownFormat

Fields: `name` (the file name or source label), `suffixes` (the suffixes declared by the candidates).

Format detection finds neither a recognized suffix nor content that matches a candidate. The message always names the input and lists the supported suffixes; detection never guesses a parser and forces a parse.

```text
unknown format for config/notes.txt: suffix not recognized and content matches no candidate; supported suffixes: .json / .toml / .yaml / .yml
```

When no candidate declares suffixes, the list is empty and the message stops after `no candidate`.
