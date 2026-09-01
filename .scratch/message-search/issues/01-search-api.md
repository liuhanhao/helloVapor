# 01 — 搜索接口与可见性

**要构建的内容：** 让服务端能按关键词在「我可见的消息」里检索内容。在此之前没有任何按内容读取的路径，`GET /chat/history` 只会按时序翻页。

**只做后端**，跑完之后现有功能必须完全不变（196 项联调是回归基线）。

**被阻塞于（Blocked by）：** 无

**状态（Status）：** claimed

- [ ] `GET /chat/messages/search?q=&limit=&offset=`，返回 `{ messages, hasMore }`，按时间倒序
- [ ] 空/空白 `q` 返回 400；未带 token 401；`limit` 夹在 1~50；`offset` ≥ 0
- [ ] 单聊可见性：`to_type = user` 且两个方向之一涉及我
- [ ] 群可见性：在我加入的群里，且**只搜入群之后的消息**（`createdAt >= joinedAt`）
- [ ] **排除已撤回的消息**（`recalled_at IS NULL`）
- [ ] **只匹配文本消息**：媒体消息取回后在 Swift 侧剔除，不在 SQL 侧用 `NOT IN`
- [ ] 结果带 `recipientType` / `recipientId` / `recipientName`，指向可跳转的会话
- [ ] 路由注册在 `routes.swift` 的 `tokenProtected` 分组内
- [ ] 新增联调用例全绿 + 现有 196 项全绿

## 实施要点

- **撤回必须排除。** `recalledAt` 是 `ChatMessage` 顶层的 `@OptionalField`，可以用 key path 写 `builder.filter(\.$recalledAt == nil)`，会生成 `recalled_at IS NULL`。撤回是软删，原文仍在 `content` 里——漏掉这条，B2 的「撤回即不再给你看」会被搜索直接绕过。
- **媒体消息不能在 SQL 侧用 `NOT IN ('image','audio','video')` 过滤。** `mine_msgType` 的**旧数据是 NULL**（按 text 解读，见 `AddMessageMsgType` 的注释），`NULL NOT IN (...)` 求值为 NULL，行会被排除——老的文本消息会一起消失。正确做法：SQL 只管可见性 + LIKE，取回后在 Swift 里按 `image / audio / video` 剔除。
- **入群时间过滤在 SQL 侧做**（`created_at >= joinedAt`）。每个群的 `joinedAt` 不同，写一个 `or` 分支按群分别加条件；只加我仍是成员的那些群。`sessions` 里是在内存里过滤的，那是历史包袱（它本来就取回了全量消息），搜索不要照抄。
- **结果里的收件主体名**：群取 `groups` 表，单聊优先取 `users` 表、无注册记录时回退消息里的发送者快照——复用 `ChatHistoryController` 已有的 `usersById` / `groupsById` 私有 helper，别再写一遍。
- **单聊的 `recipientId` 是对方**（我发的填 `to_id`，对方发的填 `mine_userid`），与 `sessions` 里的 `peerId` 算法一致；群则填群 id。
- `LIKE` 用 Fluent 的 `.contains`（生成 `LIKE '%q%'`）。**已知上限**：关键词里的 `%` / `_` 会被当通配符且不转义，搜「100%」会命中过多。为它写裸 SQL 不划算，代码里留注释说明。
- 错误文案沿用现有风格 `Abort(.xxx, reason: "...")`。

## Comments

**2026-09-01 拆分（Agent）：** 决策依据见 `../spec.md` 的「决策记录」。本 ticket 只做检索能力，前端搜索框与结果视图在 `02`。

**跟 B2 的两处耦合**（改动时留意）：撤回字段 `recalled_at`（B2 01 加的）、以及「撤回后未读数不变」的语义——搜索**不影响**未读，它是一条独立的读路径，不要顺手去改未读累加。
