// Local native integration fixture. No real credentials or account state.
import http from 'node:http';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
const video=fileURLToPath(new URL('../artifacts/test-video.mp4',import.meta.url));
const server=http.createServer((req,res)=>{
  const url=new URL(req.url,'http://localhost');
  if(url.pathname==='/video.mp4'){
    if(!existsSync(video)){res.writeHead(404);res.end();return;}
    const bytes=readFileSync(video);res.writeHead(200,{'Content-Type':'video/mp4','Content-Length':bytes.length,'Accept-Ranges':'bytes'});res.end(bytes);return;
  }
  if(url.pathname==='/login'){
    res.writeHead(302,{'Set-Cookie':'air_test_persistent=present; Max-Age=86400; Path=/; SameSite=Lax','Location':'/a'});res.end();return;
  }
  const page=url.pathname==='/b'?'B':'A';
  res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'});
  res.end(`<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Air test ${page}</title><style>body{font:20px system-ui;padding:24px;background:#f3f7f3;color:#25362c}button,a{display:inline-block;padding:16px;margin:6px;background:#dae8db;border:0;border-radius:7px;color:#25362c;text-decoration:none;font:inherit}video{display:block;width:min(720px,90%);background:#15251d;margin-top:20px}</style></head><body><h1>Air test ${page}</h1><p id="cookie">Cookie: ${String(req.headers.cookie||'').includes('air_test_persistent=present')?'PERSISTED':'EMPTY'}</p><p id="storage"></p><a href="/${page==='A'?'b':'a'}">Go ${page==='A'?'B':'A'}</a><a href="/b" target="_blank">New tab B</a><a href="/login">Set persistent cookie</a><button onclick="history.pushState({},'', '/spa');document.title='Air SPA';document.querySelector('h1').textContent='Air SPA'">SPA navigation</button><button onclick="alert('Native dialog')">Alert</button><a href="bilibili://video/test">App link</a><button onclick="document.querySelector('video').requestFullscreen()">Video fullscreen</button><video controls loop playsinline src="/video.mp4"></video><script>const old=localStorage.getItem('air_test');document.getElementById('storage').textContent='Storage: '+(old?'PERSISTED':'FIRST');localStorage.setItem('air_test','present');</script></body></html>`);
});
server.listen(18765,'127.0.0.1',()=>console.log('Native fixture: http://127.0.0.1:18765/a (use hdc rport tcp:18765 tcp:18765)'));
