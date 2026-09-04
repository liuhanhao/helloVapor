// 用户信息（服务端 /chat/me 返回，不含密码散列）
export interface UserInfo {
  id: string
  avatar: string
  nickname: string
  account: string
}

// 会话形态：单聊（与一位联系人） / 群聊（在一个群内）
export type SessionKind = 'direct' | 'group'

// 聊天窗口中的一条消息
export interface MessageItem {
  // 本地自增序号，用作列表 key
  seq: number
  // 服务端消息 id（乐观渲染时暂缺，收到确认后补上），用于与历史消息对齐去重
  id?: string
  // 是否由当前用户发出（决定气泡左右）
  fromSelf: boolean
  // 发送者昵称：群聊气泡靠它显示是谁说的（单聊与自己的消息不显示）
  senderNickname?: string
  // 发送者头像：历史消息取回查后的 senderAvatar（跟随当前值），
  // 实时收到的消息取帧里的快照——此时服务端还没回查
  senderAvatar?: string
  content: string
  // 消息类型；服务端缺省按 text 处理
  msgType: string
  // 毫秒时间戳
  timestamp: number
  // 是否已收到服务端确认（chatMessageAck）
  acked: boolean
  // 媒体消息：上传完成前的本地预览地址（blob URL），上传成功后由服务端 URL 接替
  localUrl?: string
  // 媒体文件是否正在上传（此时尚未经 WS 发出，也不参与 ack 匹配）
  uploading?: boolean
  // 发送失败的错误信息（上传被服务端拒绝或实时连接断开），存在时气泡标记失败态
  error?: string
  // 是否已被撤回：content 此时是提示文案，渲染成居中灰色提示行而非气泡
  recalled?: boolean
}

// 会话列表项中的收件主体身份：单聊为联系人（对方用户），群聊为群
// （群聊时 userid 是群 id、nickname 是群名、avatar 是群头像，username 无意义为空串）
// 字段名沿用服务端 JSON 的 peer
export interface SessionPeer {
  userid: string
  username: string
  nickname: string
  avatar: string
}

// 会话列表项：收件主体 + 最后一条消息
export interface SessionSummary {
  // 会话形态：单聊与群聊条目混排在同一列表里，读 peer 前先看 kind
  kind: SessionKind
  peer: SessionPeer
  lastMessage: {
    content: string
    msgType: string
    fromSelf: boolean
    // 毫秒时间戳（0 表示尚无消息）
    createdAt: number
    // 最后一条是否已被撤回：content 此时是提示文案，不含原文
    recalled: boolean
  }
  // 该会话我还没读的消息条数，由服务端按已读位点算出（前端不持久化）
  unreadCount: number
  // 群成员数，仅群聊条目有值
  memberCount?: number
}

// 历史消息接口返回的单条消息
export interface HistoryMessage {
  id?: string
  content: string
  msgType: string
  fromSelf: boolean
  // 毫秒时间戳
  createdAt: number
  // 发送者昵称：群聊气泡靠它显示是谁说的（单聊也一并返回，前端无需分支取数）
  senderNickname: string
  // 发送者头像：已按发送者回查 users 表（跟随当前值，不是发送时的快照）
  senderAvatar: string
  // 是否已被撤回：content 此时是提示文案，不含原文
  recalled: boolean
}

// 群：只取界面需要的字段（服务端 /chat/groups 返回的字段子集）
export interface GroupSummary {
  id: string
  name: string
  // 群头像 URL；'default' 表示还没设置，由 Avatar 回退群名首字母
  avatar: string
  memberCount: number
  // 创建者 userid：界面靠它决定「改群名」入口是否可见（服务端已定仅创建者可改群信息）
  ownerId: string
}

// 群成员（成员列表项）
export interface GroupMember {
  userid: string
  nickname: string
  username: string
  // 头像：服务端按 userId 回查 users 表，跟随当前值
  avatar: string
}

// 历史消息分页结果（messages 按时间正序）
export interface HistoryPage {
  messages: HistoryMessage[]
  hasMore: boolean
}

// 搜索结果项：除消息本身，还带「这条消息在哪个会话里说的」，前端据此跳转与显示
export interface MessageSearchItem {
  id: string
  content: string
  msgType: string
  fromSelf: boolean
  // 毫秒时间戳
  createdAt: number
  senderNickname: string
  // 定位用：点开结果要跳到这个收件主体
  recipientType: 'user' | 'group'
  recipientId: string
  // 展示用：群名或对方昵称
  recipientName: string
  // 展示用：群头像或对方头像，与会话列表保持一致
  recipientAvatar: string
}

// 搜索结果（messages 按时间倒序）。这是「消息」列表，不是会话列表
export interface MessageSearchResult {
  messages: MessageSearchItem[]
  hasMore: boolean
}

// WebSocket 消息结构（沿用现有 type / data.mine / data.to）
export interface ChatPayload {
  type: string
  data: {
    // 服务端消息 id 与时间戳（Unix 秒），随推送下发
    id?: string
    timestamp?: number
    mine: {
      avatar: string
      content: string
      mine: boolean
      userid: string
      username: string
      nickname: string
      msgType?: string
    }
    to: {
      avatar: string
      userid: string
      username: string
      nickname: string
      // 收件主体类型：user（缺省） / group；群聊时 userid 位置填群 id
      type?: 'user' | 'group'
    }
  }
}

// 服务端确认回执（chatMessageAck）
export interface ChatAck {
  type: string
  data?: {
    id?: string
    timestamp?: number
    content?: string
  }
}

// 服务端拒收消息时下发的错误帧（chatMessageError，如发消息时已不是群成员）
export interface ChatErrorMessage {
  type: string
  data?: {
    reason?: string
  }
}

// 撤回通知（chatMessageRecalled）：有人撤回了消息，客户端据此更新气泡与会话预览
export interface ChatRecalledPayload {
  type: string
  data?: {
    id?: string
    // 收件主体类型：user / group
    recipientType?: 'user' | 'group'
    // 要更新哪个会话：群为群 id，单聊为**发送者**（对接收方而言这个会话的收件主体就是对方）
    recipientId?: string
    // 服务端生成的提示文案（如「张三撤回了一条消息」）
    content?: string
  }
}
