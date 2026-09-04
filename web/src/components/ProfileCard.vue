<script setup lang="ts">
import { ref, watch } from 'vue'
import Avatar from './Avatar.vue'
import { compressAvatar } from '../avatar'
import { describeError, updateMe, uploadMedia } from '../api'
import { useAuthStore } from '../stores/auth'
import { writeClipboard } from '../clipboard'

// 资料卡。数据来自会话列表与群成员列表（两者都已带
// userid / 账号 / 昵称 / 头像），不需要额外发请求。
// 看别人时只读；看自己（editable）时可以换头像与改昵称
const props = defineProps<{
  userid: string
  nickname: string
  // 账号
  username: string
  // 头像 URL；缺省或为 'default' 时由 Avatar 回退首字母
  avatar?: string
  // 看自己：开启换头像与改昵称。看联系人/群成员时不传，保持只读
  editable?: boolean
}>()

const emit = defineEmits<{ close: []; updated: [] }>()

const auth = useAuthStore()

// 编辑态（仅 editable 时用到）
const shownAvatar = ref(props.avatar)
const draftName = ref(props.nickname)
const saving = ref(false)
const uploading = ref(false)
const editError = ref('')

// 外部数据变了要跟上（换会话、重新打开资料卡）
watch(
  () => props.avatar,
  (v) => {
    shownAvatar.value = v
  }
)
watch(
  () => props.nickname,
  (v) => {
    draftName.value = v
  }
)

async function pickAvatar(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  // 清掉 value，否则选同一个文件不会再触发 change
  input.value = ''
  if (!file || uploading.value) return

  uploading.value = true
  editError.value = ''
  try {
    const compressed = await compressAvatar(file)
    const { url } = await uploadMedia(auth.token!, 'avatar', compressed)
    // 换头像立即落库，不等「保存」：选完图就能看到效果，昵称另走保存
    const me = await updateMe(auth.token!, { avatar: url })
    auth.applyUser(me)
    shownAvatar.value = me.avatar
    emit('updated')
  } catch (e) {
    editError.value = describeError(e, '头像上传失败，请稍后重试')
  } finally {
    uploading.value = false
  }
}

async function saveNickname() {
  const name = draftName.value.trim()
  if (!name || saving.value || name === props.nickname) return
  saving.value = true
  editError.value = ''
  try {
    const me = await updateMe(auth.token!, { nickname: name })
    auth.applyUser(me)
    emit('updated')
  } catch (e) {
    editError.value = describeError(e, '保存失败，请稍后重试')
  } finally {
    saving.value = false
  }
}

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
      <h3>{{ editable ? '我的资料' : '资料' }}</h3>

      <div class="identity">
        <Avatar :src="shownAvatar" :name="nickname || userid" :size="44" />
        <input
          v-if="editable"
          v-model="draftName"
          class="name-input"
          maxlength="20"
          @keyup.enter="saveNickname"
        />
        <span v-else class="nickname">{{ nickname }}</span>
      </div>

      <!-- 换头像：选完即上传落库，不等「保存」——选完图就该立刻看到效果 -->
      <label v-if="editable" class="pick-avatar">
        {{ uploading ? '头像上传中…' : '换头像' }}
        <input
          type="file"
          accept="image/png,image/jpeg,image/webp,image/gif"
          hidden
          @change="pickAvatar"
        />
      </label>

      <div class="row">
        <span class="label">账号</span>
        <span class="value">{{ username || '—' }}</span>
      </div>
      <div class="row">
        <span class="label">用户 ID</span>
        <span class="value id" title="选中可手动复制">{{ userid }}</span>
      </div>

      <p v-if="editError" class="error">{{ editError }}</p>
      <p v-if="copyNotice" :class="['copy-notice', { failed: copyNoticeFailed }]">
        {{ copyNotice }}
      </p>

      <div class="actions">
        <button
          v-if="editable"
          class="primary"
          :disabled="saving"
          @click="saveNickname"
        >
          {{ saving ? '保存中…' : '保存昵称' }}
        </button>
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

/* 头像样式统一在 Avatar.vue 里 */

/* 改昵称：内联编辑，两个字段的事不值得套一层弹窗 */
.name-input {
  min-width: 0;
  flex: 1;
  border: 1px solid #d9d9d9;
  border-radius: 6px;
  padding: 6px 8px;
  font-size: 16px;
  font-weight: 600;
  font-family: inherit;
  color: #1d2129;
  outline: none;
}

.name-input:focus {
  border-color: #165dff;
}

.pick-avatar {
  align-self: flex-start;
  border: 1px solid #165dff;
  color: #165dff;
  border-radius: 6px;
  padding: 5px 12px;
  font-size: 12px;
  cursor: pointer;
}

.error {
  margin: 0;
  font-size: 12px;
  color: #d4380d;
  word-break: break-all;
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
