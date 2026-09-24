// Serves the built dist/ (every version) for local preview.
// Usage: node scripts/serve.mjs [port]; defaults to 4321.

import { createReadStream, existsSync, statSync } from 'node:fs'
import { createServer } from 'node:http'
import { dirname, extname, join, normalize, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const distDir = resolve(dirname(fileURLToPath(import.meta.url)), '../dist')
const port = Number(process.argv[2] ?? 4321)
const types = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.woff2': 'font/woff2',
  '.xml': 'application/xml',
  '.wasm': 'application/wasm',
}

createServer((req, res) => {
  const path = normalize(decodeURIComponent(new URL(req.url, 'http://localhost').pathname))
  let file = join(distDir, path)
  if (existsSync(file) && statSync(file).isDirectory()) file = join(file, 'index.html')
  const found = file.startsWith(distDir) && existsSync(file)
  if (!found) file = join(distDir, '404.html')
  res.writeHead(found ? 200 : 404, { 'content-type': types[extname(file)] ?? 'application/octet-stream' })
  createReadStream(file).pipe(res)
}).listen(port, '0.0.0.0', () => console.log(`serving dist/ on http://localhost:${port}/`))
