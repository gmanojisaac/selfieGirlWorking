import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';

// Serve only the preview's runtime files, on this machine's loopback interface.
const files = new Map([
  ['blazer-preview.html', 'text/html; charset=utf-8'],
  ['selfie_modifyAndStudy.glsl', 'text/plain; charset=utf-8'],
  ['selfie_modifyAndStudy.sha.json', 'application/json; charset=utf-8'],
  ['common.glsl', 'text/plain; charset=utf-8'],
  ['texture0.png', 'image/png'],
  ['texture2.png', 'image/png'],
  ['texture3.png', 'image/png'],
]);
const port = Number(process.argv[2] ?? 8080);
if (!Number.isInteger(port) || port < 1 || port > 65535 || process.argv.length > 3) {
  console.error('Usage: node serve-preview.mjs [port: 1-65535]');
  process.exit(1);
}

const server = createServer(async (request, response) => {
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    response.writeHead(405, { Allow: 'GET, HEAD' }).end();
    return;
  }
  const pathname = new URL(request.url, 'http://127.0.0.1').pathname;
  const name = pathname === '/' ? 'blazer-preview.html' : pathname.slice(1);
  if (!files.has(name)) {
    response.writeHead(404).end('Not found');
    return;
  }
  try {
    const content = await readFile(new URL(name, import.meta.url));
    response.writeHead(200, { 'Content-Type': files.get(name), 'Cache-Control': 'no-store' });
    response.end(request.method === 'HEAD' ? undefined : content);
  } catch {
    response.writeHead(404).end('File missing; run node bundle.mjs first.');
  }
});

server.on('error', error => {
  console.error(error.message);
  process.exitCode = 1;
});
server.listen(port, '127.0.0.1', () => {
  console.log(`Preview: http://127.0.0.1:${port}/blazer-preview.html`);
  console.log('Press Ctrl+C to stop. Regenerate the bundle and refresh after editing.');
});
