// 桌面端预加载脚本：默认只向网页层暴露最小标识。
// 后续若需要原生能力（系统通知、自动更新、托盘、打开外部链接等），在此用 contextBridge 安全地扩展。
const { contextBridge } = require('electron');

contextBridge.exposeInMainWorld('qmDesktop', {
  isElectron: true,
  version: require('./package.json').version
});
