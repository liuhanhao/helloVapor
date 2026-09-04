<script setup lang="ts">
import { computed, ref, watch } from 'vue'

// 头像：有图显图，无图或加载失败回退昵称首字母。
//
// 判定「有没有图」要同时覆盖两种情况：值为空，以及存量数据的 'default'——
// 老用户的 avatar 全是这个字符串，不是空值也不是 URL。只判空会让全库用户
// 都去请求 /uploads/default；只处理 @error 又挡不住 'default' 这一次请求。
const props = withDefaults(
  defineProps<{
    src?: string
    name?: string
    // 像素尺寸（正方形）
    size?: number
    // 群头像用紫色底，与个人头像区分
    group?: boolean
  }>(),
  { size: 40, group: false }
)

const failed = ref(false)
// 换了人就重置失败标记，否则新头像会沿用上一条的失败态
watch(
  () => props.src,
  () => {
    failed.value = false
  }
)

const isRealUrl = computed(() => {
  const s = (props.src ?? '').trim()
  return s !== '' && s !== 'default' && s.startsWith('/')
})

// 加载失败也回退：头像文件可能被清掉，裂图比字母块难看得多
const showImage = computed(() => isRealUrl.value && !failed.value)

const initial = computed(() => (props.name || '?').trim().slice(0, 1).toUpperCase() || '?')
</script>

<template>
  <div
    :class="['avatar', { 'group-avatar': group }]"
    :style="{
      width: `${size}px`,
      height: `${size}px`,
      fontSize: `${Math.max(11, Math.round(size * 0.42))}px`
    }"
  >
    <img v-if="showImage" :src="src" :alt="name ?? ''" @error="failed = true" />
    <template v-else>{{ initial }}</template>
  </div>
</template>

<style scoped>
/* 沿用各处既有头像的观感：圆形、居中、白字 */
.avatar {
  flex-shrink: 0;
  border-radius: 50%;
  background: #165dff;
  color: #fff;
  font-weight: 600;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.group-avatar {
  background: #722ed1;
}

.avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
</style>
