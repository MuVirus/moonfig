# guides 指南

`guides/` 讲「完成 X 的步骤」，一篇一个任务。设计取舍写 `design/`，可运行证明写
`examples/`。

## 文件

- [`layer-sources.zh.md`](layer-sources.zh.md) —— 把默认值、文件、环境变量、命令行叠成一份配置
- [`choose-extraction.zh.md`](choose-extraction.zh.md) —— `FromConfig` / serde / `derive(FromJson)` 三选一

## 规则

- 固定五段，顺序不变：适用场景、前置条件、完成标准、步骤、常见坑与下一步。
- 一篇控制在约 80 行；写不出「完成标准」的内容不是任务，放到 `design/`。
- 步骤用编号；代码片段只做示意，完整代码链到 `examples/`。
- 影响照着做的术语（如 `Getter`、`Int64Text`）在第一次出现处用一句话解释；背景术语
  链到 `design/`，不搬整张术语表。
- 不复制 API 表、错误表和设计取舍；需要时链到 `design/`。
- 与 `design/` 冲突时以 `design/` 为准，并修正 guide。
- 新增文件后在本文件登记。
