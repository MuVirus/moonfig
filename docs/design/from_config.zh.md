# 用 `FromConfig` 提取

> **结论**：`FromConfig` 是默认的结构体提取路径：每个字段一行，直接读 `Value`，不经过 JSON 往返。
> **权威边界**：规范——这条路径的 `Getter` 语义和错误规则以本文为准；签名以 `.mbti` 为准。
> **不覆盖**：三条路径怎么选见 [choose-extraction.md](../guides/choose-extraction.zh.md)；`derive(FromJson)` 和 serde 适配器见 [extract.md](extract.zh.md)；错误原文见 [errors.md](../reference/errors.zh.md)。

## 1. 形状

每个字段的**标签写在调用点**：

```moonbit nocheck
impl @config.FromConfig for Server with fn from_config(get : @config.Getter) -> Server raise @config.ConfigError {
  {
    host: get.string("db-host"),          // 标签改名：配置键与字段名解耦
    port: get.int("port"),                // 原生 Int64，不用 Int64Text
    retry: get.int32_or("retry", 3),      // 缺省值
    comment: get.opt_string("comment"),   // 可选：缺失或 null 都是 None
    tags: get.strings("tags"),            // 数组
    db: @jsonfmt.json_field(get, "db"),   // 嵌套结构体走 derive(FromJson)，一行委托
  }
}
let srv : Server = config.get_struct("server")
```

入口有三个：`Config::get_struct`（按键取子树）、`Config::get_struct_validated`（提取后跑 `Validate`）、
`Value::to_struct`（原语，标签相对该值解析）。

## 2. Getter 的语义

| 方法族 | 行为 |
|---|---|
| `string` / `bool` / `int` / `int32` / `uint64` / `float` / `float_strict` / `bytes` | 必填：缺失报 `MissingKey`，类型不符报 `TypeMismatch`，口径同 `get_*` |
| `*_or` | 缺失用默认值；**键存在但类型不符（或越界）仍然报错**，绝不静默落默认 |
| `opt_*` | 缺失或 `null` 都是 `None`；类型不符照常报错 |
| `strings` / `ints` / `floats` / `bools` / `structs` | 元素错误带下标路径（`server.tags.1`） |
| `nested` | 子 Getter 前缀接上标签，嵌套结构体递归走 `from_config` |
| `value` / `opt_value` | 逃生舱：拿原始 `Value` 自己 match |
| `field_path` | 标签的完整路径，供自定义规则和消息使用；不读取值 |

## 3. 严格性

和 `get_*` 一样的严格性：`int` 只收整数来源（精确 `Int64`，这条路径直接读 `Value`，不走 Json，
9007199254740993 这类大整数不丢）；`float` 加宽整数、`float_strict` 不加宽；字符串来源永不变成数字
或字节串。没有 Json 往返、没有探针，性能比 derive 路径好。

## 4. 为什么默认走这条路径

MoonBit 没有反射，字段和标签的对应关系只能在调用点建立——**即使标签等于字段名，也要在 impl 里写一遍**。
默认走 `FromConfig`：它在 core 里、零依赖，和 `get_*` 同一套语义，也不经过 Json。`derive(FromJson)`
是可选且实验性的适配器（见 [extract.md](extract.zh.md)），适合字段名全等于配置键、不需要默认值、没有 64 位字段的
简单结构；它经过 `Value → Json` 和标准库的 `FromJson`，严格性靠探针模拟，不是构造上的保证。嵌套结构体
若继续用 derive 路径，字段里用 `json_field` 一行委托，不用逐字段手写。逐字段一行的代价与 `Validate` impl
相同，是手写换控制力。
