# serde 类型提取示例

项目里已经在用 [serde](https://github.com/moonbit-community/serde.mbt) 描述类型时，这些类型不经任何改动就能从配置里提取：类型只实现 serde 的 `Deserialize`（由 serde 的生成器生成），moonfig 的 `Value` 树作为它的一个格式后端参与提取。

运行：

```sh
moon run examples/serde_extract
```

## 类型侧：属性 + 生成器

类型用 serde 的用户属性描述形状，`Deserialize` 代码由 serde 的生成器生成（产物 `types_derive.mbt` 已提交，改了类型后重跑一次生成器即可）：

```moonbit
#serde.derive(Deserialize)
pub(all) struct DbCfg {
  #serde.rename("db-host") // 配置键与字段名解耦
  host : String
  port : Int64             // 超出 Double 精确范围的整数按原文还原
  comment : String?        // 缺失或 null 都是 None
}

#serde.derive(Deserialize)
pub(all) struct AppCfg {
  name : String
  retries : Int32
  tags : Array[String]
  db : DbCfg
}
```

再生成：

```sh
moonx moonbit-community/serde.mbt/derive examples/serde_extract
```

## moonfig 侧：三个入口

```moonbit
let srv : DbCfg = @serde_bridge.extract_serde(value)            // 整棵树
let app : AppCfg = @serde_bridge.extract_serde_from(cfg, "app") // 按键
db: @serde_bridge.serde_field(get, "db"),                       // FromConfig 里按字段委托
```

## 严格类型

与 moonfig 其他提取路径同一套哲学：整数只收整数来源，字符串来源不变数字，浮点不截断。配置写错了，报错指到具体键：

```
== serde 类型直接从配置提取 ==
完整配置     -> name=api retries=5 db=localhost:5432 comment=primary
缺失可选字段 -> name=api retries=5 db=localhost:5432 comment=None
缺必填字段   -> error: missing key 'app.db.db-host': no source provides it
类型写错     -> error: key 'app.retries': expected Int, got Str
大整数不丢   -> name=api retries=5 db=h:9007199254740993 comment=None

== 数组字段 ==
tags -> [edge, eu]
```

注意缺必填字段那条：键名 `app.db.db-host` 带完整前缀，且显示的是**配置里的键**（`db-host`），照着改配置就行。
