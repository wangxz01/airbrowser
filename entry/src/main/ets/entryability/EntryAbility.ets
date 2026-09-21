import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { browserStore, saveCookies } from '../model/BrowserStore';

export default class EntryAbility extends UIAbility {
  onBackground(): void {
    browserStore.flush().catch(() => {});
    saveCookies().catch(() => {});
  }

  onWindowStageCreate(stage: window.WindowStage): void {
    stage.loadContent('pages/Index', (error) => {
      if (error.code) { console.error(`Air Browser failed to load: ${error.code}`); }
    });
  }
}
