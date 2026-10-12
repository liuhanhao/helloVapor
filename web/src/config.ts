// 全局配置：开发期 HTTP/WebSocket 都走 Vite 代理（与页面同源），
// 这样局域网其他电脑只需访问 5173 即可，无需直连后端 8080。
// 仍可用 VITE_WS_BASE 环境变量强制指定 WS 地址（如直连备用后端）。
const WS_HOST = import.meta.env.VITE_WS_BASE
  || `${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}`
export const WS_BASE = WS_HOST

// 媒体上传限制（与服务端 UploadRules 常量保持一致，用于发送前的本地预检；
// 服务端校验仍是权威，超限或非法类型最终以服务端返回的错误为准）
export const IMAGE_UPLOAD = {
  extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
  maxMB: 10
}

// 音频上传限制：mp3/m4a/aac/wav ≤ 20 MB
export const AUDIO_UPLOAD = {
  extensions: ['mp3', 'm4a', 'aac', 'wav'],
  maxMB: 20
}

// 视频上传限制：mp4/mov ≤ 100 MB
export const VIDEO_UPLOAD = {
  extensions: ['mp4', 'mov'],
  maxMB: 100
}
