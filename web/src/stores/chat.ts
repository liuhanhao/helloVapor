import { ref } from 'vue'
import { defineStore } from 'pinia'
import { WS_BASE } from '../config'
import {
  ApiError,
  createGroup as createGroupApi,
  fetchGroups,
  fetchGroupMembers,
  fetchHistory,
  fetchSessions,
  leaveGroup as leaveGroupApi,
  searchUsers,
  uploadMedia
} from '../api'
import type {
  ChatAck,
  ChatErrorMessage,
  ChatPayload,
  GroupMember,
  GroupSummary,
  HistoryMessage,
  MessageItem,
  SessionKind,
  SessionSummary,
  UserInfo
} from '../types'
// 打开会话时可携带的收件主体身份（群名/昵称、账号、头像），用于新会话条目的展示
type RecipientIdentity = { nickname?: string; username?: string; avatar?: string }
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

  // 会话列表（单聊与群聊混排，按最后消息时间倒序，新消息置顶）
  const sessions = ref<SessionSummary[]>([])
  const sessionsLoading = ref(false)
  const sessionsError = ref('')
  // 收件主体 id（单聊为联系人用户 id，群聊为群 id）-> 消息列表（时间正序，含历史 + 实时）
  const conversations = ref<Record<string, MessageItem[]>>({})
  // 收件主体 id -> 展示名（单聊为联系人昵称，群聊为群名）
  const recipientNames = ref<Record<string, string>>({})
  // 收件主体 id -> 会话形态：决定消息发往哪里、气泡是否显示发送者昵称
  const recipientKinds = ref<Record<string, SessionKind>>({})
  // 我加入的群：群 id -> 群信息（会话列表与群信息页的成员数从这里取）
  const groups = ref<Record<string, GroupSummary>>({})
  // 收件主体 id -> 历史是否已加载（首次打开会话时拉取）
  const historyLoaded = ref<Record<string, boolean>>({})
  // 收件主体 id -> 是否还有更早的历史可翻页
  const hasMoreHistory = ref<Record<string, boolean>>({})
  const historyLoading = ref(false)
  const historyError = ref('')
  const currentRecipientId = ref<string | null>(null)
  const connected = ref(false)
  const groupsError = ref('')

  // 收件主体是不是群
  function isGroup(recipientId: string): boolean {
    return recipientKinds.value[recipientId] === 'group'
  }

  let socket: WebSocket | null = null
  let seq = 0

  function connect() {
    // 连接凭证改用 token：身份由服务端凭 token 解析，不再由客户端自报 userid
    const token = auth.token
    if (!token || socket) return
    const url = `${WS_BASE}/chat/webSocket?token=${encodeURIComponent(token)}`
    const ws = new WebSocket(url)
    socket = ws
    ws.onopen = () => {
      connected.value = true
    }
    ws.onclose = (event) => {
      connected.value = false
      if (socket === ws) socket = null
      // 1008 = 服务端因凭证无效拒绝连接：清除登录态，由路由守卫回登录页
      if (event.code === 1008) auth.logout()
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
    recipientNames.value = {}
    recipientKinds.value = {}
    groups.value = {}
    historyLoaded.value = {}
    hasMoreHistory.value = {}
    historyLoading.value = false
    historyError.value = ''
    groupsError.value = ''
    currentRecipientId.value = null
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
        recipientNames.value[s.peer.userid] = s.peer.nickname || s.peer.username || s.peer.userid
        recipientKinds.value[s.peer.userid] = s.kind
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

  // 我加入的群：会话列表只含有过消息的会话，这里把还没发过言的群补进去，
  // 否则刚建好的群刷新后会从界面上消失。已有条目的群顺带刷新群名与成员数
  async function loadGroups() {
    const token = auth.token
    if (!token) return
    groupsError.value = ''
    try {
      const list = await fetchGroups(token)
      groups.value = Object.fromEntries(list.map((g) => [g.id, g]))
      // 服务端按创建时间倒序返回，倒着前插后最新建的群排在最上面
      for (const g of [...list].reverse()) {
        recipientNames.value[g.id] = g.name
        recipientKinds.value[g.id] = 'group'
        const idx = sessions.value.findIndex((s) => s.peer.userid === g.id)
        if (idx >= 0) {
          sessions.value[idx].peer.nickname = g.name
          sessions.value[idx].memberCount = g.memberCount
          continue
        }
        sessions.value.unshift({
          kind: 'group',
          peer: { userid: g.id, username: '', nickname: g.name, avatar: 'default' },
          lastMessage: { content: '', msgType: 'text', fromSelf: false, createdAt: 0 },
          memberCount: g.memberCount
        })
      }
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        auth.logout()
        return
      }
      groupsError.value = e instanceof Error && e.message ? e.message : '群列表加载失败'
    }
  }

  // 打开一个会话：recipientId 是收件主体 id（单聊为联系人用户 id，群聊为群 id）。
  // identity 可携带查到的身份（群名/昵称、账号、头像），用于补一条本地条目；
  // 收发消息后会自动置顶并更新预览
  function openConversation(
    recipientId: string,
    identity?: RecipientIdentity,
    kind: SessionKind = 'direct'
  ) {
    currentRecipientId.value = recipientId
    recipientNames.value[recipientId] =
      identity?.nickname || identity?.username || recipientNames.value[recipientId] || recipientId
    if (!conversations.value[recipientId]) conversations.value[recipientId] = []
    if (!sessions.value.some((s) => s.peer.userid === recipientId)) {
      sessions.value.unshift({
        kind,
        peer: {
          userid: recipientId,
          username: identity?.username ?? '',
          nickname: identity?.nickname ?? recipientNames.value[recipientId],
          avatar: identity?.avatar ?? 'default'
        },
        lastMessage: { content: '', msgType: 'text', fromSelf: false, createdAt: 0 },
        memberCount: kind === 'group' ? groups.value[recipientId]?.memberCount : undefined
      })
    }
    if (!historyLoaded.value[recipientId]) {
      void loadHistory(recipientId)
    }
  }

  // 主动发起新会话：用查到的用户身份（昵称/账号/头像）打开会话并建条目
  function openUserConversation(user: UserInfo) {
    openConversation(
      user.id,
      { nickname: user.nickname, username: user.account, avatar: user.avatar },
      'direct'
    )
  }

  // 建群后打开该群会话
  function openGroupConversation(group: GroupSummary) {
    groups.value[group.id] = group
    recipientKinds.value[group.id] = 'group'
    openConversation(group.id, { nickname: group.name }, 'group')
  }

  // 建群（被拉入者无需同意，建群即入群）：成功后打开该群会话
  async function createGroup(name: string, memberIds: string[]): Promise<GroupSummary> {
    const token = auth.token
    if (!token) throw new Error('尚未登录')
    try {
      const group = await createGroupApi(token, name, memberIds)
      openGroupConversation(group)
      return group
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) auth.logout()
      throw e
    }
  }

  // 群成员列表（非成员访问会被服务端拒绝）
  async function loadGroupMembers(groupId: string): Promise<GroupMember[]> {
    const token = auth.token
    if (!token) return []
    try {
      return await fetchGroupMembers(token, groupId)
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) auth.logout()
      throw e
    }
  }

  // 退群：退群即失去该群的访问权，本地会话与消息一并移除
  async function leaveGroup(groupId: string): Promise<void> {
    const token = auth.token
    const me = auth.user
    if (!token || !me) throw new Error('尚未登录')
    try {
      await leaveGroupApi(token, groupId, me.id)
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) auth.logout()
      throw e
    }
    sessions.value = sessions.value.filter((s) => s.peer.userid !== groupId)
    delete conversations.value[groupId]
    delete recipientNames.value[groupId]
    delete recipientKinds.value[groupId]
    delete groups.value[groupId]
    delete historyLoaded.value[groupId]
    delete hasMoreHistory.value[groupId]
    if (currentRecipientId.value === groupId) currentRecipientId.value = null
  }

  // 按账号或用户 ID 查询用户（issue 05）：返回公开身份信息，查不到时为空数组。
  // token 失效（401）按其它接口的惯例清除凭证，由路由守卫回登录页
  async function searchUser(keyword: string): Promise<UserInfo[]> {
    const token = auth.token
    if (!token) return []
    try {
      return await searchUsers(token, keyword)
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) auth.logout()
      throw e
    }
  }

  // 返回存储到响应式数组中的消息引用，供异步流程（如图片上传）后续更新状态
  function appendMessage(recipientId: string, item: Omit<MessageItem, 'seq'>): MessageItem {
    if (!conversations.value[recipientId]) conversations.value[recipientId] = []
    conversations.value[recipientId].push({ ...item, seq: seq++ })
    const list = conversations.value[recipientId]
    return list[list.length - 1]
  }

  // 新消息让对应会话置顶并更新预览与时间
  function bumpSession(
    recipientId: string,
    content: string,
    msgType: string,
    fromSelf: boolean,
    timestampMs: number
  ) {
    const idx = sessions.value.findIndex((s) => s.peer.userid === recipientId)
    let item: SessionSummary
    if (idx >= 0) {
      item = sessions.value[idx]
      sessions.value.splice(idx, 1)
    } else {
      item = {
        kind: isGroup(recipientId) ? 'group' : 'direct',
        peer: {
          userid: recipientId,
          username: '',
          nickname: recipientNames.value[recipientId] ?? recipientId,
          avatar: 'default'
        },
        lastMessage: { content: '', msgType: 'text', fromSelf: false, createdAt: 0 },
        memberCount: groups.value[recipientId]?.memberCount
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
      acked: true,
      senderNickname: m.senderNickname
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
  async function loadHistory(recipientId: string) {
    const token = auth.token
    if (!token) return
    historyLoading.value = true
    historyError.value = ''
    try {
      const page = await fetchHistory(token, recipientId, { limit: PAGE_SIZE })
      const items = page.messages.map(toMessageItem)
      const historyIds = new Set(items.map((m) => m.id).filter((id): id is string => !!id))
      const live = (conversations.value[recipientId] ?? []).filter(
        (m) => !m.id || !historyIds.has(m.id)
      )
      conversations.value[recipientId] = [...items, ...live]
      historyLoaded.value[recipientId] = true
      hasMoreHistory.value[recipientId] = page.hasMore
    } catch (e) {
      handleHistoryError(e)
    } finally {
      historyLoading.value = false
    }
  }

  // 翻页加载更早的历史，前插到当前消息列表
  async function loadOlder(recipientId: string) {
    const token = auth.token
    if (!token || historyLoading.value) return
    const list = conversations.value[recipientId] ?? []
    const serverMessages = list.filter((m) => m.id)
    if (serverMessages.length === 0) return
    const before = Math.min(...serverMessages.map((m) => m.timestamp))
    historyLoading.value = true
    historyError.value = ''
    try {
      const page = await fetchHistory(token, recipientId, { limit: PAGE_SIZE, before })
      const items = page.messages.map(toMessageItem)
      const existingIds = new Set(list.map((m) => m.id).filter((id): id is string => !!id))
      const fresh = items.filter((m) => !m.id || !existingIds.has(m.id))
      conversations.value[recipientId] = [...fresh, ...list]
      hasMoreHistory.value[recipientId] = page.hasMore
    } catch (e) {
      handleHistoryError(e)
    } finally {
      historyLoading.value = false
    }
  }

  // 经 WebSocket 发出一条聊天消息（文本与媒体消息共用；媒体消息的 content 为文件 URL）。
  // 收件主体类型按会话形态填写：群聊时 to.userid 位置填群 id（ADR-0002 扩展协议）
  function sendChatMessage(
    me: UserInfo,
    recipientId: string,
    content: string,
    msgType: string
  ): boolean {
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
          userid: recipientId,
          username: '',
          nickname: '',
          type: isGroup(recipientId) ? 'group' : 'user'
        }
      }
    }
    socket.send(JSON.stringify(payload))
    return true
  }

  // 发送文本消息：先乐观渲染，服务端回执后标记确认
  function sendText(content: string): boolean {
    const me = auth.user
    const recipientId = currentRecipientId.value
    if (!me || !recipientId || !sendChatMessage(me, recipientId, content, 'text')) return false
    const now = Date.now()
    appendMessage(recipientId, {
      fromSelf: true,
      content,
      msgType: 'text',
      timestamp: now,
      acked: false
    })
    bumpSession(recipientId, content, 'text', true, now)
    return true
  }

  // 发送媒体消息（图片/音频/视频）：先上传拿文件 URL，再以媒体消息协议
  // （msgType=image/audio/video）经 WS 发出。上传期间以本地 blob 占位
  // （图片可预览、音视频可直接播放）并显示"上传中"，被服务端拒绝或连接断开时标记失败。
  // 返回 null 表示已发出（进入 ack 等待），否则返回错误信息供界面提示。
  async function sendMedia(file: File, msgType: 'image' | 'audio' | 'video'): Promise<string | null> {
    const me = auth.user
    const recipientId = currentRecipientId.value
    const token = auth.token
    if (!me || !recipientId || !token) return '尚未登录或未打开会话'
    const label = MEDIA_LABELS[msgType]

    // 本地占位（blob URL 对图片/音频/视频均可直接渲染播放），进入"上传中"状态
    const localUrl = URL.createObjectURL(file)
    const item = appendMessage(recipientId, {
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
    if (!sendChatMessage(me, recipientId, url, msgType)) {
      item.error = '实时连接未就绪，请稍后重试'
      return item.error
    }
    bumpSession(recipientId, url, msgType, true, Date.now())
    return null
  }

  function handleServerMessage(raw: string) {
    const meId = auth.user?.id
    if (!meId) return

    let json: ChatPayload | ChatAck | ChatErrorMessage | { type: string }
    try {
      json = JSON.parse(raw)
    } catch {
      return
    }

    if (json.type === 'chatMessage') {
      const payload = json as ChatPayload
      const mine = payload.data?.mine
      const to = payload.data?.to
      // 自己发出的消息由发送时乐观渲染
      if (!mine || mine.userid === meId) return
      // 收件主体：群聊按群 id 归档，单聊按发送者（联系人）归档
      const group = to?.type === 'group'
      const recipientId = group ? to!.userid : mine.userid
      // 不是发给自己的单聊消息（群消息由服务端按成员身份扇出，无需再判）
      if (!group && to?.userid !== meId) return

      if (group) {
        // 被拉进一个还没加载过的群时（群列表里没有它），补拉一次拿群名
        if (!groups.value[recipientId]) void loadGroups()
        recipientKinds.value[recipientId] = 'group'
      } else {
        recipientNames.value[recipientId] = mine.nickname || mine.username || recipientId
      }
      const timestamp = payload.data?.timestamp != null ? payload.data.timestamp * 1000 : Date.now()
      appendMessage(recipientId, {
        id: payload.data?.id,
        fromSelf: false,
        content: mine.content,
        msgType: mine.msgType || 'text',
        timestamp,
        acked: true,
        // 群聊气泡靠它显示是谁说的；单聊不需要
        senderNickname: group ? mine.nickname || mine.username || recipientId : undefined
      })
      bumpSession(recipientId, mine.content, mine.msgType || 'text', false, timestamp)
    } else if (json.type === 'chatMessageAck') {
      // 服务端确认：标记最早一条未确认的已发消息，并补上消息 id 与服务端时间戳。
      // 上传中的媒体消息尚未经 WS 发出、已失败的消息不再期待回执，均跳过
      const ack = json as ChatAck
      const pending = findPendingMessage()
      if (pending) {
        pending.acked = true
        if (ack.data?.id) pending.id = ack.data.id
        if (ack.data?.timestamp != null) pending.timestamp = ack.data.timestamp * 1000
      }
    } else if (json.type === 'chatMessageError') {
      // 服务端拒收（如已不是群成员）：把那条消息标记为发送失败，否则用户会以为发出去了
      const pending = findPendingMessage()
      if (pending) pending.error = (json as ChatErrorMessage).data?.reason || '消息未发送'
    }
  }

  // 最早一条等待确认的已发消息：上传中的媒体消息尚未经 WS 发出、
  // 已失败的消息不再期待回执，均跳过。错误帧不带消息标识，按同样的顺序匹配
  function findPendingMessage(): MessageItem | undefined {
    for (const list of Object.values(conversations.value)) {
      const pending = list.find((m) => m.fromSelf && !m.acked && !m.uploading && !m.error)
      if (pending) return pending
    }
    return undefined
  }

  return {
    sessions,
    sessionsLoading,
    sessionsError,
    groupsError,
    conversations,
    recipientNames,
    currentRecipientId,
    historyLoaded,
    hasMoreHistory,
    historyLoading,
    historyError,
    connected,
    isGroup,
    connect,
    disconnect,
    reset,
    loadSessions,
    loadGroups,
    loadHistory,
    loadOlder,
    openConversation,
    openUserConversation,
    openGroupConversation,
    searchUser,
    createGroup,
    loadGroupMembers,
    leaveGroup,
    sendText,
    sendMedia
  }
})
