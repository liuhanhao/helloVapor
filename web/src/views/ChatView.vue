<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { AUDIO_UPLOAD, IMAGE_UPLOAD, VIDEO_UPLOAD } from '../config'
import { useAuthStore } from '../stores/auth'
import { useChatStore } from '../stores/chat'
import type { MessageItem, SessionSummary } from '../types'

const auth = useAuthStore()
const chat = useChatStore()
const router = useRouter()

// 媒体类型与上传预检规则（与服务端 UploadRules 一致），label 用于错误提示
type MediaKind = 'image' | 'audio' | 'video'
const MEDIA_RULES: Record<MediaKind, { extensions: string[]; maxMB: number; label: string }> = {
  image: { ...IMAGE_UPLOAD, label: '图片' },
  audio: { ...AUDIO_UPLOAD, label: '音频' },
  video: { ...VIDEO_UPLOAD, label: '视频' }
}

const newPeerId = ref('')
const draft = ref('')
const sendFailed = ref(false)
const messageList = ref<HTMLElement | null>(null)
const imageInput = ref<HTMLInputElement | null>(null)
const audioInput = ref<HTMLInputElement | null>(null)
const videoInput = ref<HTMLInputElement | null>(null)
// 媒体发送错误（预检或服务端拒绝）提示
const uploadError = ref('')
// 原图查看浮层当前显示的图片地址
const lightboxUrl = ref<string | null>(null)

const currentMessages = computed(() =>
  chat.currentPeerId ? chat.conversations[chat.currentPeerId] ?? [] : []
)
const peerTitle = computed(() =>
  chat.currentPeerId ? chat.peerNames[chat.currentPeerId] ?? chat.currentPeerId : ''
)
const hasMore = computed(() =>
  chat.currentPeerId ? !!chat.hasMoreHistory[chat.currentPeerId] : false
)

function sessionName(s: SessionSummary): string {
  return s.peer.nickname || s.peer.username || s.peer.userid
}

function previewText(msgType: string, content: string): string {
  switch (msgType) {
    case 'image':
      return '[图片]'
    case 'audio':
      return '[音频]'
    case 'video':
      return '[视频]'
    default:
      return content
  }
}

function sessionPreview(s: SessionSummary): string {
  if (!s.lastMessage.createdAt) return '暂无消息'
  return `${s.lastMessage.fromSelf ? '我：' : ''}${previewText(s.lastMessage.msgType, s.lastMessage.content)}`
}

// 是否媒体消息（图片/音频/视频），决定气泡布局与内边距
function isMedia(msg: MessageItem): boolean {
  return msg.msgType === 'image' || msg.msgType === 'audio' || msg.msgType === 'video'
}

function formatTime(ts: number): string {
  const d = new Date(ts)
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`
}

// 会话列表时间：当天显示时分，同年显示月日，更早显示年月日
function sessionTime(ts: number): string {
  if (!ts) return ''
  const d = new Date(ts)
  const now = new Date()
  const pad = (n: number) => String(n).padStart(2, '0')
  if (d.toDateString() === now.toDateString()) {
    return `${pad(d.getHours())}:${pad(d.getMinutes())}`
  }
  if (d.getFullYear() === now.getFullYear()) {
    return `${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
  }
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

function openSession(s: SessionSummary) {
  chat.openConversation(s.peer.userid, sessionName(s))
}

function startConversation() {
  const peerId = newPeerId.value.trim()
  if (!peerId) return
  chat.openConversation(peerId)
  newPeerId.value = ''
  sendFailed.value = false
}

function handleSend() {
  const content = draft.value.trim()
  if (!content) return
  const ok = chat.sendText(content)
  if (ok) {
    draft.value = ''
    sendFailed.value = false
  } else {
    sendFailed.value = true
  }
}

// 媒体消息的展示地址：上传完成前的本地预览（blob URL），或服务端文件 URL。
// 对图片为预览地址，对音频/视频为可直接播放的地址
function mediaSrc(msg: MessageItem): string | null {
  return msg.localUrl || msg.content || null
}

function openLightbox(msg: MessageItem) {
  const src = mediaSrc(msg)
  if (src && !msg.uploading) lightboxUrl.value = src
}

// 选择本地媒体文件并发送：先本地预检（类型/大小），再交由 store 走上传 → WS 发出流程
async function onMediaChosen(e: Event, kind: MediaKind) {
  const input = e.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = '' // 允许再次选择同一文件
  if (!file) return

  uploadError.value = ''
  const rule = MEDIA_RULES[kind]
  const ext = file.name.includes('.') ? file.name.split('.').pop()!.toLowerCase() : ''
  if (!rule.extensions.includes(ext)) {
    uploadError.value = `不支持的${rule.label}格式 ${ext ? '.' + ext : '（无扩展名）'}，仅支持 ${rule.extensions.join('/')}`
    return
  }
  if (file.size > rule.maxMB * 1024 * 1024) {
    uploadError.value = `${rule.label}大小不能超过 ${rule.maxMB} MB（当前 ${(file.size / 1024 / 1024).toFixed(1)} MB）`
    return
  }

  const err = await chat.sendMedia(file, kind)
  if (err) uploadError.value = `${rule.label}发送失败：${err}`
}

async function scrollToBottom() {
  await nextTick()
  messageList.value?.scrollTo({ top: messageList.value.scrollHeight })
}

// 分页加载更早的历史：保持滚动位置不跳动
async function loadOlder() {
  const el = messageList.value
  const peerId = chat.currentPeerId
  if (!el || !peerId) return
  const prevHeight = el.scrollHeight
  const prevTop = el.scrollTop
  await chat.loadOlder(peerId)
  await nextTick()
  el.scrollTop = el.scrollHeight - prevHeight + prevTop
}

// 最新一条消息变化（新消息/切换会话）时滚动到底部；前插历史不动位置
watch(
  () => currentMessages.value[currentMessages.value.length - 1]?.seq,
  () => {
    scrollToBottom()
  }
)
watch(
  () => chat.currentPeerId,
  () => {
    scrollToBottom()
  }
)

async function copyMyId() {
  if (!auth.user) return
  try {
    await navigator.clipboard.writeText(auth.user.id)
  } catch {
    // 剪贴板不可用时忽略
  }
}

function handleLogout() {
  chat.disconnect()
  chat.reset()
  auth.logout()
  router.replace({ name: 'login' })
}

onMounted(() => {
  chat.connect()
  void chat.loadSessions()
})
onUnmounted(() => {
  chat.disconnect()
})
</script>

<template>
  <div class="chat-page">
    <header class="topbar">
      <span class="brand">VaporChat</span>
      <span :class="['ws-status', { online: chat.connected }]">
        {{ chat.connected ? '实时连接正常' : '连接断开' }}
      </span>
      <div class="me">
        <span class="nickname">{{ auth.user?.nickname }}</span>
        <button class="copy-id" title="复制我的 userid 发给对方" @click="copyMyId">
          我的 ID：{{ auth.user?.id }}
        </button>
      </div>
      <button class="logout" @click="handleLogout">退出</button>
    </header>

    <div class="chat-body">
      <aside class="sidebar">
        <div class="new-chat">
          <input
            v-model="newPeerId"
            placeholder="输入对方 userid 发起会话"
            @keyup.enter="startConversation"
          />
          <button @click="startConversation">开始</button>
        </div>

        <p v-if="chat.sessionsLoading" class="sidebar-tip">会话加载中…</p>
        <p v-else-if="chat.sessionsError" class="sidebar-error">{{ chat.sessionsError }}</p>
        <p v-else-if="chat.sessions.length === 0" class="sidebar-tip">
          还没有会话，输入对方 userid 开始聊天
        </p>
        <ul v-else class="session-list">
          <li
            v-for="s in chat.sessions"
            :key="s.peer.userid"
            :class="{ active: s.peer.userid === chat.currentPeerId }"
            @click="openSession(s)"
          >
            <div class="avatar">{{ sessionName(s).slice(0, 1).toUpperCase() }}</div>
            <div class="session-info">
              <div class="session-top">
                <span class="name">{{ sessionName(s) }}</span>
                <span class="time">{{ sessionTime(s.lastMessage.createdAt) }}</span>
              </div>
              <div class="preview">{{ sessionPreview(s) }}</div>
            </div>
          </li>
        </ul>
      </aside>

      <main v-if="chat.currentPeerId" class="chat-main">
        <div class="chat-header">与 {{ peerTitle }} 的会话</div>

        <div ref="messageList" class="message-list">
          <div class="load-more">
            <button v-if="hasMore" :disabled="chat.historyLoading" @click="loadOlder">
              {{ chat.historyLoading ? '加载中…' : '加载更早的消息' }}
            </button>
            <span v-else-if="currentMessages.length > 0" class="no-more">没有更早的消息了</span>
          </div>
          <p v-if="chat.historyError" class="empty">{{ chat.historyError }}</p>
          <p v-if="chat.historyLoading && currentMessages.length === 0" class="empty">
            历史消息加载中…
          </p>
          <p v-else-if="currentMessages.length === 0" class="empty">
            还没有消息，发送第一条吧
          </p>
          <div
            v-for="msg in currentMessages"
            :key="msg.seq"
            :class="['message-row', msg.fromSelf ? 'self' : 'peer']"
          >
            <div :class="['bubble', isMedia(msg) ? 'media-bubble' : '']">
              <template v-if="msg.msgType === 'image'">
                <img
                  v-if="mediaSrc(msg)"
                  :class="['image-thumb', { uploading: msg.uploading, failed: !!msg.error }]"
                  :src="mediaSrc(msg)!"
                  :alt="msg.error ? '图片发送失败' : '图片消息'"
                  @click="openLightbox(msg)"
                />
                <span v-else class="media-broken">图片不可用</span>
                <span v-if="msg.uploading" class="media-hint">图片上传中…</span>
                <span v-else-if="msg.error" class="media-hint failed">发送失败：{{ msg.error }}</span>
              </template>
              <template v-else-if="msg.msgType === 'audio'">
                <audio
                  v-if="mediaSrc(msg)"
                  :class="['audio-player', { uploading: msg.uploading, failed: !!msg.error }]"
                  controls
                  preload="metadata"
                  :src="mediaSrc(msg)!"
                ></audio>
                <span v-else class="media-broken">音频不可用</span>
                <span v-if="msg.uploading" class="media-hint">音频上传中…</span>
                <span v-else-if="msg.error" class="media-hint failed">发送失败：{{ msg.error }}</span>
              </template>
              <template v-else-if="msg.msgType === 'video'">
                <video
                  v-if="mediaSrc(msg)"
                  :class="['video-player', { uploading: msg.uploading, failed: !!msg.error }]"
                  controls
                  preload="metadata"
                  :src="mediaSrc(msg)!"
                ></video>
                <span v-else class="media-broken">视频不可用</span>
                <span v-if="msg.uploading" class="media-hint">视频上传中…</span>
                <span v-else-if="msg.error" class="media-hint failed">发送失败：{{ msg.error }}</span>
              </template>
              <span v-else class="content">{{ msg.content }}</span>
              <span class="meta">
                {{ formatTime(msg.timestamp) }}
                <span v-if="msg.fromSelf && !msg.acked && !msg.uploading && !msg.error" class="pending">
                  发送中
                </span>
                <span v-if="msg.fromSelf && msg.error" class="pending failed">发送失败</span>
              </span>
            </div>
          </div>
        </div>

        <div class="input-area">
          <p v-if="sendFailed" class="error">发送失败：实时连接未就绪，请稍后重试</p>
          <p v-if="uploadError" class="error">{{ uploadError }}</p>
          <div class="input-toolbar">
            <input
              ref="imageInput"
              type="file"
              accept="image/jpeg,image/png,image/gif,image/webp"
              hidden
              @change="onMediaChosen($event, 'image')"
            />
            <input
              ref="audioInput"
              type="file"
              accept=".mp3,.m4a,.aac,.wav,audio/mpeg,audio/mp4,audio/aac,audio/x-m4a,audio/wav,audio/x-wav"
              hidden
              @change="onMediaChosen($event, 'audio')"
            />
            <input
              ref="videoInput"
              type="file"
              accept=".mp4,.mov,video/mp4,video/quicktime"
              hidden
              @change="onMediaChosen($event, 'video')"
            />
            <button class="attach" title="发送图片" @click="imageInput?.click()">图片</button>
            <button class="attach" title="发送音频" @click="audioInput?.click()">音频</button>
            <button class="attach" title="发送视频" @click="videoInput?.click()">视频</button>
          </div>
          <textarea
            v-model="draft"
            rows="2"
            placeholder="输入消息，Enter 发送"
            @keyup.enter.exact.prevent="handleSend"
          ></textarea>
          <button class="send" @click="handleSend">发送</button>
        </div>
      </main>

      <main v-else class="chat-main empty-main">
        <p>从左侧选择会话，或输入对方 userid 开始聊天</p>
      </main>
    </div>

    <!-- 原图查看浮层：点击任意处关闭 -->
    <div v-if="lightboxUrl" class="lightbox" @click="lightboxUrl = null">
      <img :src="lightboxUrl" alt="原图" @click.stop />
      <span class="lightbox-tip">点击任意处关闭</span>
    </div>
  </div>
</template>

<style scoped>
.chat-page {
  height: 100%;
  display: flex;
  flex-direction: column;
  max-width: 1000px;
  margin: 0 auto;
  background: #fff;
  box-shadow: 0 0 24px rgba(0, 0, 0, 0.06);
}

.topbar {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 16px;
  border-bottom: 1px solid #e5e6eb;
}

.brand {
  font-weight: 700;
  font-size: 16px;
}

.ws-status {
  font-size: 12px;
  color: #d4380d;
}

.ws-status.online {
  color: #389e0d;
}

.me {
  margin-left: auto;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 2px;
}

.nickname {
  font-weight: 600;
}

.copy-id {
  border: none;
  background: none;
  color: #86909c;
  font-size: 12px;
  max-width: 320px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.logout {
  border: 1px solid #d9d9d9;
  background: #fff;
  border-radius: 6px;
  padding: 6px 12px;
}

.chat-body {
  flex: 1;
  display: flex;
  min-height: 0;
}

.sidebar {
  width: 260px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  min-height: 0;
  border-right: 1px solid #e5e6eb;
  background: #fcfcfd;
}

.new-chat {
  display: flex;
  gap: 8px;
  padding: 10px;
  border-bottom: 1px solid #e5e6eb;
}

.new-chat input {
  flex: 1;
  min-width: 0;
  padding: 8px 10px;
  border: 1px solid #d9d9d9;
  border-radius: 6px;
  outline: none;
  font-size: 12px;
}

.new-chat button {
  border: none;
  background: #165dff;
  color: #fff;
  border-radius: 6px;
  padding: 8px 12px;
  font-size: 12px;
  flex-shrink: 0;
}

.sidebar-tip,
.sidebar-error {
  padding: 16px 12px;
  color: #86909c;
  font-size: 13px;
  text-align: center;
}

.sidebar-error {
  color: #d4380d;
}

.session-list {
  flex: 1;
  overflow-y: auto;
  list-style: none;
  margin: 0;
  padding: 0;
}

.session-list li {
  display: flex;
  gap: 10px;
  padding: 12px;
  cursor: pointer;
  border-bottom: 1px solid #f2f3f5;
}

.session-list li:hover {
  background: #f2f3f5;
}

.session-list li.active {
  background: #e8f3ff;
}

.avatar {
  width: 40px;
  height: 40px;
  flex-shrink: 0;
  border-radius: 50%;
  background: #165dff;
  color: #fff;
  font-weight: 600;
  display: flex;
  align-items: center;
  justify-content: center;
}

.session-info {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.session-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.session-top .name {
  font-weight: 600;
  font-size: 14px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.session-top .time {
  font-size: 11px;
  color: #86909c;
  flex-shrink: 0;
}

.preview {
  font-size: 12px;
  color: #86909c;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.chat-main {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
  min-width: 0;
}

.empty-main {
  align-items: center;
  justify-content: center;
  color: #86909c;
}

.chat-header {
  padding: 10px 16px;
  font-weight: 600;
  border-bottom: 1px solid #f2f3f5;
}

.message-list {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 12px;
  background: #f7f8fa;
}

.empty {
  color: #86909c;
  text-align: center;
}

.load-more {
  text-align: center;
}

.load-more button {
  border: 1px solid #d9d9d9;
  background: #fff;
  border-radius: 6px;
  padding: 4px 12px;
  font-size: 12px;
  color: #165dff;
  cursor: pointer;
}

.load-more button:disabled {
  color: #86909c;
  cursor: not-allowed;
}

.no-more {
  font-size: 12px;
  color: #c9cdd4;
}

.message-row {
  display: flex;
}

.message-row.self {
  justify-content: flex-end;
}

.bubble {
  max-width: 65%;
  padding: 8px 12px;
  border-radius: 10px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.peer .bubble {
  background: #fff;
  border: 1px solid #e5e6eb;
}

.self .bubble {
  background: #95ec69;
}

.content {
  white-space: pre-wrap;
  word-break: break-word;
}

.meta {
  font-size: 11px;
  color: #86909c;
  align-self: flex-end;
}

.pending {
  color: #d4380d;
  margin-left: 4px;
}

.pending.failed {
  color: #d4380d;
}

/* 媒体消息气泡（图片/音频/视频共用） */
.media-bubble {
  padding: 4px;
}

.image-thumb {
  display: block;
  max-width: 220px;
  max-height: 220px;
  border-radius: 8px;
  cursor: zoom-in;
  object-fit: contain;
}

.image-thumb.uploading {
  opacity: 0.5;
  cursor: default;
}

.image-thumb.failed {
  filter: grayscale(0.8);
  opacity: 0.7;
}

.media-broken {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 160px;
  height: 100px;
  background: #f2f3f5;
  border-radius: 8px;
  color: #86909c;
  font-size: 12px;
}

.media-hint {
  font-size: 12px;
  color: #86909c;
}

.media-hint.failed {
  color: #d4380d;
}

/* 音频消息播放器：聊天窗口内直接播放 */
.audio-player {
  display: block;
  width: 260px;
  height: 40px;
}

.audio-player.uploading {
  opacity: 0.6;
}

.audio-player.failed {
  filter: grayscale(0.8);
  opacity: 0.7;
}

/* 视频消息播放器：聊天窗口内直接播放 */
.video-player {
  display: block;
  max-width: 320px;
  max-height: 240px;
  border-radius: 8px;
  background: #000;
}

.video-player.uploading {
  opacity: 0.5;
}

.video-player.failed {
  filter: grayscale(0.8);
  opacity: 0.7;
}

/* 原图查看浮层 */
.lightbox {
  position: fixed;
  inset: 0;
  z-index: 100;
  background: rgba(0, 0, 0, 0.8);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  cursor: zoom-out;
}

.lightbox img {
  max-width: 92vw;
  max-height: 88vh;
  border-radius: 4px;
  object-fit: contain;
}

.lightbox-tip {
  color: rgba(255, 255, 255, 0.75);
  font-size: 12px;
}

.input-area {
  border-top: 1px solid #e5e6eb;
  padding: 10px 16px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.input-toolbar {
  display: flex;
  gap: 8px;
}

.attach {
  border: 1px solid #d9d9d9;
  background: #fff;
  color: #165dff;
  border-radius: 6px;
  padding: 4px 12px;
  font-size: 12px;
  cursor: pointer;
}

.attach:hover {
  border-color: #165dff;
}

.input-area .error {
  color: #d4380d;
  font-size: 12px;
}

.input-area textarea {
  resize: none;
  border: 1px solid #d9d9d9;
  border-radius: 6px;
  padding: 8px 12px;
  outline: none;
  font-family: inherit;
}

.send {
  align-self: flex-end;
  border: none;
  background: #165dff;
  color: #fff;
  border-radius: 6px;
  padding: 8px 20px;
}
</style>
