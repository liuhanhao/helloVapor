# 02 — 会话列表与历史消息

**要构建的内容：** 用户刷新页面或重新打开某个会话后，登录状态、会话列表和历史聊天记录都不丢失。服务端新增会话列表接口（按联系人分组返回对方身份与最后一条消息，按时间倒序）和历史消息接口（双方消息按时间正序、支持分页）；前端实现左侧会话列表（展示联系人、最后消息预览与时间，新消息实时置顶）、进入会话拉取历史消息、凭证存 localStorage 刷新恢复、退出登录清除凭证回到登录页。术语遵循根目录 `CONTEXT.md`（会话、联系人）。

**被阻塞于（Blocked by）：** 01 — 曳光弹：文本消息端到端跑通

**状态（Status）：** resolved

- [x] 登录后左侧展示会话列表，含联系人昵称、最后一条消息预览与时间
- [x] 点击会话项右侧加载该会话历史消息（按时间正序）
- [x] 收到新消息时对应会话自动置顶并更新预览
- [x] 刷新页面后登录态与会话列表自动恢复
- [x] 退出登录后凭证被清除并回到登录页
- [x] 历史消息分页加载正常工作

## Comments

**2026-08-27 验收检查（Agent）：** 第二阶段全部完成。验证方式与证据：

- 编译检查：`swift build` 通过（仅既有 deprecation 警告）；`vue-tsc --noEmit` 通过。
- 服务端联调（`web/e2e-check.mjs` 扩展为 30 项）：注册/登录/`/chat/me`、WS 实时互发、`chatMessageAck`（含服务端时间戳与消息 id）、推送的消息带 `data.id / / timestamp`、会话列表（含 401、用户表权威身份、无注册记录时的回退、双方视角的 `fromSelf`、按最后消息时间倒序）、历史消息（双方消息时间正序、`fromSelf` 正确、带 id 与时间戳、缺失 `peer 400`、陌生联系人空结果、`limit + before` 分页 `hasMore` 正确）全部 PASS。
- UI 冒烟（agent-browser，登录 e2e 生成的 `alice…@test.com / pass123`）：
  - 登录后侧栏出现 Bob / Offline 两个会话，按最后消息时间倒序（Offline 居首，因最后一条是 Alice 自己发给离线用户的），预览正确带「我：」前缀。
  - 点击 Bob 会话右侧加载两条历史（`你好，Bob！` 09:54:42 + `旧格式消息，来自 iOS` 09:54:43），按时间正序排列。
  - 在聊天窗口发送「浏览器冒烟测试消息」→ 右侧气泡出现 + Bob 会话置顶预览同步更新。
  - 用 Node WS 以 Bob 身份推送「来自 Bob 的实时消息」→ 浏览器实时收到气泡 + 会话预览同步更新且仍在顶部。
  - 直接访问 `/chat` 刷新页面 → 登录态自动恢复、会话列表自动恢复、重新打开 Bob 会话历史消息完整加载。
  - 点击「退出」→ 跳回登录页；再次直接访问 `/chat` → 被路由守卫拦截回登录页（凭证已清）。
- 实测中发现的回归：Vite 代理 `/chat` 同时拦截了裸的 SPA 路由 `/chat`，导致刷新 `/chat` 时代理把请求转发到 Vapor 返回 404 JSON。已在 `vite.config.ts` 把代理键改为正则 `^/chat/`，只代理 `/chat/...` 形式 API 路径，裸 `/chat` 由 Vite history 回退到 `index.html`。修复后刷新 `/chat` 工作正常。
- 实现落点：
  - 服务端：`hello/Sources/App/Controllers/ChatHistoryController.swift` 新增两个接口；`routes.swift` 注册到 `tokenProtected` 组；`WebSocketService.swift` 在推送与确认中携带消息 id 与服务端时间戳（沿 ADR-0002 增量扩展，与 iOS SwiftyJSON 容忍未知键的特性兼容）。
  - 前端：`types.ts` 新增 `SessionSummary` / `HistoryMessage` / `HistoryPage`，`MessageItem.id`，`ChatPayload.data.id / timestamp`，`ChatAck`；`api.ts` 新增 `fetchSessions` / `fetchHistory`（统一秒→毫秒）；`stores/chat.ts` 重写：会话列表 + 历史加载 + 分页 + 实时置顶 + `id` 去重 + `reset()`；`views/ChatView.vue` 重写为左侧会话列表 + 右侧聊天窗口布局，加入「加载更早的消息」按钮并保持滚动位置；`vite.config.ts` 代理键改为正则。
  - 数据库 / 迁移：无变化（消息表已具备所需扁平列）。