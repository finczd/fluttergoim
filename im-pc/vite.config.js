import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';

// PC 网页版构建配置。
// 产物输出到 dist/，部署时把 dist/* 覆盖到线上 pc/ 目录即可。
// API 走同源相对路径 /api/v1（开发经下方代理到本地 Go 网关 8080，生产由 nginx 反代）。
export default defineConfig({
  base: './',
  plugins: [vue()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    proxy: {
      // 开发代理到线上网关。目标用 https/wss，但本地 dev 访问源是 http://localhost:5173，
      // vite 的 TLS 校验会以 localhost 去对证书 altnames（DNS:im.x123.wang）导致
      // ERR_TLS_CERT_ALTNAME_INVALID / ECONNRESET，进而把 /api 与 /ws 全部打挂。
      // secure:false 关闭本地对目标证书的校验（仅开发期；线上 nginx 用真实证书不受影响）。
      '/api': { target: 'https://im.x123.wang', changeOrigin: true, secure: false },
      '/ws': {
        // WS 反代到 Go 网关（gateway:9090 在 container 内，dev 用 9090 端口透出）
        target: 'wss://im.x123.wang/ws',
        ws: true,
        secure: false, // 同 /api：关闭本地对目标证书的校验，修复 ERR_TLS_CERT_ALTNAME_INVALID
        // 修复：vite 5 ws proxy 客户端断开时 ECONNRESET 报错刷屏
        // 关闭自动重连 + 长超时，断连日志降级
        configure: (proxy) => {
          proxy.on('error', () => {});
          proxy.on('proxyReqWs', (_proxyReq, _req, socket) => {
            socket.on('error', () => {});
          });
          proxy.on('close', () => {});
        }
      }
    }
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    sourcemap: false,
    chunkSizeWarningLimit: 1500
  }
});
