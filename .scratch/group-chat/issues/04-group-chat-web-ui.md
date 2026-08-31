# 04 — Web 端群聊界面

**要构建的内容：** 让用户在浏览器里看见并使用群聊：会话列表能区分单聊与群聊，群聊窗口能显示是谁在说话，能建群、看成员、退群。

**被阻塞于（Blocked by）：** 02 — 建群与成员管理接口；03 — 群消息端到端流转

**状态（Status）：** resolved

- [x] 会话列表条目区分形态：群聊显示群名 + 成员数，单聊维持现状
- [x] 群聊窗口：气泡显示发送者昵称（自己的消息不显示）
- [x] 建群入口：选择若干用户 → 建群 → 打开该群会话
- [x] 群信息页：群名、成员列表、退群
- [x] 前端状态把会话键从「对方用户 id」泛化为「收件主体 id」（现在是 `conversations: Record<string, MessageItem[]>`，键是 `peerUserId`）
- [x] 群消息实时到达时正确归档到对应群会话，并更新会话列表预览与置顶
- [x] 手动冒烟：三人群互发、建群、退群、刷新后恢复

## 实施要点

- **最重的一处是状态结构的泛化**：`chat.ts` 里 `peerNames`、`conversations`、`currentPeerId` 都是围绕「对方用户」建的，群聊进来后这些命名会骗人。改之前先想清楚命名（参考 `CONTEXT.md` 的「收件主体」），不要沿用 `peerXxx` 指群。
- 输入区与媒体发送能力（图片/音频/视频、emoji）完全复用现有实现，群聊不应该有第二套发送逻辑。
- 术语与文案遵循 `CONTEXT.md`：界面上说「群」「成员」，不要出现「聊天室」「频道」；「联系人」只用于单聊的对方。
- 图标按需从 koboyo.com/icons 取 SVG，不引图标库（既有约定）。
- 改完跑一次 `npx vue-tsc --noEmit` 与 `npm run e2e`。

## Comments

**2026-08-31 拆分（Agent）：** 依赖 02/03 的接口契约，等它们 resolved 后再开工。

**2026-08-31 实施（Agent）：** 群聊在浏览器里可用了，验证方式与证据：

- 类型与构建：`npx vue-tsc --noEmit` 与 `npm run build` 均通过，无新增告警。
- 服务端回归：`npm run e2e` **151 PASS / 0 FAIL**（既有基线全绿，本次未动服务端）。
- 前端冒烟（临时脚本，跑完即删）：用 Vite SSR 加载 `chat.ts` 真实 store，对 8080 上的服务跑了一遍流程，**22 PASS / 0 FAIL**。覆盖：建群后打开该群会话 / 会话键判定为群 / 列表出现群条目（群名 + 成员数 3）/ 被拉入者列表出现该群 / 三人群互发各自归档 / 发送者昵称（Alice、Bob）/ 会话置顶与预览 / 自己的消息不带昵称 / 刷新后群会话与历史（含昵称）恢复且能继续发送 / 退群后会话与消息清空、不再收到该群消息 / 单聊仍标记 direct 且不串进群会话。

实现落点与给后续 issue 的约定：

- **状态里的 `peerXxx` 全部改名了**：`peerNames` → `recipientNames`、`currentPeerId` → `currentRecipientId`，参数与注释统一为「收件主体（recipient）」。`conversations` / `historyLoaded` / `hasMoreHistory` 的键不变（仍是 id），但语义已泛化为收件主体 id。**会话列表项的 `peer` 字段名保留**——那是 `/chat/sessions` 的 JSON 字段名，改它要加一层映射，收益不抵成本；类型上已注明「单聊为联系人、群聊为群」。
- **新增两个状态**回答「这个收件主体是不是群」：`recipientKinds`（id → `direct`/`group`，决定 WS 的 `to.type` 与气泡是否显示昵称）与 `groups`（群 id → 群信息，供成员数）。判定一律走 `chat.isGroup(id)`，不要在视图里另猜。
- **会话列表只含有过消息的会话**，`GET /chat/groups` 的结果要在此之后合并进列表（顺序不能倒），否则刚建好还没发言的群刷新就消失了；两个请求在 `ChatView` 的 `refreshSessions` 里串起来调用。
- **`chatMessageError` 已接**：错误帧不带消息标识，按与 ack 相同的顺序匹配最早一条待确认消息，标记 `error`（气泡显示「发送失败」，hover 看原因）。这是 03 号 ticket 明确要求前端兜住的一点。
- **没有新增图标**：`koboyo.com/icons` 在本机不可达（`curl` 与 `WebFetch` 都连不上），建群与群信息入口改用文字按钮，不引图标库也不手造 SVG path。需要图标时再补。
- **未做（规格里没要求）**：改群名、拉人入群。二者服务端接口已就绪（`PATCH /chat/groups/:id`、`POST /chat/groups/:id/members`），群信息页加个入口即可接上。
