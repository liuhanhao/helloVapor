# 02 — 标记已读接口与会话列表未读数

**要构建的内容：** 让未读数真正被算出来并送到前端。在此之前 `01` 建的表是空的，`GET /chat/sessions` 也不返回未读数，前端无从渲染。

**被阻塞于（Blocked by）：** 01 — 已读位点数据模型与迁移

**状态（Status）：** ready-for-agent

- [ ] `POST /chat/read`：请求体 `{ "recipientId": "<uuid>" }`，返回 `{ "recipientId": ..., "lastReadAt": <unix秒> }`，upsert
- [ ] 收件主体判定沿用 `/chat/history` 的既有做法：先按 `groups` 表查，命中即群（并要求成员身份，非成员 403）；否则按单聊（禁止传自己的 id）
- [ ] `GET /chat/sessions` 每个条目新增 `unreadCount: Int`
- [ ] 未读在既有的内存遍历里累加，**不新增消息查询**
- [ ] 无位点记录时按 `lastReadAt = 0` 处理（该会话可见的消息全算未读）
- [ ] 群消息跳过入群之前的（`createdAt < joinedAt`）
- [ ] 自己的消息不计入未读
- [ ] 两个接口走 `UserToken` 鉴权；未携带 token 返回 401
- [ ] 现有 151 项联调全绿 + 新增未读用例全绿

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
