// ChatPulse PC 客户端 Electron 主进程。
// 职责很薄：开一个窗口，把已构建好的前端静态产物（im-pc/dist/index.html）加载进来。
// 所有业务逻辑（登录、消息、WebSocket）都跑在网页层，Electron 只负责“包成桌面 exe”。
const { app, BrowserWindow } = require('electron');
const path = require('path');

function createWindow() {
  const win = new BrowserWindow({
    width: 1100,
    height: 760,
    minWidth: 980,
    minHeight: 640,
    title: 'ChatPulse',
    backgroundColor: '#eef1f4',
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      preload: path.join(__dirname, 'preload.js')
    }
  });

  // 开发联调：设置环境变量 ELECTRON_DEV 指向 vite dev server，即可热更新调试
  const dev = process.env.ELECTRON_DEV;
  if (dev) {
    win.loadURL(dev);
  } else {
    // 生产：加载构建产物（im-pc/dist/index.html，vite 已用 base:'./' 输出相对路径，file:// 下可正常加载）
    win.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));
  }

  if (!app.isPackaged) win.webContents.openDevTools({ mode: 'detach' });
}

app.whenReady().then(() => {
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
