# 01 — 撤回标记与读取链路不泄漏原文

**要构建的内容：** 让「这条消息已撤回」成为库里的事实，并且让两个读取接口（历史与会话列表）在遇到已撤回消息时**不再返回原文**。在此之前 `message` 表没有任何撤回痕迹，接口也就无从表达。

只做数据层与读取，**不提供撤回的写入接口**——跑完之后现有功能必须完全不变（176 项联调是回归基线）。

**被阻塞于（Blocked by）：** 无

**状态（Status）：** resolved

- [x] `message` 表新增可空 `recalled_at`（`Double`，Unix 秒含小数）
- [x] 迁移 `AddMessageRecalledAt` 可回滚，按序追加在 `configure.swift` 的 `ReadState.Migration()` 之后
- [x] `ChatMessage` 模型新增 `recalledAt` 属性
- [x] `HistoryMessageDTO` 新增 `recalled: Bool`；已撤回时 `content` 换成提示文案（不返回原文）
- [x] `SessionLastMessageDTO` 同样新增 `recalled: Bool`，最后一条已撤回时预览换成提示文案
- [x] 提示文案按查看者生成：自己发的 →「你撤回了一条消息」；别人发的 →「`昵称` 撤回了一条消息」
- [x] **未读累加循环不排除已撤回的消息**（撤回不改变条数）
- [x] `swift build` 无新增错误；现有 176 项联调全绿

## 实施要点

- **`recalled_at` 用 `Double` 可空，不用 Bool。** 与 `created_at` 同一套单位，且能支撑日后「撤回发生在多久之后」这类问题，成本为零。类型照抄 `@OptionalField(key: "mine_msgType") var msgType: String?` 的写法，只是 `.double`。
- **SQLite 一次只能加一列**（群聊 01 踩过：`.field(a).field(b).update()` 会生成 `ADD COLUMN ..., ADD COLUMN ...` 报 `near ",": syntax error`）。本迁移只加一列，但仍要保持 `prepare` / `revert` 各一条 `.update()` 的形状，别图省事合并。
- **原文留在库里，只是不对外返回。** 撤回是「不再给你看」，不是「从世界上抹掉」——所以不要 `content = ""` 写回数据库。替换只发生在构造 DTO 的地方（`ChatHistoryController.history` / `.sessions`），保持模型层是真相。
- **提示文案的判定用 `mine.userId == myId`**（`history` 与 `sessions` 里都已有 `myId`），昵称取 `message.mine.nickname`。单聊与群聊都适用：群聊时 `mine` 是真正的发送者，不是收件主体。
- **会话列表的预览**：`SessionLastMessageDTO.content` 换成提示文案即可，客户端渲染逻辑不用改。但 `unreadCount` 的累加**不能**因此把这条排除——撤回不改变条数，未读数必须保持（spec 决策记录第 3 条）。这是本 ticket 最容易写错的一处。
- 提示文案在本期由**服务端**生成（理由见 spec「补充说明」），与现有错误 `reason` 的做法一致。

## Comments

**2026-09-01 拆分（Agent）：** 决策依据见 `../spec.md` 的「决策记录」（不限时 / 软删 / 未读不变 / 实时通知）。本 ticket 只解决「库里能表达撤回」与「读出来不泄漏原文」，写入接口与协议帧在 `02`，前端在 `03`。
