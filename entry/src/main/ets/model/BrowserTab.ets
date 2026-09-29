import { image } from '@kit.ImageKit';
import { webview } from '@kit.ArkWeb';
import { desktopAgent } from './BrowserRules';
import { pageZoomScript } from './PageZoom';

@Observed
export class BrowserTab {
  id: string;
  url: string;
  source: string;
  title: string;
  favicon?: image.PixelMap;
  live: boolean = false;
  ready: boolean = false;
  loading: boolean = false;
  progress: number = 0;
  canBack: boolean = false;
  canForward: boolean = false;
  desktop: boolean = false;
  zoomPercent: number = 100;
  audio: boolean = false;
  muted: boolean = false;
  error: string = '';
  defaultAgent: string = '';
  controller: webview.WebviewController = new webview.WebviewController();
  popup?: ControllerHandler;

  constructor(id: string, url: string, title: string = '新标签页') {
    this.id = id; this.url = url; this.source = url || 'about:blank'; this.title = title;
  }

  applyAgent(): void {
    if (!this.ready) { return; }
    try {
      if (!this.defaultAgent) { this.defaultAgent = this.controller.getUserAgent(); }
      this.controller.setCustomUserAgent(this.desktop ? desktopAgent(this.defaultAgent) : this.defaultAgent);
    } catch (_) { throw new Error('Unable to apply site display mode'); }
  }

  async applyZoom(percent: number): Promise<void> {
    if (!this.ready) { throw new Error('Page is not ready'); }
    const result = await this.controller.runJavaScript(pageZoomScript(percent));
    if (result !== 'true') { throw new Error('Unable to zoom page'); }
    this.zoomPercent = percent;
  }

  syncHistory(): void {
    if (!this.ready) { return; }
    try { this.canBack = this.controller.accessBackward(); this.canForward = this.controller.accessForward(); } catch (_) {}
  }
}
