# 把 PC 网页版打包成 Windows exe（Electron）

IM PC 客户端（`im-pc`）本质是一个 Vue3 + Vite 前端。打包成桌面 exe 只需要用 **Electron** 把构建好的静态产物（`dist/`）包进一个本地窗口，业务逻辑（登录、消息、WebSocket）仍然跑在网页层，不需要改写任何前端代码。

> 关键点：网页版通过 `/api/v1` 这种**相对路径**访问后端，靠 nginx 同源反代。但 exe 用 `file://` 打开，没有服务器做反代，相对路径会失效。因此**构建 exe 版本时必须把后端地址以绝对地址“烧录”进产物**（见步骤 2）。

## 步骤

### 1. 先在 im-pc 根目录构建前端
```bash
cd im-pc
npm install
npm run build      # 产出 im-pc/dist/
```

### 2. 用绝对地址重新构建（对接线上服务器）
把 API / WebSocket 地址在构建时写死为服务器真实地址（替换成你的域名）：

```bash
cd im-pc
VITE_API_BASE=https://im.x123.wang/api/v1 \
VITE_WS_BASE=wss://im.x123.wang/ws \
npm run build
```

> 这两个变量在 `src/api/client.js` 里读取（`import.meta.env.VITE_API_BASE` / `VITE_WS_BASE`）。不设置时默认走相对路径 `/api/v1`，那种产物只能部署在 nginx 后面，不能直接进 exe。

### 3. 安装 Electron 依赖并打包
```bash
cd im-pc/electron
npm install             # 安装 electron + electron-builder（首次较慢）
npm run dist            # 产出 im-pc/electron/release/*.exe
```

打包完成后，`im-pc/electron/release/` 下会生成安装包（NSIS `.exe`）。安装即可使用。

### 4. 开发联调（可选）
想用 Electron 窗口加载 vite 热更新调试：
```bash
# 终端 A：起 vite dev server
cd im-pc && npm run dev        # 假设 5173 端口
# 终端 B：用 Electron 打开它
cd im-pc/electron
ELECTRON_DEV=http://localhost:5173 npm start
```

## 服务端注意事项（CORS）
exe 以 `file://` 或 `app://` 为来源向 `https://im.x123.wang` 发请求 / 建 WebSocket。请确保 Go 网关的 CORS 允许该来源（或允许 `*`），否则浏览器内核会拦截。若嫌 `file://` 来源难配，可改用 Electron 主进程起一个本地 HTTP 服务来 serve `dist/`（`http://127.0.0.1:port`），这样来源就是 `http://127.0.0.1`，CORS 更好配。

## 换图标（可选）
在 `im-pc/electron/package.json` 的 `build.win` 下加 `"icon": "../public/icon.ico"`（准备一个 256x256 的 `.ico`），重新 `npm run dist` 即可。
未配置时会用 Electron 默认图标，不影响功能。

## 文件清单（本目录）
- `main.js`：Electron 主进程，开窗口并加载 `../dist/index.html`
- `preload.js`：预加载脚本（默认只暴露 `window.qmDesktop` 标识，可扩展原生能力）
- `package.json`：Electron 构建配置（appId / nsis / 输出目录）
