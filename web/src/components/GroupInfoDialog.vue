<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { describeError } from '../api'
import { useChatStore } from '../stores/chat'
import { useAuthStore } from '../stores/auth'
import type { GroupMember } from '../types'
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
const memberProfile = ref<{ userid: string; nickname: string; username: string } | null>(null)

const groupName = computed(() => chat.recipientNames[props.groupId] ?? props.groupId)

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
    username: m.username
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
        <span class="label">群名称</span>
        <span class="value">{{ groupName }}</span>
      </div>
      <div class="row">
        <span class="label">成员</span>
        <span class="value">{{ members.length }} 人</span>
      </div>

      <p v-if="loading" class="tip">成员加载中…</p>
      <p v-else-if="loadError" class="error">{{ loadError }}</p>
      <ul v-else class="members">
        <li v-for="m in members" :key="m.userid" title="查看资料" @click="openProfile(m)">
          <span class="avatar">{{ (m.nickname || m.userid).slice(0, 1).toUpperCase() }}</span>
          <span class="who">
            {{ m.nickname }}
            <span v-if="m.userid === auth.user?.id" class="self-tag">我</span>
            <span class="account">{{ m.username }}</span>
          </span>
        </li>
      </ul>

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

.avatar {
  width: 28px;
  height: 28px;
  flex-shrink: 0;
  border-radius: 50%;
  background: #165dff;
  color: #fff;
  font-size: 13px;
  font-weight: 600;
  display: flex;
  align-items: center;
  justify-content: center;
}

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
