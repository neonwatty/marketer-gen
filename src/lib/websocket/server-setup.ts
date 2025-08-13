import { createServer } from 'http'
import { parse } from 'url'
import next from 'next'
import { initializeWebSocketServer } from './socket-server'

const dev = process.env.NODE_ENV !== 'production'
const hostname = 'localhost'
const port = parseInt(process.env.PORT || '3000', 10)

let server: ReturnType<typeof createServer> | null = null
let webSocketServer: ReturnType<typeof initializeWebSocketServer> | null = null

export async function setupWebSocketServer() {
  if (server) {
    return { server, webSocketServer }
  }

  const app = next({ dev, hostname, port })
  const handle = app.getRequestHandler()

  await app.prepare()

  server = createServer(async (req, res) => {
    try {
      const parsedUrl = parse(req.url!, true)
      await handle(req, res, parsedUrl)
    } catch (err) {
      console.error('Error occurred handling', req.url, err)
      res.statusCode = 500
      res.end('internal server error')
    }
  })

  // Initialize WebSocket server
  webSocketServer = initializeWebSocketServer(server)

  server.listen(port, () => {
    console.log(`> Ready on http://${hostname}:${port}`)
    console.log(`> WebSocket server initialized`)
  })

  return { server, webSocketServer }
}

export function getServer() {
  return server
}

export function getWebSocketServerInstance() {
  return webSocketServer
}

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server')
  server?.close(() => {
    console.log('HTTP server closed')
  })
})

process.on('SIGINT', () => {
  console.log('SIGINT signal received: closing HTTP server')
  server?.close(() => {
    console.log('HTTP server closed')
  })
})