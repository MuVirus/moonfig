# serde 类型提取示例

项目里已经在用 [serde](https://github.com/moonbit-community/serde.mbt) 描述类型时，这些类型不经任何改动就能从配置里提取：类型只实现 serde 的 `Deserialize`（由 serde 的生成器生成），moonfig 的 `Value` 树作为它的一个格式后端参与提取。

运行：

```sh
moon run examples/serde_extract
```

## 类型侧：属性 + 生成器

类型用 serde 的用户属性描述形状，`Deserialize` 代码由 serde 的生成器生成。产物 `types_derive.mbt` 已提交，`moon.pkg` 里用 `rule` + `dev_build` 声明了生成步骤，所以 `moon check` / `moon test` 编译本包前会自动重跑生成器：

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

对应的 `moon.pkg` 声明：

```
rule(
  name: "serde-derive",
  command: "moonx moonbit-community/serde.mbt@0.3.1/derive $input",
)
dev_build(rule: "serde-derive", input: "types.mbt", output: "types_derive.mbt")
```

版本与 `moon.mod` 里的 serde.mbt 依赖保持一致即可。不想依赖构建钩子时，也可以手动跑同一条命令：

```sh
moonx moonbit-community/serde.mbt@0.3.1/derive examples/serde_extract
```

生成文件仍然要提交：pre-build 步骤只在包本身被构建时运行，下游把本模块当依赖使用时看到的是提交的内容。

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
