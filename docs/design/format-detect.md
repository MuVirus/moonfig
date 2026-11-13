# Automatic format detection

> **Conclusion**: suffix first, then content in candidate order; if nothing looks right, raise `UnknownFormat`; never guess a parser and force it to parse.
> **Authority**: Normative — detection order, duplicate suffixes and `sniff` boundaries follow this document; signatures follow `.mbti`.
> **Out of scope**: Examples are in [examples/format_detect](../../examples/format_detect/README.md); history is in [decisions.md](../decisions/decisions.md).

## Detection order

1. **Known suffix → use the corresponding format.** The suffix is the caller's declaration and has the highest priority; even if the content looks like another format, parse by suffix. If parsing fails, report the error rather than moving to the next candidate, otherwise positions in the error would come from another parser.
2. **No suffix or unknown suffix → look at content in candidate order.** The first format whose `sniff` says "looks like it" wins. The order is the priority; put candidates with strong traits first.
3. **Nothing looks right → raise `UnknownFormat`.** The error message lists the suffixes declared by the candidates, and does not guess a parser to force-parse.

When two candidates claim the same suffix, `Detector::new` errors directly. Letting the order decide the winner would hide a config error until the candidate order changes.

## Boundaries of content detection

`sniff` only answers "does it look like it", not "can it be parsed":

- JSON, CBOR and XML have strong enough traits: the first non-whitespace character, or the CBOR major type of the first byte.
- YAML and TOML can only look at line structure and naturally overlap; candidate order decides who is asked first.
- INI and `.env` are indistinguishable by content; they are recognized only by suffix and take no part in content detection.

Using a full parse to judge format would mix "the content is broken" with "the format is wrong", and would treat one candidate's syntax error as another candidate's failure. `sniff` stays cheap and conservative; real errors are left to the selected parser.

## Interface and location

`Format` provides three self-descriptions in `core/`:

- `suffixes`: list of suffixes without dots, empty by default.
- `sniff`: looks only at the beginning, `false` by default.
- `decode_path`: checks the suffix first when the path is known, otherwise just `decode`.

[`format_detect/`](../../format_detect/) provides `Detector`, which normalizes suffixes, checks duplicate declarations and does content detection in candidate order. It reads no files and depends on no platform API.

The caller supplies the candidate table: core cannot import format packages in reverse, and format packages have no runtime self-registration. So a project using only JSON is not forced to link YAML, XML and CBOR; when a default list is needed, the application imports and assembles it.

[`FileSource::auto`](../../file_source/file_source.mbt) in `file_source/` hands the path and the already-read bytes to `Detector`; ordinary `FileSource::new` still uses the given `Format` directly. `StringSource` / `BytesSource` have no path, so just use `Detector` as a normal `Format`; it only does content detection.

## Example

[examples/format_detect](../../examples/format_detect/README.md) demonstrates suffix priority and content fallback with `.toml`, `.yaml` and a JSON file with an unknown suffix.

Related: [sources.md](sources.md) explains the division between `Format` and `Source`; [roadmap.md](../plan/roadmap.md) records implementation progress.
