# 错误参考

> **结论**：`ConfigError` 有八个变体。每条消息都写清键名；适用时还写清期望值和实际值。
> **权威边界**：规范——变体字段和 `Show` 文案以本文为准；枚举和实现以 `core/error.mbt` 为准。
> **不覆盖**：提取时怎么把标准库的 JSON 错误翻译过来见 [extract.md](../design/extract.zh.md#错误消息)；校验规则见 [validate.md](../design/validate.zh.md)。

`ConfigError` 是唯一跨库边界的错误类型。取值、提取、来源、格式和校验都抛它，调用方只捕一种类型。

`to_string()` / `Show` 是唯一支持的消息格式。上表是索引；下面每节给出具体字段、触发条件和消息示例。

| 变体 | 字段 | 何时抛出 |
|---|---|---|
| [`MissingKey`](#missingkey) | `path` | 没有任何来源提供这个路径 |
| [`TypeMismatch`](#typemismatch) | `path`、`expected`、`actual` | 值存在，但形状和请求的类型不一致 |
| [`ParseError`](#parseerror) | `message` | 格式无法解析字节，或字面量非法 |
| [`IoError`](#ioerror) | `message` | 外部数据读取失败 |
| [`MergeConflict`](#mergeconflict) | `path`、`left`、`right` | 合并会撞上不兼容的类型；预留 |
| [`InvalidValue`](#invalidvalue) | `path`、`expected`、`actual` | 校验规则失败 |
| [`UnknownKey`](#unknownkey) | `path` | 校验发现允许列表之外的键 |
| [`UnknownFormat`](#unknownformat) | `name`、`suffixes` | 格式发现既认不出后缀，也认不出内容 |

## MissingKey

字段：`path`（点号键路径）。

没有任何来源提供这个路径。`get_*`、`FromConfig` 的 getter、校验规则和提取都会报它；它们都不补默认值，默认值是 `MemorySource` 的职责。

```text
missing key 'db.host': no source provides it
```

## TypeMismatch

字段：`path`、`expected`、`actual`。

路径存在，但值的形状和请求的类型不一致。`expected` 和 `actual` 是形状名：`Str`、`Int`、`Bool`、`Float`、`Bytes`、`Array` 或 `Table`。库不会把字符串转成数字，也不会反向转换。

```text
key 'db.port': expected Int, got Str
```

## ParseError

字段：`message`（已经格式化好的底层细节）。

格式无法解析字节、类型推断失败、整数超出范围，或命令行 / 环境变量的字面量非法。来源可以在消息前加上正在读取的参数或文件；变体仍然是 `ParseError`。

```text
parse error: Invalid character 'o' at line 1, column 1
parse error: integer 99999999999999999999 exceeds Int64 range
```

## IoError

字段：`message`（路径和底层原因）。

外部数据读取失败：文件不存在、权限问题、环境变量读取失败。读到了但字节解析不了属于 `ParseError`，不是 `IoError`。`read error:` 前缀和带引号的路径是库加的；路径后面的原因来自平台的 IO 错误。

```text
read error: file 'config/app.json': No such file or directory
```

## MergeConflict

字段：`path`、`left`、`right`（两个类型名）。

预留变体。当前合并规则直接覆盖，不检测类型冲突，所以没有代码路径会抛它。保留在枚举里，是为了将来加严格合并规则时形状稳定。

```text
merge conflict at key 'db': Table vs Str
```

## InvalidValue

字段：`path`、`expected`（约束）、`actual`（规则提供的值或形状）。

校验规则失败。内置规则提供 `1..65535`、`1..64 characters`、`debug / info / warn / error`，类型不符时提供形状名。自定义规则自己决定 `actual`；密码类字段应返回长度或形状，不要返回原值。

```text
invalid value for key 'db.port': expected 1..65535, got 70000
invalid value for key 'db.user': expected 1..64 characters, got 0 characters
invalid value for key 'log.level': expected debug / info / warn / error, got verbose
```

## UnknownKey

字段：`path`（意外键的完整路径）。

校验发现一个不在 `Rule::allowed_keys` 列表里的键。检查按路径进行，不做全局扫描；嵌套表要逐层写规则。

```text
key 'db.extra' is not allowed
```

## UnknownFormat

字段：`name`（文件名或来源标签）、`suffixes`（候选格式声明的后缀）。

格式发现既没有认出后缀，也没有内容匹配候选。消息总会写出输入名并列出支持的后缀；发现过程不会猜一个解析器硬解。

```text
unknown format for config/notes.txt: suffix not recognized and content matches no candidate; supported suffixes: .json / .toml / .yaml / .yml
```

候选格式都没有声明后缀时，列表为空，消息在 `no candidate` 后结束。
