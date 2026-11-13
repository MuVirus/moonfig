# README

README 面向使用者：能做什么、怎么开始。设计取舍不写在这里，放 `docs/`，用链接指过去。

- 仓库根：`README.mbt.md` 是英文版（权威），`README_ZH.md` 是中文版，`README.md` 是指向英文版的符号链接。改一边就改另一边。
- 结构：定位 → 功能 → 安装 → 最小示例 → 用法 → 文档与许可证。首屏就要能看出这是什么、怎么用。
- 文档区先链 `docs/README.md`（英文）或 `docs/README.zh.md`（中文）；完整任务步骤放 `docs/guides/`，README 只给链接和一两句结论。
- 最小示例要能直接复制运行；只证明一个点，其余能力用链接。
- 代码块标语言。片段用 `moonbit nocheck`，不参与校验；需要保证能跑的例子放 `///` 注释的 `mbt check` 里。
- 不搬运 `moon doc` 能生成的 API 清单，不写内部架构宣言和开发约定。
- `examples/` 下示例目录的 README 是另一套写法，见 `write-example` skill。
