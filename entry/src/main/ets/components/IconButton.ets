@Component
export struct IconButton {
  @Prop icon: Resource = $r('app.media.more');
  @Prop label: string = '';
  @Prop available: boolean = true;
  @Prop selected: boolean = false;
  @Prop buttonSize: number = 44;
  onPress: () => void = () => {};

  build() {
    Button({ type: ButtonType.Normal }) {
      Image(this.icon).width(19).height(19)
    }.width(this.buttonSize).height(this.buttonSize).padding(0).borderRadius(14)
      .backgroundColor(this.selected ? $r('app.color.soft') : Color.Transparent)
      .enabled(this.available).opacity(this.available ? 1 : 0.32)
      .accessibilityText(this.label).onClick(() => { this.onPress(); })
  }
}
