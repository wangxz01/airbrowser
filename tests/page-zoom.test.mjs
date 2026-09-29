import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
const source = readFileSync(new URL('../entry/src/main/ets/model/PageZoom.ets', import.meta.url), 'utf8');
const { pageZoomScript } = await import('data:text/javascript;base64,' + Buffer.from(stripTypeScriptTypes(source)).toString('base64'));
function page(value = '', priority = '', computed = '1') {
  const style = { value, priority, getPropertyValue: () => style.value, getPropertyPriority: () => style.priority,
    setProperty: (_, v, p) => { style.value = v; style.priority = p; },
    removeProperty: () => { style.value = ''; style.priority = ''; } };
  const root = { style };
  const context = vm.createContext({ document: { documentElement: root }, getComputedStyle: () => ({ zoom: computed }) });
  return { style, apply: percent => vm.runInContext(pageZoomScript(percent), context) };
}
test('缩放从页面原倍率计算，多次调整不累乘，重置恢复原样式优先级', () => {
  const p = page('1.2', 'important', '1.2');
  assert.equal(p.apply(150), true); assert.equal(Number(p.style.value), 1.8);
  p.apply(50); assert.equal(Number(p.style.value), .6);
  p.apply(125); assert.equal(Number(p.style.value), 1.5);
  p.apply(100); assert.equal(p.style.value, '1.2'); assert.equal(p.style.priority, 'important');
});
test('无原内联缩放时重置移除属性，新文档可恢复标签倍率', () => {
  const first = page(); first.apply(75); assert.equal(first.style.value, '0.75');
  first.apply(100); assert.equal(first.style.value, '');
  const reloaded = page(); reloaded.apply(75); assert.equal(reloaded.style.value, '0.75');
});
test('拒绝无效倍率及非数字脚本输入', () => {
  for (const value of [NaN, Infinity, 0, 25, 201, 300, 76, '100;alert(1)']) assert.throws(() => pageZoomScript(value));
});
