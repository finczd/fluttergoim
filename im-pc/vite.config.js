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
      '/api': { target: 'http://127.0.0.1:8080', changeOrigin: true },
      '/ws': {
        // WS 反代到 Go 网关（gateway:9090 在 container 内，dev 用 9090 端口透出）
        target: 'ws://127.0.0.1:9090',
        ws: true,
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
