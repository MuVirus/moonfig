# design 指南

设计文档讲「为什么这样定」：取舍、边界、坑。操作步骤写 `guides/`，可运行证明写
`examples/`。

## 文件

- [`design.md`](design.zh.md) —— 主线与核心数据模型
- [`sources.md`](sources.zh.md) —— Source / Format 接口、core 边界、package 划分、来源追踪、第三方解析器的取舍
- [`cli-args.md`](cli-args.zh.md) —— 命令行参数：取值风格、短选项登记、数组声明、位置映射、冲突与来源标签
- [`extract.md`](extract.zh.md) —— 提取到结构体、整数映射、标准库错误映射
- [`validate.md`](validate.zh.md) —— 校验：按键规则表、结构体 `Validate`、未知键、错误
- [`format-detect.md`](format-detect.zh.md) —— 自动发现格式：后缀优先、内容判断、候选顺序
- [`hot-reload.md`](hot-reload.zh.md) —— 热更新：快照替换、文件轮询、失败保留旧配置

## 规则

- 一份设计一个文件，按主题命名。
- 写「为什么这样定」：结论先行，再给取舍、边界、代价。
- 开头三行固定写 `结论`、`权威边界`（这篇是规范还是导览）、`不覆盖`；检查脚本会验证。
- 规范类结论写清谁说了算：签名以 `.mbti` 为准，行为以本文为准。
- 历史只留在 `decisions/`；设计文档用现在时，不写「原来……后来……」。
- 新增文件后在本文件的索引里登记。
