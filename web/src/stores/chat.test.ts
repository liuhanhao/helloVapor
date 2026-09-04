import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { ApiError } from '../api'
import { useAuthStore } from './auth'
import { useChatStore } from './chat'

// api 层全部用 mock 顶掉，但保留 ApiError 真身——store 里靠 instanceof 判定错误类型
const mocks = vi.hoisted(() => ({
  fetchSessions: vi.fn(),
  fetchHistory: vi.fn(),
  fetchGroups: vi.fn(),
  fetchGroupMembers: vi.fn(),
  markRead: vi.fn(),
  recallMessage: vi.fn(),
  searchUsers: vi.fn(),
  searchMessages: vi.fn(),
  createGroup: vi.fn(),
  updateGroup: vi.fn(),
  addGroupMember: vi.fn(),
  leaveGroup: vi.fn(),
  uploadMedia: vi.fn()
}))

vi.mock('../api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../api')>()),
  ...mocks
}))

const ME = { id: 'me', avatar: 'default', nickname: '我', account: 'me@test.com' }
const OTHER = 'p1'

// 假的 WebSocket：记录发出的帧，并允许测试直接模拟服务端推来一帧。
// 走真实的 connect → onmessage → handleServerMessage 路径，比单独导出内部函数更接近实际
class FakeWebSocket {
  static last: FakeWebSocket | null = null
  static OPEN = 1
  readyState = 1
  onopen: (() => void) | null = null
  onclose: ((e: { code: number }) => void) | null = null
  onerror: (() => void) | null = null
  onmessage: ((e: { data: string }) => void) | null = null
  readonly sent: string[] = []
  constructor(public url: string) {
    FakeWebSocket.last = this
  }
  send(data: string) {
    this.sent.push(data)
  }
  close() {
    this.readyState = 3
    this.onclose?.({ code: 1000 })
  }
  emit(payload: unknown) {
    this.onmessage?.({ data: JSON.stringify(payload) })
  }
}

// 一条发给我（单聊）的实时消息帧
function incoming(messageId: string, content = '新消息') {
  return {
    type: 'chatMessage',
    data: {
      id: messageId,
      timestamp: 1700000000,
      mine: {
        avatar: 'default',
        content,
        mine: true,
        userid: OTHER,
        username: 'p1@test.com',
        nickname: 'P1',
        msgType: 'text'
      },
      to: { avatar: 'default', userid: 'me', username: '', nickname: '', type: 'user' }
    }
  }
}

function directSession(peerId: string, unreadCount: number) {
  return {
    kind: 'direct' as const,
    peer: {
      userid: peerId,
      username: `${peerId}@test.com`,
      nickname: peerId,
      avatar: 'default'
    },
    lastMessage: {
      content: '旧消息',
      msgType: 'text',
      fromSelf: false,
      createdAt: 1000,
      recalled: false
    },
    unreadCount,
    memberCount: undefined
  }
}

function groupSession(groupId: string, name: string, memberCount: number) {
  return {
    kind: 'group' as const,
    peer: { userid: groupId, username: '', nickname: name, avatar: 'default' },
    lastMessage: {
      content: '',
      msgType: 'text',
      fromSelf: false,
      createdAt: 0,
      recalled: false
    },
    unreadCount: 0,
    memberCount
  }
}

function useLoggedInChat() {
  const chat = useChatStore()
  chat.connect()
  return { chat, ws: FakeWebSocket.last! }
}

beforeEach(() => {
  localStorage.clear()
  localStorage.setItem('chat.token', 'tok')
  localStorage.setItem('chat.user', JSON.stringify(ME))
  setActivePinia(createPinia())
  vi.clearAllMocks()
  mocks.fetchSessions.mockResolvedValue([])
  mocks.fetchGroups.mockResolvedValue([])
  mocks.fetchGroupMembers.mockResolvedValue([])
  mocks.fetchHistory.mockResolvedValue({ messages: [], hasMore: false })
  mocks.searchUsers.mockResolvedValue([])
  mocks.markRead.mockResolvedValue({ recipientId: OTHER, lastReadAt: 1 })
  vi.stubGlobal('WebSocket', FakeWebSocket)
})

afterEach(() => {
  vi.unstubAllGlobals()
  vi.useRealTimers()
})

describe('未读计数', () => {
  it('拉取会话列表时用服务端未读数覆盖本地的乐观累加', async () => {
    const { chat } = useLoggedInChat()
    chat.unreadCounts[OTHER] = 5
    mocks.fetchSessions.mockResolvedValue([directSession(OTHER, 2)])

    await chat.loadSessions()

    // 服务端是权威来源：本地的乐观值被整体覆盖，不做合并
    expect(chat.unreadCounts[OTHER]).toBe(2)
  })

  it('收到非当前会话的消息时本地未读 +1', () => {
    const { chat, ws } = useLoggedInChat()

    ws.emit(incoming('m1'))
    expect(chat.unreadCounts[OTHER]).toBe(1)

    ws.emit(incoming('m2'))
    expect(chat.unreadCounts[OTHER]).toBe(2)
  })

  it('当前会话的新消息不累加未读，而是合批标记已读', async () => {
    vi.useFakeTimers()
    const { chat, ws } = useLoggedInChat()
    chat.openConversation(OTHER)
    mocks.markRead.mockClear()

    ws.emit(incoming('m1'))

    expect(chat.unreadCounts[OTHER]).toBe(0)
    // 打开期间的新消息走 1s 合批，不是每条一个请求
    expect(mocks.markRead).not.toHaveBeenCalled()
    await vi.advanceTimersByTimeAsync(1100)
    expect(mocks.markRead).toHaveBeenCalledTimes(1)
  })

  it('打开会话立即清零未读并写入服务端位点，不等请求返回', async () => {
    const chat = useChatStore()
    chat.unreadCounts[OTHER] = 3

    chat.openConversation(OTHER)

    expect(chat.unreadCounts[OTHER]).toBe(0)
    expect(mocks.markRead).toHaveBeenCalledWith('tok', OTHER)
  })
})

describe('会话列表', () => {
  it('新消息让会话置顶，且不产生重复条目', async () => {
    const chat = useChatStore()
    // p2 在前：收到 p1 的消息后 p1 应升到首位
    mocks.fetchSessions.mockResolvedValue([directSession('p2', 0), directSession(OTHER, 0)])
    await chat.loadSessions()
    chat.connect()
    const ws = FakeWebSocket.last!

    ws.emit(incoming('m1'))
    ws.emit(incoming('m2'))

    const ids = chat.sessions.map((s) => s.peer.userid)
    expect(ids[0]).toBe(OTHER)
    expect(ids.filter((id) => id === OTHER)).toHaveLength(1)
    expect(ids).toHaveLength(2)
  })

  it('刷新会话时按消息 id 去掉重复的历史消息', async () => {
    const { chat, ws } = useLoggedInChat()
    ws.emit(incoming('m1')) // 实时先到，随后拉取历史时不应重复

    mocks.fetchHistory.mockResolvedValue({
      hasMore: false,
      messages: [
        {
          id: 'm1',
          content: '新消息',
          msgType: 'text',
          fromSelf: false,
          createdAt: 1700000000000,
          senderNickname: 'P1'
        }
      ]
    })

    await chat.loadHistory(OTHER)

    expect(chat.conversations[OTHER]).toHaveLength(1)
  })
})

describe('群改名与拉人', () => {
  it('改群名后群表、展示名与会话列表条目同步更新', async () => {
    const chat = useChatStore()
    mocks.fetchSessions.mockResolvedValue([groupSession('g1', '旧群名', 2)])
    await chat.loadSessions()

    mocks.updateGroup.mockResolvedValue({
      id: 'g1',
      name: '新群名',
      avatar: 'default',
      memberCount: 2,
      ownerId: 'me'
    })
    await chat.renameGroup('g1', '新群名')

    // 三处不同步就会出现「列表改名了、气泡标题还是旧的」
    expect(chat.groups['g1'].name).toBe('新群名')
    expect(chat.recipientNames['g1']).toBe('新群名')
    expect(chat.sessions[0].peer.nickname).toBe('新群名')
  })

  it('拉人入群后成员数取服务端返回值，不是本地 +1', async () => {
    const chat = useChatStore()
    mocks.fetchSessions.mockResolvedValue([groupSession('g1', '群', 2)])
    await chat.loadSessions()

    mocks.addGroupMember.mockResolvedValue({
      id: 'g1',
      name: '群',
      avatar: 'default',
      memberCount: 5,
      ownerId: 'me'
    })
    await chat.addGroupMember('g1', 'p9')

    expect(chat.groups['g1'].memberCount).toBe(5)
    expect(chat.sessions[0].memberCount).toBe(5)
  })

  it('换群头像后群表同步（与改名走同一条 PATCH）', async () => {
    const chat = useChatStore()
    mocks.updateGroup.mockResolvedValue({
      id: 'g1',
      name: '群',
      avatar: '/uploads/g.png',
      memberCount: 2,
      ownerId: 'me'
    })

    await chat.changeGroupAvatar('g1', '/uploads/g.png')

    expect(chat.groups['g1'].avatar).toBe('/uploads/g.png')
    expect(mocks.updateGroup).toHaveBeenCalledWith('tok', 'g1', { avatar: '/uploads/g.png' })
  })

  it('退群后该群的本地状态全部清除', async () => {
    const chat = useChatStore()
    mocks.fetchSessions.mockResolvedValue([groupSession('g1', '群', 2)])
    await chat.loadSessions()
    chat.unreadCounts['g1'] = 3
    mocks.leaveGroup.mockResolvedValue({ id: 'g1', name: '群', memberCount: 1, ownerId: 'other' })

    await chat.leaveGroup('g1')

    expect(chat.sessions.map((s) => s.peer.userid)).not.toContain('g1')
    expect(chat.unreadCounts['g1']).toBeUndefined()
    expect(chat.groups['g1']).toBeUndefined()
  })
})

describe('消息撤回', () => {
  // 一条自己已发出的、已入库的消息（撤回入口只对此显示）
  const ownMessage = {
    seq: 0,
    id: 'm9',
    fromSelf: true,
    content: '打错的原文',
    msgType: 'text',
    timestamp: 1000,
    acked: true
  }

  it('撤回后本地消息换成提示文案，且未读数不变', async () => {
    const chat = useChatStore()
    chat.conversations[OTHER] = [{ ...ownMessage }]
    chat.unreadCounts[OTHER] = 2
    mocks.recallMessage.mockResolvedValue({ id: 'm9', recalledAt: 1 })

    await chat.recallMessage(OTHER, 'm9')

    const item = chat.conversations[OTHER][0]
    expect(item.recalled).toBe(true)
    expect(item.content).toBe('你撤回了一条消息')
    expect(item.content).not.toContain('打错的原文')
    // 撤回是软删，消息条数不变 → 未读数不变
    expect(chat.unreadCounts[OTHER]).toBe(2)
  })

  it('收到撤回帧时更新气泡与会话预览', async () => {
    const chat = useChatStore()
    mocks.fetchSessions.mockResolvedValue([directSession(OTHER, 0)])
    await chat.loadSessions()
    chat.conversations[OTHER] = [{ ...ownMessage, fromSelf: false, id: 'm5', content: '原文' }]

    chat.connect()
    FakeWebSocket.last!.emit({
      type: 'chatMessageRecalled',
      data: { id: 'm5', recipientType: 'user', recipientId: OTHER, content: 'P1撤回了一条消息' }
    })

    expect(chat.conversations[OTHER][0].recalled).toBe(true)
    expect(chat.conversations[OTHER][0].content).toBe('P1撤回了一条消息')
    expect(chat.sessions[0].lastMessage.recalled).toBe(true)
    expect(chat.sessions[0].lastMessage.content).toBe('P1撤回了一条消息')
  })

  it('没加载过的会话收到撤回帧也要更新预览（否则界面仍显示原文）', async () => {
    const chat = useChatStore()
    mocks.fetchSessions.mockResolvedValue([directSession(OTHER, 0)])
    await chat.loadSessions()

    chat.connect()
    FakeWebSocket.last!.emit({
      type: 'chatMessageRecalled',
      data: { id: 'm7', recipientType: 'user', recipientId: OTHER, content: 'P1撤回了一条消息' }
    })

    expect(chat.sessions[0].lastMessage.content).toBe('P1撤回了一条消息')
  })
})

describe('消息搜索', () => {
  // 一条命中结果：单聊里对方发来的
  const hit = {
    id: 'm1',
    content: '密码是多少',
    msgType: 'text',
    fromSelf: false,
    createdAt: 1700000000,
    senderNickname: 'P1',
    recipientType: 'user' as const,
    recipientId: OTHER,
    recipientName: 'P1'
  }

  it('结果进 searchResults，不污染会话列表', async () => {
    const chat = useChatStore()
    mocks.fetchSessions.mockResolvedValue([directSession(OTHER, 0)])
    await chat.loadSessions()
    mocks.searchMessages.mockResolvedValue({ hasMore: false, messages: [hit] })

    await chat.searchMessages('密码')

    expect(chat.searchResults).toHaveLength(1)
    expect(chat.searchResults[0].content).toBe('密码是多少')
    // 搜索结果是「消息」列表：混进 sessions 会让未读与置顶逻辑长出各种特例
    expect(chat.sessions).toHaveLength(1)
    expect(chat.sessions[0].peer.userid).toBe(OTHER)
  })

  it('清空关键词即清空结果（不留上一次的）', async () => {
    const chat = useChatStore()
    mocks.searchMessages.mockResolvedValue({ hasMore: false, messages: [hit] })
    await chat.searchMessages('密码')
    expect(chat.searchResults).toHaveLength(1)

    await chat.searchMessages('')

    expect(chat.searchResults).toEqual([])
    expect(chat.searchKeyword).toBe('')
    // 空关键词不发请求
    expect(mocks.searchMessages).toHaveBeenCalledTimes(1)
  })

  it('输入防抖：连打只发一次请求', async () => {
    vi.useFakeTimers()
    const chat = useChatStore()
    mocks.searchMessages.mockResolvedValue({ hasMore: false, messages: [] })

    chat.searchSoon('密')
    chat.searchSoon('密码')
    chat.searchSoon('密码是')
    await vi.advanceTimersByTimeAsync(400)

    expect(mocks.searchMessages).toHaveBeenCalledTimes(1)
    expect(mocks.searchMessages).toHaveBeenCalledWith('tok', '密码是', { limit: 30 })
  })
})

describe('鉴权失效', () => {
  it('接口返回 401 时清除本地登录态', async () => {
    const chat = useChatStore()
    const auth = useAuthStore()
    mocks.fetchSessions.mockRejectedValue(new ApiError(401, 'token 无效'))

    await chat.loadSessions()

    expect(auth.token).toBeNull()
    expect(localStorage.getItem('chat.token')).toBeNull()
  })
})
