// 头像压缩（B3 02）
//
// 为什么必须压缩：服务端没有图像处理库，而会话列表一次要渲染几十个头像——
// 直接把原图（图片上限 10MB）传上去，列表会直接卡死。缩放只能在前端做。
const MAX_EDGE = 256

// 压缩到最长边 256px；gif 原样返回（canvas 会丢动画，靠服务端 2MB 上限兜底）
export async function compressAvatar(file: File): Promise<File> {
  if (file.type === 'image/gif') return file

  const bitmap = await createImageBitmap(file)
  const scale = Math.min(1, MAX_EDGE / Math.max(bitmap.width, bitmap.height))
  const width = Math.max(1, Math.round(bitmap.width * scale))
  const height = Math.max(1, Math.round(bitmap.height * scale))

  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height
  const ctx = canvas.getContext('2d')
  if (!ctx) {
    bitmap.close()
    return file
  }

  // png / webp 保留透明通道（压成 jpeg 会让透明区域变黑），其余统一输出 jpeg——体积最小
  const keepAlpha = file.type === 'image/png' || file.type === 'image/webp'
  if (!keepAlpha) {
    ctx.fillStyle = '#fff'
    ctx.fillRect(0, 0, width, height)
  }
  ctx.drawImage(bitmap, 0, 0, width, height)

  const blob = await new Promise<Blob | null>((resolve) => {
    canvas.toBlob(resolve, keepAlpha ? 'image/png' : 'image/jpeg', 0.85)
  })
  bitmap.close()
  if (!blob) return file

  return new File([blob], `avatar.${keepAlpha ? 'png' : 'jpg'}`, {
    type: keepAlpha ? 'image/png' : 'image/jpeg'
  })
}
