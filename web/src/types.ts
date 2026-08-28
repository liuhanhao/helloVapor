// 用户信息（服务端 /chat/me 返回，不含密码散列）
export interface UserInfo {
  id: string
  avatar: string
  nickname: string
  account: string
}

// 聊天窗口中的一条消息
export interface MessageItem {
  // 本地自增序号，用作列表 key
  seq: number
  // 服务端消息 id（乐观渲染时暂缺，收到确认后补上），用于与历史消息对齐去重
  id?: string
  // 是否由当前用户发出（决定气泡左右）
  fromSelf: boolean
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

// 会话列表中的联系人（对方用户）身份
export interface SessionPeer {
  userid: string
  username: string
  nickname: string
  avatar: string
}

// 会话列表项：联系人 + 最后一条消息
export interface SessionSummary {
  peer: SessionPeer
  lastMessage: {
    content: string
    msgType: string
    fromSelf: boolean
    // 毫秒时间戳（0 表示尚无消息）
    createdAt: number
  }
}

// 历史消息接口返回的单条消息
export interface HistoryMessage {
  id?: string
  content: string
  msgType: string
  fromSelf: boolean
  // 毫秒时间戳
  createdAt: number
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
