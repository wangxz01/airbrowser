import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { browserStore, saveCookies } from '../model/BrowserStore';

export default class EntryAbility extends UIAbility {
  onBackground(): void {
    browserStore.flush().catch(() => {});
    saveCookies().catch(() => {});
  }

  onWindowStageCreate(stage: window.WindowStage): void {
    this.loadWindow(stage);
  }

  private async loadWindow(stage: window.WindowStage): Promise<void> {
    try {
      const appWindow = await stage.getMainWindow();
      // Let the compact browser toolbar occupy the former status-bar space.
      await appWindow.setWindowLayoutFullScreen(true);
      await appWindow.setWindowSystemBarEnable(['navigation']);
    } catch (_) {
      console.warn('Air Browser could not apply the immersive window layout.');
    }
    stage.loadContent('pages/Index', (error) => {
      if (error.code) { console.error(`Air Browser failed to load: ${error.code}`); }
    });
  }
}
