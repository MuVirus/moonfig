# 文档检查

[`scripts/check-docs.mbtx`](../../scripts/check-docs.mbtx) 把文档维护规则变成可执行检查。
CI 和 pre-commit 都会跑它，本地也可以手动跑。

## 运行

```sh
moonx scripts/check-docs.mbtx
moonx scripts/check-docs.mbtx --help
```

在仓库根目录运行。`moonx` 走 Wasm 后端，文件 IO 由 `moonbitlang/x/fs` 提供，
不需要 native 工具链。

## 检查什么

| 检查 | 规则 | 失败时 |
|---|---|---|
| 目录索引 | `docs/AGENTS.md` 登记所有直接子目录；每个子目录的 `AGENTS.md` 登记本目录的英文 `.md` 文件（`.zh.md` 副本免登记） | 在对应 `AGENTS.md` 补一行 |
| 链接与锚点 | 相对链接存在；`#锚点` 能匹配目标文件的标题 | 改链接或改标题；外部 URL 不检查 |
| 决策状态 | `decisions.md` 的二级标题从 `## 1.` 连续递增；顶部索引的 ID / 结论 / 状态 / 影响文档分别和标题、每条决策的 `Status: ... \| Affects: ...` 行一致 | 补状态行或索引 |
| 取代关系 | 被取代的决策在状态里写 `#N`；`#N` 的状态必须是 `active` 或 `partially superseded`，并在自己的状态里反向点名 | 补齐两边的状态行 |
| 设计文档开头 | `docs/design/*.md`（`AGENTS.md` 和 `.zh.md` 除外）前 12 行有 `Conclusion` / `Authority` / `Out of scope` 三行 | 补开头三行 |
| 翻译配对 | `docs/` 下每个英文主文件都有 `foo.zh.md` 副本，每个 `.zh.md` 都有英文源文件；根目录配对是 `README.mbt.md` / `README_ZH.md`、`AGENTS.md` / `AGENTS_ZH.md` | 补副本或改名 |
| 结构配对 | 每对中英文文件的标题层级序列和代码块数量一致 | 补漏掉的章节或代码块 |
| 代码块 | 开头的代码块都写了语言；没有未闭合的块 | 补 `sh` / `moonbit` / `text` 等标签 |
| 示例一致 | `examples/README.md`、CI 的 `moon run examples/...`、`examples/` 实际目录三者相同 | 补 README 行、CI 命令或目录 |
| 路线图 | README 路线图每行的状态等于 `roadmap.md` 对应章节的状态 | 改状态，或在 `roadmap_aliases()` 里补映射 |

## 扫描范围

- 扫描仓库里所有未被 `.gitignore` 忽略的 `.md` 文件，包括 `*.zh.md` 译本。
- `.gitignore` 只解析简单的 `name/` 目录规则；复杂 glob 不处理，宁可多检查。
- `.git` 和 `node_modules` 始终跳过。
- `docs/` 的 `AGENTS.md` 遍历不做目录豁免：`docs/` 下每个子目录都必须登记；`.zh.md` 不写进索引。

## 不检查什么

- 外部链接能否访问。
- 文字质量、API 语义、示例能否运行；前两项由 review 和 `moon test` 负责，CI 会跑示例并用 `scripts/check-examples.sh` 对比输出。
- 设计文档是否统一用现在时、历史是否只留在 `decisions/`；这些靠 review。
- 中英文内容是否逐句对应；这里只比较结构。英文是权威版本。
- 中文副本在语义上是否仍然同步；这靠 review。
- 代码改动是否同步了受影响的文档；靠 PR / commit 的 **Doc impact** 和 review。

## 加一项检查

1. 在 `scripts/check-docs.mbtx` 里写一个 `check_*` 函数，用 `fail(file, message)` 记录问题。
2. 在 `main` 里调用它；需要文件列表时复用 `collect_markdown` 和 `docs`。
3. 用 `moonx scripts/check-docs.mbtx` 验证，确认没问题时退出码是 0，故意改坏时是 1。
4. 更新本文件的检查表和 `--help` 文案。

普通的 `moon check` / `moon test` 不会检查 `.mbtx`，所以改完脚本要直接跑一次。

## Doc impact

改了公开 API、错误消息或用户可见行为时，同一次改动里更新受影响的文档，并在 PR / commit 里写清更新了什么：

- 公开 API 或行为：`docs/design/` 和 `.mbti` 的 diff。
- 错误消息：`docs/reference/errors.md` 和 `errors.zh.md`。
- 用法：`README.mbt.md` / `README_ZH.md`、`docs/guides/` 和 `examples/`。

提交正文写一行 `Doc impact: ...`，PR 填模板。检查脚本发现不了漏更的文档，靠 review 把关。

## 相关

- 目录层级：[docs/AGENTS.zh.md](../AGENTS.zh.md)
- 文档体系计划：[doc-system.zh.md](../plan/doc-system.zh.md)
- 示例输出检查：[scripts/check-examples.sh](../../scripts/check-examples.sh)
- 提交钩子：[.githooks/pre-commit](../../.githooks/pre-commit)
- CI：[.github/workflows/ci.yml](../../.github/workflows/ci.yml)
