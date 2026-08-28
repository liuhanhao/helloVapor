# 03 — 图片消息端到端

**要构建的内容：** 两个用户能在聊天窗口互发图片：发送方选择本地图片后先上传到服务端拿到文件 URL，再以媒体消息协议发出；接收方看到图片缩略图，点击可查看原图。服务端上传接口改为标准 multipart 表单，按类型（jpg/png/gif/webp）与大小（≤10 MB）校验，超限或非法类型返回明确错误；文件以 UUID + 原扩展名存入独立上传目录，开启静态文件服务供两端访问，替代现有硬编码单一文件的上传下载接口。上限以常量集中配置。

**被阻塞于（Blocked by）：** 01 — 曳光弹：文本消息端到端跑通

**状态（Status）：** resolved

- [x] 前端可选择本地图片并发送，上传过程中有发送状态提示
- [x] 接收方实时收到图片消息并渲染缩略图，点击可查看原图
- [x] 超过 10 MB 或非允许格式的文件被服务端拒绝，前端展示明确错误提示
- [x] 图片文件以 UUID 命名存储，历史图片可通过 URL 重复访问
- [x] 图片消息入库带 `msgType = image`，会话列表中显示"[图片]"类预览
- [x] 刷新后历史图片消息可正常加载显示

## Comments

**2026-08-27 验收检查（Agent）：** 第三阶段全部完成。验证方式与证据：

- 编译检查：`swift build` 通过（仅既有 Sendable 警告）；`vue-tsc --noEmit` 通过。
- 服务端联调（`web/e2e-check.mjs` 扩展为 41 项）：前 30 项（01/02 回归）全部保持 PASS；新增 11 项图片链路检查全部 PASS——匿名上传 401、合法 PNG 上传返回 `/uploads/<uuid>.png`（UUID + 原扩展名命名）、经 URL 静态访问 200 且 Content-Type / 字节内容一致、非法类型 txt 返回 415（"图片格式不支持，仅支持 gif/jpeg/jpg/png/webp"）、超 10MB 返回 413（"图片大小不能超过 10 MB"）、非法 msgType 返回 400、Bob 实时收到 `msgType=image` 消息（content 为文件 URL）、会话列表最后一条 `msgType=image`、历史接口返回图片消息（带 id 与 URL）、同一 URL 重复访问 200。
- 实测中发现并修复的缺陷：上传 handler 最初缺少 `req.auth.require(User.self)`，匿名请求实际可上传（仅格式错误才被拒，联调 415 暴露）。已修复，未携带 token 现在在解析表单前即返回 401。
- UI 冒烟（agent-browser，注册 Carol + curl 注册 Dave）：
  - 登录后与 Dave 打开会话，点「图片」按钮选择本地 PNG → 消息流出现缩略图（上传期间本地 blob 预览占位，成功后 src 切换为服务端 `/uploads/...` URL），会话列表预览同步为「我：[图片]」，无残留「发送中」。
  - 点击缩略图 → 原图浮层（lightbox）打开，关闭正常。
  - 刷新页面 → 登录态与会话列表恢复，重新打开会话后历史图片消息经 URL 正常加载。
  - 选择 11MB 文件 → 输入区上方出现「图片大小不能超过 10 MB（当前 11.0 MB）」明确错误提示（前端预检；服务端 413 路径已由联调覆盖，提示文案同源）。
  - Node WS 以 Dave 身份实时发送图片消息 → 浏览器侧实时渲染 peer 侧缩略图，会话预览更新为「[图片]」并置顶。
- 实现落点：
  - 服务端：`hello/Sources/App/Controllers/UploadController.swift` 新增——`UploadRules` 常量集中配置各 msgType 的允许扩展名与大小上限（图片 jpg/jpeg/png/gif/webp ≤10MB、音频 mp3/m4a/aac/wav ≤20MB、视频 mp4/mov ≤100MB，为 issue 04 预留）、multipart 解码（msgType + file）、类型/大小校验（415/413/400 明确错误）、UUID + 原扩展名存入 `Public/uploads/`；`routes.swift` 删除硬编码 666.jpg 的 uploadFile/downloadFile，新路由 `POST /chat/upload`（token 鉴权，body collect 上限取各类型最大值）；`configure.swift` 启用 FileMiddleware 托管 Public 目录（静态访问 `/uploads/<文件名>`）。iOS 端经检索未引用旧接口，删除无回归。
  - 前端：`types.ts` MessageItem 新增 `localUrl / uploading / error`；`api.ts` 新增 `uploadMedia`（multipart，不手动设 Content-Type）；`stores/chat.ts` 抽出 `sendChatMessage` 公共发送函数、`appendMessage` 返回响应式引用供异步流程更新、新增 `sendImage`（本地预览占位 → 上传 → WS 发出 → ack，失败标记 error）、ack 匹配跳过上传中/已失败消息；`views/ChatView.vue` 新增图片按钮 + 隐藏 file input（accept 限制）、图片气泡（缩略图 / 上传中提示 / 失败态）、点击查看原图浮层、上传错误提示；`config.ts` 新增 `IMAGE_UPLOAD` 预检常量（与服务端 UploadRules 保持一致）；`vite.config.ts` 代理新增 `^/uploads/`。
- 数据库 / 迁移：无变化（`msgType` 字段 01 已就绪，图片消息 content 存文件 URL）。
- 遗留：`/tmp` 下临时冒烟文件（test-image.png 等）依赖系统清理；Vapor（8080）进程验收后仍在运行可直接复验。04 号 issue（音频/视频消息）已解除阻塞——服务端上传规则已预留，前端仅需扩展选择器与播放器。
