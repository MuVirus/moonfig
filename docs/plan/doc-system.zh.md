# 文档体系计划

记录文档体系怎么一步步改。不是契约，可以随时改；每次只动一步，验收通过再进下一步。

来源：2026-11 的两轮讨论——现有文档体系评审，以及是否新增 `guides/`。

状态分三档：✅ 已完成、🚧 进行中、⬜ 未进行。

## 结论

现有结构（`design/` / `decisions/` / `plan/` / `conventions/` + skills，第 4 步新增 `reference/`）是对的，问题在治理：原则没有变成检查，已经开始漂移。改法分三层：

1. 先让文档可检查：链接、索引、示例、状态。
2. 再加一层按任务组织的 `guides/`。
3. 最后减少会过期的重复内容：片段、表。双语副本是刻意的例外：英文是权威版本，检查脚本保证结构对齐。

## 四个目标

| 目标 | 需要什么 | 对应步骤 |
|---|---|---|
| 持续开发 | 文档检查和「代码改动 → 文档影响面」 | 1、4 |
| AI 推荐 | 稳定索引、权威边界、决策状态 | 0、3 |
| 人类审核 | 结论先行、证据链接、小 diff | 3、4 |
| 人类阅读 | 人向入口、任务指南、核心概念 | 2 |

## 现状与问题

| 现象 | 影响 | 处理 |
|---|---|---|
| `README.mbt.md` 路线图与 `plan/roadmap.md` 状态不一致，README 还多出三个方向 | 人和 AI 拿到两个事实 | 第 0 步（以 README 为准，已做） |
| `decisions/` 没有独立索引，`docs/AGENTS.md` 的决策摘要停在 #9 | AI 找不到权威位置 | 第 0 步（已做） |
| `docs/AGENTS.md` 混了子目录职责和文件索引 | 每加一个文件都要改根索引 | 第 0 步（已做） |
| `decisions.md` #11 与 #13 结论相反，只靠文末一句修订 | AI 检索到旧结论 | 第 3 步（已做） |
| README 片段全是 `nocheck`，部分缺 `import` | 用户复制后编译不过，CI 发现不了 | 第 4 步 |
| CI 的 examples 列表漏了 `examples/from_config` | 新示例没有持续验证 | 第 0 步（已做） |
| 缺「完成 X 的步骤」这一层 | 用户只能读 470 行 README 或 design | 第 2 步（已做） |
| 设计文档混规范与导览 | 审稿人不知道以谁为准 | 第 3 步（已做） |

相对链接现在由 `scripts/check-docs.mbtx` 自动检查，不再依赖手工。

## 目标结构

```text
docs/
  AGENTS.md          # 子目录职责 + 导航
  README.md          # 人向入口：阅读路径、核心概念、代码 → 文档
  guides/            # 按任务：完成 X 的步骤
  design/            # 为什么这样定
  decisions/         # 当时为什么这么定
  plan/              # 接下来做什么
  conventions/       # 贡献者怎么做
  reference/         # 以后：错误目录等稳定查表
```

每个子目录有自己的 `AGENTS.md`，登记本目录文件；`docs/AGENTS.md` 只登记子目录。

`docs/README.md` 和 `reference/` 是候选，不在这轮强制落地。

## 分层边界

| 层 | 回答的问题 | 不该写 |
|---|---|---|
| `README` | 这是什么，怎么开始 | 完整任务步骤、设计取舍 |
| `guides/` | 完成 X 的步骤、顺序、坑 | API 语义表、错误目录、为什么这样定 |
| `examples/` | 最小可运行证明 | 完整任务编排 |
| `design/` | 为什么这样定 | 操作步骤 |
| `decisions/` | 当时为什么这么定 | 现行结论 |

## 总览

| 步 | 内容 | 状态 | 验收 |
|---|---|---|---|
| 0 | 修漂移 | ✅ | 同一事实只有一个状态或结论 |
| 1 | 文档检查 | ✅ | 故意改坏链接能让 CI 变红 |
| 2 | 人向入口 + guides | ✅ | 两次点击能从 README 到任务页 |
| 3 | 决策状态 + 权威边界 | ✅ | 只看索引能知道哪些决策仍生效 |
| 4 | 减少过期内容 | 🚧 | README 片段可验证，错误只有一处权威 |

建议顺序：0 → 1 → 2 → 3 → 4。0 和 1 是治理，2 是新增层；3、4 可以和 2 并行。如果想让 guides 先试水，也可以 0 → 2（只写两篇）→ 1 → 3 → 4，检查脚本随后覆盖这两篇。

## 第 0 步：修漂移　✅

目标：不改结构，只让现有文档互相一致。

- [x] 以 README 的公开状态为准，更新 `plan/roadmap.md`（README 不动）
- [x] `docs/AGENTS.md` 只留子目录职责；文件索引下沉到各目录 `AGENTS.md`
- [x] `decisions/AGENTS.md` 补 #1–#13 索引（第 3 步把索引移到 `decisions.md` 顶部）
- [x] `decisions.md` #11 加状态行「被 #13 取代」
- [x] CI 的 examples 列表补 `examples/from_config`
- [x] README 片段补齐缺失的 `import`，或改成链接到 example（详细片段已改为 examples 链接）

验收：同一事实只有一个状态或结论；`moon test` 和 CI 仍通过。

## 第 1 步：文档检查　✅

目标：把原则变成可执行检查。

- [x] `scripts/check-docs.mbtx`（MoonBit，`moonx` 跑 Wasm，无 Node）检查：
  - 每个目录的 `AGENTS.md` 是否登记本目录文件；`docs/AGENTS.md` 是否登记所有子目录
  - 相对链接和锚点是否存在
  - 决策编号是否唯一、连续（状态行在第 3 步加）
  - `README.mbt.md` / `README_ZH.md`、`AGENTS.md` / `AGENTS_ZH.md`，以及每对英文 / `.zh.md` 是否结构配对
  - 代码块是否都标了语言
  - `examples/README.md`、CI 列表、实际目录是否一致
  - README 路线图与 `roadmap.md` 的状态是否一致
- [x] 接入 CI 和 `.githooks/pre-commit`
- [x] 故意断一个链接，确认检查会失败

用法和每项检查见 [conventions/docs.zh.md](../conventions/docs.zh.md)。

验收：文档漂移时 CI 变红；检查本身在几秒内跑完。

## 第 2 步：人向入口 + guides　✅

目标：人类读者有按任务的入口。

- [x] `docs/README.md`：阅读路径、核心概念、`代码区域 → 文档` 对照表
- [x] `docs/guides/` 和索引；先写两篇：
  - [x] `layer-sources.md`：默认值、文件、环境变量、命令行怎么叠
  - [x] `choose-extraction.md`：`FromConfig` / serde / `derive(FromJson)` 三选一
- [x] 每篇固定五段：适用场景、前置条件、完成标准、步骤、常见坑 + 下一步
- [x] `write-docs` skill 新增 `references/guide.md`，并在 `SKILL.md` 的「按文档类型」挂链接
- [x] `docs/AGENTS.md` 加 `guides/`；`guides/AGENTS.md` 写任务步骤规则

约束：

- 一篇一个任务，控制在 80 行内；写不出「完成标准」的内容不是 guide。
- 不复制 API 表、错误表、设计取舍，链接到 `design/` 或 `reference/`。
- 每篇至少链一个可运行 example；代码片段只做示意。
- guide 与 design 冲突时，design 是权威。

验收：新读者从 README 两次点击能到一个任务页；每篇 guide 都有完成标准和 example 链接。

## 第 3 步：决策状态 + 权威边界　✅

目标：人和 AI 都能快速判断「哪条结论仍生效」。

- [x] 决策记录顶部加索引表：ID / 结论 / 状态 / 影响文档
- [x] 每条决策加状态行，例如：
  `状态：生效（取代 #11）｜影响：design/extract.md、guides/choose-extraction.md`
- [x] 被取代的决策在状态行写清关系，不靠文末括号
- [x] 每篇设计文档开头三行：结论、权威边界（这篇/这张表是规范还是导览）、不覆盖
- [x] 设计文档统一用现在时；历史只留在 `decisions/`
- [x] 检查脚本校验状态行、顶部索引、取代关系和设计文档开头

约束：

- 索引放在 `decisions.md` 顶部；`decisions/AGENTS.md` 只登记文件，不再维护第二份编号表。
- 状态只取 `生效` / `部分被取代` / `已取代` / `作废`；取代关系必须双向写明。
- `影响文档` 写相对 `docs/` 的路径，脚本会验证文件存在；纯实现约定写 `无（仅实现）`。

验收：只看索引能知道哪些决策仍生效；审稿人能判断一张表是规范还是导览。

## 第 4 步：减少过期内容　✅

目标：会变的东西不手抄。

- [x] README 基本用法只留核心路径，细节链接到 `examples/`
- [x] README 可运行片段移到 `examples/` 或文档注释；`examples/quick_start` 是完整程序，CI 跑所有 examples 并用 `scripts/check-examples.sh` 对比 README 输出
- [x] `docs/reference/errors.md`：`ConfigError` 各变体、触发条件、消息示例（生成或手工维护）
- [x] 英文策略：英文是权威版本。`docs/` 下每篇文档都有 `foo.zh.md` 中文副本，根目录配对为
  `README.mbt.md`（英文）/ `README_ZH.md`（中文）。检查脚本验证配对、标题层级和代码块数量；
  语义同步仍靠 review。
- [x] PR / commit 模板加 **Doc impact**：改了公开 API、错误消息、用户可见行为时，写清更新了哪些文档

验收：README 片段不再依赖不可见 `import`；错误信息只有一个权威位置。

## 现在不做

- 从零重写全部文档。
- 用机器翻译维护中文副本；中文副本手工维护。
- 引入文档站生成器。
- 为每篇文档加变更记录（git 已经有了）。

## 待定

- 除了结构检查，怎么防止中文副本在语义上漂移；目前靠 review。


## 讨论记录

- 2026-11-13：评审现有文档体系；结论是结构对、治理缺；提议增加 `guides/` 层；拆成 0–4 步。
- 2026-11-13：`docs/AGENTS.md` 改为只登记子目录，文件索引下沉到各目录 `AGENTS.md`。
- 2026-11-13：README 路线图不改；以 README 的公开状态为准，`roadmap.md` 补后续方向和状态。
- 2026-11-13：检查脚本改用 MoonBit `.mbtx`（`scripts/check-docs.mbtx`，`moonx` 跑 Wasm，文件 IO 用 `moonbitlang/x/fs`）；接入 CI 和 pre-commit，并用断链验证过会失败。
- 2026-11-13：第 2 步落地：新增 `docs/README.md` 和 `guides/` 两篇（`layer-sources`、`choose-extraction`），README 文档区加入口；`write-docs` 增加 `references/guide.md`，README 规范补「任务步骤放 guides」。
- 2026-11-13：`docs/README.md` 的术语表改为「核心概念」：入口页只讲它实际引用的模型（Source / Format / Value / MergeRule），不铺开 API 词表；深词在指南首次出现处链到 `design/`。
- 2026-11-13：guides 不设独立术语段；影响操作的词（`Getter`、`Int64Text`、`ByKind`）在首次出现处一句话解释，其余链到 `design/`。
- 2026-11-13：第 3 步落地：`decisions.md` 顶部加 ID / 结论 / 状态 / 影响文档索引，每条决策加状态行，`#11` 与 `#13` 双向写明取代关系；索引从 `decisions/AGENTS.md` 移走，避免两份表漂移。
- 2026-11-13：设计文档统一开头三行「结论 / 权威边界 / 不覆盖」；检查脚本校验状态行、索引一致性、取代关系和这三行。
- 2026-11-13：英文成为权威版本。`docs/` 下每篇文档增加 `foo.zh.md` 中文副本；根目录翻转为 `README.mbt.md`（英文）/ `README_ZH.md`（中文）。检查脚本验证配对、标题层级和代码块数量；语义同步仍靠 review。
- 2026-11-13：去掉每篇文档开头的可见译本指针；它破坏首屏，而且根 README 已有语言切换。配对仍按文件名，英文仍是权威版本。
- 2026-11-13：第 4 步落地：`examples/quick_start` 成为 README 最小示例的完整程序；`scripts/check-examples.sh` 对比每个示例的输出和 README 输出块；`docs/reference/errors.md` 成为 `ConfigError` 消息的唯一权威位置；PR / commit 模板增加 **Doc impact** 行。
