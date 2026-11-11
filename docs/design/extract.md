# 提取到结构体

## 1. 接口

```moonbit
pub fn[T : FromJson] extract(v : Value) -> T raise ConfigError
pub fn[T : FromJson] extract_from(cfg : Config, path : String) -> T raise ConfigError
pub fn[T : FromJson + Validate] extract_validated_from(cfg : Config, path : String) -> T raise ConfigError
```

`extract` 提取整棵树，`extract_from` 先按键取子树再提取；后者是自由函数，因为方法不能跨 package（见 [decisions.md](../decisions/decisions.md#2-方法不能跨包)）。`extract_validated_from` 在提取后调用结构体自己的 `Validate`，见 [validate.md](validate.md)。

实现主线是 `@json.from_json(to_json(v))`，但整数映射有一个绕不过去的矛盾：

| 字段类型 | MoonBit 标准库的 `from_json` 只认 |
|---|---|
| `Int` / `Int32` | `Json::Number`（±2^31 范围检查） |
| `Int64` / `UInt64` | `Json::String`（只吃字符串） |

`extract[T : FromJson]` 只有值级约束，看不到字段类型，所以一棵 Json 树不可能同时满足两者。取舍是：**统一映射成数字**，64 位字段用包装类型。

标准库的 `Int::from_json` 对数字只做范围检查，`3.14` 会被 `to_int()` 截断成 `3`。`extract` 在正常解码成功后，如果原值树里有浮点，会再用一棵把所有浮点换成字符串 `"NaN"` 的探针树解一次：`Double` / `Float` 接受 `"NaN"`，整数类型不接受，因此能定位到「浮点想进整数字段」并报 `TypeMismatch`。没有浮点的配置不会多跑这一遍，`Double` 字段仍返回原值，不受探针影响。

JSON 解码打开了 `preserve_number_repr=true`，所以 `1.0`、`1e2`、`-0.0` 这些「值是整数、写法是浮点」的数字也保持 `Float`，同样会被探针拦住，不会因为数值完整就绕过整数字段检查。

字符串这一侧也要补探测，因为标准库有些 `FromJson` 会把字符串当成别的形状：

| 标准库行为 | 问题 | 探针处理 |
|---|---|---|
| `Double` / `Float` 接受字符串 `"NaN"`、`"Infinity"`、`"-Infinity"` | 字符串来源变成浮点 | 把所有 `Str` 换成普通标记再解一次，报期望 `Float` 就翻成 `TypeMismatch` |
| `Int64` / `UInt64` 直接解析字符串 | 字符串来源变成 64 位整数，绕过 `Int64Text` | 同上，报期望 `Int64` / `UInt64` 就翻成 `TypeMismatch` |
| `Bytes` 字段只接受字符串 | 字符串来源变成字节串 | 标记里带换行，`Bytes::from_json` 会拒绝它 |

反方向也有一个坑：`Bytes` 和 `Str` 都映射成 `Json::String`，正常解码分不出。`extract` 逐个把 `Bytes` 节点换成一个非字符串值再解一次：字节字段会报期望 `Bytes`（合法），字符串字段会报期望 `String`，说明字节来源被当成了字符串，翻成 `TypeMismatch`。换成非字符串值而不是 `null`，是为了避免可选类型把 `null` 当成缺省值直接放过。这些探针只在树里出现对应形状时运行，纯字符串 / 纯整数配置不多跑。

| ValueKind | → Json |
|---|---|
| `Int` | `Json::number(i.to_double(), repr=i.to_string())` |
| `Float` | `Json::number` |
| `Bool` | `Json::bool` |
| `Str` | `Json::string` |
| `Bytes` | `Json::string(...)`，走标准库的字节编码 |
| `Null` | `Json::null` |
| `Array` / `Table` | 递归 |

`repr` 是标准库自己的字段：`Json::stringify` 优先写它，所以 `to_json(Value::int(9007199254740993L)).stringify()` 仍是原文 `9007199254740993`，不经过 `Double` 丢精度。`Int64Text` / `UInt64Text` 也读它，结构体里的 64 位字段写 `id : Int64Text`，`to_int64()` 取回原值。

解析侧与实测数据见 [decisions.md](../decisions/decisions.md#4-json-数值的边界)。

另一个代价：`Double` 字段收到超出 2^53 的整数会按 `Double` 取近似值（`Double` 本来就装不下）；`Int` 字段超出 ±2^31 由标准库报 overflow，库翻成「超出 Int 范围」。按键路径同理：`get_float` 默认接受整数并加宽，`get_float_strict` 只收 `Float`。

`Bytes` 是同一个道理：标准库的 `ToJson for Bytes` 把可打印 ASCII 原样输出、其余写成 `\xHH`，而 `FromJson for Bytes` 读的就是同一套格式（`moonbitlang/core/json/from_json.mbt:309`）。两头都是标准库的实现，不用库自己写编码器，也不会和标准库走偏。

## 2. 错误消息

`derive(FromJson)` 抛的是 `JsonDecodeError((JsonPath, String))`，`JsonPath` 的 `Show` 是 JSON Pointer（`/db/port`）。`extract` 拿这个路径反查 `Value`，翻成和 `get_*` 同一套错误：

| 情况 | 错误 |
|---|---|
| 字段缺失（`Missing field port`） | `MissingKey("db.port")` |
| 类型不符（`Int::from_json: expected number`） | `TypeMismatch("db.port", "Int", "Str")` |
| 整数溢出（`Int::from_json: overflow`） | `ParseError("key 'db.port' is out of range for Int")` |
| 结构体写了 `Int64`（`expected number in string representation`） | `ParseError("key 'db.port' is a 64-bit integer: declare the struct field as Int64Text or use get_int")` |

期望类型从标准库的消息前缀取（`String` → `Str`，`Double` → `Float`，`Map` → `Table`），实际类型从 `Value` 反查，所以消息里的名字和 `get_*` 一致。

## 3. 手写提取（`FromConfig`）：字段标签

`derive(FromJson)` 那条路牺牲了 per-field 的控制：字段名必须与配置键一致、没有默认值、
64 位字段要包 `Int64Text`。第二条路手写 impl，每个字段的 **json 标签内联在调用点**：

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

入口有三个：`Config::get_struct`（按键取子树）、`Config::get_struct_validated`
（提取后跑 `Validate`）、`Value::to_struct`（原语，标签相对该值解析）。

### Getter 的语义

| 方法族 | 行为 |
|---|---|
| `string` / `bool` / `int` / `int32` / `uint64` / `float` / `float_strict` / `bytes` | 必填：缺失报 `MissingKey`，类型不符报 `TypeMismatch`，口径同 `get_*` |
| `*_or` | 缺失用默认值；**键存在但类型不符（或越界）仍然报错**，绝不静默落默认 |
| `opt_*` | 缺失或 `null` 都是 `None`；类型不符照常报错 |
| `strings` / `ints` / `floats` / `bools` / `structs` | 元素错误带下标路径（`server.tags.1`） |
| `nested` | 子 Getter 前缀接上标签，嵌套结构体递归走 `from_config` |
| `value` / `opt_value` | 逃生舱：拿原始 `Value` 自己 match |

和 `get_*` 一样的严格性：`int` 只收整数来源（精确 `Int64`，这条路径直接读 `Value`，
不走 Json，9007199254740993 这类大整数不丢）；`float` 加宽整数、`float_strict` 不加宽；
字符串来源永不变成数字或字节串。没有 Json 往返、没有探针，性能比 derive 路径好。

### 两套路径的分工

MoonBit 没有反射，字段和标签的对应关系只能在调用点建立——**即使标签等于字段名，
也要在 impl 里写一遍**。所以默认走 derive(FromJson)（零样板，自动按字段名取）；
需要改名、缺省值、原生 64 位或嵌套路径时才手写 `FromConfig`。嵌套结构体若继续用
derive 路径，字段里用 `json_field` 一行委托（严格探针照常生效），不用逐字段手写。
逐字段一行的代价与 `Validate` impl 相同，是手写换控制力。

## 4. 结合 serde（`serde_bridge`）

[MoonBit 社区的 serde 框架](https://github.com/moonbit-community/serde.mbt)（`moonbit-community/serde.mbt`）把"类型描述自己的形状"和"格式读写数据模型"分开：类型实现 `Deserialize`（手写或由它的 derive 生成器生成），格式实现 `Deserializer`。`serde_bridge` 包给 moonfig 的 `Value` 写了一个 `Deserializer` 后端，任何 serde 类型都能直接从配置里提取：

```moonbit nocheck
// 类型侧：serde 用户既有代码，moonfig 不感知
impl @serde.Deserialize for Server with fn deserialize(d) -> Server raise @serde.DeError {
  d.deserialize_struct_begin("Server", ["db-host", "port"])
  // ... struct 协议逐字段读，required 收尾
}

// moonfig 侧：三 个入口
let srv : Server = @serde_bridge.extract_serde(value)          // 整棵树
let srv : Server = @serde_bridge.extract_serde_from(cfg, "srv") // 按键
db: @serde_bridge.serde_field(get, "db"),                      // FromConfig 字段级委托
```

语义与 serde 自带的 `Value` 后端对齐，且与 moonfig 的严格性一致：整数只收 `Int` 节点
（范围检查，浮点不截断、字符串不解析），`deserialize_double` 加宽整数（同 `get_float`），
字符串来源不能变数字或字节串。`DeError` 在入口翻译成 `ConfigError`：serde 的
`MissingField`/`InvalidType`/`InvalidValue` 分别对应 `MissingKey`/`TypeMismatch`/
`InvalidValue`，键名接上提取前缀（`$.db.port` → `key 'srv.db.port'`）。

依赖说明：moon.mod 因此引入 `moonbit-community/serde.mbt@0.3.1`（其自身只依赖
moonbitlang core，另有 parser/async 供它的 derive 生成器使用）。不使用 serde 的用户
不受影响：core 与 json_format 都不依赖它，现有 API 零变化。

可运行的完整示例（类型属性 + 生成器产物 + 三个入口）见
[examples/serde_extract](../../examples/serde_extract/README.md)。
