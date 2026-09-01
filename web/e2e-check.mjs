// 临时联调验证脚本：注册/登录/WS 互发/旧格式兼容/离线不报错
// BASE / WS_BASE 可用环境变量覆盖（默认 8080），便于对新构建或备用端口验证
const BASE = process.env.BASE ?? 'http://127.0.0.1:8080'
const WS_BASE = process.env.WS_BASE ?? BASE.replace(/^http/, 'ws')
const stamp = Date.now()
const results = []
function check(name, ok, extra = '') {
  results.push({ name, ok, extra })
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${extra ? '  -> ' + extra : ''}`)
}

async function register(nickname, account) {
  const res = await fetch(`${BASE}/chat/registered`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ avatar: 'default', nickname, account, password: 'pass123', confirmPassword: 'pass123' })
  })
  return { status: res.status, body: await res.json().catch(() => ({})) }
}

async function login(account, password) {
  const res = await fetch(`${BASE}/chat/login`, {
    method: 'POST',
    headers: { Authorization: `Basic ${Buffer.from(`${account}:${password}`).toString('base64')}` }
  })
  return { status: res.status, body: await res.json().catch(() => ({})) }
}

async function me(token) {
  const res = await fetch(`${BASE}/chat/me`, { headers: { Authorization: `Bearer ${token}` } })
  return { status: res.status, body: await res.json().catch(() => ({})) }
}

// 连接凭证为 token（issue 06）：身份由服务端凭 token 解析，不再由客户端自报 userid
function wsConnect(token) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`${WS_BASE}/chat/webSocket?token=${encodeURIComponent(token)}`)
    const inbox = []
    ws.onmessage = (e) => inbox.push(JSON.parse(String(e.data)))
    ws.onopen = () => resolve({ ws, inbox })
    ws.onerror = (e) => reject(new Error('ws error ' + (e?.message ?? '')))
  })
}

// 期望被服务端拒绝的连接：resolve 出 close code（1008 = 凭证无效），超时为 null
function wsConnectExpectClose(url, timeoutMs = 3000) {
  return new Promise((resolve) => {
    let settled = false
    const ws = new WebSocket(url)
    const finish = (code) => {
      if (settled) return
      settled = true
      clearTimeout(timer)
      resolve(code)
    }
    const timer = setTimeout(() => {
      try { ws.close() } catch {}
      finish(null)
    }, timeoutMs)
    // 握手成功后再被服务端关闭是正常路径：只等 close 事件，不等 onopen
    ws.onclose = (e) => finish(e.code)
    ws.onerror = () => {}
  })
}

function waitUntil(fn, timeoutMs = 3000) {
  return new Promise((resolve) => {
    const start = Date.now()
    const t = setInterval(() => {
      if (fn()) { clearInterval(t); resolve(true) }
      else if (Date.now() - start > timeoutMs) { clearInterval(t); resolve(false) }
    }, 50)
  })
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

async function main() {
  const aliceAccount = `alice${stamp}@test.com`
  const bobAccount = `bob${stamp}@test.com`

  // 1. 注册两个账号
  const ra = await register('Alice', aliceAccount)
  check('注册 Alice', ra.status === 200 && ra.body.id, JSON.stringify(ra.body))
  const rb = await register('Bob', bobAccount)
  check('注册 Bob', rb.status === 200 && rb.body.id, JSON.stringify(rb.body))

  // 2. 重复注册被拒绝
  const dup = await register('Alice2', aliceAccount)
  check('重复注册返回 409', dup.status === 409, `status=${dup.status} ${dup.body.reason ?? ''}`)

  // 3. 登录错误密码返回 401
  const badLogin = await login(aliceAccount, 'wrongpass')
  check('错误密码登录返回 401', badLogin.status === 401, `status=${badLogin.status}`)

  // 4. 正确登录拿 token，再换用户信息
  const la = await login(aliceAccount, 'pass123')
  check('Alice 登录成功', la.status === 200 && la.body.value, '')
  const lb = await login(bobAccount, 'pass123')
  check('Bob 登录成功', lb.status === 200 && lb.body.value, '')
  const mea = await me(la.body.value)
  check('/chat/me 返回用户信息且无密码散列', mea.status === 200 && mea.body.account === aliceAccount && !mea.body.passwordHash, JSON.stringify(mea.body))

  // 5. WebSocket 鉴权（issue 06）：无 token / 无效 token 一律拒绝
  const codeNoToken = await wsConnectExpectClose(`${WS_BASE}/chat/webSocket`)
  check('无 token 的 WebSocket 连接被拒绝（1008）', codeNoToken === 1008, `code=${codeNoToken}`)
  const codeBadToken = await wsConnectExpectClose(`${WS_BASE}/chat/webSocket?token=not-a-real-token`)
  check('无效 token 的 WebSocket 连接被拒绝（1008）', codeBadToken === 1008, `code=${codeBadToken}`)

  // 5b. 建立两个带有效 token 的 WebSocket 连接
  const alice = await wsConnect(la.body.value)
  const meb = await me(lb.body.value)
  const bob = await wsConnect(lb.body.value)
  check('携带有效 token 的两个 WebSocket 连接建立', true)

  // 6. Alice 发送新格式文本（带 msgType）→ Bob 实时收到，Alice 收到 ack
  alice.ws.send(JSON.stringify({
    type: 'chatMessage',
    data: {
      mine: { avatar: 'default', content: '你好，Bob！', mine: true, userid: mea.body.id, username: aliceAccount, nickname: 'Alice', msgType: 'text' },
      to: { avatar: 'default', userid: meb.body.id, username: bobAccount, nickname: 'Bob' }
    }
  }))
  const bobGot = await waitUntil(() => bob.inbox.some((m) => m.type === 'chatMessage'))
  const bobMsg = bob.inbox.find((m) => m.type === 'chatMessage')
  check('Bob 实时收到消息', !!bobGot && bobMsg?.data?.mine?.content === '你好，Bob！', JSON.stringify(bobMsg ?? null))
  check('推送的消息带服务端 id 与时间戳', !!bobMsg?.data?.id && typeof bobMsg?.data?.timestamp === 'number', JSON.stringify(bobMsg?.data ?? null))
  const aliceAcked = await waitUntil(() => alice.inbox.some((m) => m.type === 'chatMessageAck'))
  const ack = alice.inbox.find((m) => m.type === 'chatMessageAck')
  check('Alice 收到服务端确认（含时间戳）', !!aliceAcked && typeof ack?.data?.timestamp === 'number', JSON.stringify(ack ?? null))
  check('确认回执带消息 id', !!ack?.data?.id, JSON.stringify(ack?.data ?? null))
  check('Alice 不再收到反转回显', !alice.inbox.some((m) => typeof m === 'string' || (m.type === 'chatMessage' && m.data?.mine?.userid === mea.body.id)), '')

  // 7. iOS 旧格式消息（无 msgType）：Bob 发给 Alice
  bob.ws.send(JSON.stringify({
    type: 'chatMessage',
    data: {
      mine: { avatar: 'default', content: '旧格式消息，来自 iOS', mine: true, userid: meb.body.id, username: bobAccount, nickname: 'Bob' },
      to: { avatar: 'default', userid: mea.body.id, username: aliceAccount, nickname: 'Alice' }
    }
  }))
  const aliceGotOld = await waitUntil(() => alice.inbox.some((m) => m.type === 'chatMessage'))
  const aliceOldMsg = alice.inbox.find((m) => m.type === 'chatMessage')
  check('旧格式（无 msgType）消息正常转发', !!aliceGotOld && aliceOldMsg?.data?.mine?.content === '旧格式消息，来自 iOS', JSON.stringify(aliceOldMsg ?? null))

  // 8. 发给离线用户：不报错，仅入库（发送方仍收到 ack）
  const offlineId = '00000000-0000-0000-0000-000000000000'
  alice.ws.send(JSON.stringify({
    type: 'chatMessage',
    data: {
      mine: { avatar: 'default', content: '发给离线用户', mine: true, userid: mea.body.id, username: aliceAccount, nickname: 'Alice', msgType: 'text' },
      to: { avatar: 'default', userid: offlineId, username: 'offline', nickname: 'Offline' }
    }
  }))
  const offlineAcked = await waitUntil(() => alice.inbox.filter((m) => m.type === 'chatMessageAck').length >= 2)
  check('接收方离线时不报错，发送方仍收到确认', !!offlineAcked, '')

  // 9. 会话列表接口（token 鉴权）
  const noAuthSessions = await fetch(`${BASE}/chat/sessions`)
  check('未携带 token 访问会话列表返回 401', noAuthSessions.status === 401, `status=${noAuthSessions.status}`)

  const sessARes = await fetch(`${BASE}/chat/sessions`, { headers: { Authorization: `Bearer ${la.body.value}` } })
  const sessA = sessARes.status === 200 ? await sessARes.json() : []
  const aliceBob = sessA.find((s) => s.peer.userid === meb.body.id)
  const aliceOffline = sessA.find((s) => s.peer.userid === offlineId)
  check(
    'Alice 会话列表包含 Bob，最后一条为对方消息',
    !!aliceBob && aliceBob.lastMessage.content === '旧格式消息，来自 iOS' && aliceBob.lastMessage.fromSelf === false,
    JSON.stringify(aliceBob ?? null)
  )
  check(
    'Bob 的身份取自 users 表',
    !!aliceBob && aliceBob.peer.nickname === 'Bob' && aliceBob.peer.username === bobAccount,
    JSON.stringify(aliceBob?.peer ?? null)
  )
  check(
    '会话列表按最后消息时间倒序（离线用户会话更靠前）',
    !!aliceOffline && sessA.indexOf(aliceOffline) < sessA.indexOf(aliceBob) && aliceOffline.lastMessage.content === '发给离线用户' && aliceOffline.lastMessage.fromSelf === true,
    JSON.stringify(sessA.map((s) => [s.peer.userid, s.lastMessage.content]))
  )
  check('无注册记录的联系人回退消息内身份', !!aliceOffline && aliceOffline.peer.nickname === 'Offline', JSON.stringify(aliceOffline?.peer ?? null))

  const sessBRes = await fetch(`${BASE}/chat/sessions`, { headers: { Authorization: `Bearer ${lb.body.value}` } })
  const sessB = sessBRes.status === 200 ? await sessBRes.json() : []
  const bobAlice = sessB.find((s) => s.peer.userid === mea.body.id)
  check(
    'Bob 会话列表最后一条为自己发出的消息',
    !!bobAlice && bobAlice.lastMessage.content === '旧格式消息，来自 iOS' && bobAlice.lastMessage.fromSelf === true,
    JSON.stringify(bobAlice ?? null)
  )
  check('发给离线用户的消息不出现在 Bob 的会话列表', !sessB.some((s) => s.peer.userid === offlineId), '')

  // 10. 历史消息接口（token 鉴权、双方消息、时间正序）
  const noAuthHistory = await fetch(`${BASE}/chat/history?peer=${meb.body.id}`)
  check('未携带 token 访问历史消息返回 401', noAuthHistory.status === 401, `status=${noAuthHistory.status}`)
  const noPeer = await fetch(`${BASE}/chat/history`, { headers: { Authorization: `Bearer ${la.body.value}` } })
  check('缺少 peer 参数返回 400', noPeer.status === 400, `status=${noPeer.status}`)

  const histRes = await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(meb.body.id)}`, { headers: { Authorization: `Bearer ${la.body.value}` } })
  const hist = histRes.status === 200 ? await histRes.json() : { messages: [], hasMore: false }
  const histTexts = hist.messages.map((m) => m.content)
  check(
    '历史消息按时间正序且双方消息都在',
    histTexts.length === 2 && histTexts[0] === '你好，Bob！' && histTexts[1] === '旧格式消息，来自 iOS',
    JSON.stringify(hist)
  )
  check('历史消息方向正确（fromSelf）', hist.messages[0]?.fromSelf === true && hist.messages[1]?.fromSelf === false, '')
  check('历史消息带 id 与时间戳', typeof hist.messages[0]?.id === 'string' && typeof hist.messages[0]?.createdAt === 'number', JSON.stringify(hist.messages[0] ?? null))
  check('与离线用户的消息不在与 Bob 的历史中', !histTexts.includes('发给离线用户'), '')

  const stranger = await (await fetch(`${BASE}/chat/history?peer=${crypto.randomUUID()}`, { headers: { Authorization: `Bearer ${la.body.value}` } })).json()
  check('与陌生联系人的历史为空', stranger.messages.length === 0 && stranger.hasMore === false, JSON.stringify(stranger))

  // 11. 历史消息分页（limit + before 游标）
  const page1 = await (await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(meb.body.id)}&limit=1`, { headers: { Authorization: `Bearer ${la.body.value}` } })).json()
  check('分页第一页返回最新一条且 hasMore=true', page1.messages.length === 1 && page1.messages[0].content === '旧格式消息，来自 iOS' && page1.hasMore === true, JSON.stringify(page1))
  const before = page1.messages[0].createdAt
  const page2 = await (await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(meb.body.id)}&limit=1&before=${before}`, { headers: { Authorization: `Bearer ${la.body.value}` } })).json()
  check('before 游标翻页拿到更早一条且 hasMore=false', page2.messages.length === 1 && page2.messages[0].content === '你好，Bob！' && page2.hasMore === false, JSON.stringify(page2))

  // 12. 图片上传（issue 03）：multipart 表单、类型/大小校验、UUID 存储、静态访问、媒体消息流转
  // 1x1 透明 PNG
  const pngBytes = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    'base64'
  )

  async function upload(token, msgType, filename, buffer, contentType) {
    const form = new FormData()
    form.append('msgType', msgType)
    form.append('file', new Blob([buffer], { type: contentType }), filename)
    const res = await fetch(`${BASE}/chat/upload`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: form
    })
    return { status: res.status, body: await res.json().catch(() => ({})) }
  }

  const noAuthUpload2 = await fetch(`${BASE}/chat/upload`, { method: 'POST' })
  check('未携带 token 上传返回 401', noAuthUpload2.status === 401, `status=${noAuthUpload2.status}`)

  // 合法 PNG：返回 /uploads/<uuid>.png 形式的 URL
  const okUpload = await upload(la.body.value, 'image', 'cat.png', pngBytes, 'image/png')
  const uuidRe = /^\/uploads\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.png$/
  check(
    '合法 PNG 上传成功且以 UUID + 原扩展名命名',
    okUpload.status === 200 && typeof okUpload.body.url === 'string' && uuidRe.test(okUpload.body.url),
    JSON.stringify(okUpload)
  )
  const imageUrl = okUpload.body.url

  // 上传的文件可经静态服务访问（且可重复访问）
  const imgRes = await fetch(`${BASE}${imageUrl}`)
  const imgBytes = Buffer.from(await imgRes.arrayBuffer())
  check(
    '上传的图片可通过 URL 访问（Content-Type 正确、内容一致）',
    imgRes.status === 200 && imgRes.headers.get('content-type')?.startsWith('image/png') && imgBytes.equals(pngBytes),
    `status=${imgRes.status} type=${imgRes.headers.get('content-type')} bytes=${imgBytes.length}`
  )

  // 非法类型：.txt 伪装图片被拒
  const badType = await upload(la.body.value, 'image', 'notes.txt', Buffer.from('hello'), 'text/plain')
  check('非法类型（txt）被拒绝且错误明确', badType.status === 415 && /不支持/.test(badType.body.reason ?? ''), `status=${badType.status} ${badType.body.reason ?? ''}`)

  // 超过 10MB：被拒
  const oversize = await upload(la.body.value, 'image', 'big.png', Buffer.alloc(10 * 1024 * 1024 + 1), 'image/png')
  check('超过 10MB 的图片被拒绝且错误明确', oversize.status === 413 && /10 MB/.test(oversize.body.reason ?? ''), `status=${oversize.status} ${oversize.body.reason ?? ''}`)

  // 非法 msgType：被拒
  const badMsgType = await upload(la.body.value, 'file', 'a.png', pngBytes, 'image/png')
  check('不支持的 msgType 被拒绝', badMsgType.status === 400, `status=${badMsgType.status} ${badMsgType.body.reason ?? ''}`)

  // Alice 经 WS 发图片消息（msgType=image，content 为文件 URL）→ Bob 实时收到
  alice.ws.send(JSON.stringify({
    type: 'chatMessage',
    data: {
      mine: { avatar: 'default', content: imageUrl, mine: true, userid: mea.body.id, username: aliceAccount, nickname: 'Alice', msgType: 'image' },
      to: { avatar: 'default', userid: meb.body.id, username: bobAccount, nickname: 'Bob' }
    }
  }))
  const bobImage = await waitUntil(() => bob.inbox.some((m) => m.type === 'chatMessage' && m.data?.mine?.msgType === 'image'))
  const bobImageMsg = bob.inbox.find((m) => m.type === 'chatMessage' && m.data?.mine?.msgType === 'image')
  check('Bob 实时收到图片消息（msgType=image，content 为 URL）', !!bobImage && bobImageMsg?.data?.mine?.content === imageUrl, JSON.stringify(bobImageMsg?.data?.mine ?? null))

  // 入库检查：会话列表最后一条为图片消息（msgType=image）
  await sleep(300)
  const sessAfterImage = await (await fetch(`${BASE}/chat/sessions`, { headers: { Authorization: `Bearer ${lb.body.value}` } })).json()
  const bobAliceAfterImage = sessAfterImage.find((s) => s.peer.userid === mea.body.id)
  check(
    'Bob 会话列表最后一条为图片消息（msgType=image）',
    bobAliceAfterImage?.lastMessage?.msgType === 'image' && bobAliceAfterImage?.lastMessage?.content === imageUrl,
    JSON.stringify(bobAliceAfterImage?.lastMessage ?? null)
  )

  // 历史接口返回图片消息（刷新后靠它恢复）
  const histAfterImage = await (await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(meb.body.id)}`, { headers: { Authorization: `Bearer ${la.body.value}` } })).json()
  const histImage = histAfterImage.messages.find((m) => m.msgType === 'image')
  check(
    '历史消息包含图片消息（带 id 与 URL）',
    !!histImage && histImage.content === imageUrl && typeof histImage.id === 'string',
    JSON.stringify(histImage ?? null)
  )

  // 再次访问同一 URL（历史图片可通过 URL 重复访问）
  const imgRes2 = await fetch(`${BASE}${imageUrl}`)
  check('同一 URL 可重复访问', imgRes2.status === 200, `status=${imgRes2.status}`)

  // 13. 音频/视频上传与消息流转（issue 04）
  // 生成最小合法 WAV（44 字节 RIFF 头 + PCM 采样），内容真实可播放
  function makeWavBytes(seconds = 2, sampleRate = 8000) {
    const numSamples = seconds * sampleRate
    const dataSize = numSamples * 2
    const buf = Buffer.alloc(44 + dataSize)
    buf.write('RIFF', 0)
    buf.writeUInt32LE(36 + dataSize, 4)
    buf.write('WAVE', 8)
    buf.write('fmt ', 12)
    buf.writeUInt32LE(16, 16)
    buf.writeUInt16LE(1, 20) // PCM
    buf.writeUInt16LE(1, 22) // 单声道
    buf.writeUInt32LE(sampleRate, 24)
    buf.writeUInt32LE(sampleRate * 2, 28)
    buf.writeUInt16LE(2, 32)
    buf.writeUInt16LE(16, 34)
    buf.write('data', 36)
    buf.writeUInt32LE(dataSize, 40)
    for (let i = 0; i < numSamples; i++) {
      buf.writeInt16LE(Math.round(10000 * Math.sin((2 * Math.PI * 440 * i) / sampleRate)), 44 + i * 2)
    }
    return buf
  }
  const wavBytes = makeWavBytes()

  // 合法 WAV 上传为音频：200 且 UUID + 原扩展名命名
  const wavUpload = await upload(la.body.value, 'audio', 'voice.wav', wavBytes, 'audio/wav')
  const wavUrl = wavUpload.body.url
  check(
    '合法 WAV 上传为音频成功且以 UUID + 原扩展名命名',
    wavUpload.status === 200 && typeof wavUrl === 'string' && /^\/uploads\/[0-9a-f-]{36}\.wav$/.test(wavUrl),
    JSON.stringify(wavUpload)
  )

  // 静态访问：Content-Type 正确（audio/wav）、字节一致
  const wavRes = await fetch(`${BASE}${wavUrl}`)
  const wavGot = Buffer.from(await wavRes.arrayBuffer())
  check(
    'WAV 可经 URL 访问（Content-Type 为 audio/wav、内容一致）',
    wavRes.status === 200 && (wavRes.headers.get('content-type') ?? '') === 'audio/wav' && wavGot.equals(wavBytes),
    `type=${wavRes.headers.get('content-type')} bytes=${wavGot.length}`
  )

  // Range 请求（播放器拖动进度依赖）：返回 206 与 Content-Range
  const rangeRes = await fetch(`${BASE}${wavUrl}`, { headers: { Range: 'bytes=0-99' } })
  check(
    '媒体访问支持 Range 请求（206 + Content-Range）',
    rangeRes.status === 206 && (rangeRes.headers.get('content-range') ?? '').includes('bytes 0-99/'),
    `status=${rangeRes.status} content-range=${rangeRes.headers.get('content-range')}`
  )

  // 各音视频扩展名的 Content-Type 修正（合成字节即可，服务端只按扩展名校验；内容真实性由 UI 冒烟覆盖）
  for (const [mt, fname, expect] of [
    ['audio', 't.m4a', 'audio/mp4'],
    ['audio', 't.aac', 'audio/aac'],
    ['audio', 't.mp3', 'audio/mpeg'],
    ['video', 't.mp4', 'video/mp4'],
    ['video', 't.mov', 'video/quicktime']
  ]) {
    const up = await upload(la.body.value, mt, fname, Buffer.alloc(2048), 'application/octet-stream')
    const res = await fetch(`${BASE}${up.body.url}`)
    check(
      `${fname} 静态访问 Content-Type 为 ${expect}`,
      up.status === 200 && (res.headers.get('content-type') ?? '') === expect,
      `upload=${JSON.stringify(up.body)} type=${res.headers.get('content-type')}`
    )
  }

  // 非法音频类型（txt 伪装）→ 415 明确错误
  const badAudio = await upload(la.body.value, 'audio', 'song.txt', Buffer.from('hello'), 'text/plain')
  check('非法音频类型（txt）被拒绝且错误明确', badAudio.status === 415 && /音频格式不支持/.test(badAudio.body.reason ?? ''), `status=${badAudio.status} ${badAudio.body.reason ?? ''}`)

  // 超过 20MB 的音频 → 413 明确错误（在 body 收集上限 100MB 之内，走 handler 校验）
  const bigAudio = await upload(la.body.value, 'audio', 'big.mp3', Buffer.alloc(20 * 1024 * 1024 + 1), 'audio/mpeg')
  check('超过 20MB 的音频被拒绝且错误明确', bigAudio.status === 413 && /20 MB/.test(bigAudio.body.reason ?? ''), `status=${bigAudio.status} ${bigAudio.body.reason ?? ''}`)

  // 超过 100MB 的视频 → 413（超过 body 收集上限，直接被拒）
  const bigVideo = await upload(la.body.value, 'video', 'big.mp4', Buffer.alloc(100 * 1024 * 1024 + 1), 'video/mp4')
  check('超过 100MB 的视频被拒绝', bigVideo.status === 413, `status=${bigVideo.status} ${bigVideo.body.reason ?? ''}`)

  // Alice 经 WS 发音频消息（msgType=audio，content 为文件 URL）→ Bob 实时收到
  alice.ws.send(JSON.stringify({
    type: 'chatMessage',
    data: {
      mine: { avatar: 'default', content: wavUrl, mine: true, userid: mea.body.id, username: aliceAccount, nickname: 'Alice', msgType: 'audio' },
      to: { avatar: 'default', userid: meb.body.id, username: bobAccount, nickname: 'Bob' }
    }
  }))
  const bobAudio = await waitUntil(() => bob.inbox.some((m) => m.type === 'chatMessage' && m.data?.mine?.msgType === 'audio'))
  const bobAudioMsg = bob.inbox.find((m) => m.type === 'chatMessage' && m.data?.mine?.msgType === 'audio')
  check('Bob 实时收到音频消息（msgType=audio，content 为 URL）', !!bobAudio && bobAudioMsg?.data?.mine?.content === wavUrl, JSON.stringify(bobAudioMsg?.data?.mine ?? null))

  // 入库检查：此刻 Bob 会话列表最后一条为音频消息（须在视频消息发出前检查）
  await sleep(300)
  const sessBobAudio = await (await fetch(`${BASE}/chat/sessions`, { headers: { Authorization: `Bearer ${lb.body.value}` } })).json()
  const bobAliceAudio = sessBobAudio.find((s) => s.peer.userid === mea.body.id)
  check(
    'Bob 会话列表最后一条为音频消息（msgType=audio）',
    bobAliceAudio?.lastMessage?.msgType === 'audio' && bobAliceAudio?.lastMessage?.content === wavUrl,
    JSON.stringify(bobAliceAudio?.lastMessage ?? null)
  )

  // Bob 经 WS 发视频消息（msgType=video）→ Alice 实时收到
  const mp4Upload = await upload(lb.body.value, 'video', 'clip.mp4', Buffer.alloc(2048), 'video/mp4')
  const mp4Url = mp4Upload.body.url
  bob.ws.send(JSON.stringify({
    type: 'chatMessage',
    data: {
      mine: { avatar: 'default', content: mp4Url, mine: true, userid: meb.body.id, username: bobAccount, nickname: 'Bob', msgType: 'video' },
      to: { avatar: 'default', userid: mea.body.id, username: aliceAccount, nickname: 'Alice' }
    }
  }))
  const aliceVideo = await waitUntil(() => alice.inbox.some((m) => m.type === 'chatMessage' && m.data?.mine?.msgType === 'video'))
  const aliceVideoMsg = alice.inbox.find((m) => m.type === 'chatMessage' && m.data?.mine?.msgType === 'video')
  check('Alice 实时收到视频消息（msgType=video，content 为 URL）', !!aliceVideo && aliceVideoMsg?.data?.mine?.content === mp4Url, JSON.stringify(aliceVideoMsg?.data?.mine ?? null))

  // 入库检查：Alice 会话列表最后一条为 Bob 的视频消息
  await sleep(300)
  const sessAAfterAV = await (await fetch(`${BASE}/chat/sessions`, { headers: { Authorization: `Bearer ${la.body.value}` } })).json()
  const aliceBobAfterAV = sessAAfterAV.find((s) => s.peer.userid === meb.body.id)
  check(
    'Alice 会话列表最后一条为视频消息（msgType=video）',
    aliceBobAfterAV?.lastMessage?.msgType === 'video' && aliceBobAfterAV?.lastMessage?.content === mp4Url,
    JSON.stringify(aliceBobAfterAV?.lastMessage ?? null)
  )

  // 历史接口返回音频/视频消息（刷新后靠它恢复播放）
  const histAfterAV = await (await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(meb.body.id)}`, { headers: { Authorization: `Bearer ${la.body.value}` } })).json()
  const histAudio = histAfterAV.messages.find((m) => m.msgType === 'audio')
  const histVideo = histAfterAV.messages.find((m) => m.msgType === 'video')
  check(
    '历史消息包含音频与视频消息（带 id 与 URL）',
    !!histAudio && histAudio.content === wavUrl && typeof histAudio.id === 'string' && !!histVideo && histVideo.content === mp4Url && typeof histVideo.id === 'string',
    JSON.stringify({ audio: histAudio ?? null, video: histVideo ?? null })
  )

  // 历史音频/视频 URL 重复访问（刷新后可再次加载）
  const wavRes2 = await fetch(`${BASE}${wavUrl}`)
  const mp4Res2 = await fetch(`${BASE}${mp4Url}`)
  check('历史音频/视频 URL 可重复访问', wavRes2.status === 200 && mp4Res2.status === 200, `wav=${wavRes2.status} mp4=${mp4Res2.status}`)

  // 14. 用户查询（issue 05）：按账号或用户 ID 查询，返回公开身份信息，不含敏感字段
  const noAuthUsers = await fetch(`${BASE}/chat/users?q=${encodeURIComponent(bobAccount)}`)
  check('未携带 token 查询用户返回 401', noAuthUsers.status === 401, `status=${noAuthUsers.status}`)

  const noQuery = await fetch(`${BASE}/chat/users`, { headers: { Authorization: `Bearer ${la.body.value}` } })
  check('缺少查询关键字 q 返回 400', noQuery.status === 400, `status=${noQuery.status}`)

  const byAccountRes = await fetch(`${BASE}/chat/users?q=${encodeURIComponent(bobAccount)}`, { headers: { Authorization: `Bearer ${la.body.value}` } })
  const byAccount = await byAccountRes.json()
  check(
    '按账号查询命中并返回公开身份（id/昵称/账号/头像）',
    byAccountRes.status === 200 && byAccount[0]?.id === meb.body.id && byAccount[0]?.account === bobAccount && byAccount[0]?.nickname === 'Bob' && byAccount[0]?.avatar === 'default',
    JSON.stringify(byAccount)
  )

  const byIdRes = await fetch(`${BASE}/chat/users?q=${encodeURIComponent(meb.body.id)}`, { headers: { Authorization: `Bearer ${la.body.value}` } })
  const byId = await byIdRes.json()
  check('按用户 ID 查询命中同一用户', byIdRes.status === 200 && byId[0]?.id === meb.body.id, JSON.stringify(byId))

  const notFoundUser = await (await fetch(`${BASE}/chat/users?q=nobody-${stamp}@test.com`, { headers: { Authorization: `Bearer ${la.body.value}` } })).json()
  check('查无此人返回空数组（前端据此给出明确提示）', Array.isArray(notFoundUser) && notFoundUser.length === 0, JSON.stringify(notFoundUser))

  const userJson = JSON.stringify(byAccount)
  check('用户查询接口不返回密码等敏感字段', !/password/i.test(userJson) && !/hash/i.test(userJson), userJson.slice(0, 160))

  // 15. emoji 文本消息（issue 05）：emoji 即普通文本，不引入协议扩展
  const emojiText = '你好，Bob！🎉😀 表情测试 🚀👍'
  alice.ws.send(JSON.stringify({
    type: 'chatMessage',
    data: {
      mine: { avatar: 'default', content: emojiText, mine: true, userid: mea.body.id, username: aliceAccount, nickname: 'Alice', msgType: 'text' },
      to: { avatar: 'default', userid: meb.body.id, username: bobAccount, nickname: 'Bob' }
    }
  }))
  const bobEmojiOk = await waitUntil(() => bob.inbox.some((m) => m.type === 'chatMessage' && m.data?.mine?.content === emojiText))
  const bobEmojiMsg = bob.inbox.find((m) => m.type === 'chatMessage' && m.data?.mine?.content === emojiText)
  check('Bob 实时收到含 emoji 的文本消息且内容逐字符一致', !!bobEmojiOk, JSON.stringify(bobEmojiMsg?.data?.mine?.content ?? null))
  check('含 emoji 消息仍为 text 类型（无协议扩展）', bobEmojiMsg?.data?.mine?.msgType === 'text', String(bobEmojiMsg?.data?.mine?.msgType))

  await sleep(300)
  const sessEmoji = await (await fetch(`${BASE}/chat/sessions`, { headers: { Authorization: `Bearer ${la.body.value}` } })).json()
  const aliceBobEmoji = sessEmoji.find((s) => s.peer.userid === meb.body.id)
  check(
    '含 emoji 的文本消息入库且会话列表预览内容一致',
    aliceBobEmoji?.lastMessage?.content === emojiText && aliceBobEmoji?.lastMessage?.msgType === 'text',
    JSON.stringify(aliceBobEmoji?.lastMessage ?? null)
  )

  const histEmoji = await (await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(meb.body.id)}`, { headers: { Authorization: `Bearer ${la.body.value}` } })).json()
  const histEmojiMsg = histEmoji.messages.find((m) => m.content === emojiText)
  check('历史接口原样返回含 emoji 的文本消息', !!histEmojiMsg && histEmojiMsg.msgType === 'text', JSON.stringify(histEmojiMsg ?? null))

  // 16. 发起新会话（issue 05）：Alice 查询此前毫无聊天记录的 Carol → 发首条消息 → 双向可收发
  const carolAccount = `carol${stamp}@test.com`
  await register('Carol', carolAccount)
  const lc = await login(carolAccount, 'pass123')
  const mec = await me(lc.body.value)
  const carol = await wsConnect(lc.body.value)

  const carolSessionsBefore = await (await fetch(`${BASE}/chat/sessions`, { headers: { Authorization: `Bearer ${lc.body.value}` } })).json()
  check('新用户初始会话列表为空', Array.isArray(carolSessionsBefore) && carolSessionsBefore.length === 0, JSON.stringify(carolSessionsBefore.map((s) => s.peer.userid)))

  const foundCarol = await (await fetch(`${BASE}/chat/users?q=${encodeURIComponent(carolAccount)}`, { headers: { Authorization: `Bearer ${la.body.value}` } })).json()
  check('Alice 按账号查到 Carol（此前无任何聊天记录）', foundCarol[0]?.id === mec.body.id && foundCarol[0]?.nickname === 'Carol', JSON.stringify(foundCarol))

  const firstText = '你好，Carol！这是我们的第一条消息 🎉'
  alice.ws.send(JSON.stringify({
    type: 'chatMessage',
    data: {
      mine: { avatar: 'default', content: firstText, mine: true, userid: mea.body.id, username: aliceAccount, nickname: 'Alice', msgType: 'text' },
      to: { avatar: 'default', userid: mec.body.id, username: carolAccount, nickname: 'Carol' }
    }
  }))
  const carolFirst = await waitUntil(() => carol.inbox.some((m) => m.type === 'chatMessage' && m.data?.mine?.content === firstText))
  check('新会话首条消息实时送达对端', !!carolFirst, JSON.stringify(carol.inbox.map((m) => m.data?.mine?.content ?? null)))

  await sleep(300)
  const carolSessions = await (await fetch(`${BASE}/chat/sessions`, { headers: { Authorization: `Bearer ${lc.body.value}` } })).json()
  const carolAlice = carolSessions.find((s) => s.peer.userid === mea.body.id)
  check(
    'Carol 会话列表出现与 Alice 的新条目（身份取自 users 表）',
    !!carolAlice && carolAlice.peer.nickname === 'Alice' && carolAlice.peer.username === aliceAccount && carolAlice.lastMessage.content === firstText && carolAlice.lastMessage.fromSelf === false,
    JSON.stringify(carolAlice ?? null)
  )

  const carolHist = await (await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(mea.body.id)}`, { headers: { Authorization: `Bearer ${lc.body.value}` } })).json()
  check('Carol 侧历史消息包含该首条消息', carolHist.messages.length === 1 && carolHist.messages[0].content === firstText && carolHist.messages[0].fromSelf === false, JSON.stringify(carolHist))

  // Carol 回复，Alice 实时收到（新会话双向可收发）
  carol.ws.send(JSON.stringify({
    type: 'chatMessage',
    data: {
      mine: { avatar: 'default', content: '收到啦！👋', mine: true, userid: mec.body.id, username: carolAccount, nickname: 'Carol', msgType: 'text' },
      to: { avatar: 'default', userid: mea.body.id, username: aliceAccount, nickname: 'Alice' }
    }
  }))
  const aliceGotCarol = await waitUntil(() => alice.inbox.some((m) => m.type === 'chatMessage' && m.data?.mine?.userid === mec.body.id))
  check('新会话可双向收发消息（Alice 实时收到 Carol 的回复）', !!aliceGotCarol, '')

  // 伪造发件人无效（issue 06）：Alice 的连接在 payload 里冒用 Bob 的身份发给 Carol，
  // 服务端应以连接绑定的身份覆盖，Carol 看到的发件人仍是 Alice
  alice.ws.send(JSON.stringify({
    type: 'chatMessage',
    data: {
      mine: { avatar: 'default', content: '我冒充 Bob', mine: true, userid: meb.body.id, username: bobAccount, nickname: '假的Bob', msgType: 'text' },
      to: { avatar: 'default', userid: mec.body.id, username: carolAccount, nickname: 'Carol' }
    }
  }))
  const carolSpoof = await waitUntil(() => carol.inbox.some((m) => m.data?.mine?.content === '我冒充 Bob'))
  const spoofMsg = carol.inbox.find((m) => m.data?.mine?.content === '我冒充 Bob')
  check(
    '伪造发件人无效：接收方看到的仍是连接绑定的身份',
    !!carolSpoof && spoofMsg?.data?.mine?.userid === mea.body.id && spoofMsg?.data?.mine?.nickname === 'Alice',
    JSON.stringify(spoofMsg?.data?.mine ?? null)
  )

  // 17. 建群与成员管理（群聊 02）：建群 / 群列表 / 成员列表 / 拉人 / 退群 / 改群信息
  // 带 token 的 JSON 接口统一走这里，省去每处重复拼 header
  async function api(method, path, token, body) {
    const res = await fetch(`${BASE}${path}`, {
      method,
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(body === undefined ? {} : { 'Content-Type': 'application/json' })
      },
      body: body === undefined ? undefined : JSON.stringify(body)
    })
    return { status: res.status, body: await res.json().catch(() => ({})) }
  }

  // Dave：先当非成员（验证越权被拒），稍后被拉入群；Eve：始终是非成员
  const daveAccount = `dave${stamp}@test.com`
  await register('Dave', daveAccount)
  const ld = await login(daveAccount, 'pass123')
  const med = await me(ld.body.value)
  const eveAccount = `eve${stamp}@test.com`
  await register('Eve', eveAccount)
  const le = await login(eveAccount, 'pass123')
  const mee = await me(le.body.value)

  // 17.1 鉴权：未携带 token 一律 401
  for (const [name, method, path, body] of [
    ['访问群列表', 'GET', '/chat/groups', undefined],
    ['建群', 'POST', '/chat/groups', { name: '无 token 建群' }],
    ['查看群成员', 'GET', `/chat/groups/${crypto.randomUUID()}/members`, undefined]
  ]) {
    const res = await api(method, path, null, body)
    check(`未携带 token ${name}返回 401`, res.status === 401, `status=${res.status}`)
  }

  // 17.2 建群：创建者自动入群且为 owner
  const createRes = await api('POST', '/chat/groups', la.body.value, {
    name: '三人群',
    memberIds: [meb.body.id, mec.body.id]
  })
  check(
    '建群成功：创建者自动入群且为 owner，成员数 = 3',
    createRes.status === 200 && createRes.body.name === '三人群' && createRes.body.ownerId === mea.body.id && createRes.body.memberCount === 3 && createRes.body.avatar === 'default',
    JSON.stringify(createRes.body)
  )
  const groupId = createRes.body.id
  check('建群返回群 id 与创建时间', typeof groupId === 'string' && typeof createRes.body.createdAt === 'number', JSON.stringify(createRes.body))

  // 17.3 成员存在性校验：不存在的用户 id 返回明确错误，不静默丢弃
  const ghostCreate = await api('POST', '/chat/groups', la.body.value, { name: '含幽灵成员', memberIds: [crypto.randomUUID()] })
  check('建群传入不存在的用户 id 返回明确错误', ghostCreate.status === 400 && /不存在/.test(ghostCreate.body.reason ?? ''), `status=${ghostCreate.status} ${ghostCreate.body.reason ?? ''}`)
  const badIdCreate = await api('POST', '/chat/groups', la.body.value, { name: '含非法 id', memberIds: ['not-a-uuid'] })
  check('建群传入非法用户 id 返回明确错误', badIdCreate.status === 400 && /格式不正确/.test(badIdCreate.body.reason ?? ''), `status=${badIdCreate.status} ${badIdCreate.body.reason ?? ''}`)
  const emptyNameCreate = await api('POST', '/chat/groups', la.body.value, { name: '   ', memberIds: [] })
  check('群名称为空被拒', emptyNameCreate.status === 400 && /群名称不能为空/.test(emptyNameCreate.body.reason ?? ''), `status=${emptyNameCreate.status} ${emptyNameCreate.body.reason ?? ''}`)

  // 17.4 成员数上限 200：建群与拉人共用同一处校验
  const tooManyIds = Array.from({ length: 200 }, () => crypto.randomUUID())
  const overLimit = await api('POST', '/chat/groups', la.body.value, { name: '超出上限', memberIds: tooManyIds })
  check('建群成员数超过 200 被拒且错误明确', overLimit.status === 400 && /不能超过 200 人/.test(overLimit.body.reason ?? ''), `status=${overLimit.status} ${overLimit.body.reason ?? ''}`)

  // 17.5 群列表：只返回我加入的群
  const listA = await api('GET', '/chat/groups', la.body.value)
  check(
    '我的群列表包含刚创建的群（含成员数与创建者）',
    listA.status === 200 && listA.body.some((g) => g.id === groupId && g.memberCount === 3 && g.ownerId === mea.body.id),
    JSON.stringify(listA.body.map((g) => [g.name, g.memberCount]))
  )
  const listB = await api('GET', '/chat/groups', lb.body.value)
  check('被拉入群的人（Bob）群列表出现该群', listB.status === 200 && listB.body.some((g) => g.id === groupId), JSON.stringify(listB.body.map((g) => g.id)))
  const listD = await api('GET', '/chat/groups', ld.body.value)
  check('非成员（Dave）的群列表不含该群', listD.status === 200 && !listD.body.some((g) => g.id === groupId), JSON.stringify(listD.body.map((g) => g.id)))

  // 17.6 成员列表：非成员访问被拒
  const membersRes = await api('GET', `/chat/groups/${groupId}/members`, la.body.value)
  check(
    '成员列表返回全部成员，身份取自 users 表',
    membersRes.status === 200 && membersRes.body.length === 3 &&
      membersRes.body.some((m) => m.userid === meb.body.id && m.nickname === 'Bob' && m.username === bobAccount && m.avatar === 'default'),
    JSON.stringify(membersRes.body.map((m) => m.nickname))
  )
  check('成员列表含入群时间', typeof membersRes.body[0]?.joinedAt === 'number', JSON.stringify(membersRes.body[0] ?? null))
  const outsiderMembers = await api('GET', `/chat/groups/${groupId}/members`, ld.body.value)
  check('非成员查看成员列表被拒（403）', outsiderMembers.status === 403 && /不是该群成员/.test(outsiderMembers.body.reason ?? ''), `status=${outsiderMembers.status} ${outsiderMembers.body.reason ?? ''}`)
  const noGroupMembers = await api('GET', `/chat/groups/${crypto.randomUUID()}/members`, la.body.value)
  check('查看不存在的群的成员返回 404', noGroupMembers.status === 404, `status=${noGroupMembers.status}`)

  // 17.7 拉人入群：任何成员都可以，被拉入无需本人同意
  const bobAdds = await api('POST', `/chat/groups/${groupId}/members`, lb.body.value, { userId: med.body.id })
  check('任何成员都可以拉人入群（Bob 拉入 Dave，成员数 = 4）', bobAdds.status === 200 && bobAdds.body.memberCount === 4, JSON.stringify(bobAdds.body))
  const listDAfterJoin = await api('GET', '/chat/groups', ld.body.value)
  check('被拉入者（Dave）的群列表立即出现该群', listDAfterJoin.body.some((g) => g.id === groupId), JSON.stringify(listDAfterJoin.body.map((g) => g.id)))
  const dupAdd = await api('POST', `/chat/groups/${groupId}/members`, la.body.value, { userId: med.body.id })
  check('重复拉入已在群内的用户返回 409', dupAdd.status === 409 && /已在群内/.test(dupAdd.body.reason ?? ''), `status=${dupAdd.status} ${dupAdd.body.reason ?? ''}`)
  const ghostAdd = await api('POST', `/chat/groups/${groupId}/members`, la.body.value, { userId: crypto.randomUUID() })
  check('拉入不存在的用户返回明确错误', ghostAdd.status === 400 && /不存在/.test(ghostAdd.body.reason ?? ''), `status=${ghostAdd.status} ${ghostAdd.body.reason ?? ''}`)
  const outsiderAdd = await api('POST', `/chat/groups/${groupId}/members`, le.body.value, { userId: mee.body.id })
  check('非成员拉人入群被拒（403）', outsiderAdd.status === 403 && /不是该群成员/.test(outsiderAdd.body.reason ?? ''), `status=${outsiderAdd.status} ${outsiderAdd.body.reason ?? ''}`)

  // 17.8 退群：只能退自己，不能踢人
  const kickRes = await api('DELETE', `/chat/groups/${groupId}/members/${meb.body.id}`, la.body.value)
  check('创建者也不能移出其他成员（403）', kickRes.status === 403 && /不能移出其他成员/.test(kickRes.body.reason ?? ''), `status=${kickRes.status} ${kickRes.body.reason ?? ''}`)
  const leaveRes = await api('DELETE', `/chat/groups/${groupId}/members/${meb.body.id}`, lb.body.value)
  check('可以退自己所在的群，成员数减少到 3', leaveRes.status === 200 && leaveRes.body.memberCount === 3, JSON.stringify(leaveRes.body))
  const listBAfterLeave = await api('GET', '/chat/groups', lb.body.value)
  check('退群后该群从我的群列表消失', !listBAfterLeave.body.some((g) => g.id === groupId), JSON.stringify(listBAfterLeave.body.map((g) => g.id)))
  const membersAfterLeave = await api('GET', `/chat/groups/${groupId}/members`, lb.body.value)
  check('退群后失去该群访问权（查看成员 403）', membersAfterLeave.status === 403, `status=${membersAfterLeave.status}`)
  const leaveAgain = await api('DELETE', `/chat/groups/${groupId}/members/${meb.body.id}`, lb.body.value)
  check('重复退群返回 403（已不是成员）', leaveAgain.status === 403 && /无法退群/.test(leaveAgain.body.reason ?? ''), `status=${leaveAgain.status} ${leaveAgain.body.reason ?? ''}`)

  // 17.9 改群名/头像：仅创建者
  const carolPatch = await api('PATCH', `/chat/groups/${groupId}`, lc.body.value, { name: '被非创建者改名' })
  check('非创建者改群名被拒（403）', carolPatch.status === 403 && /只有群创建者/.test(carolPatch.body.reason ?? ''), `status=${carolPatch.status} ${carolPatch.body.reason ?? ''}`)
  const patchRes = await api('PATCH', `/chat/groups/${groupId}`, la.body.value, { name: '三人群（已改名）', avatar: 'group-avatar' })
  check('创建者可改群名与头像', patchRes.status === 200 && patchRes.body.name === '三人群（已改名）' && patchRes.body.avatar === 'group-avatar', JSON.stringify(patchRes.body))
  const listAfterPatch = await api('GET', '/chat/groups', lc.body.value)
  check('改名后其他成员看到的群名同步更新', listAfterPatch.body.find((g) => g.id === groupId)?.name === '三人群（已改名）', JSON.stringify(listAfterPatch.body.map((g) => g.name)))
  const patchOnlyAvatar = await api('PATCH', `/chat/groups/${groupId}`, la.body.value, { avatar: 'group-avatar-2' })
  check('可以只改头像（群名不变）', patchOnlyAvatar.status === 200 && patchOnlyAvatar.body.avatar === 'group-avatar-2' && patchOnlyAvatar.body.name === '三人群（已改名）', JSON.stringify(patchOnlyAvatar.body))
  const emptyNamePatch = await api('PATCH', `/chat/groups/${groupId}`, la.body.value, { name: '   ' })
  check('群名改为空被拒（400）', emptyNamePatch.status === 400 && /群名称不能为空/.test(emptyNamePatch.body.reason ?? ''), `status=${emptyNamePatch.status} ${emptyNamePatch.body.reason ?? ''}`)
  const noFieldPatch = await api('PATCH', `/chat/groups/${groupId}`, la.body.value, {})
  check('不带任何字段的修改被拒（400）', noFieldPatch.status === 400 && /缺少要修改/.test(noFieldPatch.body.reason ?? ''), `status=${noFieldPatch.status} ${noFieldPatch.body.reason ?? ''}`)
  const noGroupPatch = await api('PATCH', `/chat/groups/${crypto.randomUUID()}`, la.body.value, { name: '不存在的群' })
  check('修改不存在的群返回 404', noGroupPatch.status === 404, `status=${noGroupPatch.status}`)

  // 18. 群消息端到端流转（群聊 03）：扇出 → 入库 → 历史 → 会话列表
  // Alice/Bob/Carol 三人各持一条在线连接；Eve 也建连接，用于验证「非成员收不到」
  const chatGroupRes = await api('POST', '/chat/groups', la.body.value, {
    name: '消息流转群',
    memberIds: [meb.body.id, mec.body.id]
  })
  const chatGroupId = chatGroupRes.body.id
  check('建群成功：Alice/Bob/Carol 三人', chatGroupRes.status === 200 && chatGroupRes.body.memberCount === 3, JSON.stringify(chatGroupRes.body))

  const eve = await wsConnect(le.body.value)

  // 群消息：data.to 增加 type=group，userid 位置填群 id（ADR-0002：扩展现有协议）
  function sendGroupMessage(ws, me, content, msgType) {
    ws.send(JSON.stringify({
      type: 'chatMessage',
      data: {
        mine: {
          avatar: me.avatar, content, mine: true,
          userid: me.id, username: me.account, nickname: me.nickname,
          ...(msgType ? { msgType } : {})
        },
        to: { avatar: 'default', userid: chatGroupId, username: '', nickname: '', type: 'group' }
      }
    }))
  }

  const gAlice1 = '群-1：大家好'
  sendGroupMessage(alice.ws, mea.body, gAlice1, 'text')
  const bobGotG1 = await waitUntil(() => bob.inbox.some((m) => m.data?.mine?.content === gAlice1))
  const carolGotG1 = await waitUntil(() => carol.inbox.some((m) => m.data?.mine?.content === gAlice1))
  const bobG1 = bob.inbox.find((m) => m.data?.mine?.content === gAlice1)
  const carolG1 = carol.inbox.find((m) => m.data?.mine?.content === gAlice1)
  check('群消息扇出：Bob 与 Carol 各收到一份', !!bobGotG1 && !!carolGotG1, JSON.stringify([bobG1?.data?.mine?.content, carolG1?.data?.mine?.content]))
  check('扇出的两份是同一条消息（id 一致）', typeof bobG1?.data?.id === 'string' && bobG1?.data?.id === carolG1?.data?.id, JSON.stringify([bobG1?.data?.id, carolG1?.data?.id]))
  check('推送的收件主体为群（to.type=group、to.userid=群 id）', bobG1?.data?.to?.type === 'group' && bobG1?.data?.to?.userid === chatGroupId, JSON.stringify(bobG1?.data?.to ?? null))
  check('群消息推送带服务端时间戳', typeof bobG1?.data?.timestamp === 'number', JSON.stringify(bobG1?.data?.timestamp))
  const aliceAckG1 = await waitUntil(() => alice.inbox.some((m) => m.type === 'chatMessageAck' && m.data?.content === gAlice1))
  check('发送者收到群消息确认（ack）', !!aliceAckG1, '')
  check('发送者自己不回推群消息', !alice.inbox.some((m) => m.type === 'chatMessage' && m.data?.mine?.content === gAlice1), '')

  // 三连接同群互发：Bob →（Alice + Carol）、Carol →（Alice + Bob）
  const gBob2 = '群-2：Bob 收到'
  sendGroupMessage(bob.ws, meb.body, gBob2, 'text')
  await waitUntil(() => alice.inbox.some((m) => m.data?.mine?.content === gBob2) && carol.inbox.some((m) => m.data?.mine?.content === gBob2))
  const aliceG2 = alice.inbox.find((m) => m.data?.mine?.content === gBob2)
  const carolG2 = carol.inbox.find((m) => m.data?.mine?.content === gBob2)
  check('Bob 的群消息扇出给 Alice 与 Carol', !!aliceG2 && !!carolG2, JSON.stringify([aliceG2?.data?.mine?.content, carolG2?.data?.mine?.content]))
  check('群聊推送携带发送者真实昵称（气泡据此渲染）', aliceG2?.data?.mine?.nickname === 'Bob' && aliceG2?.data?.mine?.userid === meb.body.id, JSON.stringify(aliceG2?.data?.mine ?? null))

  const gCarol3 = '群-3：Carol 也在'
  sendGroupMessage(carol.ws, mec.body, gCarol3, 'text')
  await waitUntil(() => alice.inbox.some((m) => m.data?.mine?.content === gCarol3) && bob.inbox.some((m) => m.data?.mine?.content === gCarol3))
  check('Carol 的群消息扇出给 Alice 与 Bob（三连接同群互发）', alice.inbox.some((m) => m.data?.mine?.content === gCarol3) && bob.inbox.some((m) => m.data?.mine?.content === gCarol3), '')

  // 群聊同样以连接绑定的身份为准：Alice 在 payload 里冒用 Dave 的身份
  const gSpoof = '群-4：我冒充 Dave'
  alice.ws.send(JSON.stringify({
    type: 'chatMessage',
    data: {
      mine: { avatar: 'hacker', content: gSpoof, mine: true, userid: med.body.id, username: daveAccount, nickname: '假的Dave', msgType: 'text' },
      to: { avatar: 'default', userid: chatGroupId, username: '', nickname: '', type: 'group' }
    }
  }))
  const spoofGot = await waitUntil(() => bob.inbox.some((m) => m.data?.mine?.content === gSpoof))
  const gSpoofMsg = bob.inbox.find((m) => m.data?.mine?.content === gSpoof)
  check('群聊伪造发件人无效：接收方看到的仍是连接绑定的身份', !!spoofGot && gSpoofMsg?.data?.mine?.userid === mea.body.id && gSpoofMsg?.data?.mine?.nickname === 'Alice', JSON.stringify(gSpoofMsg?.data?.mine ?? null))

  // 未携带 msgType 的群消息按 text 处理
  const gNoType = '群-5：不带 msgType'
  sendGroupMessage(bob.ws, meb.body, gNoType)
  await waitUntil(() => alice.inbox.some((m) => m.data?.mine?.content === gNoType))
  check('未携带 msgType 的群消息正常扇出', alice.inbox.some((m) => m.data?.mine?.content === gNoType), '')

  // 非成员发群消息被拒
  const gEve = '群-6：Eve 想混进来'
  sendGroupMessage(eve.ws, mee.body, gEve, 'text')
  const eveRejected = await waitUntil(() => eve.inbox.some((m) => m.type === 'chatMessageError'))
  const eveError = eve.inbox.find((m) => m.type === 'chatMessageError')
  check('非成员发群消息被拒（chatMessageError）', !!eveRejected && /不是该群成员/.test(eveError?.data?.reason ?? ''), JSON.stringify(eveError ?? null))
  await sleep(300)
  check('被拒的群消息不扇出给任何成员', !alice.inbox.some((m) => m.data?.mine?.content === gEve) && !bob.inbox.some((m) => m.data?.mine?.content === gEve) && !carol.inbox.some((m) => m.data?.mine?.content === gEve), '')
  check('非成员收不到群消息（Eve 的连接只收到错误帧）', !eve.inbox.some((m) => m.type === 'chatMessage'), JSON.stringify(eve.inbox.map((m) => m.type)))

  // 群历史：peer 直接传群 id
  const gHistRes = await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(chatGroupId)}`, { headers: { Authorization: `Bearer ${la.body.value}` } })
  const gHist = gHistRes.status === 200 ? await gHistRes.json() : { messages: [], hasMore: false }
  const gHistContents = gHist.messages.map((m) => m.content)
  check(
    '群历史返回全部 5 条群消息（按时间正序）',
    gHistRes.status === 200 && gHistContents.length === 5 && [gAlice1, gBob2, gCarol3, gSpoof, gNoType].every((t) => gHistContents.includes(t)),
    JSON.stringify(gHistContents)
  )
  check(
    '群历史方向正确（fromSelf）',
    gHist.messages.find((m) => m.content === gAlice1)?.fromSelf === true && gHist.messages.find((m) => m.content === gBob2)?.fromSelf === false,
    JSON.stringify(gHist.messages.map((m) => [m.content, m.fromSelf]))
  )
  check(
    '群历史带发送者身份（昵称与 id，渲染群气泡用）',
    gHist.messages.find((m) => m.content === gBob2)?.senderNickname === 'Bob' && gHist.messages.find((m) => m.content === gBob2)?.senderUserId === meb.body.id,
    JSON.stringify(gHist.messages.find((m) => m.content === gBob2) ?? null)
  )
  check('未携带 msgType 的群消息按 text 入库', gHist.messages.find((m) => m.content === gNoType)?.msgType === 'text', JSON.stringify(gHist.messages.find((m) => m.content === gNoType) ?? null))
  check(
    '伪造发件人的群消息以服务端身份入库',
    gHist.messages.find((m) => m.content === gSpoof)?.senderNickname === 'Alice' && gHist.messages.find((m) => m.content === gSpoof)?.fromSelf === true,
    JSON.stringify(gHist.messages.find((m) => m.content === gSpoof) ?? null)
  )
  check('被拒的非成员消息不在群历史里', !gHistContents.includes(gEve), JSON.stringify(gHistContents))

  const gPage1 = await (await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(chatGroupId)}&limit=2`, { headers: { Authorization: `Bearer ${la.body.value}` } })).json()
  check('群历史支持分页（limit=2，hasMore=true）', gPage1.messages.length === 2 && gPage1.hasMore === true && gPage1.messages[1]?.content === gNoType, JSON.stringify(gPage1.messages.map((m) => m.content)))

  const eveGHistRes = await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(chatGroupId)}`, { headers: { Authorization: `Bearer ${le.body.value}` } })
  check('非成员查群历史被拒（403，不返回空数组）', eveGHistRes.status === 403 && /不是该群成员/.test((await eveGHistRes.json()).reason ?? ''), `status=${eveGHistRes.status}`)

  // 离线成员靠历史补回：Dave 入群但不建 WS 连接
  const daveJoin = await api('POST', `/chat/groups/${chatGroupId}/members`, la.body.value, { userId: med.body.id })
  check('拉 Dave 入群（成员数 4）', daveJoin.status === 200 && daveJoin.body.memberCount === 4, JSON.stringify(daveJoin.body))
  const gOffline = '群-7：Dave 离线时错过的'
  sendGroupMessage(alice.ws, mea.body, gOffline, 'text')
  await sleep(300)
  const daveGHist = await (await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(chatGroupId)}`, { headers: { Authorization: `Bearer ${ld.body.value}` } })).json()
  check(
    '离线成员靠历史补回群消息（且只看得到入群之后的）',
    daveGHist.messages.length === 1 && daveGHist.messages[0].content === gOffline && daveGHist.messages[0].fromSelf === false && daveGHist.messages[0].senderNickname === 'Alice',
    JSON.stringify(daveGHist.messages.map((m) => m.content))
  )
  const sessDave = await (await fetch(`${BASE}/chat/sessions`, { headers: { Authorization: `Bearer ${ld.body.value}` } })).json()
  const daveGroupSession = sessDave.find((s) => s.peer.userid === chatGroupId)
  check('入群后的群会话出现在该成员会话列表，预览为入群后的消息', daveGroupSession?.kind === 'group' && daveGroupSession?.lastMessage?.content === gOffline, JSON.stringify(daveGroupSession ?? null))

  // 会话列表：群会话与单聊会话一起返回
  await sleep(300)
  const sessGroupA = await (await fetch(`${BASE}/chat/sessions`, { headers: { Authorization: `Bearer ${la.body.value}` } })).json()
  const groupSession = sessGroupA.find((s) => s.peer.userid === chatGroupId)
  check(
    '会话列表出现群会话（kind=group + 群名 + 成员数）',
    groupSession?.kind === 'group' && groupSession?.peer.nickname === '消息流转群' && groupSession?.memberCount === 4,
    JSON.stringify(groupSession ?? null)
  )
  check('群会话最后一条为最新的群消息', groupSession?.lastMessage?.content === gOffline && groupSession?.lastMessage?.fromSelf === true, JSON.stringify(groupSession?.lastMessage ?? null))
  const directWithBob = sessGroupA.find((s) => s.kind === 'direct' && s.peer.userid === meb.body.id)
  check('单聊会话标记为 kind=direct 且不带成员数', !!directWithBob && directWithBob.memberCount == null, JSON.stringify(directWithBob ?? null))
  check('群会话与单聊会话按最后消息时间倒序（最新群消息置顶）', sessGroupA[0]?.peer.userid === chatGroupId, JSON.stringify(sessGroupA.map((s) => [s.kind, s.peer.userid])))

  // 入群前已存在的消息，入群后看不到（决策记录第 4 条：重新加入不回溯旧消息）
  const eveJoinRes = await api('POST', `/chat/groups/${chatGroupId}/members`, la.body.value, { userId: mee.body.id })
  check('把 Eve 拉入群（成员数 5）', eveJoinRes.status === 200 && eveJoinRes.body.memberCount === 5, JSON.stringify(eveJoinRes.body))
  const eveHistBefore = await (await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(chatGroupId)}`, { headers: { Authorization: `Bearer ${le.body.value}` } })).json()
  check('入群后仍看不到入群前的历史', eveHistBefore.messages.length === 0, JSON.stringify(eveHistBefore.messages.map((m) => m.content)))
  const sessEve = await (await fetch(`${BASE}/chat/sessions`, { headers: { Authorization: `Bearer ${le.body.value}` } })).json()
  check('没有入群后消息的群不出现在会话列表', !sessEve.some((s) => s.peer.userid === chatGroupId), JSON.stringify(sessEve.map((s) => [s.kind, s.peer.userid])))

  const gAfterEve = '群-8：Eve 入群之后才有的'
  sendGroupMessage(alice.ws, mea.body, gAfterEve, 'text')
  await sleep(300)
  const eveHistAfter = await (await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(chatGroupId)}`, { headers: { Authorization: `Bearer ${le.body.value}` } })).json()
  check('入群之后的新消息可见（且仍看不到入群前的）', eveHistAfter.messages.length === 1 && eveHistAfter.messages[0].content === gAfterEve, JSON.stringify(eveHistAfter.messages.map((m) => m.content)))
  check('入群后可实时收到群消息', eve.inbox.some((m) => m.data?.mine?.content === gAfterEve), JSON.stringify(eve.inbox.map((m) => m.data?.mine?.content ?? m.type)))

  // 退群后：群会话从会话列表消失、群历史不可查
  await api('DELETE', `/chat/groups/${chatGroupId}/members/${meb.body.id}`, lb.body.value)
  await sleep(300)
  const sessBAfterLeave = await (await fetch(`${BASE}/chat/sessions`, { headers: { Authorization: `Bearer ${lb.body.value}` } })).json()
  check('退群后群会话从会话列表消失', !sessBAfterLeave.some((s) => s.peer.userid === chatGroupId), JSON.stringify(sessBAfterLeave.map((s) => [s.kind, s.peer.userid])))
  const bobGHistRes = await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(chatGroupId)}`, { headers: { Authorization: `Bearer ${lb.body.value}` } })
  check('退群后查群历史被拒（403）', bobGHistRes.status === 403, `status=${bobGHistRes.status}`)

  // 单聊行为不变（回归）：不带 to.type 的消息仍按单聊投递
  const dmAfterGroup = '群聊落地后单聊照常'
  alice.ws.send(JSON.stringify({
    type: 'chatMessage',
    data: {
      mine: { avatar: mea.body.avatar, content: dmAfterGroup, mine: true, userid: mea.body.id, username: aliceAccount, nickname: 'Alice', msgType: 'text' },
      to: { avatar: 'default', userid: meb.body.id, username: bobAccount, nickname: 'Bob' }
    }
  }))
  const bobDmOk = await waitUntil(() => bob.inbox.some((m) => m.data?.mine?.content === dmAfterGroup))
  const bobDmMsg = bob.inbox.find((m) => m.data?.mine?.content === dmAfterGroup)
  check('单聊行为不变：不带 to.type 的消息仍按单聊投递', !!bobDmOk, '')
  check('单聊推送的收件主体为 user（协议扩展不破坏旧格式）', bobDmMsg?.data?.to?.type === 'user' && bobDmMsg?.data?.to?.userid === meb.body.id, JSON.stringify(bobDmMsg?.data?.to ?? null))
  await sleep(300)
  const gHistFinal = await (await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(chatGroupId)}`, { headers: { Authorization: `Bearer ${la.body.value}` } })).json()
  check('单聊消息不会串进群历史', !gHistFinal.messages.some((m) => m.content === dmAfterGroup), JSON.stringify(gHistFinal.messages.map((m) => m.content)))
  const dmHistFinal = await (await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(meb.body.id)}`, { headers: { Authorization: `Bearer ${la.body.value}` } })).json()
  check('单聊消息仍进单聊历史', dmHistFinal.messages.some((m) => m.content === dmAfterGroup), JSON.stringify(dmHistFinal.messages.map((m) => m.content)))

  // 19. 未读计数（未读 02）：服务端算未读 → 标记已读 → 位点持久化
  // 用全新账号，避免与前面用例的消息混在一起算不清
  const u1Account = `u1${stamp}@test.com`
  const u2Account = `u2${stamp}@test.com`
  const u3Account = `u3${stamp}@test.com`
  const u4Account = `u4${stamp}@test.com`
  await register('U1', u1Account)
  await register('U2', u2Account)
  await register('U3', u3Account)
  await register('U4', u4Account)
  const l1 = await login(u1Account, 'pass123')
  const l2 = await login(u2Account, 'pass123')
  const l3 = await login(u3Account, 'pass123')
  const l4 = await login(u4Account, 'pass123')
  const m1 = await me(l1.body.value)
  const m2 = await me(l2.body.value)
  const m3 = await me(l3.body.value)

  const sessionsOf = async (token) =>
    (await fetch(`${BASE}/chat/sessions`, { headers: { Authorization: `Bearer ${token}` } })).json()
  // 取某个收件主体的未读数（单聊按对方 id，群聊按群 id）；会话不存在时为 undefined
  const unreadOf = async (token, peerId) =>
    (await sessionsOf(token)).find((s) => s.peer.userid === peerId)?.unreadCount

  const u1 = await wsConnect(l1.body.value)
  const u2 = await wsConnect(l2.body.value)
  function sendTo(ws, me, peerId, type, content, msgType = 'text') {
    ws.send(JSON.stringify({
      type: 'chatMessage',
      data: {
        mine: { avatar: 'default', content, mine: true, userid: me.id, username: me.account, nickname: me.nickname, msgType },
        to: { avatar: 'default', userid: peerId, username: '', nickname: '', type }
      }
    }))
  }
  // 发出并等消息落库（会话列表与未读都读库）
  async function sendAndSettle(ws, me, peerId, type, content, msgType = 'text') {
    sendTo(ws, me, peerId, type, content, msgType)
    await sleep(300)
  }
  // 最近一条已入库消息的服务端 id（发送方收到的 ack 里带）
  function lastAckedId(inbox) {
    for (let i = inbox.length - 1; i >= 0; i -= 1) {
      if (inbox[i].type === 'chatMessageAck' && inbox[i].data?.id) return inbox[i].data.id
    }
    return null
  }

  // 19.1 无位点时全部计入未读（决策记录第 2 条：能看到就等于可能未读）
  await sendAndSettle(u1.ws, m1.body, m2.body.id, 'user', '未读-1：U1 发给 U2')
  await sendAndSettle(u1.ws, m1.body, m2.body.id, 'user', '未读-2：U1 又发一条')
  await sendAndSettle(u2.ws, m2.body, m1.body.id, 'user', '未读-3：U2 回一条')
  const sessU1 = await sessionsOf(l1.body.value)
  check('会话列表每个条目都带 unreadCount', sessU1.length > 0 && sessU1.every((s) => typeof s.unreadCount === 'number'), JSON.stringify(sessU1.map((s) => [s.kind, s.unreadCount])))
  check('无位点时全部计入未读（U2 未读 = 2）', (await unreadOf(l2.body.value, m1.body.id)) === 2, `unread=${await unreadOf(l2.body.value, m1.body.id)}`)
  check('自己发出的消息不计入未读（U1 未读 = 1，不是 3）', (await unreadOf(l1.body.value, m2.body.id)) === 1, `unread=${await unreadOf(l1.body.value, m2.body.id)}`)

  // 19.2 标记已读：位点是服务端的，重新拉取（刷新页面）不会丢
  const readRes = await api('POST', '/chat/read', l1.body.value, { recipientId: m2.body.id })
  check(
    '标记已读返回收件主体与位点（Unix 秒）',
    readRes.status === 200 && readRes.body.recipientId === m2.body.id && typeof readRes.body.lastReadAt === 'number',
    JSON.stringify(readRes.body)
  )
  check('标记已读后该会话未读清零', (await unreadOf(l1.body.value, m2.body.id)) === 0, `unread=${await unreadOf(l1.body.value, m2.body.id)}`)
  check('重新拉取会话列表未读仍为 0（刷新后保持，服务端是权威来源）', (await unreadOf(l1.body.value, m2.body.id)) === 0, `unread=${await unreadOf(l1.body.value, m2.body.id)}`)
  check('标记已读不影响对方的未读（U2 未读仍为 2）', (await unreadOf(l2.body.value, m1.body.id)) === 2, `unread=${await unreadOf(l2.body.value, m1.body.id)}`)

  // 19.3 位点之后的新消息继续累加（重复标记是更新同一条位点）
  await sendAndSettle(u2.ws, m2.body, m1.body.id, 'user', '未读-4：U1 已读之后到')
  await sendAndSettle(u2.ws, m2.body, m1.body.id, 'user', '未读-5：再来一条')
  check('位点之后的新消息继续计入未读（U1 未读 = 2）', (await unreadOf(l1.body.value, m2.body.id)) === 2, `unread=${await unreadOf(l1.body.value, m2.body.id)}`)
  const reread = await api('POST', '/chat/read', l1.body.value, { recipientId: m2.body.id })
  check('重复标记已读是更新同一条位点（不报错、位点前进）', reread.status === 200 && reread.body.lastReadAt > readRes.body.lastReadAt, JSON.stringify([readRes.body, reread.body]))

  // 19.4 群消息同样计入未读，且与单聊位点互不串
  const unreadGroupRes = await api('POST', '/chat/groups', l1.body.value, { name: '未读群', memberIds: [m2.body.id] })
  const unreadGroupId = unreadGroupRes.body.id
  check('建未读群成功（U1 + U2）', unreadGroupRes.status === 200 && unreadGroupRes.body.memberCount === 2, JSON.stringify(unreadGroupRes.body))
  await sendAndSettle(u1.ws, m1.body, unreadGroupId, 'group', '未读群-1')
  await sendAndSettle(u1.ws, m1.body, unreadGroupId, 'group', '未读群-2')
  check('群消息计入未读（U2 群未读 = 2）', (await unreadOf(l2.body.value, unreadGroupId)) === 2, `unread=${await unreadOf(l2.body.value, unreadGroupId)}`)
  check('自己发的群消息不计入未读（U1 群未读 = 0）', (await unreadOf(l1.body.value, unreadGroupId)) === 0, `unread=${await unreadOf(l1.body.value, unreadGroupId)}`)
  check('群未读与单聊未读互不串（U2 单聊未读仍为 2）', (await unreadOf(l2.body.value, m1.body.id)) === 2, `unread=${await unreadOf(l2.body.value, m1.body.id)}`)
  const groupRead = await api('POST', '/chat/read', l2.body.value, { recipientId: unreadGroupId })
  check('给群标记已读后群未读清零', groupRead.status === 200 && (await unreadOf(l2.body.value, unreadGroupId)) === 0, JSON.stringify(groupRead.body))

  // 19.5 入群之前的群消息不计入未读（看不到就不算未读）
  const u3Join = await api('POST', `/chat/groups/${unreadGroupId}/members`, l1.body.value, { userId: m3.body.id })
  check('把 U3 拉进未读群（成员数 3）', u3Join.status === 200 && u3Join.body.memberCount === 3, JSON.stringify(u3Join.body))
  check('入群前的群消息不计入未读（U3 看不到该群会话）', !(await sessionsOf(l3.body.value)).some((s) => s.peer.userid === unreadGroupId), JSON.stringify((await sessionsOf(l3.body.value)).map((s) => [s.kind, s.peer.userid])))
  await sendAndSettle(u1.ws, m1.body, unreadGroupId, 'group', '未读群-3：U3 入群之后到')
  check('入群之后的新群消息计入未读（U3 群未读 = 1）', (await unreadOf(l3.body.value, unreadGroupId)) === 1, `unread=${await unreadOf(l3.body.value, unreadGroupId)}`)

  // 19.6 非成员既不产生该群未读，也不能给它标记已读
  check('非成员的会话列表不出现该群（U4）', !(await sessionsOf(l4.body.value)).some((s) => s.peer.userid === unreadGroupId), JSON.stringify((await sessionsOf(l4.body.value)).map((s) => [s.kind, s.peer.userid])))
  const outsiderRead = await api('POST', '/chat/read', l4.body.value, { recipientId: unreadGroupId })
  check('非成员给群标记已读被拒（403）', outsiderRead.status === 403 && /不是该群成员/.test(outsiderRead.body.reason ?? ''), `status=${outsiderRead.status} ${outsiderRead.body.reason ?? ''}`)

  // 19.7 退群后不再产生该群未读
  const u2Leave = await api('DELETE', `/chat/groups/${unreadGroupId}/members/${m2.body.id}`, l2.body.value)
  check('U2 退群成功', u2Leave.status === 200, JSON.stringify(u2Leave.body))
  await sendAndSettle(u1.ws, m1.body, unreadGroupId, 'group', '未读群-4：U2 退群之后到')
  check('退群后该群不再出现在会话列表（不再产生未读）', !(await sessionsOf(l2.body.value)).some((s) => s.peer.userid === unreadGroupId), JSON.stringify((await sessionsOf(l2.body.value)).map((s) => [s.kind, s.peer.userid])))
  const u2ReadAfterLeave = await api('POST', '/chat/read', l2.body.value, { recipientId: unreadGroupId })
  check('退群后给该群标记已读被拒（403）', u2ReadAfterLeave.status === 403, `status=${u2ReadAfterLeave.status}`)

  // 19.8 参数校验与鉴权
  const readNoToken = await api('POST', '/chat/read', null, { recipientId: m2.body.id })
  check('未携带 token 标记已读返回 401', readNoToken.status === 401, `status=${readNoToken.status}`)
  const readSelf = await api('POST', '/chat/read', l1.body.value, { recipientId: m1.body.id })
  check('给自己标记已读被拒（400）', readSelf.status === 400 && /不能标记/.test(readSelf.body.reason ?? ''), `status=${readSelf.status} ${readSelf.body.reason ?? ''}`)
  const readNoId = await api('POST', '/chat/read', l1.body.value, {})
  check('缺少 recipientId 返回 400', readNoId.status === 400 && /缺少/.test(readNoId.body.reason ?? ''), `status=${readNoId.status} ${readNoId.body.reason ?? ''}`)

  // 20. 消息撤回（B2 02）：软删 → 不泄漏原文 → 实时通知对端 → 未读数不变
  const recallContent = '撤回测试-这句原文不该被看到'
  await sendAndSettle(u1.ws, m1.body, m2.body.id, 'user', recallContent)
  const recallId = lastAckedId(u1.inbox)
  check('发出一条待撤回的消息（拿到服务端消息 id）', !!recallId, String(recallId))

  const unreadBeforeRecall = await unreadOf(l2.body.value, m1.body.id)
  u2.inbox.length = 0

  const recallRes = await api('POST', `/chat/messages/${recallId}/recall`, l1.body.value)
  check('发送者可撤回自己的消息（返回 id 与位点）', recallRes.status === 200 && recallRes.body.id === recallId && typeof recallRes.body.recalledAt === 'number', JSON.stringify(recallRes.body))
  await sleep(300)

  const histU2 = await (await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(m1.body.id)}`, { headers: { Authorization: `Bearer ${l2.body.value}` } })).json()
  const recalledByU2 = histU2.messages.find((m) => m.id === recallId)
  check('已撤回消息标记 recalled = true', recalledByU2?.recalled === true, JSON.stringify(recalledByU2))
  check('已撤回消息不泄漏原文', !!recalledByU2 && !recalledByU2.content.includes(recallContent), String(recalledByU2?.content))
  check('对方看到「昵称撤回了一条消息」', recalledByU2?.content === 'U1撤回了一条消息', String(recalledByU2?.content))

  const histU1 = await (await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(m2.body.id)}`, { headers: { Authorization: `Bearer ${l1.body.value}` } })).json()
  const recalledByU1 = histU1.messages.find((m) => m.id === recallId)
  check('撤回者自己看到「你撤回了一条消息」', recalledByU1?.content === '你撤回了一条消息', String(recalledByU1?.content))

  check('撤回后未读数不变（撤回不改变消息条数）', (await unreadOf(l2.body.value, m1.body.id)) === unreadBeforeRecall, `${unreadBeforeRecall} -> ${await unreadOf(l2.body.value, m1.body.id)}`)

  const sessU2Item = (await sessionsOf(l2.body.value)).find((s) => s.peer.userid === m1.body.id)
  check('会话列表预览变成撤回提示', sessU2Item?.lastMessage.recalled === true && /撤回了一条消息/.test(sessU2Item.lastMessage.content ?? ''), JSON.stringify(sessU2Item?.lastMessage))

  const recallFrame = u2.inbox.find((f) => f.type === 'chatMessageRecalled')
  check('对端收到 chatMessageRecalled 帧（含收件主体与提示文案）', !!recallFrame && recallFrame.data?.id === recallId && recallFrame.data?.recipientType === 'user' && recallFrame.data?.recipientId === m1.body.id && /撤回了一条消息/.test(recallFrame.data?.content ?? ''), JSON.stringify(recallFrame))

  const recallAgain = await api('POST', `/chat/messages/${recallId}/recall`, l1.body.value)
  check('重复撤回幂等（第二次仍 200 且位点相同）', recallAgain.status === 200 && recallAgain.body.recalledAt === recallRes.body.recalledAt, JSON.stringify(recallAgain.body))

  const recallByOther = await api('POST', `/chat/messages/${recallId}/recall`, l2.body.value)
  check('撤回他人的消息被拒（403）', recallByOther.status === 403 && /只能撤回自己/.test(recallByOther.body.reason ?? ''), `status=${recallByOther.status} ${recallByOther.body.reason ?? ''}`)

  const recallGhost = await api('POST', `/chat/messages/${crypto.randomUUID()}/recall`, l1.body.value)
  check('撤回不存在的消息返回 404', recallGhost.status === 404, `status=${recallGhost.status}`)
  const recallBadId = await api('POST', '/chat/messages/not-a-uuid/recall', l1.body.value)
  check('消息 ID 格式非法返回 400', recallBadId.status === 400 && /格式不正确/.test(recallBadId.body.reason ?? ''), `status=${recallBadId.status} ${recallBadId.body.reason ?? ''}`)
  const recallNoToken = await api('POST', `/chat/messages/${recallId}/recall`, null)
  check('未携带 token 撤回返回 401', recallNoToken.status === 401, `status=${recallNoToken.status}`)

  // 20.2 群消息撤回，以及退群后失去该群的消息处置权
  const recallGroupRes = await api('POST', '/chat/groups', l1.body.value, { name: '撤回群', memberIds: [m3.body.id] })
  const recallGroupId = recallGroupRes.body.id
  check('建撤回群成功（U1 + U3）', recallGroupRes.status === 200 && recallGroupRes.body.memberCount === 2, JSON.stringify(recallGroupRes.body))

  await sendAndSettle(u1.ws, m1.body, recallGroupId, 'group', '撤回群-这句原文不该被看到')
  const groupMsgId = lastAckedId(u1.inbox)
  const recallGroupMsg = await api('POST', `/chat/messages/${groupMsgId}/recall`, l1.body.value)
  check('群消息可撤回（发送者仍是成员）', recallGroupMsg.status === 200, JSON.stringify(recallGroupMsg.body))
  const recallGroupHist = await (await fetch(`${BASE}/chat/history?peer=${encodeURIComponent(recallGroupId)}`, { headers: { Authorization: `Bearer ${l3.body.value}` } })).json()
  check('群友看到群消息已撤回且不泄漏原文', recallGroupHist.messages.some((m) => m.id === groupMsgId && m.recalled === true && !m.content.includes('撤回群-这句原文')), JSON.stringify(recallGroupHist.messages.map((m) => [m.id, m.recalled, m.content])))

  // U3 在群里发一条后退群：撤回时先过发送者校验，再撞成员身份校验
  const u3 = await wsConnect(l3.body.value)
  // wsConnect 在 onopen 就 resolve，但服务端要异步校验完 token 才注册 onText——
  // 连上就发会被静默丢弃，等一下再发
  await sleep(500)
  await sendAndSettle(u3.ws, m3.body, recallGroupId, 'group', '撤回群-U3 发的')
  const u3MsgId = lastAckedId(u3.inbox)
  check('U3 在群里发消息成功（拿到 id）', !!u3MsgId, JSON.stringify(u3.inbox.slice(-3)))
  const u3Leave = await api('DELETE', `/chat/groups/${recallGroupId}/members/${m3.body.id}`, l3.body.value)
  check('U3 退群成功', u3Leave.status === 200, JSON.stringify(u3Leave.body))
  const recallAfterLeave = await api('POST', `/chat/messages/${u3MsgId}/recall`, l3.body.value)
  check('退群后撤回群消息被拒（403）', recallAfterLeave.status === 403 && /不是该群成员/.test(recallAfterLeave.body.reason ?? ''), `status=${recallAfterLeave.status} ${recallAfterLeave.body.reason ?? ''}`)
  u3.ws.close()

  // 21. 消息搜索（B8 01）：按内容检索我可见的消息，可见性与 /chat/history 一致
  const searchOf = async (token, q, extra = '') => {
    const res = await fetch(`${BASE}/chat/messages/search?q=${encodeURIComponent(q)}${extra}`, {
      headers: { Authorization: `Bearer ${token}` }
    })
    return res.status === 200 ? await res.json() : { status: res.status }
  }
  const contentsOf = (res) => (res.messages ?? []).map((m) => m.content)

  const sMine = '搜索标记-我发的甲'
  const sPeer = '搜索标记-对方发的乙'
  await sendAndSettle(u1.ws, m1.body, m2.body.id, 'user', sMine)
  await sendAndSettle(u2.ws, m2.body, m1.body.id, 'user', sPeer)
  await sleep(300)

  const rMine = await searchOf(l1.body.value, '搜索标记')
  check('按关键词搜到自己发出与收到的消息', contentsOf(rMine).includes(sMine) && contentsOf(rMine).includes(sPeer), JSON.stringify(contentsOf(rMine)))
  check('搜索结果按时间倒序', (rMine.messages ?? []).length >= 2 && rMine.messages[0].createdAt >= rMine.messages[1].createdAt, JSON.stringify((rMine.messages ?? []).map((m) => m.createdAt)))

  const peerItem = (rMine.messages ?? []).find((m) => m.content === sPeer)
  check('结果带定位用的收件主体（单聊指向对方）', peerItem?.recipientType === 'user' && peerItem?.recipientId === m2.body.id, JSON.stringify(peerItem))
  check('结果带收件主体的展示名', !!peerItem?.recipientName, String(peerItem?.recipientName))

  // 与我无关的消息（U4 发给 U3）不该出现在我的搜索结果里
  const m4 = await me(l4.body.value)
  const sOther = '搜索标记-无关的丙'
  const u4ws = await wsConnect(l4.body.value)
  await sleep(500)
  await sendAndSettle(u4ws.ws, m4.body, m3.body.id, 'user', sOther)
  await sleep(300)
  u4ws.ws.close()
  check('搜不到与自己无关的消息', !contentsOf(await searchOf(l1.body.value, sOther)).includes(sOther), JSON.stringify(contentsOf(await searchOf(l1.body.value, sOther))))

  // 已撤回的消息：软删的原文不能被搜出来（B8 与 B2 的关键交互）
  const sRecall = '搜索标记-待撤回的丁'
  await sendAndSettle(u1.ws, m1.body, m2.body.id, 'user', sRecall)
  await sleep(300)
  check('撤回前能搜到原文', contentsOf(await searchOf(l1.body.value, sRecall)).includes(sRecall), JSON.stringify(contentsOf(await searchOf(l1.body.value, sRecall))))
  await api('POST', `/chat/messages/${lastAckedId(u1.inbox)}/recall`, l1.body.value)
  await sleep(300)
  check('撤回后搜不到原文（否则撤回形同虚设）', !contentsOf(await searchOf(l1.body.value, sRecall)).includes(sRecall), JSON.stringify(contentsOf(await searchOf(l1.body.value, sRecall))))

  // 媒体消息的 content 是文件 URL，不该被搜出来
  const sMedia = '/uploads/search-media-marker.jpg'
  await sendAndSettle(u1.ws, m1.body, m2.body.id, 'user', sMedia, 'image')
  await sleep(300)
  check('搜不到媒体消息（content 是文件 URL）', !contentsOf(await searchOf(l1.body.value, 'search-media-marker')).includes(sMedia), JSON.stringify(contentsOf(await searchOf(l1.body.value, 'search-media-marker'))))

  // 群：非成员搜不到、入群之前的群消息也搜不到（可见性与 /chat/history 一致）
  const searchGroup = await api('POST', '/chat/groups', l1.body.value, { name: '搜索群' })
  const searchGroupId = searchGroup.body.id
  check('建搜索群成功（仅 U1）', searchGroup.status === 200 && searchGroup.body.memberCount === 1, JSON.stringify(searchGroup.body))
  const sBeforeJoin = '搜索标记-入群前的戊'
  await sendAndSettle(u1.ws, m1.body, searchGroupId, 'group', sBeforeJoin)
  await sleep(300)
  check('非成员搜不到群消息', !contentsOf(await searchOf(l3.body.value, sBeforeJoin)).includes(sBeforeJoin), JSON.stringify(contentsOf(await searchOf(l3.body.value, sBeforeJoin))))

  const u3Rejoin = await api('POST', `/chat/groups/${searchGroupId}/members`, l1.body.value, { userId: m3.body.id })
  check('把 U3 拉进搜索群', u3Rejoin.status === 200 && u3Rejoin.body.memberCount === 2, JSON.stringify(u3Rejoin.body))
  const sAfterJoin = '搜索标记-入群后的己'
  await sendAndSettle(u1.ws, m1.body, searchGroupId, 'group', sAfterJoin)
  await sleep(300)
  check('入群后能搜到入群之后的群消息', contentsOf(await searchOf(l3.body.value, sAfterJoin)).includes(sAfterJoin), JSON.stringify(contentsOf(await searchOf(l3.body.value, sAfterJoin))))
  check('入群之前的群消息仍搜不到（入群时间过滤）', !contentsOf(await searchOf(l3.body.value, sBeforeJoin)).includes(sBeforeJoin), JSON.stringify(contentsOf(await searchOf(l3.body.value, sBeforeJoin))))
  const groupItem = (await searchOf(l3.body.value, sAfterJoin)).messages?.find((m) => m.content === sAfterJoin)
  check('群搜索结果指向该群', groupItem?.recipientType === 'group' && groupItem?.recipientId === searchGroupId && groupItem?.recipientName === '搜索群', JSON.stringify(groupItem))

  // 参数校验与分页
  const searchNoQ = await fetch(`${BASE}/chat/messages/search`, { headers: { Authorization: `Bearer ${l1.body.value}` } })
  check('缺少关键词 q 返回 400', searchNoQ.status === 400, `status=${searchNoQ.status}`)
  const searchNoToken = await fetch(`${BASE}/chat/messages/search?q=abc`)
  check('未携带 token 搜索返回 401', searchNoToken.status === 401, `status=${searchNoToken.status}`)
  const searchP1 = await searchOf(l1.body.value, '搜索标记', '&limit=2&offset=0')
  const searchP2 = await searchOf(l1.body.value, '搜索标记', '&limit=2&offset=2')
  check('limit 生效且 hasMore 是布尔', (searchP1.messages ?? []).length <= 2 && typeof searchP1.hasMore === 'boolean', JSON.stringify([searchP1.messages?.length, searchP1.hasMore]))
  check('offset 生效（第二页与第一页不同）', JSON.stringify(contentsOf(searchP1)) !== JSON.stringify(contentsOf(searchP2)), JSON.stringify([contentsOf(searchP1), contentsOf(searchP2)]))

  u1.ws.close()
  u2.ws.close()
  await sleep(300)

  alice.ws.close()
  bob.ws.close()
  carol.ws.close()
  eve.ws.close()
  await sleep(300)

  const failed = results.filter((r) => !r.ok)
  console.log(failed.length === 0 ? '\n全部通过' : `\n${failed.length} 项失败`)
  process.exit(failed.length === 0 ? 0 : 1)
}

main().catch((e) => { console.error('脚本异常', e); process.exit(1) })
