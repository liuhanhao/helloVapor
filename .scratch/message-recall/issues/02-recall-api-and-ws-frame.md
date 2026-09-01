# 02 — 撤回接口与 WS 协议帧

**要构建的内容：** 让用户真的能撤回，并且对方**立刻**看到。`01` 只让库里能表达撤回、读出来不泄漏原文，还没有任何写入路径。

**被阻塞于（Blocked by）：** 01 — 撤回标记与读取链路不泄漏原文

**状态（Status）：** resolved

- [x] `POST /chat/messages/:id/recall`，返回 `{ "id": ..., "recalledAt": <unix秒> }`
- [x] 只有发送者能撤回（`mine_userid == myId`），否则 403
- [x] 收件主体是群时要求成员身份（沿用 `GroupMember.requireMembership`），已退群 403
- [x] 非法 UUID 400；消息不存在 404；未带 token 401
- [x] **幂等**：已撤回过则直接返回当前状态，不重复写库、不重复扇出
- [x] `WebSocketService` 新增 `broadcast(_ json:to userIds:)` 作为扇出 seam
- [x] 扇出 `chatMessageRecalled` 帧：群聊给除发送者外的在线成员，单聊给对端
- [x] 路由注册在 `routes.swift` 的 `tokenProtected` 分组内
- [x] 新增联调用例全绿 + 现有 176 项全绿（合计 **196**）

## 实施要点

- **权限判定用 `message.mine.userId`**（发送者），不是 `to_id`。群消息里 `to_id` 是群 id，拿它比 `myId` 会永远不相等，导致谁都撤不回自己的群消息——这是个很容易写错的地方。
- **群消息撤回必须先过 `requireMembership`。** 已退群的人不该还能撤回群里的消息（退群即失去该群的访问权，这条语义在群聊里已经定死，撤回不要开后门）。
- **幂等而不是报错**：重复撤回（比如客户端连点两次）应当 200 并直接返回当前状态，不要 409——撤回是幂等操作，报冲突只会让客户端多写处理分支。判据是 `recalledAt != nil`。
- **扇出范围与发消息时严格一致**：`toType == .group` 时给除发送者外的成员，`user` 时给 `toId`。**发送者自己不回推**（它自己发起的，本地已更新）。离线用户静默跳过，不做离线补偿——与既有消息扇出保持一致。
- **`broadcast` 里复用既有的 `send(json:to socket:)`**，不要另写一份发送逻辑。注意 **不要在 `Task` 里直接操作 `WebSocket`**（会撞 `NIOCore/NIOLoopBound.swift: Precondition failed`）——接口层本来就在 async 上下文里，沿用现有写法即可，见 ROADMAP「动 WebSocket 相关代码前必读」第 1 条。
- 帧的 `data.content` 是**服务端生成**的提示文案（「`昵称` 撤回了一条消息」）。收件方不包含发送者，所以不需要「你撤回了一条」这个分支——那是发送者自己看历史时的文案，`01` 已经处理。
- 错误文案沿用现有风格 `Abort(.xxx, reason: "...")`，说明「为什么」。

### 联调用例（`web/e2e-check.mjs`）

务必覆盖：撤回成功返回位点 / **已撤回消息不泄漏原文** / 自己看是「你撤回了一条消息」、对方看是「`昵称` 撤回了一条消息」/ 撤他人的消息 403 / 不存在的消息 404 / 非法 UUID 400 / 未带 token 401 / **撤回后未读数不变** / 会话列表预览变提示 / 群消息撤回成功 / 已退群成员撤回 403 / 对端收到 `chatMessageRecalled` 帧 / 重复撤回幂等。

## Comments

**2026-09-01 拆分（Agent）：** 依赖 `01` 的 `recalledAt` 字段与「读取不泄漏原文」的 DTO 形状。前端承接在 `03`。

**为什么扇出 seam 单独抽**：`WebSocketService.connections` 是私有的，撤回是第一个「不发消息也要推帧」的场景。抽 `broadcast(_:to:)` 而不是把推送逻辑复制到 controller，是为了让「谁在线、怎么推」继续只有一个地方说了算。
