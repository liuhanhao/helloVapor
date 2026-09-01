# 03 — 前端撤回入口与渲染

**要构建的内容：** 让用户点得到撤回，并且撤回后界面立刻变成提示。服务端算得再准，前端不渲染等于没做。

**被阻塞于（Blocked by）：** 02 — 撤回接口与 WS 协议帧

**状态（Status）：** resolved

- [x] `api.ts` 新增 `recallMessage(token, messageId)`
- [x] `types.ts`：`HistoryMessage` / `MessageItem` / `SessionSummary.lastMessage` 新增 `recalled`；新增 `chatMessageRecalled` 帧的类型
- [x] `stores/chat.ts` 新增 `recallMessage(recipientId, messageId)`，成功后更新本地消息与会话预览
- [x] 收到 `chatMessageRecalled` 帧：按 `recipientId` 定位会话，按 `id` 更新消息；找不到消息也要用帧里的 `content` 更新会话预览
- [x] 已撤回消息渲染成居中灰色提示行（不显示头像、时间、气泡）
- [x] 撤回入口：自己已发出的消息（`fromSelf && acked && id && !recalled`）悬停时显示「撤回」
- [x] `npm run build` 与 `npm test` 通过
- [x] 手工冒烟：互发后一方撤回，另一端气泡与会话预览实时变提示；刷新后仍是提示

## 实施要点

- **帧里带了 `content`，直接用它更新会话预览**，不要客户端自己拼文案——收到帧时客户端可能根本没加载这个会话，拿不到发送者昵称（spec 已定文案由服务端生成）。
- **找不到消息也要更新预览**：帧到达时目标会话可能没打开过（`conversations[recipientId]` 为空）。这种情况只更新 `sessions` 里那条目的预览即可，不要因此丢弃这一帧。
- **`recalled` 的样式分支放在气泡渲染处**：已撤回的消息不再走「头像 + 昵称 + 气泡 + 时间」那套，而是单独一行居中灰色文字。别在气泡组件里堆 `v-if`。
- **撤回入口的显示条件要全**：`fromSelf && acked && id && !recalled`。缺 `acked` 会在消息还处于「发送中」时就让用户点撤回，而服务端可能还没入库；缺 `id` 则根本没法调接口。
- **不做二次确认弹窗**：撤回是用户主动点的，且不限时可预期，多加一层确认是过度设计。（若日后加了时限或批量撤回，再考虑。）
- **撤回失败要给反馈**：把 `ApiError.message` 显示出来（服务端 reason 已是可读中文），不要静默失败——用户会以为撤回了其实没有。
- 样式沿用既有气泡与会话条的配色字号，不引依赖、不新增 SVG。

## Comments

**2026-09-01 拆分（Agent）：** 依赖 `02` 的 `POST /chat/messages/:id/recall` 与 `chatMessageRecalled` 帧的形状，以及 `01` 给历史/会话列表加的 `recalled` 字段。等 01、02 都 resolved 后再开工。

## Comments

**2026-09-01 实施（Agent）：** 改动落在 `types.ts` / `api.ts` / `stores/chat.ts` / `views/ChatView.vue`。验证：`npm run build` 通过；`npm test` **13 passed**（新增 3 项撤回用例）；`npm run e2e` **196 PASS / 0 FAIL**；CDP 冒烟四项全过（证据见下）。

冒烟实测（浏览器扮 U-A，脚本经 WS 扮 U-B）：

| 检查 | 结果 |
| --- | --- |
| U-B 发消息后 U-A 看到原文 | 会话预览「B的第1条原文」，角标 1 ✓ |
| U-B 撤回后 U-A **实时**变化（未刷新） | 气泡 `message-row peer recalled` + 提示「RC-B撤回了一条消息」，会话预览同步 ✓ |
| U-A 撤回自己的消息 | 气泡变「你撤回了一条消息」，撤回按钮随之消失 ✓ |
| 刷新后持久化 | 会话预览仍是「我：你撤回了一条消息」——服务端是权威来源 ✓ |

实现落点与给后续 issue 的约定：

- **撤回状态统一收进 `applyRecalled(recipientId, messageId, content?)`**：自己发起的撤回没 content（服务端不回推给发送者），本地按发送者视角补「你撤回了一条消息」；收到帧时直接用帧里的文案。两条路径走同一个函数，避免两处文案漂移。
- **会话预览只在「被撤回的正是最后一条」时更新**（`list[list.length-1]?.id === messageId`）；本地没加载这个会话时无从判断，按「是」处理——宁可预览提前变提示，也不能让它继续显示原文。
- **撤回入口的显示条件 `fromSelf && acked && !!id && !recalled`**：缺 `acked`/`id` 时服务端还没确认入库，接口无从定位；已撤回的自然不再显示。
- **撤回失败要显形**（`recallError` 显示在输入区）：撤回是用户主动点的，静默失败会让人以为撤掉了其实没有。
- **气泡结构没有新增嵌套层级**——已撤回的分支复用了 `.message-row`，只是给它加 `recalled` 类并用 `.recall-tip` 替换 `.bubble`。这样媒体消息那几个 `<template v-if>` 一行都不用动，diff 小得多。
- **撤回按钮默认 `visibility: hidden`，`:hover` 才显示**：每行都挂一个按钮会抢气泡的视觉重心。
- 前端**没有**自己拼提示文案——帧里带了就用，自己发起时用固定的「你撤回了一条消息」。发送者昵称只有服务端权威，客户端在收到帧时未必有上下文。
