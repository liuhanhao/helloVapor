# WebSocket 消息协议采用扩展而非重新设计

服务端与客户端之间的 WebSocket 消息沿用现有 layui 风格结构（`type` / `data.mine` / `data.to`），仅新增 `msgType` 字段区分文本与媒体消息。刻意不重新设计为更干净的扁平协议，因为 iOS 客户端已按现有结构解析消息，重设计会迫使 iOS 同步改造，超出本次"Web 先跑通"的最小范围。代价是协议结构冗余、服务端解析代码较繁琐，后续若两端统一改版应整体重议本决策。

## Considered Options

- 重新设计扁平消息格式（from / to / msgType / content / metadata）：结构更干净，但 iOS 现有解析逻辑需同步修改
