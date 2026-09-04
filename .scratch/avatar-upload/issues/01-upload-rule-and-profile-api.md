# 01 — 头像上传规则、资料接口与历史头像回查

**要构建的内容：** 让头像成为可改的用户属性。在此之前 `User.avatar` 永远是 `'default'`，没有任何写入路径，而历史消息气泡读到的是发送时的头像快照。

**只做后端**（外加读取侧的一处改动），跑完之后现有功能必须完全不变（214 项联调是回归基线）。

**被阻塞于（Blocked by）：** 无

**状态（Status）：** resolved

- [x] `UploadRules` 新增 `avatar` 规则（`jpg/jpeg/png/webp/gif`，≤ 2MB），并在 `rule(for:)` 加 `case`
- [x] **上传接口不改**：`POST /chat/upload` 本来就按 `msgType` 分派，只是多一种类型
- [x] 新增 `PATCH /chat/me`（`tokenProtected`），可改 `nickname` 与 `avatar`
- [x] 两者至少给一个，否则 400；昵称 trim 后判空；只改自己
- [x] 返回更新后的 `UserInfo`
- [x] **历史消息的 `senderAvatar` 改为按 `senderUserId` 回查 `users` 表**（决策：跟随）
- [x] **无注册记录时回退消息里的快照**（这正是快照存在的意义，不能让头像变空）
- [x] `senderNickname` 同步按 `users.nickname` 优先（同一套逻辑，别只改头像）
- [x] 群头像**不改服务端**（`PATCH /chat/groups/:id` 已支持 `avatar`）
- [x] 新增联调用例全绿 + 现有 214 项全绿（合计 **229**）
- [x] 搜索结果补 `recipientAvatar`（`03` 需要它才能把搜索结果的头像也显示出来）

## 实施要点

- **先搞清楚哪些不用改**（动手前已核过，别重复劳动）：会话列表的 `SessionPeerDTO.avatar` 已优先取 `users` 表、`GroupMemberDTO.avatar` 取的也是 `user.avatar`——**这两处已经跟随**。真正用快照的只有 `ChatHistoryController` 里构造 `HistoryMessageDTO` 的那一处（`senderAvatar: message.mine.avatar`）。
- **回退分支必须保留。** 会话列表里已经有三段式回退（users → 我发出去的取 `to` → 对方发的取 `mine`），历史消息要照抄同样的形状：**查到 `users` 就用，查不到才用快照**。只写「回查 users」而丢掉回退，会让无注册记录的发送者头像变空。
- **昵称要和头像一起改**。只换头像不换昵称，会出现「新脸配旧名字」——跟 spec 里要解决的「两张脸」是同一类不一致。
- **`UploadRules` 是集中配置点**，加一条静态属性 + `rule(for:)` 一个 case 就够；`largestMaxBytes` 会自动算进去，不用手动维护。错误文案沿用既有风格（不支持格式 → 415，超限 → 400）。
- **`PATCH /chat/me` 的权限**：只从 `req.auth.require(User.self)` 取身份，没有任何「改别人」的参数——不要为了将来可能的管理员功能预留 `userId` 入参。
- **联调用例里最要紧的一条**：改头像后**历史消息气泡**的 `senderAvatar` 跟着变。这是「跟随」决策的核心，也是这个 ticket 唯一真正的语义变化。

## Comments

**2026-09-02 拆分（Agent）：** 决策依据见 `../spec.md`（历史头像跟随，2026-09-01 拍板）。本 ticket 是 B3 的服务端与读取侧，上传入口在 `02`，各处渲染在 `03`。

**注意孤儿文件**：每次换头像都会在 `Public/uploads/` 留下一个不再被引用的文件。本期不清理（归入 A3 / C2 遗留），但实施时别顺手删旧文件——那需要有引用计数的支撑，现在没有。

## Comments

**2026-09-02 实施（Agent）：** 改动落在 `UploadController`（`avatar` 规则）、新增 `UserProfileController`、`routes.swift`（`PATCH /chat/me`）、`ChatHistoryController.history`（发信者身份回查）与 `ChatHistoryController.search`（补 `recipientAvatar`）。验证：`swift build` 通过；`npm run e2e` **229 PASS / 0 FAIL**（214 基线 + 15 项 B3 用例）。

实施中确认的两件事：

- **「跟随」真正要改的确实只有历史消息一处。** 动手前核过：`SessionPeerDTO.avatar`（会话列表）与 `GroupMemberDTO.avatar`（群成员）本来就取 `users` 表，已经跟随。所以本 ticket 的语义变化集中在 `HistoryMessageDTO.senderAvatar/senderNickname`。
- **昵称必须和头像一起改。** 只换头像不换昵称会出现「新脸配旧名字」，与要解决的「两张脸」是同一类不一致；单测与联调都盯着这两条。

另外顺手补了 `MessageSearchItemDTO.recipientAvatar`——`03` 要把搜索结果的头像也显示出来，否则同一会话在列表里有头像、在搜索结果里是字母块。

**安全上的一处收口**：`PATCH /chat/me` 会校验头像必须是**站内相对路径**（以 `/` 开头），挡掉 `http://` 外链与 `javascript:` / `data:` 这类来源。这个字符串最终会进 `<img src>`，在这里收口比在渲染侧兜更稳。
