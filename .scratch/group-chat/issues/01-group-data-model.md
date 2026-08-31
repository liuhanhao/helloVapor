# 01 — 群聊数据模型与迁移

**要构建的内容：** 把「消息投递的目标」从「单个用户」泛化成「收件主体（用户或群）」，并加上群与成员两张表。这是群聊的地基：现在 `ChatMessage.to` 是单个用户（`to_userid`），会话列表按「对方用户」聚合，群里那条路径在模型上根本不存在。

只做模型与迁移，**不改任何接口行为**——跑完之后现有单聊功能必须完全不变（77 项联调是回归基线）。

**被阻塞于（Blocked by）：** 无（前置 A1~A4 已 resolved）

**状态（Status）：** resolved

- [x] 新增 `Group` 模型与 `groups` 表：`id`、`name`、`avatar`、`owner_id`、`created_at`
- [x] 新增 `GroupMember` 模型与 `group_members` 表：`id`、`group_id`、`user_id`、`joined_at`，`(group_id, user_id)` 联合唯一
- [x] `message` 表新增 `to_type`（`user` / `group`）与 `to_id`
- [x] 迁移回填旧数据：`to_type = 'user'`、`to_id = to_userid`（既有消息全是单聊）
- [x] 迁移可回滚（`revert`）；`swift build` 无新增错误
- [x] 启动后表结构正确，旧数据的 `to_type` / `to_id` 均已回填
- [x] 现有 77 项联调全绿（单聊行为零变化）

## 实施要点

- 字段命名沿用现有约定：`@Group(key: "to")` + `@Field(key: "userid")` 落盘为 `to_userid`，新增字段直接叫 `to_type` / `to_id`（不带 `to_` 前缀的嵌套语义，与既有 `mine_msgType` 的命名习惯一致即可）。
- `to_type` 用字符串存（`user` / `group`），与既有 `type`、`msgType` 的风格保持一致，不引入数据库枚举——SQLite 下枚举迁移比字符串麻烦得多。
- **`message.type` 字段不要动。** 它现在实际存的是 WS 消息的 `type` 值（`"chatMessage"`），从来没被用来区分单聊/群聊，已被误用。删除要动旧数据、收益为零；保留它、不依赖它。新逻辑一律读 `to_type`。
- 旧数据回填在 `prepare` 里用 raw SQL 完成，别指望 ORM 逐条更新。
- 迁移按 `configure.swift` 里现有顺序追加在 `Upload.Migration()` 之后。

## Comments

**2026-08-31 拆分（Agent）：** 决策依据见 `../spec.md` 的「决策记录」（复用 message 表不分表、`type` 字段保留但不依赖）。词汇（群 / 会话 / 单聊 / 成员 / 收件主体）已写入根目录 `CONTEXT.md`。

**2026-08-31 实施（Agent）：** 只动模型与迁移，未新增/改动任何接口。验证方式与证据：

- 编译：`swift build` 通过，无新增错误（仅既有 Swift 6 `Sendable` 警告，User/Upload/UserToken 同样存在）。
- 表结构（启动后 `sqlite3 chatMessage.db` 实测）：
  - `groups("id" UUID PRIMARY KEY, "name" TEXT NOT NULL, "avatar" TEXT NOT NULL, "owner_id" TEXT NOT NULL, "created_at" DOUBLE)`
  - `group_members("id" UUID PRIMARY KEY, "group_id" TEXT NOT NULL, "user_id" TEXT NOT NULL, "joined_at" DOUBLE, CONSTRAINT "uq:group_members.group_id+group_members.user_id" UNIQUE ("group_id","user_id"))`
  - `message` 由 14 列增至 16 列，新增 `to_type` / `to_id`（TEXT，可空）。
- 联合唯一实测：重复插入 `(g1, alice)` 报 `UNIQUE constraint failed: group_members.group_id, group_members.user_id`（测试数据已清除，两表均为空）。
- 回填：迁移前 216 条消息，回填后 `to_type='user' AND to_id=to_userid` 命中 216、异常 0；联调新增消息后 256 条全部命中、异常 0。
- 回滚：三条迁移 `migrate --revert` 全部成功——`to_type`/`to_id` 被删除（message 回到 14 列）、`groups` 与 `group_members` 被删除；重新 `prepare` 后表结构与回填结果复现一致。
- 回归：`web/e2e-check.mjs` 77 PASS / 0 FAIL（回滚重迁后复跑一次，同为 77/0）。

实现落点与两处需要后续 issue 知道的坑：

- 新增 `hello/Sources/App/Models/Group.swift`、`GroupMember.swift`（模型 + `Migration`，沿用 `Upload.Migration` 的写法）；`ChatMessage.swift` 新增 `RecipientType` 枚举、`toType` / `toId` 两个 `@Field` 与 `AddMessageRecipient` 迁移；`configure.swift` 三条迁移按序追加在 `Upload.Migration()` 之后。
- **`Group` 与 Fluent 的 `@Group` 属性包装器重名**：`@Group` 是 `Fields.Group` 的类型别名，模块里一旦有 `Group` 类就会被遮蔽，编译期报 `unknown attribute`。已在 `ChatMessage.swift` 加 `typealias GroupField<Value: Fields> = GroupProperty<ChatMessage, Value>`，`mine` / `to` 改用 `@GroupField(key:)`。**后续在 `ChatMessage` 里加属性时不要用 `@Group`。**
- **SQLite 的 `ALTER TABLE` 一次只能加/删一列**：`.field("to_type").field("to_id").update()` 会生成 `ADD COLUMN ... , ADD COLUMN ...` 并报 `near ",": syntax error`。`prepare` 与 `revert` 都拆成两条 `.update()`。后续给 `message` 加列时同理。
- `to_id` 的写入在 `ChatMessage.init` 里兜底：未显式传入时取 `to.userId`，因此既有调用方（WS 收发）零改动就写全了收件主体；群聊落地时显式传 `toType: .group` 与群 id 即可。
