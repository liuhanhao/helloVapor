<script setup lang="ts">
import { ref } from 'vue'
import { writeClipboard } from '../clipboard'

// 联系人 / 群成员的资料卡。数据来自会话列表与群成员列表（两者都已带
// userid / 账号 / 昵称），不需要额外发请求。
// 头像沿用列表里的首字母色块——User.avatar 目前只是 'default' 字符串，没有真实图片。
const props = defineProps<{
  userid: string
  nickname: string
  // 账号
  username: string
}>()

const emit = defineEmits<{ close: [] }>()

const copyNotice = ref('')
const copyNoticeFailed = ref(false)
let copyNoticeTimer: number | undefined

function showCopyNotice(text: string, failed: boolean) {
  copyNotice.value = text
  copyNoticeFailed.value = failed
  window.clearTimeout(copyNoticeTimer)
  copyNoticeTimer = window.setTimeout(() => {
    copyNotice.value = ''
  }, 2000)
}

async function copyUserId() {
  const ok = await writeClipboard(props.userid)
  // 复制失败时提示手动选中：ID 由可选中的 span 承载（button 内文本无法选中）
  showCopyNotice(ok ? '已复制 userid' : '复制失败，请手动选中 ID 复制', !ok)
}
</script>

<template>
  <!-- z-index 高于群信息弹窗：资料卡会从群成员列表里叠上来 -->
  <div class="mask" @click.self="emit('close')">
    <div class="dialog">
      <h3>资料</h3>

      <div class="identity">
        <span class="avatar">{{ (nickname || userid).slice(0, 1).toUpperCase() }}</span>
        <span class="nickname">{{ nickname }}</span>
      </div>

      <div class="row">
        <span class="label">账号</span>
        <span class="value">{{ username || '—' }}</span>
      </div>
      <div class="row">
        <span class="label">用户 ID</span>
        <span class="value id" title="选中可手动复制">{{ userid }}</span>
      </div>

      <p v-if="copyNotice" :class="['copy-notice', { failed: copyNoticeFailed }]">
        {{ copyNotice }}
      </p>

      <div class="actions">
        <button class="ghost" @click="emit('close')">关闭</button>
        <button class="primary" @click="copyUserId">复制用户 ID</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.mask {
  position: fixed;
  inset: 0;
  z-index: 60;
  background: rgba(0, 0, 0, 0.35);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 16px;
}

.dialog {
  width: 320px;
  max-height: 100%;
  overflow-y: auto;
  background: #fff;
  border-radius: 10px;
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 12px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.18);
}

h3 {
  margin: 0;
  font-size: 16px;
}

.identity {
  display: flex;
  align-items: center;
  gap: 10px;
}

.avatar {
  width: 44px;
  height: 44px;
  flex-shrink: 0;
  border-radius: 50%;
  background: #165dff;
  color: #fff;
  font-size: 18px;
  font-weight: 600;
  display: flex;
  align-items: center;
  justify-content: center;
}

.nickname {
  min-width: 0;
  font-size: 16px;
  font-weight: 600;
  color: #1d2129;
  word-break: break-all;
}

.row {
  display: flex;
  gap: 12px;
  font-size: 13px;
}

.label {
  width: 52px;
  flex-shrink: 0;
  color: #86909c;
}

.value {
  min-width: 0;
  word-break: break-all;
  color: #1d2129;
}

/* ID 用普通 span 承载：button 内文本在浏览器中不可选中，无法手动复制 */
.id {
  user-select: text;
  cursor: text;
}

.copy-notice {
  margin: 0;
  font-size: 12px;
  color: #00b42a;
}

.copy-notice.failed {
  color: #d4380d;
}

.actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
}

.ghost {
  border: 1px solid #d9d9d9;
  background: #fff;
  border-radius: 6px;
  padding: 7px 16px;
  font-size: 13px;
}

.primary {
  border: 1px solid #165dff;
  background: #165dff;
  color: #fff;
  border-radius: 6px;
  padding: 7px 16px;
  font-size: 13px;
}
</style>
