// 全局配置：开发期 HTTP 请求走 Vite 代理（相对路径），WebSocket 直连 Vapor 服务
export const WS_BASE = import.meta.env.VITE_WS_BASE || 'ws://127.0.0.1:8080'

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
