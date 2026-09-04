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
- **未读计数（B1）已交付并验收完毕**（3 个 tickets 全部 resolved，spec 与 issue 文件保留在 `.scratch/unread-count/` 未按「执行完即清理」删除——本节末尾的推翻记录与 ADR-0003 都指向它）：服务端 `read_states` 已读位点 + `POST /chat/read` + `GET /chat/sessions` 的 `unreadCount` + Web 端角标与清零。
- 测试现状：`npm run e2e` **229 项**服务端联调断言全绿（8080 实测：基线 77 + 群管理 33 + 群聊 41 + 未读 25 + 撤回 20 + 搜索 19 + 头像资料 15）；`npm test` **17 项** store 层单测全绿（vitest）。UI 仍靠冒烟（未读、B7、B2 已用 CDP 自动化补做，证据见 `.scratch/unread-count/issues/03`、`.scratch/group-manage/issues/02`、`.scratch/message-recall/issues/03`；B8 已由人工验收通过；**B3 待人工**，见 `.scratch/avatar-upload/issues/02` 与 `issues/03`）。

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

**B0 · iOS 端联网改造** — ❌ `wontfix`（2026-09-01 定：iOS 端暂缓，资源全部投 Web）
- 原范围：iOS 端接登录（取 token）、修正 WS 连接 URL（scheme / 端口 / 路径 / token）、消息改为经 WS 收发而非本地模拟。
- **为什么不做**：本轮重新评估发现它不是「修正连接 URL」——`VaporChat/NetWork/` 目录下只有 `ADSChatURL.swift`，iOS 端**没有登录、没有 token、消息收发是本地模拟**，这是重写客户端数据层，量级与「改个 URL」完全不同。在 Web 端体验补齐之前投入不划算。
- 恢复条件：日后重启 iOS 端时，`git log -- .scratch/ROADMAP.md` 可取回本条原文；同时要重新评估 iOS 端数据层现状。

**B1 · 未读消息计数** — ✅ **已交付并验证完毕**（3 个 tickets 全部 resolved）
- spec：`.scratch/unread-count/spec.md`；ADR：`docs/adr/0003-unread-count-server-side-read-cursor.md`
- 交付面：`read_states` 表 + `POST /chat/read`（upsert 位点，非成员 403）+ `GET /chat/sessions` 的 `unreadCount`（**零额外消息查询**，在既有内存遍历里累加）+ Web 端角标与三条标记已读路径（打开会话立即发 / 会话内新消息 1s 合批 / 切换会话补发上一个）
- 已定：**服务端已读位点**（推翻原先的「前端本地计数」，理由见本节末尾推翻记录）、**无位点时全部算未读**（不漏报且自愈）、**群消息与单聊同一套规则**（99+ 封顶）、**位点用时间戳不用消息 id**、**不做「标记为未读」**、**未读不落 localStorage**（服务端是唯一真相）
- 词汇「已读位点」已写入 `CONTEXT.md`
- **已知上限（继承 C1 的上限）**：`GET /chat/sessions` 全量取消息再内存过滤。量上来后**未读计数与会话列表必须一起改成 SQL 侧聚合，不要只改其中一个**。

**B6 · 联系人资料卡** ✅ 已交付
- 范围：单聊顶栏点昵称 / 群信息页点成员 → 弹出资料卡（昵称、账号、用户 ID，可复制 userid）。
- 关键取舍：**不引入好友关系**。要的是「查看信息」而不是「管理关系」——「好友」是 `CONTEXT.md` 里「联系人」的 Avoid 词，且本文件已定「不做好友关系与添加好友流程」，为「看得见」去推翻它不值得。
- **零后端改动**：`SessionPeerDTO` 与 `GroupMemberDTO` 都已带 `userid / 账号 / 昵称`，前端内存里就有，资料卡不发任何请求。
- 顺带把 `writeClipboard` 从 `ChatView.vue` 抽到 `web/src/clipboard.ts`——顶栏「复制我的 ID」与资料卡共用。
- Blocked by：无。

**B7 · 群改名与拉人入群的前端入口** — ✅ **已交付并验证完毕**（2026-09-01，2 个 tickets 全部 resolved）
- spec：`.scratch/group-manage/spec.md`；tickets：`issues/01` 接口封装与群状态同步 → `issues/02` 改名与拉人界面（均已 resolved，证据见各 ticket 的 Comments）
- 范围：群信息弹窗补「改群名」（仅创建者可见）与「拉人入群」，拉人复用既有的 `searchUsers` 选人；改名/加人后同步三处状态（`groups` / `sessions` 条目 / `recipientNames`）。
- **零后端改动**：`PATCH /chat/groups/:id`（`GroupController.update`）与 `POST /chat/groups/:id/members`（`addMember`）已实现并注册在 `tokenProtected` 下，且 **e2e 第 17 节已把它们的全部分支覆盖**（非创建者 403 / 重复拉人 409 / 幽灵用户 400 / 空名 400 / 空 body 400）——本功能**不需要新增任何服务端用例**，176 项继续全绿即是验收标准。
- 为什么优先：候选池里唯一「不动协议、不动迁移」的一块，且补的是真实断点（建完的群既不能改名也不能加人）。先做它给后面的 B2/B8 留一条干净的回归基线。
- **两个易踩的形状坑**（已写进 spec）：① `addMember` 只收**单个** `userId`，与建群的 `memberIds` 数组不同形；② 改名后必须同步 `sessions` 条目的 `peer.nickname`，否则「列表改名了、气泡标题还是旧的」。
- Blocked by：无。

**B8 · 消息搜索** — ✅ **已交付并验收完毕**（2026-09-02，2 个 tickets 全部 resolved）
- spec：`.scratch/message-search/spec.md`；tickets：`issues/01` 搜索接口与可见性 → `issues/02` 搜索框与结果视图（**均 resolved**，2026-09-02 人工验收通过）
- 范围：跨会话按关键词检索消息内容，结果可点击跳转到所属会话。
- 为什么：会话一多，「翻页找一条历史消息」是 IM 最常见的痛点之一，而 `GET /chat/history` 只支持按时间翻页，没有按内容检索。
- **已决策（2026-09-01）**：① **按内容检索，不做「会话列表过滤框」**——原先倾向过滤框（成本低得多），但那是错的：`GET /chat/sessions` 每个会话只返回**最后一条**消息，过滤框只能按会话名和那一条预览过滤，**搜不到消息内容**，等于把功能本身省掉了。② 全局搜索，不做「仅当前会话」。③ 不返回上下文（点进会话即可看到）。④ 媒体消息不匹配（content 是文件 URL，LIKE 它只会出噪音）。
- **可见性与 `/chat/history` 严格一致**：单聊两个方向；群要求成员身份且**只搜入群之后的消息**。搜索不能成为绕过退群/入群时间限制的旁路。
- **必须排除已撤回的消息**——撤回是软删，原文仍在 `content` 里；不排除的话 B2 刚建的「撤回即不再给你看」会被搜索直接绕过。这条有专门的联调用例盯着。
- 已验证：服务端联调 **214 项**全绿（196 基线 + 19 项搜索）、前端单测 16 项、`npm run build` 通过
- **已知上限**：SQLite `LIKE` 全表扫描；关键词里的 `%` / `_` **未转义**（会当通配符，搜「100%」命中过多）；不返回上下文。
- Blocked by：无硬前置。

**B10 · 删除消息（仅我删）**（2026-09-01 从 B2 拆出，Status: `needs-info`）
- 范围（待定）：把一条消息从**我自己**的视图里删掉，对别人不可见地保留。
- **为什么要跟撤回分开**：撤回改的是消息本身（所有人都不看），删除要 per-user 的删除标记——是两套数据模型。更要紧的是**未读语义不同**：已撤回的消息仍算一条未读（它还在、只是换成提示），而我删掉的消息**不该**再算我的未读。混在一个功能里会让未读出现两种互相矛盾的规则。
- **开工前要定的**：① 删掉的消息在会话列表预览里怎么显示（直接跳过、显示上一条）；② 删除能不能撤销；③ 与撤回的关系——撤回过的消息还能不能再删。
- Blocked by：无硬前置，但上述决策未定 → `needs-info`。

**B9 · 输入中（typing indicator）**（本次规划新增，Status: `needs-info`）
- 范围（待定）：沿 ADR-0002「扩展而非重新设计」，WS 加一种提示帧，对端气泡区显示「正在输入…」。
- **缺这三条就不能开 spec**：① 停止输入的判定——对端超时还是失焦事件？超时几秒？② 节流策略——每次按键一帧会打爆连接；③ 群聊里要不要显示（200 人群刷「正在输入」是噪音，可能只显示第一个，或干脆只做单聊）。
- Blocked by：无硬前置，但上面三条不定就是 `needs-info`。

**B2 · 消息撤回（B10 单列出「删除」）** — ✅ **已交付并验证完毕**（2026-09-01，3 个 tickets 全部 resolved）
- spec：`.scratch/message-recall/spec.md`；tickets：`01` 撤回标记与读取不泄漏原文 → `02` 撤回接口与 WS 协议帧 → `03` 前端入口与渲染
- 四项语义已拍板并写进 spec 的「决策记录」：**不限时 / 软删 / 撤回后未读数不变 / 新增协议帧实时通知**
- 交付面：`message.recalled_at` + `POST /chat/messages/:id/recall` + `chatMessageRecalled` 帧 + `WebSocketService.broadcast` seam + 前端撤回入口与提示行渲染
- 词汇「撤回（Recall）」已写入 `CONTEXT.md`
- **「删除（仅我删）已拆为 B10」**——见 P1 里 B10 条目。撤回改的是消息本身，删除要 per-user 标记，且**未读语义不同**（我删掉的不该算我未读，已撤回的仍算），是两套数据模型
- **已知上限（继承 C1 / 未读）**：`GET /chat/sessions` 全量取消息再内存过滤，撤回不改这一点；撤回**不清理媒体文件**（文件仍留在 `Public/uploads/`，与 A3 的孤儿文件回收一并处理）

**B3 · 头像上传与个人资料编辑** — 实现完成，**待人工冒烟**（2026-09-02）
- spec：`.scratch/avatar-upload/spec.md`；tickets：`issues/01` 上传规则 + 资料接口 + 历史头像回查（**已 resolved**）→ `issues/02` 上传与编辑入口 / `issues/03` 各处头像渲染（**均 ready-for-human**，仅剩浏览器冒烟）
- 已验证：服务端联调 **229 项**全绿（214 基线 + 15 项 B3）、前端单测 17 项、`npm run build` 通过
- 范围：新增 `avatar` 上传类型与 `PATCH /chat/me`，前端各处头像改为「有图显图、无图回退首字母」。
- **已决策（2026-09-01）：历史消息气泡的头像跟随新头像。** 实现上历史接口按 `senderUserId` 回查 `users` 表取权威头像/昵称，不再沿用 `ChatMessage.mine.avatar` 快照。代价是历史接口多一次查询；收益是全局只有一张脸。
- **服务端改动面比看上去小**（2026-09-02 核过）：会话列表的 `SessionPeerDTO.avatar` 与群成员的 `GroupMemberDTO.avatar` **本来就回查 `users` 表**，已经跟随了；真正用快照的只有历史消息一处。群头像也不用改服务端——B7 的 `PATCH /chat/groups/:id` 早就支持 `avatar` 字段。
- **前端改动面比看上去大**：目前所有头像（会话列表、搜索结果、气泡、资料卡、群成员列表）**都是首字母方块，一处图片都没有**，所以 5 处渲染都要改；且服务端没有图像库，压缩只能放前端。
- **已知上限**：改头像/群头像不实时通知（与 B7 的改名、拉人一致）；每次换头像会在 `Public/uploads/` 留下孤儿文件（A3 的清理策略本来就未做，B3 会让它变多）。
- Blocked by：A3、A4（均已 resolved）。

**B4 · iOS 端媒体消息** — ❌ `wontfix`（2026-09-01 定，随 B0 一并暂缓）
- 原范围：iOS 端发送与渲染图片/音频/视频。
- 为什么不做：Blocked by **B0**，而 B0 已标 `wontfix`。原先只依赖「协议已预留 `msgType`」，忽略了 iOS 端尚无联网能力——媒体消息得先有通道。

**B5 · 自动化测试转正** — ✅ **已完成**（2026-09-01）
- ✅ `npm run e2e`：**176 项**服务端联调断言
- ✅ `npm test`：**10 项** `stores/chat.ts` 状态逻辑单测（vitest，`src/stores/chat.test.ts`）
- ✅ CI：`.github/workflows/web.yml`（Linux：build + 单测）与 `.github/workflows/e2e.yml`（macOS：起 Vapor 服务跑联调）

**CI 为什么按路径拆成两个 workflow**：e2e 需要一个真跑在 8080 的 Vapor 服务，而 `hello/Package.swift` **只声明了 `.macOS(.v12)`**，Linux 上 `swift build` 不被支持——**这是硬约束，不是保守**。macOS runner 分钟数是 Linux 的 10 倍，所以 e2e job 只在 `hello/**` 或 `web/e2e-check.mjs` 变更时触发，纯前端改动不烧这份配额。
> 日后想让 e2e 上 Linux：先给 `Package.swift` 加 Linux 平台，**并验证 FluentSQLiteDriver 在那边的行为**，再改 runner——别在 CI 上赌。

**测试环境为什么没用 happy-dom**（`src/test-setup.ts` 的由来）：`window.localStorage` 与全局 `localStorage` 是**同一个裸对象**，`getItem / setItem / removeItem / clear` 一个都没有（happy-dom 14 与 15 均复现，与 vitest 2.1 搭配时）。stores 只依赖 `window.setTimeout`（标记已读合批）与 `localStorage`（auth store 初始化即读）两个全局，所以改成 `environment: 'node'` + 最小垫片：`window` 指向 `globalThis`，配一个内存版 Storage。**不为一个 Storage 拉进整个 DOM 实现。** 附带好处：`window === globalThis`，`vi.useFakeTimers()` 能同时管住 `window.setTimeout`。

**单测覆盖什么**：未读累加与清零、当前会话新消息走合批而非累加、会话置顶去重、历史与实时消息按 id 合并、群改名/拉人的三处状态同步、退群清理、401 清登录态。**不做组件快照**——维护成本高于收益。

**测试有效性做过变异校验**：临时去掉 `applyGroupSummary` 里的会话列表同步，2 项测试如预期失败，确认这套测试不是空跑通过。

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

**C3 · 群角色与权限（群主转让 / 踢人 / 禁言 / 群公告 / 解散）**（本次规划新增，Status: `needs-info`）
- 为什么现在不能开工：当前权限只有一条隐式规则「仅创建者可改群名」（`GroupController` 里硬编码比对 `ownerId`）。要做转让/踢人/禁言，得先把**群角色**变成领域概念——`CONTEXT.md` 现在只有「成员」，没有「群主 / 管理员」，也没定角色能不能叠加。
- **前置的产品决策（不定就没法写 spec）**：① **无主群归谁**——C1 的已知上限：owner 退群后群变无主，「自动转让」与「随最后一人退出而解散」语义完全不同，各有代价；② 群公告算**消息**还是算**群属性**（决定它进不进 `message` 表、算不算未读）；③ 禁言是「不能发」还是「发了丢弃」（涉及要不要给发送方回 `chatMessageError` 帧）。
- Blocked by：无硬前置，但上述决策未定 → `needs-info`。

**C4 · 会话免打扰与置顶**（本次规划新增，Status: `needs-info`）
- 为什么现在浮现：未读角标上线后，「这个群别提醒我」是紧接着的自然需求。
- **待决策**：免打扰时未读**还算不算**？「算但不角标」与「完全不算」会走向不同的数据模型——后者要在 `read_states` 之外再记一层「该会话是否计入」，且和「无位点全量计入」的自愈语义正面冲突。置顶要不要跨端同步（不同步就只是前端 localStorage，同步就得进库）。
- Blocked by：无硬前置。

**C5 · @提及与「有人@我」单独计数**（本次规划新增，Status: `needs-info`）
- 背景：群聊 spec 与未读 spec **都**把它列为 Out of Scope，未读 spec 还明确写了「@提及单独计数」不做。现在群聊与未读都已落地，可以重新评估，但不要当成顺手就能加的。
- **待决策**：@提及是「未读的一个筛选项」还是「独立的一层计数」；被 @ 的人已读后，别人看到的未读怎么算；提及信息存消息体还是单独的关系表。
- Blocked by：无硬前置。

## 不做的（已定 `wontfix`，勿重复提案）

- **iOS 端联网改造与媒体消息（B0 / B4）** —— 2026-09-01 定：资源全部投 Web 端。B0 实为重写 iOS 客户端数据层（该端当前无登录、无 token、消息收发是本地模拟），不是「修正连接 URL」。恢复条件见 P1 里 B0 条目。
- **已读回执（「对方看没看我的消息」）** —— 与 `CONTEXT.md` 的「已读位点」方向相反，混用会让接口语义彻底错位。未读 spec 已明确列为 Out of Scope。
- **好友关系与添加好友流程** —— 联系人由历史消息推导，用户靠 userid / 账号发起会话。加好友要重做数据模型，不是加个按钮。
- **消息转发** —— 原 Web IM spec 的 Out of Scope。
- **按消息 id 的精确已读位点** —— 未读 spec 已定为用时间戳，代价（同秒到达的边界不精确）对未读计数没有实际影响。

## 建议批次

1. **批次一（安全与卫生）** ✅ ~~A1 → A2 → A3 → A4~~ 全部完成
2. **批次二（回归网 + 群聊）** ✅ ~~群聊 01 → 02 → 03 → 04~~ 全部完成（B5 仅完成 `npm run e2e` 部分，CI 集成与前端单测仍缺）
3. **批次三（补齐与生产化）**：✅ ~~B1 未读计数~~ 全部完成（3 个 tickets 全部 resolved）
4. **批次四（2026-09-01 确认的顺序）**：✅ ~~B7 群改名与拉人~~ → ✅ ~~B5 回归网~~ → ✅ ~~B2 消息撤回~~ → ✅ ~~B8 消息搜索~~ **批次四全部完成**
5. **批次五**：**B3 头像上传与资料编辑**（下一个任务，spec 与 tickets 已就绪）
6. **批次六（生产化）**：**C2**

**批次四的顺序理由**（2026-09-01 确认）：**B7 打头**——服务端接口早已就绪，缺口只在前端，是候选池里唯一「不动协议、不动迁移」的一块，且补的是真实断点（建完的群既不能改名也不能加人），先做它给后面的 B2/B8 留一条干净的回归基线。**B5 紧跟**——B2 要扩展协议、B8 要加查询，回归网缺位等于蒙眼改，且它已连续两批被跳过。**B2 在 B8 之前**——B2 是四者里唯一会引入数据变更的（新迁移 + 新协议帧），越早做，后面越少在两种协议形态上反复。

**为什么把群聊提到体验补齐（B1/B2/B3）前面**（2026-09-01 注：这段是当时的判断，B1 的决策现已拍板，见 ADR-0003）：群聊的 tickets 已经描述完整、阻塞边清晰，可以直接认领开工；而 B1（未读）还卡在一个产品决策上（服务端已读位点 vs 前端本地计数）。先把能确定推进的推完，决策等它自然成熟。B5 收尾放最前，是因为群聊要同时动协议、数据模型和前端状态组织方式——没有回归网等于蒙眼改，而它只要半天到一天。

## 待办 / 遗留

- **清理 8081 上的遗留进程**（issue 05 联调时起的，跑的是旧构建）。8080 是本轮新构建（PID 4547），A1~A4 均已生效。
- ~~**B3 开工前必须先定的一件事**~~ ✅ **2026-09-01 已定：跟随（回查 `users` 表）**。起因是本轮规划发现的不一致：消息里存的是发送时的**头像/昵称快照**（`ChatMessage.mine.avatar` → `HistoryMessageDTO.senderAvatar`），而会话列表优先取 `users` 表的**权威值**（`ChatHistoryController.sessions` 里 `usersById` 命中就覆盖快照）——改头像后同一个人会出现两张脸。定「跟随」后历史接口要按 `senderUserId` 回查 `users` 表，多一次查询换全局一致；B3 开工照此实现即可。
- **A3 的清理策略未定**：既有测试媒体一个都没删（`chatMessage.db` 里有对应的媒体消息，删了会 404），孤儿文件回收与配额也没有——有了 A4 的归属数据之后再做。
- **A4 的访问控制未收紧**：媒体 URL 仍是公开直链。原因是浏览器加载 `<img>`/`<audio>`/`<video>` 不带 `Authorization` 头，「受控路由 + Bearer」走不通，只剩签名 URL（需处理历史消息里 URL 过期）或 token 拼 query（等于把长期凭证当短期链接用）。现在文件名是 UUID 不可枚举，风险有限，等真有外部访问需求再收紧。
- ~~C1 群聊停在 `needs-info`~~ ✅ 已拍板并拆成 4 个 tickets；**每个 ticket 开工前请清空上下文**（当前会话已经很长，继续堆会影响判断质量）。
- ~~**B1 未读计数已决策：先做前端本地计数**~~ ❌ **2026-09-01 推翻，改服务端已读位点。**
  原决策：在「服务端已读位点（可跨端同步）」与「前端本地计数（换设备就丢）」之间选了后者，理由不是它更好，而是**群聊还没落地，未读的语义尚未定型**。
  **推翻理由**：① 该前提已消失（群聊已上线）；② 更关键的取舍当初没称准——本地计数会漏计**页面关闭期间**到达的消息，而这对 Web 应用是常态而非边界，结果是角标显示 0 却确实有未读，比没有角标更糟；③ 成本比当初预估低得多，`sessions` 已在内存遍历全部消息，未读可零额外查询累加。
  新决策与完整权衡见 **ADR-0003**；实施见 `.scratch/unread-count/` 的 spec 与 3 个 tickets。
  **教训**：写下「等 X 落地再补」这类决策时，要把触发条件写成可观测的事实。这条写了「等群聊上线」，但没人盯着它——群聊上线后是隔了若干轮会话才被重新发现的。
- A1/A2 的技术要点已内联到本文件「已完成（现状基线）」下的「动 WebSocket 相关代码前必读」，不再单独留 issue 文件。
