# 04 — 音频与视频消息

**要构建的内容：** 两个用户能在聊天窗口互发音频和视频：复用图片消息的上传与媒体消息链路，扩展服务端类型与大小校验（音频 mp3/m4a/aac/wav ≤20 MB，视频 mp4/mov ≤100 MB）；接收方在聊天窗口内直接播放音频与视频，无需下载。超限或非法类型拒绝并给出明确提示。

**被阻塞于（Blocked by）：** 03 — 图片消息端到端

**状态（Status）：** resolved

- [x] 前端可选择本地音频文件发送，接收方在聊天窗口内直接播放
- [x] 前端可选择本地视频文件发送，接收方在聊天窗口内直接播放
- [x] 超过大小上限或非允许格式的文件被拒绝，前端展示明确错误提示
- [x] 音频/视频消息分别以 `msgType = audio / video` 入库，会话列表显示对应预览
- [x] 刷新后历史音频/视频消息可正常加载播放

## Comments

**2026-08-28 验收检查（Agent）：** 第四阶段全部完成。验证方式与证据：

- 编译检查：`swift build` 通过（仅既有 Sendable 警告）；`vue-tsc --noEmit` 通过。
- 服务端联调（`web/e2e-check.mjs` 扩展为 58 项）：前 46 项（01/02/03 回归）全部保持 PASS；新增 12 项音频/视频链路检查全部 PASS——合法 WAV 上传 200 且 UUID 命名、Content-Type 修正（m4a→audio/mp4、aac→audio/aac、mp3→audio/mpeg、wav→audio/wav、mp4→video/mp4、mov→video/quicktime，原 Vapor 内置映射对 aac 缺失、对 m4a 错误地映射为 audio/mpeg）、媒体访问支持 Range 请求（206 + Content-Range）、非法音频类型（txt）返回 415「音频格式不支持，仅支持 aac/m4a/mp3/wav」、超过 20MB 音频返回 413「音频大小不能超过 20 MB」、超过 100MB 视频返回 413、WS 实时发送 audio/video 消息对端可收到、内容与会话/历史 msgType 正确、同一 URL 可重复访问。
- 实测中发现并修复的缺陷：Vapor 内置 `HTTPMediaType.fileExtension` 对 `aac` 缺失（响应无 Content-Type）、对 `m4a` 错误地映射为 `audio/mpeg`，部分浏览器因此拒绝在 `<audio>/<video>` 中直接播放。新增 `UploadsTypeMiddleware` 在 FileMiddleware 之前拦截 `/uploads/*` 请求，按 `UploadRules` 显式给出正确 MIME；流式输出复用 `req.fileio.asyncStreamFile`（支持 Range 拖动进度、ETag 缓存）。e2e 全量验证后旧进程替换为新构建（8080）。
- UI 冒烟（agent-browser，注册 Eva + curl 注册 Frank，通过 Vite 代理 8080）：
  - 点击「音频」按钮选 mp3 → 气泡出现 `<audio controls>`（期间本地 blob 可预览，src 切到 `/uploads/...`），会话列表预览同步为「我：[音频]」，无残留「发送中」。
  - 点击「视频」按钮选 mp4 → 气泡出现 `<video controls>`（160x120 测试图案，readyState=4、duration=2 秒、可正常播放），会话预览同步为「我：[视频]」。
  - 选择 fake.txt → 输入区上方出现「不支持的音频格式 .txt，仅支持 mp3/m4a/aac/wav」明确错误提示。
  - 选择 21MB mp3 → 输入区上方出现「音频大小不能超过 20 MB（当前 21.0 MB）」明确错误提示（前端预检；服务端 413 路径已由联调覆盖，文案同源）。
  - Node WS 以 Frank 身份实时发送 audio+video 消息 → 浏览器侧实时渲染 peer 侧气泡（音频可播、视频 160x120 可播），会话预览更新为「[视频]」并置顶。
  - 刷新页面 → 登录态与会话列表自动恢复，重新打开会话后历史音频/视频消息经 URL 正常加载并可播放。
  - 截图证据（聊天窗口 + 会话列表 + 工具栏三按钮）：消息流显示两条音视频气泡与会话预览「[视频]」、工具栏「图片/音频/视频」、连接状态「实时连接正常」。
- 实现落点：
  - 服务端：`hello/Sources/App/Controllers/UploadController.swift` 扩展——新增 `UploadsTypeMiddleware`（扩展名→MIME 映射涵盖 UploadRules 所有允许格式、安全文件名校验、复用 `req.fileio.asyncStreamFile(at:mediaType:)` 流式输出）；`hello/Sources/App/configure.swift` 在 FileMiddleware 之前 `app.middleware.use(UploadsTypeMiddleware())`。UploadRules 已有 audio/video 规则（mp3/m4a/aac/wav ≤20MB、mp4/mov ≤100MB）保持不变。
  - 前端：`web/src/config.ts` 新增 `AUDIO_UPLOAD` / `VIDEO_UPLOAD` 预检常量；`web/src/stores/chat.ts` 将 `sendImage` 泛化为 `sendMedia(file, msgType)`（blob URL 占位可同时驱动图片预览与音视频本地播放），导出名同步更新；`web/src/views/ChatView.vue` 工具栏新增「音频」「视频」按钮与对应 accept 限制的隐藏 file input，气泡按 `msgType` 分别渲染（`media-bubble` 布局 + `<audio controls preload="metadata">` / `<video controls preload="metadata">`，uploading/failed 视觉态沿用）；`web/src/api.ts` 与 `vite.config.ts` 无功能变更（后者代理目标改为可用 VAPOR_URL 环境变量覆盖，便于备用端口联调）。
- 数据库 / 迁移：无变化（`msgType` 字段 01 已就绪，audio/video 消息 content 存文件 URL）。
- 遗留：暂未清理 `hello/Public/uploads/` 中本会话产生的测试文件（约 40 个媒体文件，总计 ~448K，含本任务自身测试与 01–03 历次冒烟残留，与 issue 03 的处理方式一致，依赖系统清理；不会上传到 origin——仓库根 .gitignore 未跟踪该目录）。后续任务队列：emoji 面板与新会话 (05)、WS 鉴权、iOS 媒体消息、群聊。
