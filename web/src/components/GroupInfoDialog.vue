<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { describeError } from '../api'
import { useChatStore } from '../stores/chat'
import { useAuthStore } from '../stores/auth'
import type { GroupMember, UserInfo } from '../types'
import { compressAvatar } from '../avatar'
import { uploadMedia } from '../api'
import Avatar from './Avatar.vue'
import ProfileCard from './ProfileCard.vue'

// left：退群成功（本地会话已由 store 移除），由使用方关闭弹窗
const emit = defineEmits<{ left: []; close: [] }>()
const props = defineProps<{ groupId: string }>()

const chat = useChatStore()
const auth = useAuthStore()

const members = ref<GroupMember[]>([])
const loading = ref(true)
const loadError = ref('')
const confirming = ref(false)
const leaving = ref(false)
const leaveError = ref('')
// 点成员条目打开的资料卡（数据已在成员列表里，不额外发请求）
const memberProfile = ref<{
  userid: string
  nickname: string
  username: string
  avatar: string
} | null>(null)

const groupName = computed(() => chat.recipientNames[props.groupId] ?? props.groupId)
// 仅创建者可改群信息（服务端已定死）。判定直接比 ownerId——本功能不引入「管理员/群主」角色
const isOwner = computed(() => chat.groups[props.groupId]?.ownerId === auth.user?.id)

// 改群名：内联编辑，两个字段的事不值得套一层弹窗
const editing = ref(false)
const nameDraft = ref('')
const renaming = ref(false)
const renameError = ref('')

// 拉人入群：任何成员可拉。服务端一次只收一个 userId，被拉入无需本人同意
const inviteOpen = ref(false)
const inviteKeyword = ref('')
const inviteSearching = ref(false)
const inviteResults = ref<UserInfo[]>([])
const inviting = ref(false)
const inviteError = ref('')
const inviteTip = ref('')

onMounted(async () => {
  try {
    members.value = await chat.loadGroupMembers(props.groupId)
  } catch (e) {
    loadError.value = describeError(e, '成员列表加载失败')
  } finally {
    loading.value = false
  }
})

function openProfile(m: GroupMember) {
  memberProfile.value = {
    userid: m.userid,
    nickname: m.nickname || m.username || m.userid,
    username: m.username,
    avatar: m.avatar
  }
}

function startRename() {
  nameDraft.value = groupName.value
  renameError.value = ''
  editing.value = true
}

async function submitRename() {
  const name = nameDraft.value.trim()
  // 服务端对空名返回 400，前端先拦一次，省一次往返
  if (!name || renaming.value) return
  renaming.value = true
  renameError.value = ''
  try {
    await chat.renameGroup(props.groupId, name)
    editing.value = false
  } catch (e) {
    renameError.value = describeError(e, '改群名失败，请稍后重试')
  } finally {
    renaming.value = false
  }
}

// 已在群内的人直接禁选，避免让用户撞上服务端的 409「该用户已在群内」
function isMember(userId: string): boolean {
  return members.value.some((m) => m.userid === userId)
}

async function searchInvitee() {
  const kw = inviteKeyword.value.trim()
  if (!kw || inviteSearching.value) return
  inviteSearching.value = true
  inviteError.value = ''
  inviteTip.value = ''
  try {
    inviteResults.value = await chat.searchUser(kw)
    if (inviteResults.value.length === 0) {
      inviteError.value = '未找到该用户，请检查账号或用户 ID 是否正确'
    }
  } catch (e) {
    inviteError.value = describeError(e, '查询用户失败，请稍后重试')
  } finally {
    inviteSearching.value = false
  }
}

const avatarUploading = ref(false)
// 群头像：群表里就有，非创建者也能看到，只是不能改
const groupAvatar = computed(() => chat.groups[props.groupId]?.avatar)

// 换群头像（仅创建者）：与改群名走同一条 PATCH，服务端两个字段都能收
async function pickGroupAvatar(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  // 清掉 value，否则选同一个文件不会再触发 change
  input.value = ''
  if (!file || avatarUploading.value) return

  avatarUploading.value = true
  inviteError.value = ''
  try {
    const compressed = await compressAvatar(file)
    const { url } = await uploadMedia(auth.token!, 'avatar', compressed)
    await chat.changeGroupAvatar(props.groupId, url)
  } catch (e) {
    inviteError.value = describeError(e, '群头像上传失败，请稍后重试')
  } finally {
    avatarUploading.value = false
  }
}

async function invite(u: UserInfo) {
  if (inviting.value) return
  inviting.value = true
  inviteError.value = ''
  inviteTip.value = ''
  try {
    await chat.addGroupMember(props.groupId, u.id)
    members.value = await chat.loadGroupMembers(props.groupId)
    inviteResults.value = []
    inviteKeyword.value = ''
    // 拉人没有实时通知，被拉的人要等下次 loadGroups 才看得到群。
    // 静默成功会让操作者以为失败了，所以必须说出来
    inviteTip.value = `已把 ${u.nickname} 拉进群（现 ${members.value.length} 人），对方下次打开时才会看到这个群`
  } catch (e) {
    inviteError.value = describeError(e, '拉人入群失败，请稍后重试')
  } finally {
    inviting.value = false
  }
}

// 退群不可逆（退群后失去该群的访问权），先要一次确认
async function leave() {
  if (leaving.value) return
  leaving.value = true
  leaveError.value = ''
  try {
    await chat.leaveGroup(props.groupId)
    emit('left')
  } catch (e) {
    leaveError.value = describeError(e, '退群失败，请稍后重试')
  } finally {
    leaving.value = false
    confirming.value = false
  }
}
</script>

<template>
  <div class="mask" @click.self="emit('close')">
    <div class="dialog">
      <h3>群信息</h3>

      <div class="row">
        <span class="label">群头像</span>
        <Avatar :src="groupAvatar" :name="groupName" :size="40" group />
        <label v-if="isOwner" class="link">
          {{ avatarUploading ? '上传中…' : '换群头像' }}
          <input
            type="file"
            accept="image/png,image/jpeg,image/webp,image/gif"
            hidden
            @change="pickGroupAvatar"
          />
        </label>
      </div>

      <div class="row">
        <span class="label">群名称</span>
        <template v-if="editing">
          <input
            v-model="nameDraft"
            class="name-input"
            maxlength="30"
            @keyup.enter="submitRename"
          />
          <button class="link" :disabled="renaming" @click="submitRename">
            {{ renaming ? '保存中…' : '保存' }}
          </button>
          <button class="link" @click="editing = false">取消</button>
        </template>
        <template v-else>
          <span class="value">{{ groupName }}</span>
          <button v-if="isOwner" class="link" @click="startRename">改群名</button>
        </template>
      </div>
      <p v-if="renameError" class="error">{{ renameError }}</p>
      <div class="row">
        <span class="label">成员</span>
        <span class="value">{{ members.length }} 人</span>
      </div>

      <p v-if="loading" class="tip">成员加载中…</p>
      <p v-else-if="loadError" class="error">{{ loadError }}</p>
      <ul v-else class="members">
        <li v-for="m in members" :key="m.userid" title="查看资料" @click="openProfile(m)">
          <Avatar :src="m.avatar" :name="m.nickname || m.userid" :size="32" />
          <span class="who">
            {{ m.nickname }}
            <span v-if="m.userid === auth.user?.id" class="self-tag">我</span>
            <span class="account">{{ m.username }}</span>
          </span>
        </li>
      </ul>

      <div v-if="inviteOpen" class="invite">
        <div class="search-row">
          <input
            v-model="inviteKeyword"
            placeholder="输入对方账号或 userid 查找"
            @keyup.enter="searchInvitee"
          />
          <button :disabled="inviteSearching" @click="searchInvitee">
            {{ inviteSearching ? '查找中…' : '查找' }}
          </button>
        </div>
        <ul v-if="inviteResults.length > 0" class="results">
          <li v-for="u in inviteResults" :key="u.id">
            <span class="who">
              {{ u.nickname }}
              <span class="account">{{ u.account }}</span>
            </span>
            <button v-if="isMember(u.id)" class="picked" disabled>已在群内</button>
            <button v-else :disabled="inviting" @click="invite(u)">拉入</button>
          </li>
        </ul>
      </div>
      <p v-if="inviteTip" class="tip">{{ inviteTip }}</p>
      <p v-if="inviteError" class="error">{{ inviteError }}</p>

      <p v-if="leaveError" class="error">{{ leaveError }}</p>

      <div class="actions">
        <template v-if="confirming">
          <span class="confirm-tip">退群后将看不到该群的消息</span>
          <button class="ghost" @click="confirming = false">取消</button>
          <button class="danger" :disabled="leaving" @click="leave">
            {{ leaving ? '退出中…' : '确认退群' }}
          </button>
        </template>
        <template v-else>
          <button class="ghost" @click="inviteOpen = !inviteOpen">
            {{ inviteOpen ? '收起' : '拉人入群' }}
          </button>
          <button class="ghost" @click="emit('close')">关闭</button>
          <button class="danger" @click="confirming = true">退群</button>
        </template>
      </div>
    </div>

    <!-- 成员资料卡：叠在群信息弹窗之上 -->
    <ProfileCard
      v-if="memberProfile"
      :userid="memberProfile.userid"
      :nickname="memberProfile.nickname"
      :username="memberProfile.username"
      :avatar="memberProfile.avatar"
      @close="memberProfile = null"
    />
  </div>
</template>

<style scoped>
.mask {
  position: fixed;
  inset: 0;
  z-index: 50;
  background: rgba(0, 0, 0, 0.35);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 16px;
}

.dialog {
  width: 340px;
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

/* 改群名的内联编辑：沿用建群弹窗的输入框与按钮样式 */
.name-input {
  flex: 1;
  min-width: 0;
  border: 1px solid #d9d9d9;
  border-radius: 6px;
  padding: 5px 8px;
  outline: none;
  font-size: 13px;
  font-family: inherit;
}

.link {
  flex-shrink: 0;
  border: none;
  background: none;
  color: #165dff;
  font-size: 13px;
  padding: 0;
}

.link:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.invite {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.search-row {
  display: flex;
  gap: 8px;
}

.search-row input {
  flex: 1;
  min-width: 0;
  border: 1px solid #d9d9d9;
  border-radius: 6px;
  padding: 8px 10px;
  outline: none;
  font-size: 13px;
  font-family: inherit;
}

.search-row button {
  flex-shrink: 0;
  border: none;
  background: #165dff;
  color: #fff;
  border-radius: 6px;
  padding: 8px 14px;
  font-size: 13px;
}

.search-row button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.results {
  list-style: none;
  margin: 0;
  padding: 0;
  border: 1px solid #f2f3f5;
  border-radius: 6px;
  max-height: 160px;
  overflow-y: auto;
}

.results li {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 7px 10px;
  border-bottom: 1px solid #f2f3f5;
}

.results li:last-child {
  border-bottom: none;
}

.results .who {
  flex: 1;
}

.results button {
  flex-shrink: 0;
  border: 1px solid #165dff;
  background: #fff;
  color: #165dff;
  border-radius: 6px;
  padding: 4px 12px;
  font-size: 12px;
}

.results button.picked {
  border-color: #d9d9d9;
  color: #86909c;
  cursor: default;
}

.members {
  list-style: none;
  margin: 0;
  padding: 0;
  border: 1px solid #f2f3f5;
  border-radius: 6px;
  max-height: 260px;
  overflow-y: auto;
}

.members li {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  border-bottom: 1px solid #f2f3f5;
  cursor: pointer;
}

.members li:hover {
  background: #f7f8fa;
}

.members li:last-child {
  border-bottom: none;
}

/* 头像样式统一在 Avatar.vue 里 */

.who {
  min-width: 0;
  font-size: 13px;
  color: #1d2129;
}

.self-tag {
  margin-left: 4px;
  font-size: 11px;
  color: #165dff;
}

.account {
  margin-left: 6px;
  font-size: 11px;
  color: #86909c;
}

.tip {
  margin: 0;
  color: #86909c;
  font-size: 13px;
}

.error {
  color: #d4380d;
  font-size: 12px;
  line-height: 1.4;
  margin: 0;
}

.actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
}

.confirm-tip {
  margin-right: auto;
  font-size: 12px;
  color: #86909c;
}

.ghost {
  border: 1px solid #d9d9d9;
  background: #fff;
  border-radius: 6px;
  padding: 7px 16px;
  font-size: 13px;
}

.danger {
  border: 1px solid #d4380d;
  background: #fff;
  color: #d4380d;
  border-radius: 6px;
  padding: 7px 16px;
  font-size: 13px;
}

.danger:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
