# 手写 FromConfig 示例

`derive(FromJson)` 零样板，但字段名必须和配置键一致、没有默认值、64 位字段要包 `Int64Text`。需要改名、缺省值、原生 `Int64` 或逐字段控制时，手写 `FromConfig`：每个字段一行，配置键（json 标签）就写在调用点上。

运行：

```sh
moon run examples/from_config
```

## 类型侧：标签写在字段调用点

```moonbit
/// 嵌套结构体继续用 derive(FromJson)：字段名等于配置键，零样板
#derive(@json.FromJson)
struct DbCfg {
  host : String
  port : Int32
}

/// 嵌套结构体手写：字段名和配置键不同，需要标签
struct PoolCfg {
  size : Int32
  timeout_ms : Int64
}

impl @config.FromConfig for PoolCfg with fn from_config(get : @config.Getter) -> PoolCfg raise @config.ConfigError {
  { size: get.int32("size"), timeout_ms: get.int("timeout_ms") }
}

/// 顶层结构体：改名、原生 64 位、缺省值、可选字段、数组都在这里
struct ServerCfg {
  host : String
  port : Int64
  retry : Int32
  comment : String?
  tags : Array[String]
  db : DbCfg
  pool : PoolCfg
}

impl @config.FromConfig for ServerCfg with fn from_config(get : @config.Getter) -> ServerCfg raise @config.ConfigError {
  {
    host: get.string("db-host"),          // 标签改名：配置键 db-host，字段名 host
    port: get.int("port"),                // 原生 Int64，不用 Int64Text，大整数不丢
    retry: get.int32_or("retry", 3),      // 缺失用默认值；写错类型仍报错
    comment: get.opt_string("comment"),   // 缺失或 null 都是 None
    tags: get.strings("tags"),            // 数组
    db: @jsonfmt.json_field(get, "db"),   // 嵌套走 derive(FromJson)
    pool: get.nested("pool"),             // 嵌套继续走手写 FromConfig
  }
}

let srv : ServerCfg = cfg.get_struct("server")
```

每条标签都相对 `get_struct` 传入的子树解析，报错路径自动接上前缀（`server.db-host`）。

| 写法 | 行为 |
|---|---|
| `get.string` / `get.int` / `get.int32` / `get.opt_string` | 必填字段，缺失报 `MissingKey`，类型不符报 `TypeMismatch` |
| `get.int32_or("retry", 3)` | **只在缺失时**用默认值；键存在但类型不符仍然报错，不静默落默认 |
| `get.strings` / `get.ints` / `get.structs` | 数组，元素错误带下标路径（`server.tags.1`） |
| `get.nested` | 子 `Getter` 前缀接上标签，嵌套结构体递归走 `from_config` |
| `@jsonfmt.json_field` | 字段级委托给 `derive(FromJson)`，严格探针照常生效 |

## 输出

```text
== 手写 FromConfig 提取 ==
完整配置     -> host=localhost port=5432 retry=5 comment=primary tags=[edge, eu] db=db.internal:5432 pool=8/30000
缺省值       -> host=localhost port=5432 retry=3 comment=None tags=[] db=db.internal:5432 pool=8/30000
缺必填字段   -> error: missing key 'server.db-host': no source provides it
默认值不兜底 -> error: key 'server.retry': expected Int, got Str
大整数不丢   -> host=localhost port=9007199254740993 retry=5 comment=None tags=[] db=db.internal:5432 pool=8/30000
```

- **缺省值**：`retry` 没写，落到默认 `3`；`comment` 缺失是 `None`。
- **缺必填字段**：键名是配置里的 `server.db-host`，不是字段名 `host`。
- **默认值不兜底**：`retry` 写成字符串 `"5"`，虽然字段有默认值，仍然报类型错误。
- **大整数不丢**：`9007199254740993` 超出 `Double` 精确范围，按原生 `Int64` 原样读出。

## 三个入口

```moonbit
let srv : ServerCfg = cfg.get_struct("server")                     // 按键取子树
let srv : ServerCfg = cfg.get_struct_validated("server")           // 再跑结构体的 Validate（需实现 Validate）
let srv : ServerCfg = value.to_struct()                            // 从一个 Value 直接提取
```

`get_struct` / `get_struct_validated` 是 `Config` 上的方法，`to_struct` 挂在 `Value` 上；标签都相对传入的那棵子树解析。

## 和 serde 怎么选

已经在用 [serde](https://github.com/moonbit-community/serde.mbt) 描述类型时，直接用 [`serde_bridge`](../serde_extract/README.md)，类型不用改。没有 serde 依赖、又只需要字段级控制时，手写 `FromConfig` 更直接：不生成代码，标签就是普通函数参数。

代码位置：[`main.mbt`](main.mbt)。
