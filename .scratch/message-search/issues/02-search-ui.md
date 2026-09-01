# 02 — 搜索框与结果视图

**要构建的内容：** 让用户真的能搜、并且能点结果跳过去。在此之前 `01` 只提供了检索能力，界面上没有任何入口。

**被阻塞于（Blocked by）：** 01 — 搜索接口与可见性

**状态（Status）：** ready-for-agent

- [ ] `api.ts` 新增 `searchMessages(token, keyword, { limit, offset })`
- [ ] `stores/chat.ts` 新增搜索状态与 `searchMessages()` 动作
- [ ] **搜索结果不进 `sessions`**（独立列表，不污染未读与置顶逻辑）
- [ ] 会话列表顶部加搜索框：有关键词时列表区渲染搜索结果，清空恢复会话列表
- [ ] 点结果跳到该会话：`openConversation(recipientId, identity, kind)`
- [ ] 空结果、搜索中、搜索失败三种状态都有明确界面反馈
- [ ] `npm run build` 与 `npm test` 通过
- [ ] 冒烟：搜一个关键词，结果出现且点击能跳到对应会话

## 实施要点

- **搜索结果单独存一份（`searchResults`），绝不要塞进 `sessions`。** `sessions` 是「会话」列表，每条带未读与置顶语义；搜索结果是「消息」列表，两者混在一起会让未读计数和置顶逻辑长出各种特例。
- **点结果跳转用现成的 `openConversation(recipientId, identity, kind)`**：`recipientId` 与 `recipientType` 接口已返回，`recipientName` 可直接当 identity 的 nickname 用。跳过去后 `loadHistory` 会拉取该会话历史——不返回上下文也够用（spec 决策记录第 3 条）。
- **清空关键词要恢复会话列表并清掉结果**，不要留着上一次的结果——用户会以为那还是搜索结果。
- **搜索要不要防抖**：输入时发请求会很吵，用 `setTimeout` 合批即可（`stores/chat.ts` 里标记已读已有一个合批的现成写法可参考），别引依赖。
- **三种状态都要有反馈**：搜索中（"搜索中…"）、空结果（"没有找到相关消息"）、失败（显示 `ApiError.message`，服务端 reason 已是可读中文）。
- 结果条目展示：收件主体名 + 发送者昵称 + 内容 + 时间，沿用会话条目的既有风格；不引依赖、不新增 SVG。

## Comments

**2026-09-01 拆分（Agent）：** 依赖 `01` 的 `GET /chat/messages/search` 及其返回条目形状（`recipientType` / `recipientId` / `recipientName`）。
