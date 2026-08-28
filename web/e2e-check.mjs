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

function wsConnect(userid, username) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`${WS_BASE}/chat/webSocket?userid=${encodeURIComponent(userid)}&username=${encodeURIComponent(username)}`)
    const inbox = []
    ws.onmessage = (e) => inbox.push(JSON.parse(String(e.data)))
    ws.onopen = () => resolve({ ws, inbox })
    ws.onerror = (e) => reject(new Error('ws error ' + (e?.message ?? '')))
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

  // 5. 建立两个 WebSocket 连接
  const alice = await wsConnect(mea.body.id, aliceAccount)
  const meb = await me(lb.body.value)
  const bob = await wsConnect(meb.body.id, bobAccount)
  check('两个 WebSocket 连接建立', true)

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

  alice.ws.close()
  bob.ws.close()
  await sleep(300)

  const failed = results.filter((r) => !r.ok)
  console.log(failed.length === 0 ? '\n全部通过' : `\n${failed.length} 项失败`)
  process.exit(failed.length === 0 ? 0 : 1)
}

main().catch((e) => { console.error('脚本异常', e); process.exit(1) })
