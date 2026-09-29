// Layout zoom, independent of touch/pinch magnification. No native bridge is exposed.
export function pageZoomScript(percent: number): string {
  if (!Number.isFinite(percent) || percent < 50 || percent > 200 || percent % 25 !== 0) {
    throw new Error('Invalid page zoom');
  }
  return `(() => {
    const root = document.documentElement;
    if (!root) return false;
    const key = '__airBrowserLayoutZoom_v1';
    let saved = root[key];
    if (!saved) {
      if (${percent} === 100) return true;
      const scale = Number.parseFloat(getComputedStyle(root).zoom);
      saved = { value: root.style.getPropertyValue('zoom'), priority: root.style.getPropertyPriority('zoom'),
        scale: Number.isFinite(scale) && scale > 0 ? scale : 1 };
      root[key] = saved;
    }
    if (${percent} === 100) {
      if (saved.value) root.style.setProperty('zoom', saved.value, saved.priority);
      else root.style.removeProperty('zoom');
      delete root[key];
    } else {
      root.style.setProperty('zoom', String(saved.scale * ${percent} / 100), 'important');
    }
    return true;
  })()`;
}
