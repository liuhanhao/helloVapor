// 测试环境垫片：stores 只依赖两个浏览器全局——window.setTimeout（标记已读的合批窗口）
// 与 localStorage（auth store 初始化即读凭证）。这里给最小实现，不引 happy-dom：
// 为一个 Storage 拉进整个 DOM 实现不划算，而且它的 Storage 在 vitest 里挂不上。
class MemoryStorage {
  private data = new Map<string, string>()

  getItem(key: string): string | null {
    return this.data.get(key) ?? null
  }
  setItem(key: string, value: string) {
    this.data.set(key, String(value))
  }
  removeItem(key: string) {
    this.data.delete(key)
  }
  clear() {
    this.data.clear()
  }
}

// window 指向 globalThis：window.setTimeout 即 Node 的 setTimeout，
// 因此 vi.useFakeTimers() 能同时管住它（标记已读的合批测试依赖这一点）
Object.defineProperty(globalThis, 'window', {
  value: globalThis,
  writable: true,
  configurable: true
})
Object.defineProperty(globalThis, 'localStorage', {
  value: new MemoryStorage(),
  writable: true,
  configurable: true
})
