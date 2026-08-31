<script setup lang="ts">
import { computed, ref } from 'vue'
import { EMOJI_GROUPS } from '../emoji'

// 选中某个 emoji 时抛出，由使用方（输入框）决定插入到哪里
const emit = defineEmits<{ (e: 'select', emoji: string): void }>()

const activeIndex = ref(0)
const activeGroup = computed(() => EMOJI_GROUPS[activeIndex.value])
</script>

<template>
  <div class="emoji-panel">
    <div class="emoji-tabs">
      <button
        v-for="(group, index) in EMOJI_GROUPS"
        :key="group.name"
        :class="['emoji-tab', { active: index === activeIndex }]"
        type="button"
        @click="activeIndex = index"
      >
        {{ group.name }}
      </button>
    </div>
    <div class="emoji-grid">
      <button
        v-for="(emoji, index) in activeGroup.emojis"
        :key="`${activeGroup.name}-${index}`"
        class="emoji-item"
        type="button"
        :title="emoji"
        @click="emit('select', emoji)"
      >
        {{ emoji }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.emoji-panel {
  width: 320px;
  background: #fff;
  border: 1px solid #e5e6eb;
  border-radius: 8px;
  box-shadow: 0 6px 20px rgba(0, 0, 0, 0.12);
  overflow: hidden;
}

.emoji-tabs {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  padding: 6px 8px;
  border-bottom: 1px solid #f2f3f5;
}

.emoji-tab {
  border: none;
  background: none;
  color: #4e5969;
  font-size: 12px;
  padding: 3px 8px;
  border-radius: 10px;
  cursor: pointer;
}

.emoji-tab:hover {
  background: #f2f3f5;
}

.emoji-tab.active {
  background: #e8f3ff;
  color: #165dff;
  font-weight: 600;
}

.emoji-grid {
  display: grid;
  grid-template-columns: repeat(8, 1fr);
  gap: 2px;
  padding: 8px;
  max-height: 200px;
  overflow-y: auto;
}

.emoji-item {
  border: none;
  background: none;
  font-size: 20px;
  line-height: 1;
  padding: 6px 0;
  border-radius: 6px;
  cursor: pointer;
}

.emoji-item:hover {
  background: #f2f3f5;
}
</style>
