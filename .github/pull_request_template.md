## Summary

<!-- What changed, and why. Link the issue when there is one. -->

## Doc impact

<!-- Public API, error messages or user-visible behaviour changed? Name the documents updated. Write "none" only when no user-visible surface changed. -->

- [ ] Public API changed: updated `docs/design/` (and the `.mbti` diff is expected)
- [ ] Error message changed: updated `docs/reference/errors.md` and `errors.zh.md`
- [ ] User-visible behaviour changed: updated `README.mbt.md` / `README_ZH.md`, `docs/guides/` or `examples/`
- [ ] No user-visible change

Documents updated:

<!-- List the paths, or write "none" with the reason. -->

## Checks

- [ ] `moonx scripts/check-docs.mbtx`
- [ ] `moon fmt --check`
- [ ] `moon check --target all --deny-warn`
- [ ] `moon test --target all --deny-warn`
