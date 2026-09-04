# 02 — 搜索框与结果视图

**要构建的内容：** 让用户真的能搜、并且能点结果跳过去。在此之前 `01` 只提供了检索能力，界面上没有任何入口。

**被阻塞于（Blocked by）：** 01 — 搜索接口与可见性

**状态（Status）：** resolved（✅ 2026-09-02 人工验收通过）

- [x] `api.ts` 新增 `searchMessages(token, keyword, { limit, offset })`
- [x] `stores/chat.ts` 新增搜索状态与 `searchMessages()` / `searchSoon()` / `clearSearch()` 动作
- [x] **搜索结果不进 `sessions`**（独立列表，不污染未读与置顶逻辑）
- [x] 会话列表顶部加搜索框：有关键词时列表区渲染搜索结果，清空恢复会话列表
- [x] 点结果跳到该会话：`openConversation(recipientId, identity, kind)`
- [x] 空结果、搜索中、搜索失败三种状态都有明确界面反馈
- [x] `npm run build` 与 `npm test` 通过（单测 16 项，其中 3 项覆盖搜索）
- [x] 冒烟：搜一个关键词，结果出现且点击能跳到对应会话 **← 2026-09-02 人工验收通过**

## 实施要点

- **搜索结果单独存一份（`searchResults`），绝不要塞进 `sessions`。** `sessions` 是「会话」列表，每条带未读与置顶语义；搜索结果是「消息」列表，两者混在一起会让未读计数和置顶逻辑长出各种特例。
- **点结果跳转用现成的 `openConversation(recipientId, identity, kind)`**：`recipientId` 与 `recipientType` 接口已返回，`recipientName` 可直接当 identity 的 nickname 用。跳过去后 `loadHistory` 会拉取该会话历史——不返回上下文也够用（spec 决策记录第 3 条）。
- **清空关键词要恢复会话列表并清掉结果**，不要留着上一次的结果——用户会以为那还是搜索结果。
- **搜索要不要防抖**：输入时发请求会很吵，用 `setTimeout` 合批即可（`stores/chat.ts` 里标记已读已有一个合批的现成写法可参考），别引依赖。
- **三种状态都要有反馈**：搜索中（"搜索中…"）、空结果（"没有找到相关消息"）、失败（显示 `ApiError.message`，服务端 reason 已是可读中文）。
- 结果条目展示：收件主体名 + 发送者昵称 + 内容 + 时间，沿用会话条目的既有风格；不引依赖、不新增 SVG。

## Comments

**2026-09-01 拆分（Agent）：** 依赖 `01` 的 `GET /chat/messages/search` 及其返回条目形状（`recipientType` / `recipientId` / `recipientName`）。

## Comments

**2026-09-01 实施（Agent）：** 改动落在 `api.ts` / `types.ts` / `stores/chat.ts` / `views/ChatView.vue`。验证：`npm run build` 通过（含 `vue-tsc`，模板里的绑定与函数名都过了类型检查）；`npm test` **16 passed**（新增 3 项：结果隔离不污染 `sessions`、清空关键词即清空结果、输入防抖只发一次请求）；`npm run e2e` 214 项全绿。

实现落点：

- **搜索结果存 `searchResults`，不进 `sessions`**——这是本 ticket 最关键的一条。两者混在一起会让未读计数和置顶逻辑长出各种特例，所以宁可多一个状态。
- **防抖放进 store（`searchSoon` + `SEARCH_DEBOUNCE_MS = 300`）**而不是视图层：输入是视图的事，但「什么时候发请求」是数据层的事，且这样能被单测覆盖（已覆盖）。
- **防抖窗口内就把 `searching` 置为 true**：否则结果区会先闪一下「没有找到相关消息」再出结果。
- **`reset()` 与 `leaveGroup()` 都会清理/刷新搜索结果**——退群后这个群的消息已从可见范围里消失，留着旧结果就是错的。
- 结果条目**复用了会话条目的 `.avatar` / `.session-info` / `.session-top` 等既有样式**，只新增了 `.search-list` 的容器样式，没有另起炉灶。

### 唯一未完成：浏览器冒烟（待人工）

**为什么没做**：跑完自动化验证时已是次日，Chrome 的 CDP 调试端点（9222）在监听但对 HTTP 请求无响应（`/json/version`、`/json/list` 均返回空），CDP 代理连不上。**重启 Chrome 会关掉你正在看的所有标签页，这个我没擅自做。**

**要补的话怎么做**（服务端与前端 dev server 都还开着）：

1. 打开 `http://127.0.0.1:5173/`，登录任一账号
2. 在会话里发两条含同一关键词的消息，比如「麒麟芯片」「麒麟9000」
3. 在会话列表顶部的搜索框输入「麒麟」→ 应出现 2 条结果，每条显示会话名、时间与内容
4. 点其中一条 → 应跳到对应会话并加载历史
5. 清空搜索框 → 应恢复会话列表
6. （顺带验证 B2）搜一条**已撤回**消息的原文 → 应搜不到

第 6 步比较关键：它验证的是「撤回是软删、原文仍躺在库里，但搜索必须排除」这条与 B2 的契约。服务端用例已经覆盖了（撤回后搜不到原文），这里只是确认前端不会绕过它。
