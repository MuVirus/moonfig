---
name: write-code
description: 写或修改本仓库 MoonBit 代码时使用。约束 doc 注释与行内注释的写法及其与 docs/ 的分工：注释只说这个 API 自己，对比与取舍指路到文档。
---

# 写代码

注释的职责是**说清楚这个 API 自己**：是什么、怎么用、有什么坑；不是替文档做选型对比。

## 一、注释

- 不与其他代码对比。选型给一句话加指路（`docs/guides/…`、`docs/design/…`），不展开。
- 设计理由只留直接解释示例的那一句，其余升进 `docs/design/`。
- 行内注释解释调用与键名，不复述代码。

## 二、分工

- 每个事实只有一个权威位置：docs 已有的不搬进注释；注释独有的坑先升进 docs，注释留链接。
- 公共 API 示例放 `///` 的 `mbt check` 块，编译过的完整版进 `_test.mbt`，注释里指过去；见 `docs/conventions/testing.md`。
- 块风格、工具链等编码约定见 `AGENTS.md`。

## 三、完成前检查

- [ ] 注释里没有对比段，指路的路径真实存在
- [ ] 示例能编译
- [ ] `moon info && moon fmt` 跑过，`.mbti` diff 符合预期
