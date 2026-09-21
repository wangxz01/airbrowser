import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
const source = readFileSync(new URL('../entry/src/main/ets/model/BrowserStore.ets', import.meta.url), 'utf8').replace(/^import .*;\n/gm, '').replace(/^export /gm, '');
function create(database, cookieSave = async () => {}) {
  return new Function('preferences','webview','initialSnapshot','restoreSnapshot', stripTypeScriptTypes(source) + '\nreturn {browserStore,saveCookies};')(
    { getPreferences: async () => database }, { WebCookieManager: { saveCookieAsync:cookieSave } }, () => ({}), x => JSON.parse(x || '{}'));
}

test('连续保存串行落盘，较早的慢写入不能覆盖新状态', async () => {
  let release; const gate = new Promise(r => { release=r; }); const writes=[];
  const db={get:async()=>'',put:async(k,v)=>{if(writes.length===0)await gate;writes.push(JSON.parse(v));},flush:async()=>{}};
  const {browserStore:s}=create(db); await s.open({});
  s.capture({version:1});const first=s.flush();s.capture({version:2});const second=s.flush();
  release(); await Promise.all([first,second]); assert.deepEqual(writes,[{version:1},{version:2}]);
});

test('写入失败后保留待保存内容，可重试', async () => {
  let fail=true, saved;
  const db={get:async()=>'',put:async(k,v)=>{if(fail)throw new Error('disk');saved=v;},flush:async()=>{}};
  const {browserStore:s}=create(db); await s.open({});s.capture({version:7});
  await assert.rejects(s.flush()); assert.ok(s.lastError);
  fail=false;await s.flush();assert.equal(JSON.parse(saved).version,7);
});

test('Cookie保存必须等待完成，失败不得显示保存成功', async () => {
  let release; const {saveCookies}=create({},()=>new Promise(r=>{release=r;}));let done=false;
  const result=saveCookies().then(()=>{done=true;});await Promise.resolve();assert.equal(done,false);release();await result;assert.equal(done,true);
  const failing=create({},async()=>{throw new Error('storage');});await assert.rejects(failing.saveCookies());assert.ok(failing.browserStore.lastError);
});

test('旧写入失败但新写入成功后，重试不能把状态回滚', async () => {
  let release; const gate=new Promise(r=>{release=r;});let calls=0,saved;
  const db={get:async()=>'',put:async(k,v)=>{calls++;if(calls===1){await gate;throw new Error('old write failed');}saved=v;},flush:async()=>{}};
  const {browserStore:s}=create(db);await s.open({});
  s.capture({version:1});const first=s.flush();s.capture({version:2});const second=s.flush();
  release();await assert.rejects(first);await second;await s.flush();
  assert.equal(JSON.parse(saved).version,2);assert.equal(calls,2);
});
