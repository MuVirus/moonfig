# 项目 AGENTS.md 指南

这是一个 [MoonBit](https://docs.moonbitlang.com) 项目。

你可以在这里浏览和安装额外的 skill：
<https://github.com/moonbitlang/skills>

## 这个项目是什么

`moonfig` 是一个 MoonBit 综合配置库。它从多种来源、多种格式读配置，归一成同一种中间表示，
按层合并（后加入的来源覆盖先加入的），最后按键取值或提取成结构体。

- **多来源**：内存表、配置文件、环境变量、命令行参数。
- **多格式**：JSON、INI、`.env`、YAML、TOML、XML、CBOR，也能直接给 `Value` 树；按后缀或内容识别。
- **两种取法**：按键 `get_*`，或提取到自定义结构体。
- **不止解析**：热更新、来源追踪、校验。

### 设计约束

- **平台**：`core/` 在所有 target 上编译通过；平台相关的部分各自一个包，放在模块根目录。
- **包名**：不得与 core 的包重名；格式包以 `_format` 结尾，来源包以 `_source` 结尾。
- **跨包调用**：方法不能跨包（`4059`）；改用自由函数，如 `to_json(v)`。

### 文档

文档放在 `docs/`。英文是权威版本；每篇文档旁边有 `foo.zh.md` 中文副本。根目录的配对是
`README.mbt.md` / `README_ZH.md` 和 `AGENTS.md` / `AGENTS_ZH.md`。
[`docs/AGENTS.md`](docs/AGENTS.md) 登记子目录；每个子目录各有自己的
`AGENTS.md`，管本目录的文件。中英文不一致时以英文为准，并修中文副本。

改动公开 API、错误消息或用户可见行为时，同一次改动里更新受影响的文档，并在 PR / commit
里用 `Doc impact:` 一行写清影响面。错误消息原文只放在
[`docs/reference/errors.md`](docs/reference/errors.md)。

## 项目结构

- MoonBit 的包按目录组织；每个目录有一个 `moon.pkg`，列出这个包的依赖。每个包有自己的源文件、
  黑盒测试文件（后缀 `_test.mbt`）和白盒测试文件（后缀 `_wbtest.mbt`）。

- 每个模块目录有一个 `moon.mod`，记录模块元信息。

- 仓库根是 `moon.work` workspace，本身没有 `moon.mod`。所有模块都在 `modules/`
  下：`modules/moonfig` 是 `MuVirus/moonfig`，每个适配器一个
  `modules/moonfig-<name>/`（`-toml`、`-yaml`、`-xml`、`-cbor`、`-serde`）。
  `examples/`、`benchmarks/` 也是 workspace 成员，但不发布。根目录的
  `moon check` 和 `moon test` 覆盖所有成员；`moon package`、`moon publish`
  这类按模块执行的命令要在模块目录里跑（`moon -C modules/moonfig publish`）。

- 在 `modules/moonfig` 里，核心包在 `core/`；不需要第三方解析器的格式包
  （`json_format`、`ini_format`、`dotenv_format`）在 `core/format/`；文件、
  环境变量和命令行来源在 `file_source/`、`env_source/`、`cli_source/`。
  需要解析器的格式是独立模块而不是包：模块的依赖会被它所有 package 共享，
  进而传到每个使用者。文档在仓库根的 `docs/`，见
  [`docs/AGENTS.md`](docs/AGENTS.md)。

- 测试遵循 `docs/conventions/testing.md`：公开 API 的示例写在 `///` 文档注释的 ` ```mbt check ` 代码块里，
  私有逻辑放进 `_wbtest.mbt`，公开 API 的行为放进 `_test.mbt`。本项目不用内联测试。

- `.githooks/pre-commit` 里有一个 pre-commit 钩子；每个 clone 执行一次
  `git config core.hooksPath .githooks` 即可启用。

## 编码约定

- MoonBit 的代码按 block 组织，每个 block 用 `///|` 分隔，block 之间的顺序无关紧要。
  有些重构可以按 block 逐个处理。

- 尽量把废弃的 block 放在每个目录下名为 `deprecated.mbt` 的文件里。

- import 别名一律显式写出（`@config`、`@jsonfmt`）。

## 工具

- `moon fmt` 用来把代码格式化。

- `moonx scripts/check-docs.mbtx` 检查 Markdown：目录索引、链接与锚点、决策状态与索引、
  设计文档开头、中英文配对、代码块语言、示例和路线图。走 Wasm 后端；CI 和
  pre-commit 也会跑它。用法和每项检查见 [docs/conventions/docs.md](docs/conventions/docs.md)。

- `moon ide` 提供项目导航功能，比如 `peek-def`、`outline` 和 `find-references`。
  详见 $moonbit-agent-guide。

- `moon info` 用来更新包生成的接口，每个包都有一个生成的接口文件 `.mbti`，它是这个包的简要形式化描述。
  如果 `.mbti` 没有变化，说明你的改动对外部使用者没有可见的变化，这通常是安全的重构。

- 最后一步跑 `moon info && moon fmt`，更新接口并格式化代码。检查 `.mbti` 文件的 diff，
  看这些变化是否符合预期。

- 跑 `moon test` 检查测试是否通过。MoonBit 支持快照测试；当输出发生变化时，跑 `moon test --update`
  刷新快照。

- 对稳定或极不可能变化的结果，优先用 `assert_eq` 或 `assert_true(pattern is Pattern(...))`。
  对会记录结构化调试输出的快照测试，derive `Debug` 并用 `debug_inspect`，而不是 derive `Show`。
  对结果确凿、有明确定义的东西（比如科学计算），优先写断言测试。可以用
  `moon coverage analyze > uncovered.log` 看哪些代码没被测试覆盖。
