# 01 — 已读位点数据模型与迁移

**要构建的内容：** 把「我在某个会话读到哪」变成可持久化的事实。在此之前服务端不记录任何已读位置，未读数无从计算。

只做模型与迁移，**不改任何接口行为**——跑完之后现有功能必须完全不变（151 项联调是回归基线，其中 77 项是历史基线、33 项群管理、41 项群聊）。

**被阻塞于（Blocked by）：** 无

**状态（Status）：** resolved

- [x] 新增 `ReadState` 模型与 `read_states` 表：`id`、`user_id`、`recipient_type`、`recipient_id`、`last_read_at`
- [x] `(user_id, recipient_type, recipient_id)` 联合唯一
- [x] `recipient_type` 复用 `ChatMessage.RecipientType`（`user` / `group`），不新造枚举
- [x] 迁移可回滚（`revert`）；`swift build` 无新增错误
- [x] 启动后表结构正确，联合唯一约束生效
- [x] 现有 151 项联调全绿（不动任何接口，行为零变化）

## 实施要点

- 表名与 `CONTEXT.md` 的「已读位点」词条对应。字段叫 `recipient_type` / `recipient_id`，与 `message` 表的 `to_type` / `to_id` 保持同一套命名，不要写成 `session_type` 或 `peer_id`。
- `last_read_at` 用 `Double`（Unix 秒含小数），与 `ChatMessage.createdAt`、`GroupMember.joinedAt` 的时间表示一致——三者会在同一段代码里比较。
- 模型与迁移沿用 `GroupMember.swift` 的写法；迁移按顺序追加在 `configure.swift` 的 `GroupMember.Migration()` 之后。
- 联合唯一约束用 `.unique(on: "user_id", "recipient_type", "recipient_id")`（`GroupMember` 里已有同样写法可参考）。
- **`Group` 与 Fluent 的 `@Group` 属性包装器重名**（见 ROADMAP「动群聊相关代码前必读」第 1 条）：新模型里若要用 `@Group` 属性包装器会踩同一个坑，本表用不到，但心里有数。
- 本 ticket 不写任何查询方法——`02` 才知道要怎么查。先不要提前加。

## Comments

**2026-09-01 拆分（Agent）：** 决策依据见 `../spec.md` 的「决策记录」与 ADR-0003（服务端已读位点 vs 前端本地计数）。词汇「已读位点」已写入 `CONTEXT.md`。

**2026-09-01 实施（Agent）：** 只动模型与迁移，未新增/改动任何接口。验证方式与证据：

- 编译：`swift build` 通过，无新增错误（仅既有 `main.swift` 的 `Application(env)` deprecation 告警）。
- 表结构（启动后 `sqlite3 chatMessage.db` 实测）：
  `CREATE TABLE IF NOT EXISTS "read_states" ("id" UUID PRIMARY KEY, "user_id" TEXT NOT NULL, "recipient_type" TEXT NOT NULL, "recipient_id" TEXT NOT NULL, "last_read_at" DOUBLE NOT NULL, CONSTRAINT "uq:read_states.user_id+read_states.recipient_type+read_states.recipient_id" UNIQUE ("user_id","recipient_type","recipient_id"))`
- 联合唯一实测：重复插入 `(u1, group, g1)` 报 `UNIQUE constraint failed: read_states.user_id, read_states.recipient_type, read_states.recipient_id`（测试数据已清除，表为空）。
- 回滚：`swift run Run migrate --revert` 只回滚 `CreateReadState` 一条，`read_states` 被删除，**其余 6 张表（groups / group_members / message / users / user_tokens / uploads）与数据全部完好**。重新 `prepare`（重启服务走 `autoMigrate`）后表结构与首次一致。
- 回归：`web/e2e-check.mjs` **151 PASS / 0 FAIL**（未改任何接口，行为零变化）。

实现落点与给后续 issue 的约定：

- 新增 `hello/Sources/App/Models/ReadState.swift`（模型 + `Migration`），迁移按序追加在 `configure.swift` 的 `AddMessageRecipient()` 之后。
- **`last_read_at` 用 `@Field` 而不是 `@Timestamp`**——`GroupMember.joinedAt` 用 `@Timestamp` 是因为入群时间写一次就不变；位点每次标记已读都要更新，`@Timestamp(on: .create)` 只在创建时写一次。类型取 `Double`（Unix 秒含小数），与 `ChatMessage.createdAt`、`GroupMember.joinedAt` 一致——三者会在同一段代码里比较。
- **`recipientType` 存 `RecipientType.rawValue` 字符串**，与 `message.to_type` 同义；不引入数据库枚举（SQLite 下枚举迁移比字符串麻烦得多，群聊 01 已踩过）。
- **模型里故意没写任何查询方法。** `02` 才知道要怎么查（按 `user_id` 一次查全量建 `[key: lastReadAt]` 字典），现在提前加会是错的形状，届时还得删。
- **`migrate --revert` 需要交互确认**，非交互环境要 `yes y | swift run Run migrate --revert`；直接跑会在 stdin 上撞 `Fatal error: Received EOF on stdin`。
- **Fluent 按批次回滚**：本次只回滚了最后一条（`CreateReadState`），因为前面的迁移属于更早的批次。`02` 若新增迁移，回滚时会连带回滚同一批次内的其他迁移——**动生产库前先确认批次边界**。
