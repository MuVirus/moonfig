# 提取到结构体：三选一

把配置子树读进自己的结构体。三条路都保持严格类型；差别在控制力、依赖和类型改造量。
接口和取舍见 [extract.md](../design/extract.zh.md)。

## 适用场景

- 配置键和字段名不一致、需要默认值或嵌套字段：用 `FromConfig`
- 类型已经实现 serde 的 `Deserialize`，不想为配置再写一遍：用 `serde_bridge`
- 结构体是简单 JSON 形状，字段名等于配置键：用 `derive(FromJson)`

## 前置条件

- `FromConfig`：默认提取路径，只依赖 `core`；`from_config` 收到一个 `Getter`，按标签
  读字段
- serde（`moonbit-community/serde.mbt`）：类型有 `Deserialize`（手写或
  `#serde.derive(Deserialize)`），依赖 `serde_bridge`；它把 `Value` 接到 serde 后端
- `derive(FromJson)`：由 `moonbitlang/core/json` 生成实现；类型加
  `#derive(@json.FromJson)`，再加一行 `pub extend T with @json.FromJson::{from_json}`；
  依赖 `json_format`
- 64 位整数：`FromConfig` 和 `serde_bridge` 直接读 `Value`，用 `Int64`；
  `derive(FromJson)` 经过 Json，用 `Int64Text`（`json_format` 的包装类型，
  `to_int64()` 取回）
- 要校验：类型实现 `Validate`（提取后执行的校验 trait），提取时走带 `validated` 的入口

## 完成标准

- 结构体编译通过，嵌套字段也能取到
- 缺键报 `MissingKey`，类型不符报 `TypeMismatch`，消息带完整键路径
- `*_or` 只在键缺失时用默认值；键存在但类型不符仍然报错
- 换来源（文件 / 环境变量 / 命令行）不用改提取代码

## 步骤

1. 默认用 `FromConfig`：`from_config` 收到 `Getter`，每个字段一行，标签、默认值、嵌套
   都写在同一处；标签相对 `get_struct` 的子树解析。

```moonbit nocheck
impl @config.FromConfig for Server with fn from_config(get : @config.Getter) -> Server raise @config.ConfigError {
  {
    host: get.string("db-host"),      // 配置键 db-host，字段名 host
    port: get.int("port"),            // 原生 Int64
    retry: get.int32_or("retry", 3),  // 缺失才用 3
    pool: get.nested("pool"),         // 递归走 Pool 的 from_config
  }
}
let srv : Server = cfg.get_struct("server")
```

2. 类型已经有 serde 描述时，改用 `serde_bridge`：它把 `Value` 当 serde 后端，类型侧
   不用为配置改动。

```moonbit nocheck
let app : AppCfg = @serde_bridge.extract_serde_from(cfg, "app")
```

3. 结构简单、字段名等于配置键时，用 `derive(FromJson)`；`extract_from` 先按键取子树
   再解码。

```moonbit nocheck
#derive(@json.FromJson)
struct Port { port : Int32 }

pub extend Port with @json.FromJson::{from_json}
let port : Port = @jsonfmt.extract_from(cfg, "db")
```

嵌套可以混用：`FromConfig` 的字段里用 `@jsonfmt.json_field(get, "db")`，或
`@serde_bridge.serde_field(get, "db")` 一行委托，不必整棵树换写法。

## 常见坑与下一步

- `derive(FromJson)` 忽略结构体里没有的字段；要查未知键只能用 `FromConfig` + `Validate`。
- 取值方法 `int` 只收整数来源，字符串 `"5432"` 不会自动转换。
- 三条路的错误消息和 `get_*` 同一口径，别在调用方再包一层。
- 校验见 [validate.md](../design/validate.zh.md)。
- 下一步：完整代码见 [from_config](../../examples/from_config/README.md)、
  [serde_extract](../../examples/serde_extract/README.md)、
  [strict_types](../../examples/strict_types/README.md)。
