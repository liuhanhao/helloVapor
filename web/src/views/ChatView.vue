<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { AUDIO_UPLOAD, IMAGE_UPLOAD, VIDEO_UPLOAD } from '../config'
import { describeError } from '../api'
import { writeClipboard } from '../clipboard'
import { useAuthStore } from '../stores/auth'
import { useChatStore } from '../stores/chat'
import type { MessageItem, SessionSummary } from '../types'
import EmojiPanel from '../components/EmojiPanel.vue'
import CreateGroupDialog from '../components/CreateGroupDialog.vue'
import GroupInfoDialog from '../components/GroupInfoDialog.vue'
import ProfileCard from '../components/ProfileCard.vue'
// 图标取自 koboyo.com/icons（SVG，不引入图标库依赖）
import smileIcon from '../assets/icons/smile.svg'
import searchIcon from '../assets/icons/magnifying-glass.svg'

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
// 查询用户并发起新会话的中间态与错误提示
const userSearching = ref(false)
const newChatError = ref('')
const messageList = ref<HTMLElement | null>(null)
const draftInput = ref<HTMLTextAreaElement | null>(null)
// emoji 面板开关与容器（点击容器外部或按 Esc 关闭）
const emojiOpen = ref(false)
const emojiWrap = ref<HTMLElement | null>(null)
const imageInput = ref<HTMLInputElement | null>(null)
const audioInput = ref<HTMLInputElement | null>(null)
const videoInput = ref<HTMLInputElement | null>(null)
// 媒体发送错误（预检或服务端拒绝）提示
const uploadError = ref('')
// 撤回失败的原因（撤回是用户主动点的，静默失败会让人以为撤掉了其实没有）
const recallError = ref('')
// 原图查看浮层当前显示的图片地址
const lightboxUrl = ref<string | null>(null)
// 复制 userid 的结果提示（2 秒后自动消失）
const copyNotice = ref('')
const copyNoticeFailed = ref(false)
let copyNoticeTimer: number | undefined
// 建群与群信息弹窗
const createGroupOpen = ref(false)
const groupInfoOpen = ref(false)
// 联系人资料卡（单聊顶栏点昵称打开；群成员的资料卡由群信息弹窗自己管）
const contactProfile = ref<{ userid: string; nickname: string; username: string } | null>(null)

const currentMessages = computed(() =>
  chat.currentRecipientId ? chat.conversations[chat.currentRecipientId] ?? [] : []
)
const peerTitle = computed(() =>
  chat.currentRecipientId
    ? chat.recipientNames[chat.currentRecipientId] ?? chat.currentRecipientId
    : ''
)
const hasMore = computed(() =>
  chat.currentRecipientId ? !!chat.hasMoreHistory[chat.currentRecipientId] : false
)
// 当前会话是不是群聊：决定消息发往哪里、气泡是否显示发送者昵称
const currentIsGroup = computed(() =>
  chat.currentRecipientId ? chat.isGroup(chat.currentRecipientId) : false
)
const currentMemberCount = computed(
  () => chat.sessions.find((s) => s.peer.userid === chat.currentRecipientId)?.memberCount ?? 0
)

// 单聊顶栏的昵称可点开联系人资料；群聊走「群信息」里的成员列表。
// 数据取自会话列表（已带 userid / 账号 / 昵称），不额外发请求
function openContactProfile() {
  const s = chat.sessions.find((x) => x.peer.userid === chat.currentRecipientId)
  if (!s) return
  contactProfile.value = {
    userid: s.peer.userid,
    nickname: s.peer.nickname || s.peer.username || s.peer.userid,
    username: s.peer.username
  }
}

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

// 未读条数：服务端按已读位点算出，本地只在收到非当前会话消息时乐观 +1
function unreadCount(s: SessionSummary): number {
  return chat.unreadCounts[s.peer.userid] ?? 0
}

// 角标文案：超过 99 显示「99+」，避免大群刷屏时撑破条目
function unreadLabel(s: SessionSummary): string {
  const n = unreadCount(s)
  return n > 99 ? '99+' : String(n)
}

// 是否媒体消息（图片/音频/视频），决定气泡布局与内边距
function isMedia(msg: MessageItem): boolean {
  return msg.msgType === 'image' || msg.msgType === 'audio' || msg.msgType === 'video'
}

// 只有自己已发出、已入库且未撤回的消息可撤：
// 缺 acked（还在发送中）或 id（服务端还没确认）时接口无从定位，不显示入口
function canRecall(msg: MessageItem): boolean {
  return msg.fromSelf && msg.acked && !!msg.id && !msg.recalled
}

async function recall(msg: MessageItem) {
  const recipientId = chat.currentRecipientId
  if (!msg.id || !recipientId) return
  recallError.value = ''
  try {
    await chat.recallMessage(recipientId, msg.id)
  } catch (e) {
    recallError.value = describeError(e, '撤回失败，请稍后重试')
  }
}

// 群聊里别人发的消息标出是谁说的；单聊只有两个人、自己的消息不必重复署名
function showSenderName(msg: MessageItem): boolean {
  return currentIsGroup.value && !msg.fromSelf && !!msg.senderNickname
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
  chat.openConversation(s.peer.userid, s.peer, s.kind)
}

// 发起新会话：按输入的账号或用户 ID 查询用户，查到后建立会话条目并打开
// （查不到、查到自己、请求失败都给出明确提示）
async function startConversation() {
  const keyword = newPeerId.value.trim()
  if (!keyword || userSearching.value) return
  userSearching.value = true
  newChatError.value = ''
  try {
    const matched = await chat.searchUser(keyword)
    const target = matched[0]
    if (!target) {
      newChatError.value = '未找到该用户，请检查账号或用户 ID 是否正确'
      return
    }
    if (target.id === auth.user?.id) {
      newChatError.value = '这是你自己，请输入对方的账号或用户 ID'
      return
    }
    chat.openUserConversation(target)
    newPeerId.value = ''
    sendFailed.value = false
  } catch (e) {
    newChatError.value = describeError(e, '查询用户失败，请稍后重试')
  } finally {
    userSearching.value = false
  }
}

// 把 emoji 插入到输入框的光标处（emoji 即普通文本，随文本消息一起发送）
function insertEmoji(emoji: string) {
  const el = draftInput.value
  if (!el) {
    draft.value += emoji
    return
  }
  const start = el.selectionStart ?? draft.value.length
  const end = el.selectionEnd ?? start
  draft.value = draft.value.slice(0, start) + emoji + draft.value.slice(end)
  void nextTick(() => {
    el.focus()
    const caret = start + emoji.length
    el.setSelectionRange(caret, caret)
  })
}

// 点击面板与按钮之外的地方、或按 Esc 时关闭面板
function onGlobalPointerDown(e: MouseEvent) {
  if (!emojiOpen.value) return
  const target = e.target as Node | null
  if (target && emojiWrap.value?.contains(target)) return
  emojiOpen.value = false
}

function onGlobalKeydown(e: KeyboardEvent) {
  if (emojiOpen.value && e.key === 'Escape') emojiOpen.value = false
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
  const recipientId = chat.currentRecipientId
  if (!el || !recipientId) return
  const prevHeight = el.scrollHeight
  const prevTop = el.scrollTop
  await chat.loadOlder(recipientId)
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
  () => chat.currentRecipientId,
  () => {
    scrollToBottom()
  }
)

function showCopyNotice(text: string, failed: boolean) {
  copyNotice.value = text
  copyNoticeFailed.value = failed
  window.clearTimeout(copyNoticeTimer)
  copyNoticeTimer = window.setTimeout(() => {
    copyNotice.value = ''
  }, 2000)
}

async function copyMyId() {
  if (!auth.user) return
  const ok = await writeClipboard(auth.user.id)
  // 复制失败时提示手动选中：ID 由可选中的 span 承载（button 内文本无法选中）
  showCopyNotice(ok ? '已复制 userid' : '复制失败，请手动选中 ID 复制', !ok)
}

function handleLogout() {
  chat.disconnect()
  chat.reset()
  auth.logout()
  router.replace({ name: 'login' })
}

// 会话列表只含有过消息的会话，群列表要随后补上还没发言的群，顺序不能颠倒
async function refreshSessions() {
  await chat.loadSessions()
  await chat.loadGroups()
}

onMounted(() => {
  chat.connect()
  void refreshSessions()
  document.addEventListener('mousedown', onGlobalPointerDown)
  document.addEventListener('keydown', onGlobalKeydown)
})
onUnmounted(() => {
  chat.disconnect()
  window.clearTimeout(copyNoticeTimer)
  document.removeEventListener('mousedown', onGlobalPointerDown)
  document.removeEventListener('keydown', onGlobalKeydown)
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
        <div class="my-id-row">
          <span class="my-id" title="选中可手动复制">我的 ID：{{ auth.user?.id }}</span>
          <button class="copy-id" title="复制我的 userid 发给对方" @click="copyMyId">复制</button>
        </div>
        <span v-if="copyNotice" :class="['copy-notice', { failed: copyNoticeFailed }]">
          {{ copyNotice }}
        </span>
      </div>
      <button class="logout" @click="handleLogout">退出</button>
    </header>

    <div class="chat-body">
      <aside class="sidebar">
        <div class="new-chat">
          <input
            v-model="newPeerId"
            placeholder="输入对方账号或 userid 查找"
            @keyup.enter="startConversation"
          />
          <button
            class="search-user"
            title="查找用户并发起会话"
            aria-label="查找用户并发起会话"
            :disabled="userSearching"
            @click="startConversation"
          >
            <img :src="searchIcon" alt="" />
          </button>
          <button class="create-group" title="选择若干用户建群" @click="createGroupOpen = true">
            建群
          </button>
        </div>
        <p v-if="newChatError" class="new-chat-error">{{ newChatError }}</p>
        <p v-if="chat.groupsError" class="new-chat-error">{{ chat.groupsError }}</p>

        <p v-if="chat.sessionsLoading" class="sidebar-tip">会话加载中…</p>
        <p v-else-if="chat.sessionsError" class="sidebar-error">{{ chat.sessionsError }}</p>
        <p v-else-if="chat.sessions.length === 0" class="sidebar-tip">
          还没有会话，输入对方账号或 userid 开始聊天
        </p>
        <ul v-else class="session-list">
          <li
            v-for="s in chat.sessions"
            :key="s.peer.userid"
            :class="{ active: s.peer.userid === chat.currentRecipientId }"
            @click="openSession(s)"
          >
            <div :class="['avatar', { 'group-avatar': s.kind === 'group' }]">
              {{ sessionName(s).slice(0, 1).toUpperCase() }}
            </div>
            <div class="session-info">
              <div class="session-top">
                <span class="name">
                  {{ sessionName(s) }}
                  <span v-if="s.kind === 'group'" class="member-count">
                    {{ s.memberCount ?? 0 }} 人
                  </span>
                </span>
                <span class="time">{{ sessionTime(s.lastMessage.createdAt) }}</span>
              </div>
              <div class="session-bottom">
                <span class="preview">{{ sessionPreview(s) }}</span>
                <span
                  v-if="unreadCount(s) > 0"
                  class="unread-badge"
                  :aria-label="`${unreadLabel(s)} 条未读消息`"
                  >{{ unreadLabel(s) }}</span
                >
              </div>
            </div>
          </li>
        </ul>
      </aside>

      <main v-if="chat.currentRecipientId" class="chat-main">
        <div class="chat-header">
          <span v-if="currentIsGroup" class="header-title">
            {{ peerTitle }}
            <span class="member-count">{{ currentMemberCount }} 人</span>
          </span>
          <span v-else class="header-title">
            与
            <button class="peer-link" title="查看联系人资料" @click="openContactProfile">
              {{ peerTitle }}
            </button>
            的会话
          </span>
          <button v-if="currentIsGroup" class="group-info" @click="groupInfoOpen = true">
            群信息
          </button>
        </div>

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
            :class="['message-row', msg.fromSelf ? 'self' : 'peer', msg.recalled ? 'recalled' : '']"
          >
            <div class="message-col">
              <!-- 群聊里别人发的消息要标出是谁说的（单聊只有两个人，不需要） -->
              <span v-if="!msg.recalled && showSenderName(msg)" class="sender-name">{{ msg.senderNickname }}</span>
              <!-- 已撤回：不再显示气泡，改一行居中灰色提示 -->
              <div v-if="msg.recalled" class="recall-tip">{{ msg.content }}</div>
              <div v-else :class="['bubble', isMedia(msg) ? 'media-bubble' : '']">
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
                  <span
                    v-if="msg.fromSelf && msg.error"
                    class="pending failed"
                    :title="msg.error"
                  >发送失败</span>
                </span>
              </div>
            </div>
            <!-- 撤回入口：只有自己已发出且已入库的消息能撤 -->
            <button
              v-if="canRecall(msg)"
              class="recall-btn"
              title="撤回这条消息"
              @click="recall(msg)"
            >
              撤回
            </button>
          </div>
        </div>

        <div class="input-area">
          <p v-if="sendFailed" class="error">发送失败：实时连接未就绪，请稍后重试</p>
          <p v-if="uploadError" class="error">{{ uploadError }}</p>
          <p v-if="recallError" class="error">{{ recallError }}</p>
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
            <!-- emoji 面板：点击插入 Unicode emoji，随文本消息一起发送 -->
            <div ref="emojiWrap" class="emoji-wrap">
              <button
                :class="['attach', 'emoji-toggle', { active: emojiOpen }]"
                title="选择表情"
                @click="emojiOpen = !emojiOpen"
              >
                <img class="icon" :src="smileIcon" alt="" />表情
              </button>
              <EmojiPanel v-if="emojiOpen" class="emoji-popover" @select="insertEmoji" />
            </div>
          </div>
          <textarea
            ref="draftInput"
            v-model="draft"
            rows="2"
            placeholder="输入消息，Enter 发送"
            @keyup.enter.exact.prevent="handleSend"
          ></textarea>
          <button class="send" @click="handleSend">发送</button>
        </div>
      </main>

      <main v-else class="chat-main empty-main">
        <p>从左侧选择会话，或输入对方账号 / userid 开始聊天</p>
      </main>
    </div>

    <!-- 建群：选成员 → 建群 → 打开该群会话 -->
    <CreateGroupDialog v-if="createGroupOpen" @created="createGroupOpen = false" @close="createGroupOpen = false" />

    <!-- 群信息：群名、成员列表、退群 -->
    <GroupInfoDialog
      v-if="groupInfoOpen && chat.currentRecipientId"
      :group-id="chat.currentRecipientId"
      @left="groupInfoOpen = false"
      @close="groupInfoOpen = false"
    />

    <!-- 联系人资料：昵称 / 账号 / 用户 ID -->
    <ProfileCard
      v-if="contactProfile"
      :userid="contactProfile.userid"
      :nickname="contactProfile.nickname"
      :username="contactProfile.username"
      @close="contactProfile = null"
    />

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

.my-id-row {
  display: flex;
  align-items: center;
  gap: 6px;
}

/* ID 用普通 span 承载：button 内文本在浏览器中不可选中，无法手动复制 */
.my-id {
  font-size: 12px;
  color: #86909c;
  user-select: text;
  cursor: text;
  word-break: break-all;
}

.copy-id {
  flex-shrink: 0;
  border: 1px solid #d9d9d9;
  background: #fff;
  color: #165dff;
  border-radius: 4px;
  padding: 1px 8px;
  font-size: 12px;
}

.copy-notice {
  font-size: 11px;
  color: #389e0d;
}

.copy-notice.failed {
  color: #d4380d;
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
  display: flex;
  align-items: center;
  justify-content: center;
}

.new-chat button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.new-chat .search-user {
  width: 34px;
  padding: 0;
}

.new-chat .search-user img {
  width: 16px;
  height: 16px;
}

/* 建群入口：与查找用户并排，字数固定避免挤占输入框 */
.new-chat .create-group {
  flex-shrink: 0;
  padding: 8px 10px;
}

/* 查询用户失败的明确提示（查无此人 / 查到自己 / 请求失败） */
.new-chat-error {
  padding: 6px 12px 0;
  color: #d4380d;
  font-size: 12px;
  line-height: 1.4;
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

/* 群会话头像换色：会话列表里一眼分清单聊与群聊 */
.group-avatar {
  background: #722ed1;
}

/* 群成员数：跟在群名后面 */
.member-count {
  margin-left: 6px;
  font-weight: 400;
  font-size: 11px;
  color: #86909c;
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

/* 预览与未读角标同一行：角标固定宽度，预览吃掉剩余空间 */
.session-bottom {
  display: flex;
  align-items: center;
  gap: 6px;
}

.preview {
  flex: 1;
  min-width: 0;
  font-size: 12px;
  color: #86909c;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* 未读角标：沿用会话列表的圆角与字号，不引图标库 */
.unread-badge {
  flex-shrink: 0;
  min-width: 18px;
  padding: 0 5px;
  border-radius: 9px;
  background: #f53f3f;
  color: #fff;
  font-size: 11px;
  line-height: 18px;
  text-align: center;
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
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 16px;
  font-weight: 600;
  border-bottom: 1px solid #f2f3f5;
}

.header-title {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* 群信息入口：查看群名、成员列表并退群 */
.group-info {
  margin-left: auto;
  flex-shrink: 0;
  border: 1px solid #d9d9d9;
  background: #fff;
  color: #165dff;
  border-radius: 6px;
  padding: 4px 12px;
  font-size: 12px;
}

/* 顶栏里的联系人昵称：可点开资料卡，样式贴近普通文字以免看着像按钮 */
.peer-link {
  border: none;
  background: none;
  padding: 0;
  font: inherit;
  color: #165dff;
  cursor: pointer;
}

.peer-link:hover {
  text-decoration: underline;
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

/* 气泡与发送者昵称同属一列；宽度上限从气泡移到这一列，气泡仍按内容收缩 */
.message-col {
  display: flex;
  flex-direction: column;
  gap: 2px;
  max-width: 65%;
  align-items: flex-start;
}

.self .message-col {
  align-items: flex-end;
}

.sender-name {
  font-size: 11px;
  color: #86909c;
  padding: 0 2px;
}

/* 已撤回的消息：整行居中，不再左右分列，也不显示气泡 */
.message-row.recalled {
  justify-content: center;
}

.recalled .message-col {
  max-width: 100%;
  align-items: center;
}

.recall-tip {
  font-size: 12px;
  color: #86909c;
  background: #f2f3f5;
  border-radius: 4px;
  padding: 4px 10px;
}

/* 撤回入口：悬停才出现，避免每行都挂一个按钮抢视觉重心 */
.recall-btn {
  align-self: center;
  flex-shrink: 0;
  margin-left: 8px;
  border: none;
  background: none;
  color: #86909c;
  font-size: 12px;
  padding: 2px 4px;
  border-radius: 4px;
  visibility: hidden;
}

.message-row:hover .recall-btn {
  visibility: visible;
}

.recall-btn:hover {
  color: #165dff;
  background: #f2f3f5;
}

.bubble {
  max-width: 100%;
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

/* emoji 面板：按钮与浮层同属一个容器，点击容器内不关闭面板 */
.emoji-wrap {
  position: relative;
}

.emoji-toggle {
  display: flex;
  align-items: center;
  gap: 4px;
}

.emoji-toggle.active {
  border-color: #165dff;
  background: #e8f3ff;
}

.emoji-toggle .icon {
  width: 14px;
  height: 14px;
}

.emoji-popover {
  position: absolute;
  bottom: calc(100% + 8px);
  left: 0;
  z-index: 20;
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
