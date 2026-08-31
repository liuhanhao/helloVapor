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
  }
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
}

// 群：只取界面需要的字段（服务端 /chat/groups 返回的字段子集）
export interface GroupSummary {
  id: string
  name: string
  memberCount: number
}

// 群成员（成员列表项）
export interface GroupMember {
  userid: string
  nickname: string
  username: string
}

// 历史消息分页结果（messages 按时间正序）
export interface HistoryPage {
  messages: HistoryMessage[]
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
