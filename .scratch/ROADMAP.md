# helloVapor 剩余功能路线图

本文件是「Web 版 IM 聊天」交付完成后的**后续规划**：剩余功能候选池、优先级、阻塞边与建议批次。已交付部分的 issue 文件与 spec 按「执行完即清理」原则删除，必要的结论保留在本文件。

新建功能时按 `docs/agents/issue-tracker.md` 的约定：一个功能一个目录（`.scratch/<feature-slug>/spec.md` + `issues/NN-<slug>.md`）。本文件只做排布，不替代各功能的 spec。

## 已完成（现状基线）

- **Web 版 IM 聊天已交付并验收完毕**（原 `web-im-chat` 的 spec 与 5 个 issue 已按「执行完即清理」原则删除）：注册/登录、会话列表与历史消息分页、文本（含 emoji）与图片/音频/视频消息端到端、按账号或 userid 发起新会话、刷新恢复登录态、退出清除凭证。
- **仍然成立的设计边界**（原 spec 的 Out of Scope 里，尚未转成后续任务、需要长期遵守的两条）：
  - **不做好友关系与添加好友流程**——联系人由历史消息推导，用户之间靠 userid 或账号发起会话。这条决定了「加好友」这类需求要重新设计数据模型，不是加个按钮的事（顶栏「我的 ID」的复制能力就是为了让用户把 userid 发给对方）。
  - **不做消息转发**（撤回与删除已列入 B2）。
- 追加修复（未单独立 issue）：顶栏「我的 ID」——ID 文本从 `<button>` 改为可选中的 `<span>`，复制增加 `execCommand` 降级与成功/失败反馈。
- **批次一（安全与卫生）已全部完成并验证**（issue 文件按「执行完即清理」原则已删除，关键结论与技术记忆保留在此）：
  - **A1 WS 连接鉴权**：握手校验 token，身份由服务端解析；发送者身份以连接绑定身份为准
  - **A2 连接注册表并发**：连接表收敛为 `ConnectionTable`（pthread 互斥锁），告警清零，多实例外置的 seam 就位
  - **A3 上传目录治理**：`hello/Public/uploads/` 进 `.gitignore`，未跟踪媒体文件从 100+ 降到 0
  - **A4 上传归属**：新增 `uploads` 表记录上传者 / URL / msgType / 字节数

  **动 WebSocket 相关代码前必读——下面每条都是真踩过的：**
  1. **不要切到 `Task` 里操作 WebSocket。** 它绑在连接的 event loop 上，跨线程调用 `onText` / `close` 会直接撞 `NIOCore/NIOLoopBound.swift: Precondition failed`。鉴权要走 `EventLoopFuture` 链。
  2. **`Request` 不能跨 `Task` 使用。** 需要的东西（如 token）必须在进 Task 之前取出来。
  3. **推送前必须用连接身份覆盖 `data.mine` 的四个身份字段。** 只覆盖入库用的 `Mine` 不够——推送原本转发的是客户端原文，冒用的身份照样会显示给接收方。
  4. **锁的选型**：`NSLock` 被标了 `noasync`，在 async 上下文调用会告警，封装成同步方法也躲不掉；actor 要 `await`，会切离 event loop；`Synchronization.Mutex` 要 macOS 15+（本工程声明的是 12）。当前用 pthread 互斥锁。真要外置连接表时改用 NIO 的 `NIOLockedValueBox`（需给 `Package.swift` 加 `swift-nio` 显式依赖；`WebSocket` 本身是 `Sendable`，可以直接装）。
  5. **Fluent 查询**：`\.$value == x` 写在 guard 链里推断不出 Root，要写成 `\UserToken.$value`，且文件需 `import Fluent`。
- **B5 部分完成**：`web/e2e-check.mjs` 接入 `npm run e2e`（默认打 8080，可用 `BASE` 覆盖）。CI 集成与前端单测仍缺。
- 测试现状：`npm run e2e` **151 项**服务端联调断言全绿（8080 实测：基线 77 + 02 号 ticket 的 33 项群管理 + 03 号 ticket 的 41 项群聊）；UI 仍靠手工冒烟。

## 本次规划时发现的两件事

1. **iOS 端目前完全没有联网。** `ADSChatViewController.sendMessageModel` 只写本地 SQLite 并随机标记发送成功/失败，`NetWork/` 目录下只有一个 `ADSChatURL.swift`；`ADSWebSocketService` 的连接 URL 是 `http://127.0.0.1chat/`（scheme 错、缺端口、路径也不是 `chat/webSocket`）。因此：
   - 服务端加鉴权不会破坏 iOS 既有能力（它本来就没连上）；
   - 但「iOS 端媒体消息」不是加个 `msgType` 渲染就完事，前面还横着一个「iOS 端联网改造」——见 B0。
2. **群聊的难点不在功能，在词汇。** 「会话」在 `CONTEXT.md` 里被定义为「两个用户之间的单聊」，而 `ChatMessage.to` 是单个用户。群聊要把「消息投递的目标」从「用户」泛化成「用户或群」，先定词再改模型，否则代码里从此有两套「会话」。词汇方案已写进 `.scratch/group-chat/spec.md`。

## 候选池

优先级含义：P0 = 安全/正确性，先做；P1 = 单聊体验补齐；P2 = 架构扩展。**Blocked by 全部 resolved 才解除阻塞。**

### P0 — 安全与正确性（批次一，✅ 全部完成）

- **A1 · WebSocket 连接鉴权** ✅ resolved
- **A2 · 连接注册表并发与生命周期** ✅ resolved
- **A3 · 上传目录治理** ✅ resolved（清理策略待定，见「待办 / 遗留」）
- **A4 · 上传文件的归属** ✅ resolved（访问控制维持公开直链，见「待办 / 遗留」）

### P1 — 单聊体验补齐

**B0 · iOS 端联网改造**（本次规划新增，B4 的前置）
- 范围：iOS 端接登录（取 token）、修正 WS 连接 URL（scheme / 端口 / 路径 / token）、消息改为经 WS 收发而非本地模拟。
- 为什么：不先做这个，B4（iOS 媒体消息）无从谈起——媒体消息得先有通道。
- Blocked by：无（A1 后连接协议已确定）。

**B1 · 未读消息计数** — ✅ 已决策，tickets 已就绪（Status: ready-for-agent）
- spec：`.scratch/unread-count/spec.md`（含「决策记录」，5 条全部拍板）；ADR：`docs/adr/0003-unread-count-server-side-read-cursor.md`
- tickets：`issues/01` 已读位点数据模型与迁移 → `issues/02` 标记已读接口与会话列表未读数 → `issues/03` 前端未读角标与清零（按阻塞边顺序认领）
- 范围：会话列表显示未读数，进入会话后清零。
- **已决策：服务端已读位点**（新增 `read_states` 表）——**推翻**本文件原先的「先做前端本地计数」，原决策的唯一前提「群聊尚未落地」已消失，且本地计数会漏计页面关闭期间的消息。理由与代价见 ADR-0003 与本节末尾「待办 / 遗留」的推翻记录。
- 已定：**无位点时全部算未读**（不会漏报且自愈）、**群消息与单聊同一套规则**（数字 99+ 封顶）、**位点用时间戳不用消息 id**、**不做「标记为未读」**
- 词汇「已读位点」已写入 `CONTEXT.md`
- Blocked by：无硬前置（A1 与群聊 01~04 均已 resolved）

**B6 · 联系人资料卡** ✅ 已交付
- 范围：单聊顶栏点昵称 / 群信息页点成员 → 弹出资料卡（昵称、账号、用户 ID，可复制 userid）。
- 关键取舍：**不引入好友关系**。要的是「查看信息」而不是「管理关系」——「好友」是 `CONTEXT.md` 里「联系人」的 Avoid 词，且本文件已定「不做好友关系与添加好友流程」，为「看得见」去推翻它不值得。
- **零后端改动**：`SessionPeerDTO` 与 `GroupMemberDTO` 都已带 `userid / 账号 / 昵称`，前端内存里就有，资料卡不发任何请求。
- 顺带把 `writeClipboard` 从 `ChatView.vue` 抽到 `web/src/clipboard.ts`——顶栏「复制我的 ID」与资料卡共用。
- Blocked by：无。

**B2 · 消息撤回与删除**
- 范围：协议新增撤回类型（沿 ADR-0002「扩展而非重新设计」路线），撤回后气泡变提示、会话列表预览同步更新。
- Blocked by：A1（已 resolved）。

**B3 · 头像上传与个人资料编辑**
- 范围：复用上传能力新增头像类型，支持改昵称/头像；`User.avatar` 目前只是 `'default'` 字符串。
- Blocked by：A3、A4（均已 resolved）。

**B4 · iOS 端媒体消息**
- 范围：iOS 端发送与渲染图片/音频/视频。
- Blocked by：**B0**（本次修正：原先只依赖「协议已预留 `msgType`」，忽略了 iOS 端尚无联网能力）。

**B5 · 自动化测试转正**（部分完成）
- 范围：~~把 `e2e-check.mjs` 接进 npm script~~ ✅（`npm run e2e`）；**剩余**：接进 CI、补前端 store 层单测。
- 为什么：群聊会同时动协议、数据模型和前端状态，没有回归网风险高。

### P2 — 架构扩展

**C1 · 群聊** — ✅ **已交付并验证完毕**（4 个 tickets 01~04 全部 resolved）
- spec 与 issue 文件已按「执行完即清理」原则删除（结论全部保留在本节；需要原文时 `git log -- .scratch/group-chat/` 可取回）
- 词汇（群 / 会话 / 单聊 / 成员 / 收件主体）**已写入 `CONTEXT.md`**
- 已定：**建群即入群**（不做邀请确认）、**上限 200 人**、**仅创建者可改群名·任何成员可拉人·只能退自己**、**退群即失去该群访问权且不留系统消息**、**复用 message 表加 `to_type`/`to_id`**、**`type` 字段保留但不依赖**、**成员能且只能看到入群之后的群消息**
- 交付面：`groups` / `group_members` 两表 + 六个群管理接口 + WS 群消息扇出 + `chatMessageError` 帧 + 会话/历史按收件主体泛化 + Web 端建群/群信息/退群界面
- **未做**（规格 Out of Scope，接口已就绪待接）：改群名、拉人入群的前端入口；群主转让、踢人、禁言、@提及、群公告、群解散、群聊未读计数、群聊离线推送
- **已知上限（本期接受）**：① `GET /chat/sessions` 先全量取回我的消息再在内存里按 `joined_at` 过滤（沿用单聊原有的内存去重做法），群消息量涨上来后要改成 SQL 侧带条件；② owner 退群未做特殊处理——不转让、不解散，群会变成无主状态（扇出按成员表走，不受影响），要处理得先定「无主群归谁」的产品语义

**动群聊相关代码前必读**——下面每条都是真踩过的：
1. **`Group` 与 Fluent 的 `@Group` 属性包装器重名**，模块里一旦有 `Group` 类就会被遮蔽，编译期报 `unknown attribute`。`ChatMessage` 里已加 `typealias GroupField<Value: Fields> = GroupProperty<ChatMessage, Value>`，`mine` / `to` 改用 `@GroupField(key:)`。**在 `ChatMessage` 里加属性时不要用 `@Group`。**
2. **SQLite 的 `ALTER TABLE` 一次只能加/删一列**：`.field("to_type").field("to_id").update()` 会生成 `ADD COLUMN ... , ADD COLUMN ...` 并报 `near ",": syntax error`。`prepare` 与 `revert` 都要拆成两条 `.update()`。
3. **WS 协议只加了一个字段** `data.to.type`（`user` / `group`），缺省按 `user`——iOS 旧格式消息不带该字段，行为完全不变。群聊时 `to.userid` 位置填群 id，不新增字段。
4. **前端状态里的 `peerXxx` 已全部改名为 `recipientXxx`**（`recipientNames` / `currentRecipientId`）；但会话列表项的 `peer` 字段名保留——那是 `/chat/sessions` 的 JSON 字段名，改它要加一层映射。**判定是不是群一律走 `chat.isGroup(id)`，不要在视图里另猜。**
5. **`GET /chat/sessions` 只含有过消息的会话**，`GET /chat/groups` 的结果必须在它之后合并进列表（顺序不能倒），否则刚建好还没发言的群刷新就消失了。
6. `GroupMember.requireMembership` / `counts` 是「我是不是这个群的成员」的唯一入口（WS、查历史、会话列表三处共用）；不要各写一遍，容易漏。

**C2 · 生产化与部署**
- 范围：SQLite → Postgres、HTTPS、docker-compose 配置、日志与配置外置、多实例下的连接表外置（`A2` 已留好 seam）。
- 顺带收益：上了 HTTPS/正式域名后，浏览器剪贴板 API 进入安全上下文，「复制 userid」的降级路径自然消失。
- Blocked by：无硬阻塞（A2、A3 已完成）。

## 建议批次

1. **批次一（安全与卫生）** ✅ ~~A1 → A2 → A3 → A4~~ 全部完成
2. **批次二（回归网 + 群聊）** ✅ ~~群聊 01 → 02 → 03 → 04~~ 全部完成（B5 仅完成 `npm run e2e` 部分，CI 集成与前端单测仍缺）
3. **批次三（补齐与生产化）**：**B1 → B2 → B3 → B0 → B4 → C2 生产化**

**为什么把群聊提到体验补齐（B1/B2/B3）前面**（2026-09-01 注：这段是当时的判断，B1 的决策现已拍板，见 ADR-0003）：群聊的 tickets 已经描述完整、阻塞边清晰，可以直接认领开工；而 B1（未读）还卡在一个产品决策上（服务端已读位点 vs 前端本地计数）。先把能确定推进的推完，决策等它自然成熟。B5 收尾放最前，是因为群聊要同时动协议、数据模型和前端状态组织方式——没有回归网等于蒙眼改，而它只要半天到一天。

## 待办 / 遗留

- **清理 8081 上的遗留进程**（issue 05 联调时起的，跑的是旧构建）。8080 是本轮新构建（PID 4547），A1~A4 均已生效。
- **A3 的清理策略未定**：既有测试媒体一个都没删（`chatMessage.db` 里有对应的媒体消息，删了会 404），孤儿文件回收与配额也没有——有了 A4 的归属数据之后再做。
- **A4 的访问控制未收紧**：媒体 URL 仍是公开直链。原因是浏览器加载 `<img>`/`<audio>`/`<video>` 不带 `Authorization` 头，「受控路由 + Bearer」走不通，只剩签名 URL（需处理历史消息里 URL 过期）或 token 拼 query（等于把长期凭证当短期链接用）。现在文件名是 UUID 不可枚举，风险有限，等真有外部访问需求再收紧。
- ~~C1 群聊停在 `needs-info`~~ ✅ 已拍板并拆成 4 个 tickets；**每个 ticket 开工前请清空上下文**（当前会话已经很长，继续堆会影响判断质量）。
- ~~**B1 未读计数已决策：先做前端本地计数**~~ ❌ **2026-09-01 推翻，改服务端已读位点。**
  原决策：在「服务端已读位点（可跨端同步）」与「前端本地计数（换设备就丢）」之间选了后者，理由不是它更好，而是**群聊还没落地，未读的语义尚未定型**。
  **推翻理由**：① 该前提已消失（群聊已上线）；② 更关键的取舍当初没称准——本地计数会漏计**页面关闭期间**到达的消息，而这对 Web 应用是常态而非边界，结果是角标显示 0 却确实有未读，比没有角标更糟；③ 成本比当初预估低得多，`sessions` 已在内存遍历全部消息，未读可零额外查询累加。
  新决策与完整权衡见 **ADR-0003**；实施见 `.scratch/unread-count/` 的 spec 与 3 个 tickets。
  **教训**：写下「等 X 落地再补」这类决策时，要把触发条件写成可观测的事实。这条写了「等群聊上线」，但没人盯着它——群聊上线后是隔了若干轮会话才被重新发现的。
- A1/A2 的技术要点已内联到本文件「已完成（现状基线）」下的「动 WebSocket 相关代码前必读」，不再单独留 issue 文件。
