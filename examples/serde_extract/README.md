# serde 类型提取

类型只用 serde 描述，moonfig 的 `Value` 树作为 serde 的后端参与提取：类型不用为配置改动，moonfig 也不用知道类型形状。

运行：

```sh
moon run examples/serde_extract
```

## 关键片段

类型侧只有 `#serde.derive(Deserialize)`（`types_derive.mbt` 是它的生成产物，已提交）：

```moonbit
#serde.derive(Deserialize)
pub(all) struct DbCfg {
  #serde.rename("db-host") // 配置键与字段名解耦
  host : String
  port : Int64
}
```

提取是一个调用，`"app"` 是配置里的根键：

```moonbit
let app : AppCfg = @serde_bridge.extract_serde_from(cfg, "app")
```

完整类型和两个输入见 [`main.mbt`](main.mbt)。

## 输出

<!-- example-output -->
```text
name=api db=localhost:5432 tags=edge, eu
missing db-host -> missing key 'app.db.db-host': no source provides it
```

缺必填字段时键名带完整前缀，且显示配置里的键 `db-host`，照着改配置就行。
