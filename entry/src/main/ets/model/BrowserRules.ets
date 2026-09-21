export const MAX_TABS: number = 24;
export const MAX_HISTORY: number = 300;
export const BILI_HOME: string = 'https://www.bilibili.com/';
export const BILI_LOGIN: string = 'https://passport.bilibili.com/login';

export interface SavedTab { id: string; url: string; title: string; }
export interface SavedPage { url: string; title: string; time: number; }
export interface SitePreference { host: string; desktop: boolean; }
export interface BrowserSnapshot {
  version: number;
  tabs: SavedTab[];
  activeId: string;
  bookmarks: SavedPage[];
  history: SavedPage[];
  sites: SitePreference[];
  collapsed: boolean;
  sidebarWidth: number;
  backNavigates: boolean;
}
export interface BackState { editing: boolean; dialog: boolean; panel: boolean; fullscreen: boolean; navigates: boolean; canBack: boolean; }

export function backAction(s: BackState): string {
  if (s.editing) { return 'keyboard'; }
  if (s.dialog) { return 'dialog'; }
  if (s.panel) { return 'panel'; }
  if (s.fullscreen) { return 'fullscreen'; }
  if (s.navigates && s.canBack) { return 'history'; }
  return 'stay';
}

export function webHost(input: string): string {
  if (typeof input !== 'string' || input.length > 8192 || /[\s\u0000-\u001f\u007f\\]/.test(input)) { return ''; }
  const m = input.match(/^https?:\/\/([^/?#]+)(?:[/?#]|$)/i);
  if (!m || m[1].includes('@')) { return ''; }
  const authority = m[1];
  const parts = authority.match(/^(\[[a-fA-F0-9:]+\]|[a-zA-Z0-9.-]+)(?::([0-9]{1,5}))?$/);
  if (!parts || (parts[2] && (Number(parts[2]) < 1 || Number(parts[2]) > 65535))) { return ''; }
  const host = parts[1].toLowerCase();
  if (host.includes('..') || host.startsWith('.') || host.endsWith('.')) { return ''; }
  return host;
}

export function isWebUrl(input: string): boolean { return webHost(input).length > 0; }

// Empty return means explicitly unsupported input; text searches use HTTPS.
export function resolveAddress(input: string): string {
  const value = input.trim();
  if (!value || value.length > 8192 || /[\u0000-\u001f\u007f]/.test(value)) { return ''; }
  if (/^https?:\/\//i.test(value)) { return isWebUrl(value) ? value : ''; }
  if (!/\s/.test(value) && /^(?:localhost(?=[:/?#]|$)|\[[a-fA-F0-9:]+\]|[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+)(?::[0-9]+)?(?:[/?#].*)?$/.test(value)) {
    const url = 'https://' + value;
    return isWebUrl(url) ? url : '';
  }
  if (/^[a-z][a-z0-9+.-]*:/i.test(value)) { return ''; }
  return 'https://cn.bing.com/search?q=' + encodeURIComponent(value);
}

export function desktopAgent(original: string): string {
  // Preserve the installed rendering engine's real version instead of claiming a newer Chrome.
  const engine = original.match(/AppleWebKit\/([0-9.]+)/);
  const chrome = original.match(/Chrome\/([0-9.]+)/);
  if (engine && chrome) {
    return `Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/${engine[1]} (KHTML, like Gecko) Chrome/${chrome[1]} Safari/${engine[1]}`;
  }
  return original.replace(/\b(Mobile|Tablet)\b/g, '').replace(/ {2,}/g, ' ');
}

export function initialSnapshot(): BrowserSnapshot {
  return { version: 1, tabs: [{ id: 'welcome', url: '', title: '新标签页' }], activeId: 'welcome', bookmarks: [], history: [], sites: [], collapsed: false, sidebarWidth: 220, backNavigates: false };
}

function cleanPages(pages: SavedPage[], limit: number): SavedPage[] {
  if (!Array.isArray(pages)) { return []; }
  const result: SavedPage[] = [];
  pages.slice(0, limit).forEach((p: SavedPage) => {
    if (p && typeof p.url === 'string' && isWebUrl(p.url) && !result.some((v: SavedPage) => v.url === p.url)) {
      result.push({ url: p.url, title: typeof p.title === 'string' ? p.title.slice(0, 200) : webHost(p.url), time: typeof p.time === 'number' && Number.isFinite(p.time) ? p.time : 0 });
    }
  });
  return result;
}

export function restoreSnapshot(raw: string): BrowserSnapshot {
  if (!raw || raw.length > 2000000) { return initialSnapshot(); }
  try {
    const source = JSON.parse(raw) as BrowserSnapshot;
    if (!source || source.version !== 1 || !Array.isArray(source.tabs)) { return initialSnapshot(); }
    const tabs: SavedTab[] = [];
    source.tabs.slice(0, MAX_TABS).forEach((t: SavedTab) => {
      if (t && typeof t.url === 'string' && (t.url === '' || isWebUrl(t.url))) {
        const id = typeof t.id === 'string' && /^[a-zA-Z0-9_-]{1,80}$/.test(t.id) ? t.id : `restored-${tabs.length}`;
        if (!tabs.some((v: SavedTab) => v.id === id)) {
          tabs.push({ id: id, url: t.url, title: typeof t.title === 'string' ? t.title.slice(0, 200) : '标签页' });
        }
      }
    });
    if (tabs.length === 0) { tabs.push({ id: 'welcome', url: '', title: '新标签页' }); }
    const sites: SitePreference[] = [];
    if (Array.isArray(source.sites)) {
      source.sites.slice(0, 200).forEach((s: SitePreference) => {
        if (s && typeof s.host === 'string' && webHost('https://' + s.host) === s.host && !sites.some((v: SitePreference) => v.host === s.host)) {
          sites.push({ host: s.host, desktop: s.desktop === true });
        }
      });
    }
    return {
      version: 1, tabs: tabs, activeId: tabs.some((t: SavedTab) => t.id === source.activeId) ? source.activeId : tabs[0].id,
      bookmarks: cleanPages(source.bookmarks, 200), history: cleanPages(source.history, MAX_HISTORY), sites: sites,
      collapsed: source.collapsed === true, sidebarWidth: typeof source.sidebarWidth === 'number' && Number.isFinite(source.sidebarWidth) ? Math.min(280, Math.max(180, source.sidebarWidth)) : 220,
      backNavigates: source.backNavigates === true
    };
  } catch (_) { return initialSnapshot(); }
}

export function recordVisit(pages: SavedPage[], url: string, title: string, time: number): SavedPage[] {
  if (!isWebUrl(url)) { return pages; }
  const visit: SavedPage = { url: url, title: title.slice(0, 200), time: time };
  const result: SavedPage[] = [visit, ...pages.filter((p: SavedPage) => p.url !== url)];
  return result.slice(0, MAX_HISTORY);
}

export function nextAfterClose(ids: string[], active: string, closing: string): string {
  const index = ids.indexOf(closing);
  if (index < 0 || active !== closing) { return active; }
  if (ids.length === 1) { return ''; }
  return index + 1 < ids.length ? ids[index + 1] : ids[index - 1];
}
