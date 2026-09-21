import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { KeyCode } from '@kit.InputKit';
import { webview } from '@kit.ArkWeb';
import { BrowserTab } from '../model/BrowserTab';
import { BrowserSnapshot, SavedPage, SavedTab, SitePreference, BILI_HOME, MAX_TABS,
  backAction, isWebUrl, webHost, resolveAddress, recordVisit, nextAfterClose } from '../model/BrowserRules';
import { browserStore, saveCookies } from '../model/BrowserStore';
import { BrowserPane } from '../components/BrowserPane';
import { IconButton } from '../components/IconButton';
import { TabRow } from '../components/TabRow';

@Entry
@Component
struct Index {
  @State ready: boolean = false;
  @State tabs: BrowserTab[] = [];
  @State activeId: string = '';
  @State bookmarks: SavedPage[] = [];
  @State history: SavedPage[] = [];
  @State sites: SitePreference[] = [];
  @State collapsed: boolean = false;
  @State sidebarWidth: number = 220;
  @State windowWidth: number = 1000;
  @State backNavigates: boolean = false;
  @State address: string = '';
  @State editing: boolean = false;
  @State fullScreen: boolean = false;
  @State @Watch('syncPanel') panel: string = '';
  @State sheetShown: boolean = false;
  @State menuShown: boolean = false;
  @State homeQuery: string = '';
  @State homeEditing: boolean = false;
  private homeSearch: SearchController = new SearchController();
  @State notice: string = '';
  @State progress: number = 100;
  @State canBack: boolean = false;
  @State canForward: boolean = false;
  @State loading: boolean = false;
  @State starred: boolean = false;
  @State currentDesktop: boolean = false;
  @State activeHome: boolean = true;
  @State dialogKind: string = '';
  @State dialogMessage: string = '';
  @State dialogValue: string = '';
  @State dialogOrigin: string = '';
  private input: TextInputController = new TextInputController();
  private closed: SavedTab[] = [];
  private exitHandler?: FullScreenExitHandler;
  private fullTabId: string = '';
  private jsResult?: JsResult;
  private noticeTimer: number = -1;
  private sequence: number = 0;
  private systemBarQueue: Promise<void> = Promise.resolve();

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    const state = await browserStore.open(this.getUIContext().getHostContext() as common.UIAbilityContext);
    this.bookmarks = state.bookmarks; this.history = state.history; this.sites = state.sites;
    this.collapsed = state.collapsed; this.sidebarWidth = state.sidebarWidth; this.backNavigates = state.backNavigates;
    this.tabs = state.tabs.map((saved: SavedTab) => {
      const tab = new BrowserTab(saved.id, saved.url, saved.title);
      tab.desktop = this.preferDesktop(saved.url);
      tab.live = saved.id === state.activeId && saved.url !== '';
      return tab;
    });
    this.activeId = state.activeId;
    try { webview.WebCookieManager.putAcceptCookieEnabled(true); } catch (_) {}
    this.ready = true; this.syncView();
    if (browserStore.lastError) { this.showNotice(browserStore.lastError); }
  }

  private syncPanel(): void { this.sheetShown = this.panel !== ''; }

  private current(): BrowserTab | undefined { return this.tabs.find((t: BrowserTab) => t.id === this.activeId); }
  private compact(): boolean { return this.collapsed || this.windowWidth < 720; }
  private newId(): string { this.sequence++; return `tab-${Date.now()}-${this.sequence}`; }
  private preferDesktop(url: string): boolean { return this.sites.some((s: SitePreference) => s.host === webHost(url) && s.desktop); }

  private capture(): void {
    if (!this.ready) { return; }
    const snapshot: BrowserSnapshot = {
      version: 1, tabs: this.tabs.map((t: BrowserTab): SavedTab => ({ id: t.id, url: t.url, title: t.title })),
      activeId: this.activeId, bookmarks: this.bookmarks, history: this.history, sites: this.sites,
      collapsed: this.collapsed, sidebarWidth: this.sidebarWidth, backNavigates: this.backNavigates
    };
    browserStore.capture(snapshot);
  }

  private syncView(): void {
    const tab = this.current();
    if (!tab) { return; }
    if (!this.editing) { this.address = tab.url; }
    this.canBack = tab.canBack; this.canForward = tab.canForward; this.progress = tab.progress;
    this.loading = tab.loading; this.currentDesktop = tab.desktop; this.activeHome = !tab.live;
    this.starred = this.bookmarks.some((p: SavedPage) => p.url === tab.url);
  }

  private showNotice(message: string): void {
    clearTimeout(this.noticeTimer); this.notice = message;
    this.noticeTimer = setTimeout(() => { this.notice = ''; }, 4500);
  }

  onPageHide(): void { this.capture(); browserStore.flush().catch(() => {}); saveCookies().catch(() => {}); }
  onPageShow(): void { if (browserStore.lastError) { this.showNotice(browserStore.lastError); } }
  aboutToDisappear(): void {
    clearTimeout(this.noticeTimer); this.capture(); browserStore.flush().catch(() => {});
    this.jsResult?.handleCancel(); this.jsResult = undefined;
    this.leaveFullscreen();
  }

  onBackPress(): boolean {
    if (this.menuShown) { this.menuShown = false; return true; }
    const action = backAction({ editing: this.editing || this.homeEditing, dialog: this.dialogKind !== '', panel: this.panel !== '',
      fullscreen: this.fullScreen, navigates: this.backNavigates, canBack: this.canBack });
    if (action === 'keyboard') { this.homeSearch.stopEditing(); this.homeEditing = false; this.input.stopEditing(); this.editing = false; this.syncView(); }
    else if (action === 'dialog') { this.answerDialog(false); }
    else if (action === 'panel') { this.panel = ''; }
    else if (action === 'fullscreen') { this.leaveFullscreen(); }
    else if (action === 'history') { this.goBack(); }
    else { this.showNotice('网页后退请使用顶部箭头；上滑回到桌面。'); }
    return true;
  }

  private selectTab(id: string): void {
    if (this.fullScreen) { this.leaveFullscreen(); }
    this.homeSearch.stopEditing(); this.homeEditing = false; this.homeQuery = '';
    this.input.stopEditing(); this.editing = false; this.menuShown = false; this.panel = '';
    const tab = this.tabs.find((t: BrowserTab) => t.id === id);
    if (!tab) { return; }
    this.activeId = id;
    if (tab.url && !tab.live) { tab.source = tab.url; tab.live = true; }
    this.syncView(); this.capture();
  }

  private addTab(url: string = '', popup?: ControllerHandler): void {
    if (this.tabs.length >= MAX_TABS) {
      popup?.setWebController(null);
      this.showNotice(`最多保留 ${MAX_TABS} 个标签，请先关闭一些标签。`); return;
    }
    const tab = new BrowserTab(this.newId(), url, url ? webHost(url) : '新标签页');
    tab.desktop = this.preferDesktop(url); tab.popup = popup; tab.live = !!url || !!popup;
    this.tabs = [...this.tabs, tab]; this.selectTab(tab.id);
  }

  private closeTab(id: string): void {
    const tab = this.tabs.find((t: BrowserTab) => t.id === id);
    if (!tab) { return; }
    if (id === this.fullTabId) { this.leaveFullscreen(); }
    if (id === this.activeId && this.dialogKind) { this.answerDialog(false); }
    if (tab.url) { const saved: SavedTab = { id: tab.id, url: tab.url, title: tab.title }; const items: SavedTab[] = [saved, ...this.closed]; this.closed = items.slice(0, 12); }
    try { if (tab.ready) { tab.controller.stop(); tab.controller.loadUrl('about:blank'); } } catch (_) {}
    const next = nextAfterClose(this.tabs.map((t: BrowserTab) => t.id), this.activeId, id);
    this.tabs = this.tabs.filter((t: BrowserTab) => t.id !== id);
    if (this.tabs.length === 0) { this.addTab(); }
    else { this.selectTab(next); }
    saveCookies().catch(() => {}); this.capture();
  }

  private reopen(): void {
    if (!this.closed.length) { this.showNotice('本次打开期间没有关闭的网页。'); return; }
    if (this.tabs.length >= MAX_TABS) { this.showNotice('请先关闭一个标签。'); return; }
    const saved = this.closed[0]; this.closed = this.closed.slice(1); this.addTab(saved.url);
  }

  private moveTab(id: string, direction: number): void {
    const i = this.tabs.findIndex((t: BrowserTab) => t.id === id);
    const j = i + direction;
    if (i < 0 || j < 0 || j >= this.tabs.length) { return; }
    const copy = this.tabs.slice(); const held = copy[i]; copy[i] = copy[j]; copy[j] = held;
    this.tabs = copy; this.capture();
  }

  private navigate(input: string): void {
    const url = resolveAddress(input);
    if (!url) { this.showNotice('请输入网址或搜索词，目前支持 HTTP 和 HTTPS 网页。'); return; }
    const tab = this.current(); if (!tab) { return; }
    this.homeSearch.stopEditing(); this.homeEditing = false; this.homeQuery = '';
    this.input.stopEditing(); this.editing = false; this.menuShown = false; this.panel = '';
    tab.favicon = undefined;
    tab.url = url; tab.title = webHost(url); tab.error = ''; tab.desktop = this.preferDesktop(url);
    if (tab.live && tab.ready) {
      try { tab.applyAgent(); tab.controller.loadUrl(url); }
      catch (_) { tab.error = '无法打开网址，请重试。'; }
    } else { tab.source = url; tab.live = true; }
    this.syncView(); this.capture();
  }

  private goBack(): void {
    const tab = this.current(); if (!tab?.ready) { return; }
    try { if (tab.controller.accessBackward()) { tab.controller.backward(); } } catch (_) { this.showNotice('暂时无法后退。'); }
  }

  private goForward(): void {
    const tab = this.current(); if (!tab?.ready) { return; }
    try { if (tab.controller.accessForward()) { tab.controller.forward(); } } catch (_) { this.showNotice('暂时无法前进。'); }
  }

  private reload(): void {
    const tab = this.current(); if (!tab) { return; }
    if (!tab.live && tab.url) { tab.source = tab.url; tab.live = true; this.syncView(); return; }
    if (!tab.ready) { return; }
    try {
      if (tab.loading) { tab.controller.stop(); tab.loading = false; }
      else { tab.error = ''; tab.controller.refresh(); }
      this.syncView();
    } catch (_) { this.showNotice('暂时无法刷新。'); }
  }

  private pageChanged(tab: BrowserTab, url: string, finished: boolean): void {
    if (!this.tabs.some((t: BrowserTab) => t.id === tab.id)) { return; }
    if (finished) { this.history = recordVisit(this.history, url, tab.title || webHost(url), Date.now()); }
    this.syncView(); this.capture();
  }

  private newWindow(event: OnWindowNewEvent): void {
    if (!event.isUserTrigger || (event.targetUrl && event.targetUrl !== 'about:blank' && !isWebUrl(event.targetUrl))) {
      event.handler.setWebController(null); this.showNotice('已阻止自动弹窗或应用跳转。'); return;
    }
    this.addTab(isWebUrl(event.targetUrl) ? event.targetUrl : '', event.handler);
  }

  private fullscreen(tabId: string, handler?: FullScreenExitHandler): void {
    if (handler) {
      this.exitHandler = handler; this.fullTabId = tabId; this.fullScreen = true; this.panel = '';
      this.input.stopEditing(); this.editing = false;
      this.setSystemBars(true);
    } else if (this.fullTabId === tabId) {
      this.exitHandler = undefined; this.fullTabId = ''; this.fullScreen = false; this.setSystemBars(false);
    }
  }

  private leaveFullscreen(): void {
    const handler = this.exitHandler;
    this.exitHandler = undefined; this.fullTabId = ''; this.fullScreen = false;
    try { handler?.exitFullScreen(); } catch (_) {}
    this.setSystemBars(false);
  }

  private setSystemBars(full: boolean): void {
    if (deviceInfo.deviceType === '2in1') { return; }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.systemBarQueue = this.systemBarQueue.catch(() => {}).then(async () => {
      const appWindow = await window.getLastWindow(context);
      await appWindow.setWindowSystemBarEnable(full ? [] : ['status', 'navigation']);
      await appWindow.setWindowLayoutFullScreen(full);
    }).catch(() => {});
  }

  private toggleStar(): void {
    const tab = this.current(); if (!tab || !isWebUrl(tab.url)) { return; }
    if (this.bookmarks.some((p: SavedPage) => p.url === tab.url)) {
      this.bookmarks = this.bookmarks.filter((p: SavedPage) => p.url !== tab.url);
      this.showNotice('已取消收藏');
    } else {
      if (this.bookmarks.length >= 200) { this.showNotice('收藏已满，请先移除一些收藏。'); return; }
      this.bookmarks = [{ url: tab.url, title: tab.title, time: Date.now() }, ...this.bookmarks]; this.showNotice('已收藏');
    }
    this.syncView(); this.capture();
  }

  private toggleDesktop(): void {
    const tab = this.current(); if (!tab || !isWebUrl(tab.url)) { return; }
    tab.desktop = !tab.desktop;
    const host = webHost(tab.url);
    const setting: SitePreference = { host: host, desktop: tab.desktop };
    const sites: SitePreference[] = [setting, ...this.sites.filter((s: SitePreference) => s.host !== host)];
    this.sites = sites.slice(0, 200);
    try { tab.applyAgent(); if (tab.ready) { tab.controller.refresh(); } } catch (_) { this.showNotice('显示模式切换失败，请重试。'); }
    this.syncView(); this.capture(); this.panel = '';
  }

  private async saveNow(): Promise<void> {
    this.capture(); this.panel = '';
    try { await browserStore.flush(); await saveCookies(); browserStore.lastError = ''; this.showNotice('标签与可持久化的网站状态已保存。'); }
    catch (_) { this.showNotice(browserStore.lastError || '保存失败，请重试。'); }
  }

  private clearCache(): void {
    const tab = this.current(); this.panel = '';
    if (!tab?.ready) { this.showNotice('请先打开一个网页。'); return; }
    try { tab.controller.removeCache(true); this.showNotice('已清理网页资源缓存，未清除 Cookie 和网站存储。'); }
    catch (_) { this.showNotice('缓存清理失败，请稍后重试。'); }
  }

  private sleepOthers(): void {
    let count = 0;
    this.tabs.forEach((tab: BrowserTab) => {
      if (tab.id !== this.activeId && tab.live && !tab.audio && !tab.popup) {
        try { tab.controller.stop(); } catch (_) {}
        tab.live = false; tab.ready = false; tab.canBack = false; tab.canForward = false;
        tab.controller = new webview.WebviewController(); count++;
      }
    });
    this.panel = ''; this.showNotice(`已休眠 ${count} 个无声音的后台标签，重新打开时会加载页面。`);
  }

  private openDialog(tab: BrowserTab, kind: string, message: string, value: string, result: JsResult): void {
    if (tab.id !== this.activeId || this.jsResult) { result.handleCancel(); return; }
    this.jsResult = result; this.dialogOrigin = webHost(tab.url); this.dialogKind = kind;
    this.dialogMessage = message.slice(0, 2000); this.dialogValue = value; this.panel = '';
  }

  private answerDialog(accept: boolean): void {
    const result = this.jsResult; this.jsResult = undefined;
    if (accept) {
      if (this.dialogKind === 'prompt') { result?.handlePromptConfirm(this.dialogValue); }
      else { result?.handleConfirm(); }
    } else { result?.handleCancel(); }
    this.dialogKind = ''; this.dialogMessage = ''; this.dialogValue = '';
  }

  @Builder
  private browserToolbar() {
    Row({ space: 1 }) {
      IconButton({ icon: $r('app.media.sidebar'), label: '展开或收起标签栏', onPress: () => { this.collapsed = !this.collapsed; this.capture(); } })
      IconButton({ icon: $r('app.media.back'), label: '网页后退', available: this.canBack, onPress: () => { this.goBack(); } })
      IconButton({ icon: $r('app.media.forward'), label: '网页前进', available: this.canForward, onPress: () => { this.goForward(); } })
      if (this.windowWidth > 500) {
        IconButton({ icon: this.loading ? $r('app.media.close') : $r('app.media.refresh'), label: this.loading ? '停止加载' : '刷新网页', onPress: () => { this.reload(); } })
      }
      Row() {
        if (this.windowWidth > 600) {
          Image(this.address.startsWith('https://') ? $r('app.media.lock') : $r('app.media.globe')).width(14).height(14)
            .margin({ left: 10 })
        }
        TextInput({ text: this.address, placeholder: '搜索或输入网址', controller: this.input })
          .layoutWeight(1).height(36).fontSize(14).fontColor($r('app.color.text')).backgroundColor(Color.Transparent)
          .padding({ left: 10, right: 4 }).enterKeyType(EnterKeyType.Go).maxLength(8192)
          .onFocus(() => { this.editing = true; })
          .onBlur(() => { this.editing = false; this.syncView(); })
          .onChange((value) => { this.address = value; })
          .onSubmit(() => { this.navigate(this.address); })
          .onKeyEvent((event) => {
            if (event.type === KeyType.Down && (event.keyCode === KeyCode.KEYCODE_ENTER || event.keyCode === KeyCode.KEYCODE_NUMPAD_ENTER)) {
              const value = this.address; event.stopPropagation(); this.navigate(value);
            }
          })
          .accessibilityText('地址和搜索')
        if (this.editing) {
          IconButton({ icon: $r('app.media.forward'), label: '打开网址或搜索', onPress: () => { this.navigate(this.address); } })
        } else if (this.windowWidth > 600) {
          IconButton({ icon: $r('app.media.star'), label: this.starred ? '取消收藏' : '收藏网页', selected: this.starred,
            available: !!this.current()?.url, onPress: () => { this.toggleStar(); } })
        }
      }.height(36).layoutWeight(1).backgroundColor($r('app.color.background')).borderRadius(18).margin({ left: 3, right: 3 })
      Button({ type: ButtonType.Normal }) {
        Image($r('app.media.more')).width(19).height(19)
      }.width(44).height(44).padding(0).borderRadius(14).backgroundColor(Color.Transparent)
        .accessibilityText('更多选项')
        .onClick(() => { this.menuShown = !this.menuShown; })
        .bindMenu(this.menuShown, this.menuContents, {
          placement: Placement.BottomRight, borderRadius: 24,
          onAppear: () => { this.input.stopEditing(); this.homeSearch.stopEditing(); },
          onDisappear: () => { this.menuShown = false; }
        })
    }.height(48).width('100%').padding({ left: 4, right: 4 }).backgroundColor($r('app.color.chrome'))
      .visibility(this.fullScreen ? Visibility.None : Visibility.Visible)
  }

  @Builder
  private sidebar() {
    Column({ space: 4 }) {
      if (!this.compact()) {
        Row() {
          Text('标签页').fontSize(12).fontColor($r('app.color.muted')).layoutWeight(1)
          Text(`${this.tabs.length}`).fontSize(12).fontColor($r('app.color.muted'))
        }.height(26).width('100%').padding({ left: 10, right: 10 })
      }
      List({ space: 4 }) {
        ForEach(this.tabs, (tab: BrowserTab) => {
          ListItem() {
            TabRow({ tab: tab, selected: this.activeId === tab.id, compact: this.compact(),
              onSelect: () => { this.selectTab(tab.id); }, onClose: () => { this.closeTab(tab.id); }, onMove: (direction) => { this.moveTab(tab.id, direction); } })
          }
        }, (tab: BrowserTab) => tab.id)
        ListItem() {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 10 }) {
              Image($r('app.media.plus')).width(18).height(18)
              if (!this.compact()) { Text('新建标签页').fontSize(13).fontColor($r('app.color.muted')) }
            }.width('100%').justifyContent(this.compact() ? FlexAlign.Center : FlexAlign.Start).padding({ left: this.compact() ? 0 : 10 })
          }.width('100%').height(44).backgroundColor($r('app.color.soft')).borderRadius(14).padding(0)
            .accessibilityText('新建标签页').onClick(() => { this.addTab(); })
        }
      }.width('100%').layoutWeight(1).scrollBar(BarState.Auto)
    }.width(this.compact() ? 52 : this.sidebarWidth).height('100%').padding({ top: 8, bottom: 8, left: 5, right: 5 })
      .backgroundColor($r('app.color.chrome')).visibility(this.fullScreen ? Visibility.None : Visibility.Visible)
  }

  @Builder
  private siteTile(label: string, mark: string, color: string, url: string) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 10 }) {
        Text(mark).fontSize(22).fontWeight(FontWeight.Medium).fontColor(Color.White)
          .width(48).height(48).textAlign(TextAlign.Center).backgroundColor(color).borderRadius(16)
        Text(label).fontSize(13).fontColor($r('app.color.text')).maxLines(1)
      }.width('100%').padding({ top: 16, bottom: 16 })
    }.width(this.windowWidth - (this.compact() ? 52 : this.sidebarWidth) > 680 ? '16.66%' : '33.33%')
      .padding(3).backgroundColor(Color.Transparent).borderRadius(20)
      .accessibilityText(label).onClick(() => { this.navigate(url); })
  }

  @Builder
  private sectionTitle(title: string, action: string, target: string) {
    Row() {
      Text(title).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).layoutWeight(1)
      Button(action, { type: ButtonType.Capsule }).fontSize(13).fontColor($r('app.color.accent'))
        .height(36).backgroundColor(Color.Transparent).onClick(() => { this.panel = target; })
    }.width('100%').margin({ bottom: 8 })
  }

  @Builder
  private homePageCard(page: SavedPage, favorite: boolean) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Image(favorite ? $r('app.media.star') : $r('app.media.globe')).width(20).height(20)
        Column({ space: 5 }) {
          Text(page.title || webHost(page.url)).fontSize(14).fontColor($r('app.color.text'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(webHost(page.url)).fontSize(12).fontColor($r('app.color.muted')).maxLines(1)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Image($r('app.media.forward')).width(16).height(16)
      }.width('100%').padding(16)
    }.width('100%').height(72).padding(0).borderRadius(18).backgroundColor($r('app.color.background'))
      .onClick(() => { this.navigate(page.url); })
  }

  @Builder
  private home() {
    Scroll() {
      Column({ space: 28 }) {
        Column({ space: 12 }) {
          Text('Air').fontSize(42).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
          Text('开启新的探索').fontSize(14).fontColor($r('app.color.muted'))
          Search({ value: this.homeQuery, placeholder: '搜索或输入网址', controller: this.homeSearch })
            .searchButton('搜索').height(56).borderRadius(28).fontColor($r('app.color.text'))
            .backgroundColor($r('app.color.background')).margin({ top: 16 })
            .onChange((value: string) => { this.homeQuery = value; })
            .onEditChange((editing: boolean) => { this.homeEditing = editing; })
            .onSubmit((value: string) => { this.navigate(value); })
            .accessibilityText('主页搜索或输入网址')
        }.width('100%').padding({ top: 24, bottom: 4 })
        Column() {
          Row() {
            Text('常用网站').fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
          }.width('100%').margin({ bottom: 8 })
          Flex({ wrap: FlexWrap.Wrap }) {
            this.siteTile('哔哩哔哩', '哔', '#D94C7B', BILI_HOME)
            this.siteTile('必应', 'B', '#167C85', 'https://www.bing.com/')
            this.siteTile('百度', '度', '#3764DC', 'https://www.baidu.com/')
            this.siteTile('知乎', '知', '#2479D9', 'https://www.zhihu.com/')
            this.siteTile('维基百科', 'W', '#626B7B', 'https://zh.wikipedia.org/')
            this.siteTile('GitHub', 'G', '#323C50', 'https://github.com/')
          }.width('100%').backgroundColor($r('app.color.background')).borderRadius(24).padding(8)
        }.width('100%')
        Column({ space: 8 }) {
          this.sectionTitle('我的收藏', '全部收藏', 'bookmarks')
          if (this.bookmarks.length === 0) {
            Row({ space: 14 }) {
              Image($r('app.media.star')).width(24).height(24)
              Column({ space: 6 }) {
                Text('把喜欢的网站留在这里').fontSize(14).fontColor($r('app.color.text'))
                Text('浏览网页时，点击地址栏的星标即可收藏').fontSize(12).fontColor($r('app.color.muted'))
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            }.width('100%').padding(22).borderRadius(24).backgroundColor($r('app.color.background'))
          } else {
            ForEach(this.bookmarks.slice(0, 4), (page: SavedPage) => { this.homePageCard(page, true); }, (page: SavedPage) => page.url)
          }
        }.width('100%').alignItems(HorizontalAlign.Start)
        if (this.history.length > 0) {
          Column({ space: 8 }) {
            this.sectionTitle('最近访问', '全部历史', 'history')
            ForEach(this.history.slice(0, 4), (page: SavedPage) => { this.homePageCard(page, false); }, (page: SavedPage) => page.url)
          }.width('100%')
        }
      }.width('100%').constraintSize({ maxWidth: 840 }).padding({ left: 28, right: 28, top: 24, bottom: 40 })
    }.width('100%').height('100%').backgroundColor($r('app.color.soft')).scrollBar(BarState.Auto)
  }

  @Builder
  private content() {
    Stack({ alignContent: Alignment.Center }) {
      ForEach(this.tabs, (tab: BrowserTab) => {
          BrowserPane({ tab: tab, active: tab.id === this.activeId,
            onChanged: () => { this.syncView(); this.capture(); },
            onLocation: (url, finished) => { this.pageChanged(tab, url, finished); },
            onBeforeNavigate: (url) => {
              const desktop = this.preferDesktop(url);
              if (tab.desktop !== desktop) {
                tab.desktop = desktop;
                try { tab.applyAgent(); } catch (_) { this.showNotice('未能应用此站点的显示偏好。'); }
              }
            },
            onPopup: (event) => { this.newWindow(event); },
            onFullscreen: (handler) => { this.fullscreen(tab.id, handler); },
            onDialog: (kind, message, value, result) => { this.openDialog(tab, kind, message, value, result); },
            onClose: () => { this.closeTab(tab.id); },
            onNotice: (message) => { this.showNotice(message); }
          }).visibility(tab.id === this.activeId ? Visibility.Visible : Visibility.Hidden)
      }, (tab: BrowserTab) => tab.id)
      if (this.activeHome) { this.home(); }
    }.width('100%').height('100%').backgroundColor($r('app.color.background'))
  }

  @Builder
  private menuItem(label: string, action: () => void) {
    Button(label, { type: ButtonType.Normal }).width('100%').height(44).fontSize(14).fontColor($r('app.color.text'))
      .backgroundColor(Color.Transparent).borderRadius(16).align(Alignment.Start).padding({ left: 12, right: 12 }).onClick(action)
  }

  @Builder
  private menuContents() {
    Menu() {
      MenuItemGroup() {
        MenuItem({ startIcon: $r('app.media.plus'), content: '新建标签页' }).onClick(() => { this.addTab(); })
        MenuItem({ content: '重新打开关闭的标签' }).onClick(() => { this.reopen(); })
      }
      MenuItemGroup() {
        MenuItem({ startIcon: $r('app.media.star'), content: '收藏夹' }).onClick(() => { this.panel = 'bookmarks'; })
        MenuItem({ content: '浏览历史' }).onClick(() => { this.panel = 'history'; })
        MenuItem({ content: this.starred ? '取消收藏当前网页' : '收藏当前网页' })
          .enabled(!this.activeHome).onClick(() => { this.toggleStar(); })
      }
      MenuItemGroup() {
        MenuItem({ startIcon: $r('app.media.refresh'), content: '刷新网页' }).enabled(!this.activeHome).onClick(() => { this.reload(); })
        MenuItem({ content: this.currentDesktop ? '使用默认网页' : '请求电脑版网页' }).enabled(!this.activeHome)
          .onClick(() => { this.toggleDesktop(); })
        MenuItem({ content: this.current()?.muted ? '恢复网页声音' : '静音网页' }).enabled(!this.activeHome).onClick(() => {
          const tab = this.current(); if (!tab?.ready) { return; }
          try { tab.muted = !tab.muted; tab.controller.setAudioMuted(tab.muted); this.showNotice(tab.muted ? '当前标签已静音' : '当前标签已恢复声音'); } catch (_) {}
        })
      }
      MenuItemGroup() {
        MenuItem({ content: '设置' }).onClick(() => { this.panel = 'settings'; })
        MenuItem({ startIcon: $r('app.media.close'), content: '关闭当前标签' }).onClick(() => { this.closeTab(this.activeId); })
      }
    }.width(272)
  }

  @Builder
  private pageList(pages: SavedPage[], favorites: boolean) {
    if (pages.length === 0) {
      Text(favorites ? '还没有收藏的网页' : '还没有浏览记录').fontSize(14).fontColor($r('app.color.muted')).padding(24)
    }
    ForEach(pages, (page: SavedPage) => {
      Row() {
        Column({ space: 4 }) {
          Text(page.title || webHost(page.url)).fontSize(14).fontColor($r('app.color.text')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(webHost(page.url)).fontSize(12).fontColor($r('app.color.muted')).maxLines(1)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start).padding(10).onClick(() => { this.addTab(page.url); })
        if (favorites) {
          IconButton({ icon: $r('app.media.close'), label: '移除收藏', onPress: () => {
            this.bookmarks = this.bookmarks.filter((p: SavedPage) => p.url !== page.url); this.syncView(); this.capture();
          } })
        }
      }.width('100%').constraintSize({ minHeight: 64 }).padding(6).borderRadius(18).backgroundColor($r('app.color.background'))
    }, (page: SavedPage) => page.url)
    if (!favorites && pages.length > 0) {
      this.menuItem('清空浏览历史', () => {
        this.getUIContext().showAlertDialog({ title: '清空浏览历史？', message: '不会清除标签、收藏和登录数据。',
          primaryButton: { value: '取消', action: () => {} },
          secondaryButton: { value: '清空', action: () => { this.history = []; this.capture(); } } });
      })
    }
  }

  @Builder
  private settingsContents() {
    Text('浏览与布局').fontSize(12).fontColor($r('app.color.muted')).padding(12)
    Row() {
      Text('系统返回控制网页后退').fontSize(14).fontColor($r('app.color.text')).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.backNavigates }).onChange((value) => { this.backNavigates = value; this.capture(); })
    }.width('100%').height(56).padding({ left: 12, right: 12 })
    Text('关闭时，网页后退使用顶部箭头；系统返回仅收起浮层或退出全屏。').fontSize(12).fontColor($r('app.color.muted')).padding(12)
    Text(`展开的标签栏宽度：${this.sidebarWidth} vp`).fontSize(14).fontColor($r('app.color.text')).padding(12)
    Slider({ value: this.sidebarWidth, min: 180, max: 280, step: 10 }).padding({ left: 12, right: 12 })
      .onChange((value) => { this.sidebarWidth = value; this.capture(); })
    Divider().color($r('app.color.line')).margin({ top: 12, bottom: 8 })
    Text('本机数据').fontSize(12).fontColor($r('app.color.muted')).padding(12)
    this.menuItem('保存标签与网站状态', () => { this.saveNow(); })
    this.menuItem('只清理网页资源缓存', () => { this.clearCache(); })
    this.menuItem('休眠无声音的后台标签', () => {
      this.getUIContext().showAlertDialog({ title: '休眠后台标签？', message: '无声音的后台页面将停止，表单和页面内历史不会保留；再次打开会重新加载。正在发声的标签会保留。',
        primaryButton: { value: '取消', action: () => {} }, secondaryButton: { value: '休眠', action: () => { this.sleepOthers(); } } });
    })
    Text('登录有效期由网站决定。应用重启后恢复标签地址；网页内的前进后退历史从本次打开重新开始。').fontSize(12).fontColor($r('app.color.muted')).padding(12)
    Divider().color($r('app.color.line')).margin({ top: 12, bottom: 8 })
    Text('Air 浏览器 0.1.0').fontSize(13).fontColor($r('app.color.text')).padding(12)
  }

  @Builder
  private panelView() {
    Column() {
      Row() {
        Text(this.panel === 'settings' ? '设置' : this.panel === 'history' ? '浏览历史' : '收藏夹')
          .fontSize(22).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).layoutWeight(1)
      }.height(64).width('100%').padding({ left: 24, right: 56 })
      Scroll() {
        Column({ space: 8 }) {
          if (this.panel === 'settings') { this.settingsContents(); }
          else if (this.panel === 'history') { this.pageList(this.history, false); }
          else { this.pageList(this.bookmarks, true); }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, bottom: 24 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Auto)
    }.width('100%').height('100%')
  }

  @Builder
  private dialogView() {
    Stack() {
      Row().width('100%').height('100%').backgroundColor('#66000000')
      Column({ space: 16 }) {
        Text(this.dialogOrigin).fontSize(13).fontColor($r('app.color.muted')).maxLines(1)
        Scroll() { Text(this.dialogMessage).fontSize(16).fontColor($r('app.color.text')).width('100%') }
          .constraintSize({ maxHeight: 240 }).width('100%')
        if (this.dialogKind === 'prompt') {
          TextInput({ text: this.dialogValue }).onChange((value) => { this.dialogValue = value; }).fontSize(16)
        }
        Row({ space: 12 }) {
          if (this.dialogKind !== 'alert') { Button('取消').onClick(() => { this.answerDialog(false); }).backgroundColor($r('app.color.soft')).fontColor($r('app.color.text')) }
          Button('确定').onClick(() => { this.answerDialog(true); }).backgroundColor($r('app.color.accent')).fontColor($r('app.color.background'))
        }.justifyContent(FlexAlign.End).width('100%')
      }.width('88%').constraintSize({ maxWidth: 480 }).padding(24).backgroundColor($r('app.color.background')).borderRadius(28)
    }.width('100%').height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        if (this.ready) {
          this.browserToolbar();
          Row() {
            this.sidebar();
            Stack({ alignContent: Alignment.TopStart }) {
              this.content();
              if (this.loading && !this.fullScreen) {
                Progress({ value: this.progress, total: 100, type: ProgressType.Linear }).width('100%').height(2).color($r('app.color.accent'))
              }
            }.layoutWeight(1).height('100%')
          }.width('100%').layoutWeight(1)
        } else { LoadingProgress().width(40).height(40).color($r('app.color.accent')) }
      }.width('100%').height('100%').backgroundColor($r('app.color.background'))
      if (this.fullScreen) {
        Row() {
          IconButton({ icon: $r('app.media.exit_fullscreen'), label: '退出视频全屏', onPress: () => { this.leaveFullscreen(); } })
        }.backgroundColor($r('app.color.chrome')).borderRadius(8).position({ x: 12, y: 12 })
      }
      if (this.dialogKind) { this.dialogView(); }
      if (this.notice) {
        Text(this.notice).fontSize(13).fontColor($r('app.color.text')).backgroundColor($r('app.color.selected'))
          .padding({ top: 12, bottom: 12, left: 18, right: 18 }).borderRadius(9).margin({ bottom: 18 })
          .constraintSize({ maxWidth: '88%' }).onClick(() => { this.notice = ''; })
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.background'))
      .bindSheet($$this.sheetShown, this.panelView(), {
        height: '80%', width: 520, preferType: SheetType.CENTER,
        showClose: true, dragBar: false, backgroundColor: $r('app.color.soft'),
        onDisappear: () => { this.panel = ''; }
      })
      .onAreaChange((oldArea, newArea) => { this.windowWidth = Number(newArea.width); })
  }
}
