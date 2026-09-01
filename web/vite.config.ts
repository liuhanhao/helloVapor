import { defineConfig } from 'vitest/config'
import vue from '@vitejs/plugin-vue'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue()],
  // 只测 stores 的状态逻辑（不做组件快照）。环境取 node + test-setup.ts 里的
  // 最小 window/localStorage 垫片，不引 DOM 实现
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
    setupFiles: ['./src/test-setup.ts']
  },
  server: {
    port: 5173,
    // 开发期代理后端请求，避免跨域（服务端同时启用 CORS 作为兜底）。
    // 代理目标可用 VAPOR_URL 环境变量覆盖（默认 8080），便于对备用端口的新构建联调。
    // 注意：键以 ^ 开头按正则匹配——只代理 /chat/xxx 形式的 API 路径，
    // 不拦裸 /chat（那是 SPA 路由，刷新时需由 Vite 回退到 index.html）
    proxy: {
      '^/chat/': {
        target: process.env.VAPOR_URL || 'http://127.0.0.1:8080',
        changeOrigin: true
      },
      // 上传的媒体文件（服务端 FileMiddleware 托管 Public 目录，/uploads/<文件名>）
      '^/uploads/': {
        target: process.env.VAPOR_URL || 'http://127.0.0.1:8080',
        changeOrigin: true
      }
    }
  }
})
