import { BrowserTab } from '../model/BrowserTab';
import { IconButton } from './IconButton';

@Component
export struct TabRow {
  @ObjectLink tab: BrowserTab;
  @Prop selected: boolean = false;
  @Prop compact: boolean = false;
  onSelect: () => void = () => {};
  onClose: () => void = () => {};
  onMove: (direction: number) => void = () => {};

  @Builder
  private tabMenu() {
    Menu() {
      MenuItem({ content: '关闭标签' }).onClick(() => { this.onClose(); })
      MenuItem({ content: '向上移动' }).onClick(() => { this.onMove(-1); })
      MenuItem({ content: '向下移动' }).onClick(() => { this.onMove(1); })
    }
  }

  build() {
    Row() {
      Row({ space: 8 }) {
        Stack({ alignContent: Alignment.BottomEnd }) {
          if (this.tab.favicon) {
            Image(this.tab.favicon).width(20).height(20).objectFit(ImageFit.Contain)
          } else if (this.tab.loading) {
            LoadingProgress().width(20).height(20).color($r('app.color.accent'))
          } else {
            Image(this.tab.url ? $r('app.media.globe') : $r('app.media.app_icon')).width(20).height(20)
          }
          if (this.tab.audio) {
            Image($r('app.media.volume')).width(12).height(12).padding(1)
              .backgroundColor($r('app.color.background')).borderRadius(6).offset({ x: 3, y: 3 })
          } else if (!this.tab.live && this.tab.url) {
            Image($r('app.media.sleep')).width(12).height(12).padding(1)
              .backgroundColor($r('app.color.background')).borderRadius(6).offset({ x: 3, y: 3 })
          }
        }.width(20).height(20)
        if (!this.compact) {
          Text(this.tab.title || '正在加载…').fontSize(13).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor($r('app.color.text')).layoutWeight(1)
        }
      }.layoutWeight(1).height(44).padding({ left: this.compact ? 0 : 10 })
        .justifyContent(this.compact ? FlexAlign.Center : FlexAlign.Start)
        .onClick(() => { this.onSelect(); }).accessibilityText(this.tab.title)
      if (!this.compact && this.selected) {
        IconButton({ icon: $r('app.media.close'), label: '关闭标签', buttonSize: 40, onPress: () => { this.onClose(); } })
      }
    }.width('100%').height(44).borderRadius(14)
      .backgroundColor(this.selected ? $r('app.color.selected') : Color.Transparent)
.bindContextMenu(this.tabMenu, ResponseType.LongPress)
  }
}
