import { useUiStore } from '../stores/ui';
import { useContentStore } from '../stores/content';
import { useAuthStore } from '../stores/auth';

// 视图切换：对齐编译版 switchView 的核心职责（设置 view/filter/search，按需加载数据）。
export function useNavigation() {
  const ui = useUiStore();
  const content = useContentStore();
  const auth = useAuthStore();

  const VALID = ['chats', 'contacts', 'groups', 'favorites', 'files', 'settings', 'moments'];

  async function switchView(view) {
    if (!VALID.includes(view)) view = 'chats';
    ui.view = view;
    ui.filter = 'all';
    ui.search = '';
    // 进入朋友圈默认看自己的时间线（查看他人由 Inspector 显式 openMoments 设置 owner）
    if (view === 'moments') ui.momentsOwner = null;
    if (view === 'favorites' && !content.favorites.length) await content.loadFavorites();
    if (view === 'files' && !content.media.length) await content.loadMedia();
    if (view === 'settings' && !Object.keys(auth.preferences).length) await auth.loadPreferences();
  }

  return { switchView, VALID };
}
