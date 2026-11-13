# 最小示例

两层 `StringSource` 叠在一起：第一层给出 `db.host` 和 `db.port`，第二层只覆盖 `db.port`。后加的来源只覆盖同名键，其余键保留。

运行：

```sh
moon run examples/quick_start
```

完整程序在 [`main.mbt`](main.mbt)，导入在 [`moon.pkg`](moon.pkg)；把整个目录复制走就能直接运行。

## 输出

<!-- example-output -->
```text
db.host = localhost
db.port = 6543
```

`db.host` 来自第一层，没有被第二层影响；`db.port` 被第二层覆盖。README 的快速开始用的就是这个例子。
