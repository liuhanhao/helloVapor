import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import { fetchMe, login as apiLogin, register as apiRegister } from '../api'
import type { UserInfo } from '../types'

const TOKEN_KEY = 'chat.token'
const USER_KEY = 'chat.user'

export const useAuthStore = defineStore('auth', () => {
  const token = ref<string | null>(localStorage.getItem(TOKEN_KEY))
  const user = ref<UserInfo | null>(loadStoredUser())

  const isLoggedIn = computed(() => !!token.value && !!user.value)

  function loadStoredUser(): UserInfo | null {
    const raw = localStorage.getItem(USER_KEY)
    if (!raw) return null
    try {
      return JSON.parse(raw) as UserInfo
    } catch {
      return null
    }
  }

  function persist() {
    if (token.value) localStorage.setItem(TOKEN_KEY, token.value)
    if (user.value) localStorage.setItem(USER_KEY, JSON.stringify(user.value))
  }

  // 登录：先换 token，再拉取用户信息；刷新后凭 localStorage 恢复
  async function login(account: string, password: string) {
    const { value } = await apiLogin(account, password)
    const me = await fetchMe(value)
    token.value = value
    user.value = me
    persist()
  }

  // 注册：成功后直接自动登录
  async function register(params: {
    nickname: string
    account: string
    password: string
    confirmPassword: string
  }) {
    await apiRegister(params)
    await login(params.account, params.password)
  }

  // 退出登录：清除本地凭证
  function logout() {
    token.value = null
    user.value = null
    localStorage.removeItem(TOKEN_KEY)
    localStorage.removeItem(USER_KEY)
  }

  return { token, user, isLoggedIn, login, register, logout }
})
