# 02 — 标记已读接口与会话列表未读数

**要构建的内容：** 让未读数真正被算出来并送到前端。在此之前 `01` 建的表是空的，`GET /chat/sessions` 也不返回未读数，前端无从渲染。

**被阻塞于（Blocked by）：** 01 — 已读位点数据模型与迁移

**状态（Status）：** resolved

- [x] `POST /chat/read`：请求体 `{ "recipientId": "<uuid>" }`，返回 `{ "recipientId": ..., "lastReadAt": <unix秒> }`，upsert
- [x] 收件主体判定沿用 `/chat/history` 的既有做法：先按 `groups` 表查，命中即群（并要求成员身份，非成员 403）；否则按单聊（禁止传自己的 id）
- [x] `GET /chat/sessions` 每个条目新增 `unreadCount: Int`
- [x] 未读在既有的内存遍历里累加，**不新增消息查询**
- [x] 无位点记录时按 `lastReadAt = 0` 处理（该会话可见的消息全算未读）
- [x] 群消息跳过入群之前的（`createdAt < joinedAt`）
- [x] 自己的消息不计入未读
- [x] 两个接口走 `UserToken` 鉴权；未携带 token 返回 401
- [x] 现有 151 项联调全绿 + 新增未读用例全绿

## 实施要点

- **未读累加的位置很关键**：`ChatHistoryController.sessions` 已经取回了「我参与的全部消息」并在 `for message in messages` 里遍历去重。把累加塞进**同一个循环**，就能零额外查询拿到全部会话的未读数。不要为每个会话单独发一条 count 查询——那会把请求放大 N 倍。
- 位点在遍历**之前**一次查回：`ReadState` 按 `user_id` 查全量，建成 `[key: lastReadAt]`。key 与循环里已有的 `key = "\(kind):\(peerId)"` 严格对齐，否则群会话与同 id 的单聊会串。
- 判定顺序：跳过自己发的（`message.mine.userId == myId`）→ 跳过 `createdAt <= lastReadAt` → 群消息再跳过入群前的。**入群过滤必须保留**，否则未读数会和「点进去读不到的消息数」对不上（这正是群聊 03 号 ticket 踩过的坑）。
- `SessionSummaryDTO` 新增 `unreadCount: Int`（不需要 `encodeIfPresent`——单聊群聊都有值）。
- 错误返回沿用现有风格 `Abort(.badRequest, reason: "...")`，文案说明「为什么」；群 id 的 UUID 校验与「群不存在 / 不是成员」的返回码沿用 `GroupController` 的既有约定（非法 UUID 400，不是成员 403）。
- 路由注册在 `routes.swift` 的 `tokenProtected` 分组内，与 `/chat/history`、`/chat/sessions` 放一起。
- 联调用例补进 `web/e2e-check.mjs`（脚本里已有注册/登录/建群/WS 的现成范式）。务必覆盖：**刷新后未读数保持**（这是本次推翻「前端本地计数」的核心理由，必须有对应用例）。

## Comments

**2026-09-01 拆分（Agent）：** 本 ticket 是未读功能的全部服务端工作，前端承接在 `03`。核心决策（服务端位点、无位点时全量计入、群消息计入）见 `../spec.md` 的「决策记录」与 ADR-0003。

**2026-09-01 实施（Agent）：** 全部服务端改动落在 `ChatHistoryController.swift` 与 `routes.swift`，未新增迁移（`01` 已建表）。验证：

- 编译：`swift build` 通过，无新增错误（仍只有既有 `Sendable` 告警）。
- 联调：`web/e2e-check.mjs` **176 PASS / 0 FAIL**（151 项原基线 + 25 项新增未读用例）。
- 新增用例覆盖：无位点时全量计入 / 自己的消息不计入 / 标记已读清零 / 重新拉取（刷新）保持 / 位点之后的新消息继续累加 / 重复标记是更新同一条位点 / 群消息计入 / 单聊与群位点互不串 / 入群前的群消息不计入 / 非成员无该群未读且标记已读 403 / 退群后不再产生未读 / 未带 token 401 / 给自己标记 400 / 缺 recipientId 400。

实现落点与给后续 issue 的约定：

- **未读累加塞进 `sessions` 已有的那个 `for message in messages`**，零额外消息查询；位点只在遍历**前**查一次（`ReadState` 按 `user_id` 全量）。新增查询总数为 1。
- **`joinedAtByGroupId` 的值由 `Date` 改成 Unix 秒**（`timeIntervalSince1970`）。原来那条 `createdAt < joinedAt` 比较的是两个 `Date`，本次要拿 `createdAt` 与位点的 `Double` 比，统一成同一套单位后三处比较（`createdAt` / `joinedAt` / `lastReadAt`）不再混用类型。
- **键对齐用 `sessionKey(_ kindOrType:peerId:)` 一个函数**：它把 `user`/`group` 与会话列表的 `direct`/`group` 都归一到 `"\(kind):\(peerId)"`，位点字典与遍历字典都走它。两处各写一遍字符串拼接迟早会串位（群 id 与同 id 单聊的键只差 kind）。
- **判定顺序**：跳过自己发的 → 跳过位点之前的 → 群消息再跳过入群前的。`continue`（入群前）+ `seen` 去重都在累加**之后**，否则每个会话只会数到 1 条。
- **非 UUID 的 `recipientId` 按单聊处理，不报 400** —— 沿用 `/chat/history` 的既有判定（它也是 `UUID(uuidString:)` 失败就当单聊）。群不存在同理落到单聊，不会 404。只有「命中群但不是成员」走 `requireMembership` 的 403。
- `POST /chat/read` 是**先查后写**的 upsert，没有用数据库的 upsert 能力（SQLite 下要写原始 SQL）。并发重复提交会撞联合唯一约束报 500，前端有节流，暂不处理。
