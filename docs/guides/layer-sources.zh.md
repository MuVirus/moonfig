# 叠加多来源

把默认值、配置文件、环境变量和命令行叠成一份配置。后加的覆盖先加的，最后还能查出
一个值来自哪一层。来源和合并规则见 [sources.md](../design/sources.zh.md) 与
[design.md](../design/design.zh.md#3-配置对象与取值)。

## 适用场景

- 同一套配置键要供本地开发、CI 和线上使用，只换来源
- 需要「默认值 → 文件 → 环境变量 → 命令行」这种固定优先级
- 排查配置时，要回答「这个值是谁给的」

## 前置条件

- 已安装 moonfig，并引入 `core`、用到的格式包和 Source 包；安装见
  [README](../../README_ZH.md#安装)
- 文件来源要有格式：`FileSource::new(path, format)`；想按后缀或内容自动选择，用
  `FileSource::auto(path, detector)`
- 环境变量来源要定前缀，比如 `APP_`
- 命令行来源默认只认 `--key=value`；空格分隔要显式切到 `Separate`

## 完成标准

- `build()` 不报错，每个键都能 `get_*` 到预期值
- `origin_of(path)` 指出赢家来源；被覆盖的层不再出现
- 改一层来源或调整顺序，不用改读取代码

## 步骤

1. 先放默认值：`MemorySource` 把内存里的一棵 `Value` 当一层，所有键都有可用值。
2. 加文件层：`FileSource::new("config/app.json", JsonFormat::new())`。
3. 加环境变量层：`EnvSource::new("APP_")`；`APP_DB_PORT` 落到 `db.port`。
4. 加命令行层：`CliSource::new()`；`--log-level=debug` 落到 `log.level`。短选项和数组
   要先登记，风格见 [cli-args.md](../design/cli-args.zh.md)。
5. `build()` 后按键取值；需要诊断时用 `origin_of`（查某个键来自哪层）或 `origins`
   （列出所有叶子路径）。

```moonbit nocheck
let cfg = Config::new()
  .add(MemorySource::new(Value::table({
    "db": Value::table({ "host": Value::str("localhost"), "port": Value::int(5432L) }),
    "log": Value::table({ "level": Value::str("info") }),
  })))
  .add(FileSource::new("config/app.json", JsonFormat::new()))
  .add(EnvSource::new("APP_"))
  .add(CliSource::new())
  .build()

cfg.get_int("db.port")          // 环境变量给了 6543 就是 6543
cfg.origin_of("db.port")        // Some(env:APP_DB_PORT)
```

## 常见坑与下一步

- 加入顺序就是优先级；默认 `LastWins`。要反过来用
  `.with_rule(MergeRule::FirstWins)`，按来源类型排序用 `MergeRule::ByKind`，数组里按
  优先级从高到低写（如 `[Env, File]`）。
- 嵌套表逐键合并，数组整体替换；数组不会按元素合并。
- 环境变量把 `_` 和 `.` 当层级；命令行把 `-` 和 `.` 当层级；键统一转小写。
- 环境变量和命令行没有类型声明，内容按字面猜：`6543` 是 `Int`，`true` 是 `Bool`，
  其余是字符串。
- 表节点的来源是「最后碰它的那层」，只有叶子路径准确。
- 文件不存在报 `IoError`，内容坏了报 `ParseError`；热更新失败时保留旧配置，见
  [hot-reload.md](../design/hot-reload.zh.md)。
- 下一步：把子树读进结构体，见 [choose-extraction.zh.md](choose-extraction.zh.md)；四层完整
  演示见 [examples/multi_source](../../examples/multi_source/README.md)。
