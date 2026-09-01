# 03 — 前端未读角标与清零

**要构建的内容：** 让用户在会话列表里看见未读，并在打开会话时清零。服务端算得再准，前端不渲染等于没做。

**被阻塞于（Blocked by）：** 02 — 标记已读接口与会话列表未读数

**状态（Status）：** resolved

- [x] 会话列表条目在未读 > 0 时显示角标；超过 99 显示「99+」
- [x] 打开会话时调 `POST /chat/read` 清零，并把本地该会话未读置 0
- [x] 会话打开期间该会话收到新消息也标记已读（节流，避免每条消息一个请求）
- [x] 收到非当前会话的消息时，本地未读 +1（不发请求，等下次 `refreshSessions` 与服务端对齐）
- [x] 刷新后未读数来自服务端，保持准确
- [x] `npm run build` 通过
- [x] 手工冒烟：切换会话清零、刷新保持、群消息计入

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

**2026-09-01 实施（Agent）：** 改动落在 `api.ts`（`markRead`）、`types.ts`（`SessionSummary.unreadCount`）、`stores/chat.ts`（未读状态与标记已读）、`views/ChatView.vue`（角标渲染与样式）。验证：

- `npx vue-tsc --noEmit` 与 `npm run build` 均通过（无新增告警）。
- 服务端未动，复跑 `npm run e2e` **176 PASS / 0 FAIL**。
- **手工冒烟尚未做**（需要两个浏览器会话互发）：切换会话清零、刷新保持、群消息计入。冒烟入口 `http://localhost:5173`（Vite 代理 8080），服务端已跑在 8080 的新构建上。
- 未读链路的服务端一侧由 `02` 的 25 项新增用例覆盖（未读累加、清零、刷新保持、群消息计入、入群前不计入），前端只负责渲染与时机。

实现落点与给后续 issue 的约定：

- **未读只存 `unreadCounts: Record<收件主体 id, number>`，不落 localStorage。** `loadSessions` 每次用服务端值整体覆盖它，本地只在「收到非当前会话消息」时 +1。服务端是唯一真相，冲突时以服务端为准，不做合并。
- **标记已读的三条路径**：打开会话立即发（`openConversation` 里直接 `void markRead`）→ 会话内新消息走 `markReadSoon`（1s 合批）→ 切换会话时把上一个会话待发的那次补上，避免落在窗口里的消息漏标。节流用 `setTimeout`，没引依赖。
- **角标放在预览行**（`.session-bottom` 里与 `.preview` 并排，`.preview` 加 `flex: 1; min-width: 0` 才能继续省略号截断）。样式沿用条目的圆角字号，红底白字，没引图标库。
- **已知上限**：角标不做「99+」之外的折叠，200 人群刷屏时未读会很大（spec 的 Out of Scope 明确由「99+」兜住）；`GET /chat/sessions` 全量取消息再内存过滤的上限未读一并继承，量上来要两个一起改。

**2026-09-01 手工冒烟（Agent，经 CDP 自动化，U-B 走 WS + 浏览器扮 U-A）：** 因为两个浏览器同源会共享 localStorage、登录态互相打架，改用「浏览器登录 U-A + 临时脚本以 U-B 身份经 WS 发消息」走完三步：

- **群消息计入未读**：U-B 发 3 条单聊 + 2 条群，U-A 会话列表快照 → `[{冒烟群 2 人, B-5, badge=2}, {SmokeB, B-3, badge=3}]`。✓
- **切换会话清零**：点击 SmokeB 会话 → 快照 `{冒烟群 2 人, B-5, badge=2, active=false}, {SmokeB, B-3, badge=null, active=true}`。单聊清零，群未读保留。✓
- **刷新保持**：再次刷新页面 → `[{冒烟群 2 人, B-5, badge=2}, {SmokeB, B-3, badge=null}]`，未读从服务端重拉，与刷新前一致。✓
- **会话内新消息不累加（用户故事 3）**：点击群会话再收一条群消息 → 群 badge=null；再刷新仍 null，标记已读已落库。✓
- **角标视觉**：红底白字圆角，置于预览行右侧，与列表条目既有样式一致（截图已确认，未入档，避免给 spec 目录带无关产物）。
