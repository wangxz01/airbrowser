# 原生界面更新 · 2026-09-21

- 新标签页提供 ArkUI Search、六个常用网站、最多四条收藏和四条最近访问，完整列表在系统浮层中打开。
- 使用可换行网站宫格，主页可以滚动；保留 48 vp 顶栏、44 vp 点击区域和可折叠左侧标签。
- 地址栏、按钮、标签和首页卡片使用圆角；浅色与深色资源均已更新。
- 右上角通过 bindMenu + Menu / MenuItemGroup / MenuItem 呈现系统浮动菜单，设置 24 vp 圆角。网页专用操作在主页禁用。
- 设置、收藏夹、历史采用 bindSheet，使用系统遮罩、关闭按钮及浮层动画。Toggle、Slider 和确认操作继续使用系统组件。
- 未修改网页引擎、登录数据保存机制或包名。常用网站目前为固定入口，收藏可自行增删。

## 验证

- 签名构建成功；资源检查和原有 12 项测试通过。
- 已在连接的 MatePad 上覆盖安装，实际检查主页与原生菜单。未卸载或清除应用数据。
- HarmonyOS 5.0.5（API 17）模拟器检查：设置打开与系统返回关闭，历史及收藏浮层打开关闭，菜单返回关闭，新标签页打开。
- 模拟器的中文输入法提交文字后，主页 Search 搜索按钮可打开必应搜索结果。真机软键盘和硬件键盘组合仍需要实际使用确认。
- 真机截图：`artifacts/ui-refresh-home.png`、`artifacts/ui-refresh-menu.png`。
- 模拟器设置截图：`artifacts/ui-refresh-settings.png`。

## 官方组件参考

- [菜单控制：bindMenu](https://developer.huawei.com/consumer/en/doc/harmonyos-references-V14/ts-universal-attributes-menu-V14)
- [半模态转场：bindSheet](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-sheet-transition)
- [Search 搜索组件](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-search)
