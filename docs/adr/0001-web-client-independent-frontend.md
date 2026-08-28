# Web 端采用独立前端工程

Web 版聊天客户端作为独立前端工程（Vue 3 + Vite + TypeScript），不放入 Vapor 的 `Public/` 静态托管，也不用 Leaf 服务端渲染。选择独立工程是为了获得完整的组件化开发体验和构建工具链；代价是需要处理前后端分离的开发代理与部署，iOS 与 Web 之间通过同一套 HTTP + WebSocket 协议互通。

## Considered Options

- Vapor `Public/` 静态托管原生页面：零构建零依赖，但缺少组件化能力，后续维护成本高
- Leaf 服务端渲染：交互能力弱，不适合实时聊天场景
