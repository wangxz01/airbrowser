import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
const source = readFileSync(new URL('../entry/src/main/ets/model/BrowserRules.ets', import.meta.url), 'utf8');
const rules = await import('data:text/javascript;base64,' + Buffer.from(stripTypeScriptTypes(source)).toString('base64'));
const { resolveAddress, webHost, isWebUrl, restoreSnapshot, initialSnapshot, backAction, nextAfterClose, recordVisit, desktopAgent } = rules;

test('地址栏区分域名、带端口本地服务、搜索词和不允许的协议', () => {
  assert.equal(resolveAddress(' bilibili.com/video/BV1test '), 'https://bilibili.com/video/BV1test');
  assert.equal(resolveAddress('localhost:8080/test'), 'https://localhost:8080/test');
  assert.equal(resolveAddress('http://127.0.0.1:8123/test'), 'http://127.0.0.1:8123/test');
  assert.equal(resolveAddress('B站 视频'), 'https://cn.bing.com/search?q=B%E7%AB%99%20%E8%A7%86%E9%A2%91');
  for (const url of ['javascript:alert(1)', 'file:///etc/passwd', 'data:text/html,x', 'intent://x', 'bilibili://video', 'https://good.test@evil.test', 'https://good.test\\@evil.test', 'https://x.test:99999', 'a\nb']) assert.equal(resolveAddress(url), '', url);
});

test('网站身份按完整主机名划分，不混淆相似域名', () => {
  assert.equal(webHost('https://WWW.BILIBILI.COM/video/x'), 'www.bilibili.com');
  assert.equal(webHost('https://www.bilibili.com.evil.test/'), 'www.bilibili.com.evil.test');
  assert.equal(webHost('https://www.bilibili.com@evil.test/'), '');
  assert.equal(isWebUrl('https://[::1]:8080/'), true);
  assert.equal(isWebUrl('https://a..b/'), false);
});

test('一次返回只处理最高优先级，默认不会触发网页后退或退出', () => {
  const s = { editing:false, dialog:false, panel:false, fullscreen:false, navigates:false, canBack:true };
  assert.equal(backAction(s), 'stay');
  assert.equal(backAction({ ...s, navigates:true }), 'history');
  assert.equal(backAction({ ...s, fullscreen:true, navigates:true }), 'fullscreen');
  assert.equal(backAction({ ...s, panel:true, fullscreen:true }), 'panel');
  assert.equal(backAction({ ...s, dialog:true, panel:true }), 'dialog');
  assert.equal(backAction({ ...s, editing:true, dialog:true }), 'keyboard');
  assert.equal(backAction({ ...s, navigates:true, canBack:false }), 'stay');
});

test('关闭当前、后台和最后一个标签时保持选择一致', () => {
  assert.equal(nextAfterClose(['a','b','c'], 'b', 'b'), 'c');
  assert.equal(nextAfterClose(['a','b','c'], 'c', 'c'), 'b');
  assert.equal(nextAfterClose(['a','b','c'], 'a', 'b'), 'a');
  assert.equal(nextAfterClose(['a'], 'a', 'a'), '');
  assert.equal(nextAfterClose(['a'], 'a', 'missing'), 'a');
});

test('损坏、过期版本和异常存档能够恢复到可用首页', () => {
  for (const raw of ['', '{', 'null', '[]', '{"version":2,"tabs":[]}', 'x'.repeat(2000001)]) {
    const value = restoreSnapshot(raw); assert.equal(value.tabs.length, 1); assert.equal(value.activeId, value.tabs[0].id);
  }
});

test('恢复时丢弃危险网址和重复标识，限制存档大小和布局参数', () => {
  const saved = initialSnapshot();
  saved.tabs = [{ id:'a', url:'https://example.com', title:'A' }, { id:'a', url:'https://b.test', title:'duplicate' }, { id:'bad', url:'javascript:evil()', title:'bad' }];
  saved.activeId = 'missing'; saved.sidebarWidth = 9999;
  saved.history = [{ url:'file:///tmp/x', title:'secret', time:0 }];
  saved.sites = [{ host:'bilibili.com.evil.test', desktop:true }, { host:'bilibili.com', desktop:true }];
  const result = restoreSnapshot(JSON.stringify(saved));
  assert.equal(result.tabs.length, 1); assert.equal(result.activeId, 'a'); assert.equal(result.sidebarWidth, 280); assert.equal(result.history.length, 0);
  assert.equal(result.sites.length, 2);
});

test('历史去重并限制为最近300条，不记录内部页面', () => {
  let pages = [];
  for (let i=0;i<310;i++) pages = recordVisit(pages, `https://example.com/${i}`, `Page ${i}`, i);
  assert.equal(pages.length, 300);
  pages = recordVisit(pages, 'https://example.com/42', 'Updated', 400);
  assert.equal(pages.length, 300); assert.equal(pages[0].title, 'Updated');
  assert.equal(recordVisit(pages, 'about:blank', '', 500), pages);
});

test('请求电脑版网页沿用本机引擎版本', () => {
  const agent = desktopAgent('Mozilla/5.0 (Linux; Android 12; Tablet) AppleWebKit/537.36 Chrome/132.0.6834.0 Mobile Safari/537.36');
  assert.ok(agent.includes('Chrome/132.0.6834.0')); assert.ok(!agent.includes('Mobile')); assert.ok(!agent.includes('Android'));
  assert.equal(desktopAgent('ArkWeb Mobile Tablet'), 'ArkWeb ');
});
