import type {
  GroupMember,
  GroupSummary,
  HistoryPage,
  SessionSummary,
  UserInfo
} from './types'

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

// 会话列表：单聊与群聊条目统一返回（条目带 kind 与群成员数），按最后消息时间倒序。
// 只含有过消息的会话——还没发过言的群要由 GET /chat/groups 补进列表
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

// 历史消息：与指定收件主体（联系人用户 id 或群 id）的消息按时间正序分页返回
// 群 id 与用户 id 同为 UUID，由服务端查表区分；非成员查群历史会被拒
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

// 查询用户（issue 05）：按账号或用户 ID 查询，返回公开身份信息（不含密码等敏感字段）。
// 查不到时返回空数组，由界面给出明确提示
export function searchUsers(token: string, keyword: string): Promise<UserInfo[]> {
  return request<UserInfo[]>(`/chat/users?q=${encodeURIComponent(keyword)}`, {
    headers: { Authorization: `Bearer ${token}` }
  })
}

// 我加入的群（按创建时间倒序）
export function fetchGroups(token: string): Promise<GroupSummary[]> {
  return request<GroupSummary[]>('/chat/groups', {
    headers: { Authorization: `Bearer ${token}` }
  })
}

// 建群：memberIds 不含自己（创建者自动入群且为群创建者），被拉入无需本人同意
export function createGroup(
  token: string,
  name: string,
  memberIds: string[]
): Promise<GroupSummary> {
  return request<GroupSummary>('/chat/groups', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ name, memberIds })
  })
}

// 群成员列表（非成员访问被拒）
export function fetchGroupMembers(token: string, groupId: string): Promise<GroupMember[]> {
  return request<GroupMember[]>(`/chat/groups/${encodeURIComponent(groupId)}/members`, {
    headers: { Authorization: `Bearer ${token}` }
  })
}

// 退群：只能退自己，退群即失去该群的访问权
export function leaveGroup(
  token: string,
  groupId: string,
  userId: string
): Promise<GroupSummary> {
  return request<GroupSummary>(
    `/chat/groups/${encodeURIComponent(groupId)}/members/${encodeURIComponent(userId)}`,
    { method: 'DELETE', headers: { Authorization: `Bearer ${token}` } }
  )
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
