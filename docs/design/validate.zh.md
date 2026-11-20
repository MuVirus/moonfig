# 校验

> **结论**：校验是配置读进来之后显式的一步：`Rule` 说一条键上的约束，`Validate` 实现说一个结构体字段上的约束，两者报同一套 `ConfigError`，消息格式一致。
> **权威边界**：规范——规则、未知键和错误形状以本文为准；签名以 `.mbti` 为准。
> **不覆盖**：完整代码见 [examples/validate](../../examples/validate/README.md)，历史见 [decisions.md](../decisions/decisions.zh.md)。

类型系统拦不住写错的配置。`70000` 是合法的整数，`"verbose"` 是合法的字符串，没人读的键照样解析成功。不查的话，这些问题要到很晚才暴露：端口绑不上、日志级别悄悄退回默认、多出来的 `extra` 一直躺着。校验把发现的时机挪到启动时——这时候「拒绝启动」还是一个选项。

## 读值不等于检查

`get_int("db.port")` 回答的是「值是多少」，哪儿要用就在哪儿调。如果它顺手把范围也管了，同一份配置就会在每个调用点重查一遍，规则写在哪取决于最后一个调用者。所以检查是单独一步：什么时候跑由调用方决定，只跑一次。

约束有两种写法，因为有两种处境：结构体还不存在的时候，和已经有了的时候。

## `Rule`：把约束写成数据

`Rule` 只回答一个问题：这个路径上的值行不行？一条规则是一个小值，装着一条路径和一次检查。它不是 trait，也没有谁去实现它；你用 `Rule::int_range`、`Rule::string_len`、`Rule::one_of`、`Rule::allowed_keys` 或 `Rule::custom` 造出来，装进数组交给 `Config::validate`：

```moonbit
cfg.validate([
  Rule::int_range("db.port", 1L, 65535L),
  Rule::string_len("db.user", 1, 64),
  Rule::one_of("log.level", ["debug", "info", "warn", "error"]),
  Rule::allowed_keys("db", ["host", "port", "user"]),
])
```

这是「配置还没被类型描述过」时用的形状：`Config` 上没有字段声明，约束没处挂，路径也没处推，规则表就是那份缺失的声明。规则是数据，所以可以是字面量、运行时拼出来，或交给热更新。

规则只看得到自己那条路径上的值。执行方先在合并结果里解析路径，再把值交给检查：路径不存在会在检查之前报 `MissingKey`，所以必填项不用单独写规则，规则自己只负责比较。`Rule::allowed_keys` 是同一个值换个对象——比的是某一层表的键集合，未知键就是在这里被抓住的。

`validate` 遇到第一个错误就停，和 `get_*` 一个口径；要一次列全用 `validate_all`，它返回 `Array[ConfigError]`，顺序和规则表一致。两个都带 `raise`：没 `build()` 时会现场合并，读取或解析失败要报出来。

`Rule::custom(path, expected, check)` 是兜底：`check : (Value) -> String?` 返回 `None` 通过、`Some(实际值)` 失败，`expected` 是消息里「期望」的那段文字，`实际值` 进消息。密码这类字段只返回长度或类型，别返回原值。

## `Validate`：约束跟着类型走

配置提取成结构体之后，结构体就是规则表当初要手写的那份声明：名字和类型都写下来了，路径从 `prefix` 推。`Validate` 是这个处境下的 trait，只有一个方法，写在字段旁边：

```moonbit
impl @config.Validate for DbCfg with fn validate(self, prefix) {
  @config.check_int_range(prefix.add("port"), self.port.to_int64(), 1L, 65535L)
  @config.check_string_len(prefix.add("user"), self.user, 1, 64)
}

let db : DbCfg = cfg.get_struct_validated("db")
```

`get_struct_validated` 先走 `get_struct`，所以结构体是 `FromConfig` 类型；derive 路径上 `extract_validated_from(cfg, "db")` 先走 `extract_from`。两者随后都调结构体自己的 `Validate`，`prefix` 是提取时的起始路径，拼上字段名就是完整路径，错误消息和按键校验一致。`check_int_range` 和 `check_string_len` 就是对应内置规则的比较那一半——查路径在提取时已经做过。

`Validate` 是类型自己的代码，不是传进来的数据，换来的是规则做不到的两件事：字段改名时约束跟着走；手里有整个结构体，可以拿字段互相比较。

两个名字很容易混：`Config::validate` 吃规则表，`Validate::validate` 是结构体上的方法。

## 怎么选

一条键上的约束用 `Rule`；约束长在结构体字段上、或要拿两个字段比，用 `Validate`。两者不互相替代：未知键只有规则看得到，字段互比则写进 `Validate` 最省事——两个字段都在它手里。

## 未知键

`derive(FromJson)` 会忽略结构体里没有的字段，也不提供未知字段钩子，所以结构体不知道自己外面多了什么。未知键只能按键查：

```moonbit
Rule::allowed_keys("db", ["host", "port", "user"])
```

`allowed_keys` 和别的规则一样是 `Rule`，走同样的路径解析；不写就不查。嵌套结构要逐层给 `allowed_keys`；递归 strict schema 暂不做。

## 错误

校验抛两个变体：值不符合约束时 `InvalidValue(path, 期望约束, 实际)`，出现没列出的键时 `UnknownKey(path)`。字段、触发条件和消息原文见 [errors.md](../reference/errors.zh.md#invalidvalue) 和 [errors.md](../reference/errors.zh.md#unknownkey)。

`actual` 由规则给：类型不符时是形状名（`Str`），长度不符时是长度，自定义规则自己决定。
错误消息不打印密码类字段的原值。

## 边界

- 校验只读合并后的结果，不改值；要修值应该在 Source 层做。
- 校验失败不自动回退到旧配置；热更新时是否保留旧配置由调用方决定。
- 不给每个 `get_*` 加 `get_int_range` 之类的变体：API 会膨胀，同一份配置还会被反复检查。
- 不靠 `derive(FromJson)` 自动校验：派生的是标准库 trait，拿不到字段名、约束和未知键。
- 不做反射 / schema 自动映射：MoonBit 没有宏，最后仍要手写字段清单，不如直接写 `Validate`。

完整可运行的例子见 [`examples/validate`](../../examples/validate/README.md)。
