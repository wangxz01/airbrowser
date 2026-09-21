import { BrowserTab } from '../model/BrowserTab';
import { isWebUrl } from '../model/BrowserRules';
import { saveCookies } from '../model/BrowserStore';

@Component
export struct BrowserPane {
  @ObjectLink tab: BrowserTab;
  @Prop active: boolean = false;
  onChanged: () => void = () => {};
  onLocation: (url: string, finished: boolean) => void = () => {};
  onBeforeNavigate: (url: string) => void = () => {};
  onPopup: (event: OnWindowNewEvent) => void = () => {};
  onFullscreen: (handler?: FullScreenExitHandler) => void = () => {};
  onDialog: (kind: string, message: string, value: string, result: JsResult) => void = () => {};
  onClose: () => void = () => {};
  onNotice: (message: string) => void = () => {};

  private attached(): void {
    this.tab.ready = true;
    try {
      this.tab.applyAgent();
      if (this.tab.popup) {
        this.tab.popup.setWebController(this.tab.controller);
        this.tab.popup = undefined;
      }
    } catch (_) {
      this.tab.error = '页面暂时无法打开，请重试。';
    }
    this.onChanged();
  }

  private location(url: string, finished: boolean): void {
    if (!isWebUrl(url)) { return; }
    this.tab.url = url;
    this.tab.syncHistory();
    this.onLocation(url, finished);
    this.onChanged();
  }

  aboutToDisappear(): void {
    this.tab.ready = false;
    this.tab.audio = false;
  }

  build() {
    Stack() {
      if (this.tab.live) {
      Web({ src: this.tab.source, controller: this.tab.controller })
        .width('100%').height('100%')
        .javaScriptAccess(true).domStorageAccess(true).fileAccess(false)
        .mixedMode(MixedMode.None).mediaPlayGestureAccess(true)
        .multiWindowAccess(true).allowWindowOpenMethod(false)
        .onControllerAttached(() => { this.attached(); })
        .onPageBegin((event) => {
          if (event && isWebUrl(event.url)) {
            this.tab.favicon = undefined;
            this.tab.error = ''; this.tab.loading = true;
            this.location(event.url, false);
          }
        })
        .onPageEnd((event) => {
          this.tab.loading = false; this.tab.progress = 100;
          if (event) { this.location(event.url, true); }
          if (!this.tab.favicon) {
            try { this.tab.favicon = this.tab.controller.getFavicon(); } catch (_) {}
          }
          saveCookies().catch(() => { if (this.active) { this.onNotice('网站状态保存失败，可在菜单中重试保存。'); } });
          this.onChanged();
        })
        .onNavigationEntryCommitted((event) => {
          if (event.isMainFrame) { this.location(event.url, event.isSameDocument); }
        })
        .onFaviconReceived((event) => {
          if (event?.favicon) { this.tab.favicon = event.favicon; }
        })
        .onTitleReceive((event) => {
          if (event && event.title) { this.tab.title = event.title.slice(0, 200); this.onChanged(); }
        })
        .onProgressChange((event) => {
          if (event) { this.tab.progress = event.newProgress; this.tab.loading = event.newProgress < 100; this.onChanged(); }
        })
        .onAudioStateChanged((event) => { if (event) { this.tab.audio = event.playing; this.onChanged(); } })
        .onFullScreenEnter((event) => {
          if (!event) { return; }
          if (this.active) { this.onFullscreen(event.handler); }
          else { event.handler.exitFullScreen(); }
        })
        .onFullScreenExit(() => { this.onFullscreen(); })
        .onWindowNew((event) => { if (event) { this.onPopup(event); } })
        .onWindowExit(() => { this.onClose(); })
        .onOverrideUrlLoading((request) => {
          if (!request.isMainFrame()) { return false; }
          const url = request.getRequestUrl();
          if (url === 'about:blank') { return false; }
          if (isWebUrl(url)) { this.onBeforeNavigate(url); return false; }
          if (this.active) { this.onNotice('已阻止离开浏览器的应用跳转。'); }
          return true;
        })
        .onErrorReceive((event) => {
          if (event && event.request.isMainFrame()) {
            this.tab.error = '加载失败，请检查网络后重试。'; this.tab.loading = false; this.onChanged();
          }
        })
        .onSslErrorEventReceive((event) => {
          if (event) { event.handler.handleCancel(); }
          this.tab.error = '此网站的安全证书验证失败，已停止连接。';
          this.tab.loading = false; this.onChanged();
        })
        .onRenderExited(() => {
          this.tab.error = '网页进程已结束，请重新加载此标签。';
          this.tab.loading = false; this.onChanged();
        })
        .onPermissionRequest((event) => {
          if (event) { event.request.deny(); }
          if (this.active) { this.onNotice('当前版本暂未开放摄像头和麦克风权限。'); }
        })
        .onDownloadStart(() => { this.onNotice('当前版本暂不支持文件下载。'); })
        .onAlert((event) => {
          if (event) { this.onDialog('alert', event.message, '', event.result); }
          return true;
        })
        .onConfirm((event) => {
          if (event) { this.onDialog('confirm', event.message, '', event.result); }
          return true;
        })
        .onPrompt((event) => {
          if (event) { this.onDialog('prompt', event.message, event.value, event.result); }
          return true;
        })
      }
      if (this.tab.error) {
        Column({ space: 16 }) {
          Text('页面暂时不可用').fontSize(20).fontColor($r('app.color.text'))
          Text(this.tab.error).fontSize(14).fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
          Button('重新加载').backgroundColor($r('app.color.accent')).fontColor($r('app.color.background'))
            .onClick(() => {
              this.tab.error = '';
              try { this.tab.controller.loadUrl(this.tab.url); } catch (_) { this.tab.error = '请关闭此标签后重新打开。'; }
            })
        }.width('100%').height('100%').justifyContent(FlexAlign.Center).padding(28).backgroundColor($r('app.color.background'))
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.background'))
  }
}
