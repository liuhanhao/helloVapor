<script setup lang="ts">
import { computed, ref } from 'vue'
import { describeError } from '../api'
import { useChatStore } from '../stores/chat'
import type { UserInfo } from '../types'

// created：建群成功并已打开该群会话，由使用方关闭弹窗
const emit = defineEmits<{ created: []; close: [] }>()
const chat = useChatStore()

const name = ref('')
const keyword = ref('')
const searching = ref(false)
const searchError = ref('')
const results = ref<UserInfo[]>([])
// 待拉入群的成员（建群时不含自己：创建者自动入群）
const selected = ref<UserInfo[]>([])
const creating = ref(false)
const createError = ref('')

// 群名与至少一个成员是建群的最低条件
const canCreate = computed(
  () => !!name.value.trim() && selected.value.length > 0 && !creating.value
)

async function search() {
  const kw = keyword.value.trim()
  if (!kw || searching.value) return
  searching.value = true
  searchError.value = ''
  try {
    results.value = await chat.searchUser(kw)
    if (results.value.length === 0) {
      searchError.value = '未找到该用户，请检查账号或用户 ID 是否正确'
    }
  } catch (e) {
    searchError.value = describeError(e, '查询用户失败，请稍后重试')
  } finally {
    searching.value = false
  }
}

function isSelected(user: UserInfo): boolean {
  return selected.value.some((u) => u.id === user.id)
}

function toggle(user: UserInfo) {
  const idx = selected.value.findIndex((u) => u.id === user.id)
  if (idx >= 0) selected.value.splice(idx, 1)
  else selected.value.push(user)
}

async function create() {
  if (!canCreate.value) return
  creating.value = true
  createError.value = ''
  try {
    await chat.createGroup(name.value.trim(), selected.value.map((u) => u.id))
    emit('created')
  } catch (e) {
    createError.value = describeError(e, '建群失败，请稍后重试')
  } finally {
    creating.value = false
  }
}
</script>

<template>
  <div class="mask" @click.self="emit('close')">
    <div class="dialog">
      <h3>建群</h3>

      <label class="field">
        <span>群名称</span>
        <input v-model="name" placeholder="例如：周末篮球" maxlength="30" />
      </label>

      <div class="field">
        <span>成员</span>
        <div class="search-row">
          <input
            v-model="keyword"
            placeholder="输入对方账号或 userid 查找"
            @keyup.enter="search"
          />
          <button :disabled="searching" @click="search">
            {{ searching ? '查找中…' : '查找' }}
          </button>
        </div>
        <p v-if="searchError" class="error">{{ searchError }}</p>
        <ul v-if="results.length > 0" class="results">
          <li v-for="u in results" :key="u.id">
            <span class="who">
              {{ u.nickname }}
              <span class="account">{{ u.account }}</span>
            </span>
            <button :class="{ picked: isSelected(u) }" @click="toggle(u)">
              {{ isSelected(u) ? '已选' : '添加' }}
            </button>
          </li>
        </ul>
      </div>

      <div v-if="selected.length > 0" class="picked-list">
        <span v-for="u in selected" :key="u.id" class="chip">
          {{ u.nickname }}
          <button title="移出成员" @click="toggle(u)">×</button>
        </span>
      </div>

      <p v-if="createError" class="error">{{ createError }}</p>

      <div class="actions">
        <button class="ghost" @click="emit('close')">取消</button>
        <button class="primary" :disabled="!canCreate" @click="create">
          {{ creating ? '创建中…' : '创建群聊' }}
        </button>
      </div>
    </div>
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
  width: 380px;
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

.field {
  display: flex;
  flex-direction: column;
  gap: 6px;
  font-size: 13px;
  color: #4e5969;
}

.field input {
  border: 1px solid #d9d9d9;
  border-radius: 6px;
  padding: 8px 10px;
  outline: none;
  font-size: 13px;
  font-family: inherit;
}

.search-row {
  display: flex;
  gap: 8px;
}

.search-row input {
  flex: 1;
  min-width: 0;
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
}

.results li {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 8px 10px;
  border-bottom: 1px solid #f2f3f5;
}

.results li:last-child {
  border-bottom: none;
}

.who {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: #1d2129;
}

.account {
  margin-left: 6px;
  font-size: 11px;
  color: #86909c;
}

.results button {
  flex-shrink: 0;
  border: 1px solid #165dff;
  background: #fff;
  color: #165dff;
  border-radius: 4px;
  padding: 3px 10px;
  font-size: 12px;
}

.results button.picked {
  border-color: #d9d9d9;
  color: #86909c;
}

.picked-list {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.chip {
  display: flex;
  align-items: center;
  gap: 4px;
  background: #f2f3f5;
  border-radius: 12px;
  padding: 3px 8px;
  font-size: 12px;
  color: #1d2129;
}

.chip button {
  border: none;
  background: none;
  color: #86909c;
  font-size: 14px;
  line-height: 1;
  padding: 0;
  cursor: pointer;
}

.error {
  color: #d4380d;
  font-size: 12px;
  line-height: 1.4;
  margin: 0;
}

.actions {
  display: flex;
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
  border: none;
  background: #165dff;
  color: #fff;
  border-radius: 6px;
  padding: 7px 16px;
  font-size: 13px;
}

.primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
