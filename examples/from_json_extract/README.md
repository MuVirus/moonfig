# 用 derive(FromJson) 提取结构体

结构体字段名与配置键一致时，给类型加 `#derive(@json.FromJson)`，再用 `extract_from` 一次把配置子树解码成结构体。

运行：

```sh
moon run examples/from_json_extract
```

关键调用：

```moonbit
#derive(@json.FromJson)
struct DbCfg {
  port : Int32
  name : String
}

let db : DbCfg = extract_from(cfg, "db")
```

`"db"` 是配置里的根键，字段名对应子树下的键；类型不符直接报错，`"5432"` 不会变成 `5432`。

这条路径是实验性的，`extract_from` 会发出 `alert_experimental`；示例在 `moon.pkg` 里关掉了它。

## 输出

<!-- example-output -->
```text
port = 5432, name = main
string port -> key 'db.port': expected Int, got Str
```
