// 写入剪贴板：优先 Clipboard API；它在非安全上下文（http 且非 localhost，如用局域网 IP 访问）
// 下不存在或被拒，此时降级到临时 textarea + execCommand。两者都失败返回 false。
// 抽出来是因为顶栏「复制我的 ID」与资料卡「复制 userid」都要用。
export function writeClipboard(text: string): boolean | Promise<boolean> {
  if (navigator.clipboard?.writeText) {
    return navigator.clipboard
      .writeText(text)
      .then(() => true)
      .catch(() => legacyCopy(text))
  }
  return legacyCopy(text)
}

function legacyCopy(text: string): boolean {
  const ta = document.createElement('textarea')
  ta.value = text
  ta.setAttribute('readonly', '')
  ta.style.position = 'fixed'
  ta.style.top = '0'
  ta.style.opacity = '0'
  document.body.appendChild(ta)
  ta.select()
  ta.setSelectionRange(0, text.length)
  try {
    return document.execCommand('copy')
  } catch {
    return false
  } finally {
    document.body.removeChild(ta)
  }
}
