import net from 'node:net'

function rawRequest(label, extraHeaders, cb) {
  const sock = net.connect(8080, '127.0.0.1', () => {
    sock.write('GET /chat/webSocket?userid=rawtest&username=rawtest HTTP/1.1\r\n' +
      'host: 127.0.0.1:8080\r\n' +
      'connection: upgrade\r\n' +
      'upgrade: websocket\r\n' +
      'sec-websocket-key: dGhlIHNhbXBsZSBub25jZQ==\r\n' +
      'sec-websocket-version: 13\r\n' +
      extraHeaders +
      '\r\n')
  })
  let buf = ''
  const timer = setTimeout(() => { console.log(label, '-> TIMEOUT'); sock.destroy(); cb() }, 4000)
  sock.on('data', (d) => {
    buf += d.toString()
    if (buf.includes('\r\n\r\n')) {
      clearTimeout(timer)
      console.log(label, '->', buf.split('\r\n\r\n')[0].replace(/\r\n/g, ' | '))
      sock.destroy()
      cb()
    }
  })
}

rawRequest('no-ext', '', () => {
  rawRequest('with-ext', 'sec-websocket-extensions: permessage-deflate; client_max_window_bits\r\n', () => {
    process.exit(0)
  })
})
