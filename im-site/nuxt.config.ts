import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

/**
 * Generate a stable build version string (served as runtime config public.buildVersion).
 * - If CI=true uses $BUILD_VERSION / $BUILD_ID.
 * - Else reads last 12 chars of git sha (git rev-parse HEAD).
 * - Else falls back to a timestamp YYYYMMDDHHMMSS.
 * This is injected into nuxt.config.ts via Vite define, and we also render a
 * "<meta name='build-version'>" tag plus inject a SRI-like manifest version.
 */
function genBuildVersion() {
  if (process.env.BUILD_VERSION) return process.env.BUILD_VERSION
  if (process.env.BUILD_ID) return process.env.BUILD_ID
  try {
    const gitDir = path.resolve(process.cwd(), '.git')
    if (fs.existsSync(gitDir)) {
      const headFile = path.join(gitDir, 'HEAD')
      if (fs.existsSync(headFile)) {
        const head = fs.readFileSync(headFile, 'utf-8').trim()
        if (!head.startsWith('ref:')) return head.slice(0, 12)
        const ref = head.slice(5).trim() // refs/heads/master
        const refFile = path.join(gitDir, ref)
        if (fs.existsSync(refFile)) return fs.readFileSync(refFile, 'utf-8').trim().slice(0, 12)
        const packedRefs = path.join(gitDir, 'packed-refs')
        if (fs.existsSync(packedRefs)) {
          const lines = fs.readFileSync(packedRefs, 'utf-8').split(/\r?\n/)
          const line = lines.find(l => l.endsWith(ref))
          if (line) return line.split(/\s+/)[0].slice(0, 12)
        }
      }
    }
  } catch {
    // ignore
  }
  const d = new Date()
  const pad = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}${pad(d.getMonth()+1)}${pad(d.getDate())}${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`
}

const BUILD_VERSION = genBuildVersion()
const __dirname = path.dirname(fileURLToPath(import.meta.url))

console.log('[nuxt.config] buildVersion =', BUILD_VERSION)

export default defineNuxtConfig({
  compatibilityDate: '2024-11-01',
  devtools: { enabled: true },

  // SSR mode (SEO friendly)
  ssr: true,

  // Global CSS
  css: ['~/assets/css/main.css'],

  runtimeConfig: {
    adminPassword: process.env.ADMIN_PASSWORD || 'admin123',
    public: {
      siteUrl: process.env.SITE_URL || 'https://chatpulse.cn',
      siteName: 'ChatPulse',
      buildVersion: BUILD_VERSION,
    },
  },

  // Experimental: more aggressive prefetch of route chunks & payload extraction
  // Helps avoid "Failed to fetch dynamically imported module" after deploy.
  experimental: {
    watcher: 'parcel',
    payloadExtraction: true,
    defaults: {
      useAsyncData: { deep: false },
      nuxtLink: {
        prefetch: true,
        prefetchOn: { visibility: true, interaction: true },
      },
    },
  },

  // Rendering config: add build-version meta + SRI-like build tag so the client
  // can detect mismatches (and auto hard-reload) right before hydration.
  app: {
    head: {
      htmlAttrs: { lang: 'zh-CN' },
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
        { name: 'format-detection', content: 'telephone=no' },
        { name: 'build-version', content: BUILD_VERSION },
        { name: 'x-build-version', content: BUILD_VERSION },
      ],
      link: [
        { rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' },
      ],
    },
  },

  // Build tuning: stable Vite chunk hashing + force Nuxt to write assets under
  // the same folder for easier Nginx serving rules.
  vite: {
    define: {
      __BUILD_VERSION__: JSON.stringify(BUILD_VERSION),
    },
    build: {
      cssCodeSplit: true,
      rollupOptions: {
        output: {
          // Stable, content-based asset hashing to avoid cache misses.
          entryFileNames: '_nuxt/[name]-[hash].js',
          chunkFileNames: '_nuxt/[name]-[hash].js',
          assetFileNames: '_nuxt/[name]-[hash][extname]',
        },
      },
    },
  },

  // Nitro preset for PM2 / baota deployment
  nitro: {
    preset: 'node-server',
    // Keep uploaded files (logo / screenshots) & static assets available under
    // the exact same URL whether served by Nitro dev/preview or node-server.
    publicAssets: [
      {
        baseURL: '/',
        dir: 'public',
        // Default 7d max-age; _nuxt subdir overrides with 1y immutable via Nginx
        maxAge: 60 * 60 * 24 * 7,
      },
    ],
    compressPublicAssets: true,
  },

  typescript: { strict: true },
})
