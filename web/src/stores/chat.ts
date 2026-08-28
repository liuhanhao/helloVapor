import { ref } from 'vue'
import { defineStore } from 'pinia'
import { WS_BASE } from '../config'
import { ApiError, fetchHistory, fetchSessions, uploadMedia } from '../api'
import type { ChatAck, ChatPayload, HistoryMessage, MessageItem, SessionSummary, UserInfo } from '../types'
import { useAuthStore } from './auth'

// 历史消息每页条数
const PAGE_SIZE = 20

// 媒体消息类型对应的展示标签（错误提示用），与服务端 UploadRules 的规则一一对应
const MEDIA_LABELS: Record<'image' | 'audio' | 'video', string> = {
  image: '图片',
  audio: '音频',
  video: '视频'
}

export const useChatStore = defineStore('chat', () => {
  const auth = useAuthStore()

  // 会话列表（按最后消息时间倒序，新消息置顶）
  const sessions = ref<SessionSummary[]>([])
  const sessionsLoading = ref(false)
  const sessionsError = ref('')
  // peerUserId -> 消息列表（时间正序，含历史 + 实时）
  const conversations = ref<Record<string, MessageItem[]>>({})
  // peerUserId -> 对方昵称
  const peerNames = ref<Record<string, string>>({})
  // peerUserId -> 历史是否已加载（首次打开会话时拉取）
  const historyLoaded = ref<Record<string, boolean>>({})
  // peerUserId -> 是否还有更早的历史可翻页
  const hasMoreHistory = ref<Record<string, boolean>>({})
  const historyLoading = ref(false)
  const historyError = ref('')
  const currentPeerId = ref<string | null>(null)
  const connected = ref(false)

  let socket: WebSocket | null = null
  let seq = 0

  function connect() {
    const me = auth.user
    if (!me || socket) return
    const url = `${WS_BASE}/chat/webSocket?userid=${encodeURIComponent(me.id)}&username=${encodeURIComponent(me.account)}`
    const ws = new WebSocket(url)
    socket = ws
    ws.onopen = () => {
      connected.value = true
    }
    ws.onclose = () => {
      connected.value = false
      if (socket === ws) socket = null
    }
    ws.onerror = () => {
      connected.value = false
    }
    ws.onmessage = (event) => {
      handleServerMessage(String(event.data))
    }
  }

  function disconnect() {
    socket?.close()
    socket = null
    connected.value = false
  }

  // 退出登录时清空内存态，避免不同账号之间串数据
  function reset() {
    sessions.value = []
    sessionsLoading.value = false
    sessionsError.value = ''
    conversations.value = {}
    peerNames.value = {}
    historyLoaded.value = {}
    hasMoreHistory.value = {}
    historyLoading.value = false
    historyError.value = ''
    currentPeerId.value = null
    seq = 0
  }

  // 拉取会话列表（登录与刷新后调用）
  async function loadSessions() {
    const token = auth.token
    if (!token) return
    sessionsLoading.value = true
    sessionsError.value = ''
    try {
      sessions.value = await fetchSessions(token)
      for (const s of sessions.value) {
        peerNames.value[s.peer.userid] = s.peer.nickname || s.peer.username || s.peer.userid
      }
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        // token 已失效：清除凭证回登录页（路由守卫负责跳转）
        auth.logout()
        return
      }
      sessionsError.value = e instanceof Error && e.message ? e.message : '会话列表加载失败'
    } finally {
      sessionsLoading.value = false
    }
  }

  function openConversation(peerId: string, peerName?: string) {
    currentPeerId.value = peerId
    if (peerName) peerNames.value[peerId] = peerName
    if (!peerNames.value[peerId]) peerNames.value[peerId] = peerId
    if (!conversations.value[peerId]) conversations.value[peerId] = []
    // 会话列表暂无此联系人时补一条本地条目（如通过 userid 发起新会话），
    // 收发消息后会自动置顶并更新预览
    if (!sessions.value.some((s) => s.peer.userid === peerId)) {
      sessions.value.unshift({
        peer: { userid: peerId, username: '', nickname: peerNames.value[peerId], avatar: 'default' },
        lastMessage: { content: '', msgType: 'text', fromSelf: false, createdAt: 0 }
      })
    }
    if (!historyLoaded.value[peerId]) {
      void loadHistory(peerId)
    }
  }

  // 返回存储到响应式数组中的消息引用，供异步流程（如图片上传）后续更新状态
  function appendMessage(peerId: string, item: Omit<MessageItem, 'seq'>): MessageItem {
    if (!conversations.value[peerId]) conversations.value[peerId] = []
    conversations.value[peerId].push({ ...item, seq: seq++ })
    const list = conversations.value[peerId]
    return list[list.length - 1]
  }

  // 新消息让对应会话置顶并更新预览与时间
  function bumpSession(peerId: string, content: string, msgType: string, fromSelf: boolean, timestampMs: number) {
    const idx = sessions.value.findIndex((s) => s.peer.userid === peerId)
    let item: SessionSummary
    if (idx >= 0) {
      item = sessions.value[idx]
      sessions.value.splice(idx, 1)
    } else {
      item = {
        peer: { userid: peerId, username: '', nickname: peerNames.value[peerId] ?? peerId, avatar: 'default' },
        lastMessage: { content: '', msgType: 'text', fromSelf: false, createdAt: 0 }
      }
    }
    item.lastMessage = { content, msgType, fromSelf, createdAt: timestampMs }
    sessions.value.unshift(item)
  }

  function toMessageItem(m: HistoryMessage): MessageItem {
    return {
      seq: seq++,
      id: m.id,
      fromSelf: m.fromSelf,
      content: m.content,
      msgType: m.msgType,
      timestamp: m.createdAt,
      acked: true
    }
  }

  function handleHistoryError(e: unknown) {
    if (e instanceof ApiError && e.status === 401) {
      auth.logout()
      return
    }
    historyError.value = e instanceof Error && e.message ? e.message : '历史消息加载失败'
  }

  // 首次打开会话：拉取最近一页历史，并与拉取期间实时到达的消息按 id 去重合并
  async function loadHistory(peerId: string) {
    const token = auth.token
    if (!token) return
    historyLoading.value = true
    historyError.value = ''
    try {
      const page = await fetchHistory(token, peerId, { limit: PAGE_SIZE })
      const items = page.messages.map(toMessageItem)
      const historyIds = new Set(items.map((m) => m.id).filter((id): id is string => !!id))
      const live = (conversations.value[peerId] ?? []).filter((m) => !m.id || !historyIds.has(m.id))
      conversations.value[peerId] = [...items, ...live]
      historyLoaded.value[peerId] = true
      hasMoreHistory.value[peerId] = page.hasMore
    } catch (e) {
      handleHistoryError(e)
    } finally {
      historyLoading.value = false
    }
  }

  // 翻页加载更早的历史，前插到当前消息列表
  async function loadOlder(peerId: string) {
    const token = auth.token
    if (!token || historyLoading.value) return
    const list = conversations.value[peerId] ?? []
    const serverMessages = list.filter((m) => m.id)
    if (serverMessages.length === 0) return
    const before = Math.min(...serverMessages.map((m) => m.timestamp))
    historyLoading.value = true
    historyError.value = ''
    try {
      const page = await fetchHistory(token, peerId, { limit: PAGE_SIZE, before })
      const items = page.messages.map(toMessageItem)
      const existingIds = new Set(list.map((m) => m.id).filter((id): id is string => !!id))
      const fresh = items.filter((m) => !m.id || !existingIds.has(m.id))
      conversations.value[peerId] = [...fresh, ...list]
      hasMoreHistory.value[peerId] = page.hasMore
    } catch (e) {
      handleHistoryError(e)
    } finally {
      historyLoading.value = false
    }
  }

  // 经 WebSocket 发出一条聊天消息（文本与媒体消息共用；媒体消息的 content 为文件 URL）
  function sendChatMessage(me: UserInfo, peerId: string, content: string, msgType: string): boolean {
    if (!socket || socket.readyState !== WebSocket.OPEN) return false
    const payload: ChatPayload = {
      type: 'chatMessage',
      data: {
        mine: {
          avatar: me.avatar,
          content,
          mine: true,
          userid: me.id,
          username: me.account,
          nickname: me.nickname,
          msgType
        },
        to: {
          avatar: 'default',
          userid: peerId,
          username: '',
          nickname: ''
        }
      }
    }
    socket.send(JSON.stringify(payload))
    return true
  }

  // 发送文本消息：先乐观渲染，服务端回执后标记确认
  function sendText(content: string): boolean {
    const me = auth.user
    const peerId = currentPeerId.value
    if (!me || !peerId || !sendChatMessage(me, peerId, content, 'text')) return false
    const now = Date.now()
    appendMessage(peerId, {
      fromSelf: true,
      content,
      msgType: 'text',
      timestamp: now,
      acked: false
    })
    bumpSession(peerId, content, 'text', true, now)
    return true
  }

  // 发送媒体消息（图片/音频/视频）：先上传拿文件 URL，再以媒体消息协议
  // （msgType=image/audio/video）经 WS 发出。上传期间以本地 blob 占位
  // （图片可预览、音视频可直接播放）并显示"上传中"，被服务端拒绝或连接断开时标记失败。
  // 返回 null 表示已发出（进入 ack 等待），否则返回错误信息供界面提示。
  async function sendMedia(file: File, msgType: 'image' | 'audio' | 'video'): Promise<string | null> {
    const me = auth.user
    const peerId = currentPeerId.value
    const token = auth.token
    if (!me || !peerId || !token) return '尚未登录或未打开会话'
    const label = MEDIA_LABELS[msgType]

    // 本地占位（blob URL 对图片/音频/视频均可直接渲染播放），进入"上传中"状态
    const localUrl = URL.createObjectURL(file)
    const item = appendMessage(peerId, {
      fromSelf: true,
      content: '',
      msgType,
      timestamp: Date.now(),
      acked: false,
      localUrl,
      uploading: true
    })

    // 第一步：上传文件拿 URL（类型/大小校验不通过时服务端返回明确错误）
    let url: string
    try {
      ;({ url } = await uploadMedia(token, msgType, file))
    } catch (e) {
      item.uploading = false
      item.error = e instanceof Error && e.message ? e.message : `${label}上传失败`
      return item.error
    }

    // 上传成功：切换为服务端 URL 展示，释放本地预览
    item.content = url
    item.localUrl = undefined
    item.uploading = false
    URL.revokeObjectURL(localUrl)

    // 第二步：经 WS 以媒体消息协议发出（连接未就绪则标记失败）
    if (!sendChatMessage(me, peerId, url, msgType)) {
      item.error = '实时连接未就绪，请稍后重试'
      return item.error
    }
    bumpSession(peerId, url, msgType, true, Date.now())
    return null
  }

  function handleServerMessage(raw: string) {
    const meId = auth.user?.id
    if (!meId) return

    let json: ChatPayload | ChatAck | { type: string }
    try {
      json = JSON.parse(raw)
    } catch {
      return
    }

    if (json.type === 'chatMessage') {
      const payload = json as ChatPayload
      const mine = payload.data?.mine
      const to = payload.data?.to
      if (!mine) return
      // 只渲染发给自己的消息（自己发出的消息由发送时乐观渲染）
      if (to?.userid === meId && mine.userid !== meId) {
        const peerId = mine.userid
        peerNames.value[peerId] = mine.nickname || mine.username || peerId
        const timestamp =
          payload.data?.timestamp != null ? payload.data.timestamp * 1000 : Date.now()
        appendMessage(peerId, {
          id: payload.data?.id,
          fromSelf: false,
          content: mine.content,
          msgType: mine.msgType || 'text',
          timestamp,
          acked: true
        })
        bumpSession(peerId, mine.content, mine.msgType || 'text', false, timestamp)
      }
    } else if (json.type === 'chatMessageAck') {
      // 服务端确认：标记最早一条未确认的已发消息，并补上消息 id 与服务端时间戳。
      // 上传中的媒体消息尚未经 WS 发出、已失败的消息不再期待回执，均跳过
      const ack = json as ChatAck
      for (const peerId of Object.keys(conversations.value)) {
        const pending = conversations.value[peerId].find(
          (m) => m.fromSelf && !m.acked && !m.uploading && !m.error
        )
        if (pending) {
          pending.acked = true
          if (ack.data?.id) pending.id = ack.data.id
          if (ack.data?.timestamp != null) pending.timestamp = ack.data.timestamp * 1000
          break
        }
      }
    }
  }

  return {
    sessions,
    sessionsLoading,
    sessionsError,
    conversations,
    peerNames,
    historyLoaded,
    hasMoreHistory,
    historyLoading,
    historyError,
    currentPeerId,
    connected,
    connect,
    disconnect,
    reset,
    loadSessions,
    loadHistory,
    loadOlder,
    openConversation,
    sendText,
    sendMedia
  }
})
