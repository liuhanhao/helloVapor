# 01 — 曳光弹：文本消息端到端跑通

**要构建的内容：** 两个用户在浏览器里分别注册登录，进入聊天窗口后能实时互发文本消息——这是穿透所有层的第一发曳光弹。包含前端独立工程骨架（Vue 3 + Vite + TypeScript + Pinia + Vue Router，开发代理指向 Vapor）、登录/注册页与登录态错误提示、聊天窗口（消息气泡 + 输入框）；服务端将 WebSocket 消息真正路由推送给接收方并回送发送方确认（替代现有反转回显），协议沿用现有结构并支持 `msgType` 缺省按文本处理，启用 CORS 中间件，`message` 表迁移新增 `msgType` 字段。遵循 ADR-0001（独立前端工程）与 ADR-0002（扩展协议）。

**被阻塞于（Blocked by）：** 无——可立即开始

**状态（Status）：** resolved

- [x] 访客可在前端注册新账号并登录，登录失败有明确错误提示
- [x] 登录后建立 WebSocket 连接并可发送文本消息，消息立即出现在自己的聊天窗口
- [x] 对方在线时实时收到消息并渲染在聊天窗口
- [x] 接收方离线时消息仅入库，服务端不报错
- [x] iOS 客户端发出的旧格式文本消息依然正常入库且可被转发（向后兼容）
- [x] 服务端、前端均可本地启动并联调成功（两个浏览器账号实时互聊）

## Comments

**2026-08-26 验收检查（Agent）：** 第一阶段全部完成。验证方式与证据：

- 编译检查：`swift build` 通过（仅 deprecation 警告）；`vue-tsc --noEmit` 通过。
- 联调检查：本地启动 Vapor（8080）后运行 `web/e2e-check.mjs`，13 项全部 PASS——注册/登录/`/chat/me`、409 重复注册、401 错误密码、双方 WebSocket 实时互发、`chatMessageAck` 确认（含时间戳）、不再有反转回显、旧格式（无 msgType）消息正常转发、离线接收方不报错。
- 入库检查：`chatMessage.db` 中三类消息（含旧格式与离线消息）均已落库，`mine_msgType` 正确写为 `text`。
- 前端启动：Vite dev（5173）页面 200，`/chat` 代理正确转发到 Vapor（经代理登录返回 401 证明链路通）。
- 实现落点：CORS（`configure.swift`）、`AddMessageMsgType` 迁移与 `msgType` 缺省逻辑（`ChatMessage.swift`、`WebSocketService.swift`）、注册/登录/`me` 路由（`routes.swift`）、前端工程骨架与页面（`web/src/`）。

注意：iOS 端（`ADSWebSocket.swift`）目前仅通过 WS 收消息、未主动发送，旧格式兼容在协议层验证（服务端缺省 `msgType=text`），符合本 issue 要求。02 号 issue（会话列表与历史消息）现已解除阻塞。
