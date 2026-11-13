# 手写 FromConfig

字段的配置键直接写在提取调用里，每个字段一行：`get.*` 的参数就是配置键，改名、默认值、可选字段和嵌套结构体都写在同一处。

运行：

```sh
moon run examples/from_config
```

## 关键片段

```moonbit
impl @config.FromConfig for ServerCfg with fn from_config(get : @config.Getter) -> ServerCfg raise @config.ConfigError {
  {
    host: get.string("db-host"), // 配置键 db-host，字段名 host
    port: get.int("port"), // 原生 Int64，大整数不丢
    retry: get.int32_or("retry", 3), // 缺失时用 3，类型不符仍报错
    comment: get.opt_string("comment"), // 缺失或 null 都是 None
    pool: get.nested("pool"), // 嵌套走 PoolCfg 的 from_config
  }
}

let srv : ServerCfg = cfg.get_struct("server")
```

标签都相对 `get_struct` 传入的子树解析。完整类型见 [`main.mbt`](main.mbt)。

## 输出

<!-- example-output -->
```text
host=localhost port=5432 retry=3 comment=None pool=8/30000
wrong retry -> key 'server.retry': expected Int, got Str
```

缺失才落默认值：`retry` 写成字符串 `"5"` 时仍然报类型错误。
