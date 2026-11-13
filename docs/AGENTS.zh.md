# docs 指南

`docs/` 放项目的说明文档。代码怎么写见根目录 `AGENTS.md`；写作与审查规则见
`write-docs` skill。

## 目录

- `guides/` —— 按任务的操作步骤，讲「完成 X 怎么做」。文件索引见
  [`guides/AGENTS.zh.md`](guides/AGENTS.zh.md)。
- `design/` —— 设计文档，讲「为什么这样定」。文件索引见
  [`design/AGENTS.zh.md`](design/AGENTS.zh.md)。
- `decisions/` —— 决策记录，讲「当时为什么这么定」。文件索引见
  [`decisions/AGENTS.zh.md`](decisions/AGENTS.zh.md)。
- `plan/` —— 计划文档，讲「接下来做什么」。文件索引见
  [`plan/AGENTS.zh.md`](plan/AGENTS.zh.md)。
- `conventions/` —— 项目规范，讲「怎么做」。文件索引见
  [`conventions/AGENTS.zh.md`](conventions/AGENTS.zh.md)。
- `reference/` —— 具体形状的查阅表，讲「到底是什么」。文件索引见
  [`reference/AGENTS.zh.md`](reference/AGENTS.zh.md)。

## 规则

- 本文件只登记直接子目录和职责；具体文件登记在所属目录的 `AGENTS.md`。
- 新增子目录：在本文件加一行，并在该目录建 `AGENTS.md`。
- 新增文件：先在所属目录的 `AGENTS.md` 登记，再写内容。
- 用户怎么用写 `README.mbt.md` / `README_ZH.md`；任务步骤写 `guides/`；设计取舍写
  `design/`。
- 人向入口是 [`README.zh.md`](README.zh.md)：阅读路径、核心概念、代码区域到文档的对照。
- 英文是权威版本。`docs/` 下每个英文主文件旁边都有 `*.zh.md` 中文副本；`.zh.md` 不登记进各目录索引。
- 改动公开 API、错误消息或用户可见行为时，同一次改动里更新受影响的文档，并在 PR / commit 里写清。错误消息原文只放在 [`reference/errors.zh.md`](reference/errors.zh.md)。
