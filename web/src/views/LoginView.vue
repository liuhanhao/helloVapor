<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { describeError } from '../api'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()
const router = useRouter()

type Mode = 'login' | 'register'
const mode = ref<Mode>('login')
const submitting = ref(false)
const errorMsg = ref('')

const loginForm = reactive({ account: '', password: '' })
const registerForm = reactive({
  nickname: '',
  account: '',
  password: '',
  confirmPassword: ''
})

function switchMode(next: Mode) {
  mode.value = next
  errorMsg.value = ''
}

async function handleLogin() {
  errorMsg.value = ''
  if (!loginForm.account || !loginForm.password) {
    errorMsg.value = '请输入账号和密码'
    return
  }
  submitting.value = true
  try {
    await auth.login(loginForm.account.trim(), loginForm.password)
    router.replace({ name: 'chat' })
  } catch (e) {
    errorMsg.value = describeError(e, '登录失败，请稍后重试')
  } finally {
    submitting.value = false
  }
}

async function handleRegister() {
  errorMsg.value = ''
  const { nickname, account, password, confirmPassword } = registerForm
  if (!nickname || !account || !password || !confirmPassword) {
    errorMsg.value = '请填写完整的注册信息'
    return
  }
  if (password !== confirmPassword) {
    errorMsg.value = '两次输入的密码不一致'
    return
  }
  submitting.value = true
  try {
    await auth.register({
      nickname: nickname.trim(),
      account: account.trim(),
      password,
      confirmPassword
    })
    router.replace({ name: 'chat' })
  } catch (e) {
    errorMsg.value = describeError(e, '注册失败，请稍后重试')
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="login-page">
    <div class="login-card">
      <h1 class="title">VaporChat</h1>
      <div class="tabs">
        <button :class="['tab', { active: mode === 'login' }]" @click="switchMode('login')">
          登录
        </button>
        <button :class="['tab', { active: mode === 'register' }]" @click="switchMode('register')">
          注册
        </button>
      </div>

      <p v-if="errorMsg" class="error">{{ errorMsg }}</p>

      <form v-if="mode === 'login'" class="form" @submit.prevent="handleLogin">
        <input v-model="loginForm.account" placeholder="账号" autocomplete="username" />
        <input
          v-model="loginForm.password"
          type="password"
          placeholder="密码"
          autocomplete="current-password"
        />
        <button type="submit" class="primary" :disabled="submitting">
          {{ submitting ? '登录中…' : '登录' }}
        </button>
      </form>

      <form v-else class="form" @submit.prevent="handleRegister">
        <input v-model="registerForm.nickname" placeholder="昵称" />
        <input v-model="registerForm.account" placeholder="账号" autocomplete="username" />
        <input
          v-model="registerForm.password"
          type="password"
          placeholder="密码"
          autocomplete="new-password"
        />
        <input
          v-model="registerForm.confirmPassword"
          type="password"
          placeholder="确认密码"
          autocomplete="new-password"
        />
        <button type="submit" class="primary" :disabled="submitting">
          {{ submitting ? '注册中…' : '注册' }}
        </button>
      </form>
    </div>
  </div>
</template>

<style scoped>
.login-page {
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.login-card {
  width: 360px;
  background: #fff;
  border-radius: 12px;
  padding: 32px 28px;
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.08);
}

.title {
  text-align: center;
  font-size: 24px;
  margin-bottom: 20px;
}

.tabs {
  display: flex;
  border-bottom: 1px solid #e5e6eb;
  margin-bottom: 16px;
}

.tab {
  flex: 1;
  border: none;
  background: none;
  padding: 8px 0;
  color: #86909c;
}

.tab.active {
  color: #165dff;
  border-bottom: 2px solid #165dff;
  font-weight: 600;
}

.error {
  background: #fff2f0;
  border: 1px solid #ffccc7;
  color: #d4380d;
  border-radius: 6px;
  padding: 8px 12px;
  margin-bottom: 12px;
}

.form {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.form input {
  padding: 10px 12px;
  border: 1px solid #d9d9d9;
  border-radius: 6px;
  outline: none;
}

.form input:focus {
  border-color: #165dff;
}

.form .primary {
  background: #165dff;
  color: #fff;
  border: none;
  border-radius: 6px;
  padding: 10px 0;
  margin-top: 4px;
}

.form .primary:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>
