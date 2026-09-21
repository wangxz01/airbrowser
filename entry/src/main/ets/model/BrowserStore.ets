import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { webview } from '@kit.ArkWeb';
import { BrowserSnapshot, initialSnapshot, restoreSnapshot } from './BrowserRules';

export class BrowserStore {
  private db?: preferences.Preferences;
  private queued: string = '';
  private timer: number = -1;
  private pending: Promise<void> = Promise.resolve();
  private revision: number = 0;
  lastError: string = '';
  ready: boolean = false;

  async open(context: common.UIAbilityContext): Promise<BrowserSnapshot> {
    try {
      this.db = await preferences.getPreferences(context, { name: 'air_browser_v1' });
      const raw = String(await this.db.get('session', ''));
      this.ready = true;
      return restoreSnapshot(raw);
    } catch (_) {
      this.lastError = '本机存储不可用，暂时无法保存标签与收藏。';
      return initialSnapshot();
    }
  }

  capture(snapshot: BrowserSnapshot): void {
    if (!this.ready) { return; }
    this.revision++;
    this.queued = JSON.stringify(snapshot);
    clearTimeout(this.timer);
    this.timer = setTimeout(() => { this.flush().catch(() => {}); }, 400);
  }

  flush(): Promise<void> {
    clearTimeout(this.timer);
    const value = this.queued;
    const revision = this.revision;
    if (!value || !this.db) { return this.pending; }
    this.queued = '';
    const next = this.pending.catch(() => {}).then(async () => {
      if (!this.db) { return; }
      await this.db.put('session', value);
      await this.db.flush();
    }).catch(() => {
      // Retain the latest state for a retry without allowing an older write to replace it.
      if (!this.queued && revision === this.revision) { this.queued = value; }
      this.lastError = '标签或收藏未保存，请在菜单中重试保存。';
      throw new Error('Unable to persist browser state');
    });
    this.pending = next;
    return next;
  }
}

export const browserStore: BrowserStore = new BrowserStore();

// ArkWeb owns app-private cookies and website storage. Credentials are never exported
// to Preferences or logs, and normal cache cleanup does not delete login data.
export async function saveCookies(): Promise<void> {
  try { await webview.WebCookieManager.saveCookieAsync(); }
  catch (_) { browserStore.lastError = '网站登录数据暂未保存，请在菜单中重试保存。'; throw new Error('Cookie persistence failed'); }
}
