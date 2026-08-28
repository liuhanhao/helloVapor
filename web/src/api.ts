import type { HistoryPage, SessionSummary, UserInfo } from './types'

// 服务端返回的错误结构
interface ApiErrorResponse {
  error?: boolean
  reason?: string
}

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string
  ) {
    super(message)
  }
}

// UTF-8 安全的 base64（Basic Auth 编码账号密码）
function utf8ToBase64(input: string): string {
  const bytes = new TextEncoder().encode(input)
  let binary = ''
  bytes.forEach((b) => (binary += String.fromCharCode(b)))
  return btoa(binary)
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  let res: Response
  try {
    res = await fetch(path, init)
  } catch {
    throw new ApiError(0, '无法连接服务端，请确认 Vapor 服务已启动')
  }
  if (!res.ok) {
    let reason = ''
    try {
      const body = (await res.json()) as ApiErrorResponse
      reason = body.reason || ''
    } catch {
      // 响应体非 JSON，忽略
    }
    throw new ApiError(res.status, reason || `请求失败（${res.status}）`)
  }
  return (await res.json()) as T
}

// 注册
export function register(params: {
  nickname: string
  account: string
  password: string
  confirmPassword: string
}): Promise<UserInfo> {
  return request<UserInfo>('/chat/registered', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ avatar: 'default', ...params })
  })
}

// 登录（Basic Auth），返回 token
export function login(account: string, password: string): Promise<{ value: string }> {
  const basic = utf8ToBase64(`${account}:${password}`)
  return request<{ value: string }>('/chat/login', {
    method: 'POST',
    headers: { Authorization: `Basic ${basic}` }
  })
}

// 用 token 换取当前用户信息
export function fetchMe(token: string): Promise<UserInfo> {
  return request<UserInfo>('/chat/me', {
    headers: { Authorization: `Bearer ${token}` }
  })
}

// 会话列表：按联系人分组返回对方身份与最后一条消息，按时间倒序
// （服务端时间戳为 Unix 秒，这里统一转为毫秒）
export async function fetchSessions(token: string): Promise<SessionSummary[]> {
  const raw = await request<SessionSummary[]>('/chat/sessions', {
    headers: { Authorization: `Bearer ${token}` }
  })
  return raw.map((s) => ({
    ...s,
    lastMessage: { ...s.lastMessage, createdAt: s.lastMessage.createdAt * 1000 }
  }))
}

// 历史消息：与指定联系人的双方消息按时间正序分页返回
// opts.before 为毫秒时间戳，取该时间之前（不含）的更早消息
export async function fetchHistory(
  token: string,
  peerId: string,
  opts: { limit?: number; before?: number } = {}
): Promise<HistoryPage> {
  const params = new URLSearchParams({ peer: peerId })
  if (opts.limit != null) params.set('limit', String(opts.limit))
  if (opts.before != null) params.set('before', String(opts.before / 1000))
  const page = await request<HistoryPage>(`/chat/history?${params.toString()}`, {
    headers: { Authorization: `Bearer ${token}` }
  })
  return {
    hasMore: page.hasMore,
    messages: page.messages.map((m) => ({ ...m, createdAt: m.createdAt * 1000 }))
  }
}

// 上传媒体文件（multipart 表单）：按 msgType 校验类型与大小，返回可访问的文件 URL。
// 注意不手动设置 Content-Type，让浏览器自动携带 multipart 边界
export function uploadMedia(
  token: string,
  msgType: 'image' | 'audio' | 'video',
  file: File
): Promise<{ url: string }> {
  const form = new FormData()
  form.append('msgType', msgType)
  form.append('file', file)
  return request<{ url: string }>('/chat/upload', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: form
  })
}

// 将服务端错误转换为用户可见的中文提示
export function describeError(e: unknown, fallback: string): string {
  if (e instanceof ApiError) {
    switch (e.status) {
      case 401:
        return '账号或密码错误'
      case 409:
        return '账号已存在'
      case 0:
        return e.message
      default:
        return e.message || fallback
    }
  }
  return fallback
}
