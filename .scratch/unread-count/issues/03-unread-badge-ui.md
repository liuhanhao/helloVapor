# 03 — 前端未读角标与清零

**要构建的内容：** 让用户在会话列表里看见未读，并在打开会话时清零。服务端算得再准，前端不渲染等于没做。

**被阻塞于（Blocked by）：** 02 — 标记已读接口与会话列表未读数

**状态（Status）：** ready-for-agent

- [ ] 会话列表条目在未读 > 0 时显示角标；超过 99 显示「99+」
- [ ] 打开会话时调 `POST /chat/read` 清零，并把本地该会话未读置 0
- [ ] 会话打开期间该会话收到新消息也标记已读（节流，避免每条消息一个请求）
- [ ] 收到非当前会话的消息时，本地未读 +1（不发请求，等下次 `refreshSessions` 与服务端对齐）
- [ ] 刷新后未读数来自服务端，保持准确
- [ ] `npm run build` 通过；手工冒烟：切换会话清零、刷新保持、群消息计入

## 实施要点

- **未读不要持久化到 localStorage。** 服务端是权威来源，刷新即重新拉取。顶栏登录态用 localStorage 是因为它是凭证，未读不是凭证——不要照搬 `stores/auth.ts` 的做法，那会引入第二处真相（ROADMAP 的 B1 原决策正是栽在这里）。
- 本地 +1 只是**乐观更新**，用于「不刷新页面就能看到角标变化」；服务端值在 `refreshSessions` 时覆盖它。两者冲突时以服务端为准，不要试图合并。
- 角标的显示判断放在 `ChatView.vue` 的会话列表渲染里；未读数存进 `stores/chat.ts`，与 `recipientKinds` / `recipientNames` 一样按收件主体 id 索引，命名用 `unreadCounts`，**不要叫 `unread` 再配一堆布尔**。
- 标记已读的节流：用时间戳或 `setTimeout` 合批即可，别引依赖。注意「打开会话」这一次必须立即发，不能等节流窗口。
- 样式沿用会话列表既有条目的配色与圆角，不引图标库，不新增 SVG。
- 术语与文案遵循 `CONTEXT.md`：界面上说「未读」，不要出现「已读回执」（那是另一个方向的概念，见 spec 的 Avoid 表）。
- 改完跑一次 `npx vue-tsc --noEmit` 与 `npm run build`，并复跑 `npm run e2e`（服务端未动，151 项应仍全绿）。

## Comments

**2026-09-01 拆分（Agent）：** 依赖 `02` 的接口契约（`POST /chat/read` 与 `SessionSummaryDTO.unreadCount`），等它 resolved 后再开工。
