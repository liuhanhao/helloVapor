# 01 — 已读位点数据模型与迁移

**要构建的内容：** 把「我在某个会话读到哪」变成可持久化的事实。在此之前服务端不记录任何已读位置，未读数无从计算。

只做模型与迁移，**不改任何接口行为**——跑完之后现有功能必须完全不变（151 项联调是回归基线，其中 77 项是历史基线、33 项群管理、41 项群聊）。

**被阻塞于（Blocked by）：** 无

**状态（Status）：** ready-for-agent

- [ ] 新增 `ReadState` 模型与 `read_states` 表：`id`、`user_id`、`recipient_type`、`recipient_id`、`last_read_at`
- [ ] `(user_id, recipient_type, recipient_id)` 联合唯一
- [ ] `recipient_type` 复用 `ChatMessage.RecipientType`（`user` / `group`），不新造枚举
- [ ] 迁移可回滚（`revert`）；`swift build` 无新增错误
- [ ] 启动后表结构正确，联合唯一约束生效
- [ ] 现有 151 项联调全绿（不动任何接口，行为零变化）

## 实施要点

- 表名与 `CONTEXT.md` 的「已读位点」词条对应。字段叫 `recipient_type` / `recipient_id`，与 `message` 表的 `to_type` / `to_id` 保持同一套命名，不要写成 `session_type` 或 `peer_id`。
- `last_read_at` 用 `Double`（Unix 秒含小数），与 `ChatMessage.createdAt`、`GroupMember.joinedAt` 的时间表示一致——三者会在同一段代码里比较。
- 模型与迁移沿用 `GroupMember.swift` 的写法；迁移按顺序追加在 `configure.swift` 的 `GroupMember.Migration()` 之后。
- 联合唯一约束用 `.unique(on: "user_id", "recipient_type", "recipient_id")`（`GroupMember` 里已有同样写法可参考）。
- **`Group` 与 Fluent 的 `@Group` 属性包装器重名**（见 ROADMAP「动群聊相关代码前必读」第 1 条）：新模型里若要用 `@Group` 属性包装器会踩同一个坑，本表用不到，但心里有数。
- 本 ticket 不写任何查询方法——`02` 才知道要怎么查。先不要提前加。

## Comments

**2026-09-01 拆分（Agent）：** 决策依据见 `../spec.md` 的「决策记录」与 ADR-0003（服务端已读位点 vs 前端本地计数）。词汇「已读位点」已写入 `CONTEXT.md`。
