<template>
  <NuxtLayout>
    <NuxtPage />
  </NuxtLayout>

  <!-- Global recovery banner for production "Failed to fetch dynamically imported module" -->
  <Transition name="banner">
    <div v-if="showRecoveryBanner" class="recovery-banner" role="alert">
      <div class="recovery-banner__msg">
        <strong>网站版本已更新</strong>，正在刷新本地缓存...
        <span v-if="countdown > 0">{{ countdown }} 秒后自动刷新</span>
      </div>
      <button class="recovery-banner__btn" @click="hardReloadNow()">
        立即刷新
      </button>
    </div>
  </Transition>
</template>

<script setup lang="ts">
const { public: { siteName, siteUrl, buildVersion } } = useRuntimeConfig()

useHead({
  titleTemplate: (title) => title ? `${title} - ${siteName}` : `${siteName} - 企业级即时通讯系统 | 源码出售+定制开发`,
  meta: [
    { name: 'description', content: `${siteName} 是一套完整的企业级即时通讯系统，包含 Go 后端 + Vue 管理后台 + Flutter 移动端。支持单聊/群聊/音视频通话/红包转账/朋友圈/靓号系统。源码出售、私有化部署、定制开发。` },
    { name: 'keywords', content: '即时通讯系统,IM系统,企业通讯,聊天APP源码,即时通讯源码,Go IM,Flutter聊天,私有化部署IM,定制开发IM,ChatPulse' },
    { name: 'author', content: siteName },
    { property: 'og:site_name', content: siteName },
    { property: 'og:type', content: 'website' },
    { property: 'og:url', content: siteUrl },
    { property: 'og:locale', content: 'zh_CN' },
    { name: 'twitter:card', content: 'summary_large_image' },
  ],
  link: [
    { rel: 'canonical', href: siteUrl }
  ]
})

// ============================================================
//  Build version mismatch + dynamic import error recovery
//  Goal: never let users stare at a blank white screen after deploy
// ============================================================
const showRecoveryBanner = ref(false)
const countdown = ref(0)
let reloadTimer: any = null

// Only run mismatch detection in browser hydration
if (typeof window !== 'undefined') {
  // Server rendered this meta tag; the client runtimeConfig carries the
  // build version embedded into the entry script (downloaded at this load).
  // If they differ, one of them is stale -> the page needs a hard reload.
  const serverBuildMeta = document.querySelector<HTMLMetaElement>('meta[name="build-version"], meta[name="x-build-version"]')
  const serverBuild = serverBuildMeta?.content || ''
  const clientBuild = String(buildVersion || '')
  const loadedFromUrl = location.href

  // 1. Hydration mismatch -> immediate hard reload (with cache bust)
  if (serverBuild && clientBuild && serverBuild !== clientBuild) {
    const q = new URLSearchParams(location.search)
    if (!q.has('__v')) {
      q.set('__v', clientBuild.slice(0, 10))
      const next = location.pathname + '?' + q.toString() + location.hash
      requestAnimationFrame(() => { location.replace(next) })
    }
  }

  // 2. Build version check on every navigation.
  //    After a deploy, the browser can still have an old entry chunk with a
  //    newer HTML, causing lazy route chunks to 404. We check by re-fetching
  //    the current page's HTML on router navigation and comparing meta tags.
  const router = useRouter()
  let checking = false
  router.afterEach(async (to) => {
    if (checking) return
    checking = true
    try {
      const meta = await fetchCurrentBuild()
      if (meta && clientBuild && meta !== clientBuild && !showRecoveryBanner.value) {
        triggerRecovery(`route mismatch navigating to ${to.fullPath}`)
      }
    } catch {
      // offline or network error -> silently ignore
    } finally {
      checking = false
    }
  })

  async function fetchCurrentBuild() {
    try {
      const res = await fetch(location.pathname, {
        method: 'GET',
        headers: { 'Accept': 'text/html' },
        credentials: 'same-origin',
        cache: 'no-store',
      })
      if (!res.ok) return ''
      const html = await res.text()
      const match = html.match(/<meta[^>]+name=["'](?:x-)?build-version["'][^>]*content=["']([^"']+)["']/i)
        || html.match(/<meta[^>]+content=["']([^"']+)["'][^>]*name=["'](?:x-)?build-version["']/i)
      return match ? match[1] : ''
    } catch {
      return ''
    }
  }

  // Remember state in sessionStorage to avoid infinite reload loops.
  function reloadKey(url: string) {
    try {
      return 'reload_' + url.replace(/[?#].*$/, '')
    } catch { return 'reload_' }
  }

  function alreadyAttemptedReload() {
    try {
      const k = reloadKey(loadedFromUrl)
      const last = Number(sessionStorage.getItem(k) || '0')
      if (!last) return false
      return Date.now() - last < 45 * 1000 // one reload per 45s per page
    } catch {
      return false
    }
  }
  function markReloadAttempted() {
    try { sessionStorage.setItem(reloadKey(loadedFromUrl), String(Date.now())) } catch {}
  }
  function clearReloadAttempted() {
    try {
      Object.keys(sessionStorage).forEach(k => { if (k.startsWith('reload_')) sessionStorage.removeItem(k) })
    } catch {}
  }
  // Clear reload lock when user comes back after more than 2 min in another tab
  window.addEventListener('pageshow', () => clearReloadAttempted(), { once: true })
}

function triggerRecovery(reason?: string) {
  // eslint-disable-next-line no-console
  console.warn('[nuxt-recovery] Triggering recovery banner, reason =', reason || 'unknown')
  if (alreadyAttemptedReload()) return
  showRecoveryBanner.value = true
  countdown.value = 2
  if (reloadTimer) clearInterval(reloadTimer)
  reloadTimer = setInterval(() => {
    countdown.value -= 1
    if (countdown.value <= 0) {
      if (reloadTimer) clearInterval(reloadTimer)
      hardReloadNow()
    }
  }, 1000)
}

function hardReloadNow() {
  if (reloadTimer) clearInterval(reloadTimer)
  markReloadAttempted()
  try {
    // Append __v=<buildVersion> cache-bust and do a full reload (bypass HTTP cache)
    const url = new URL(location.href)
    if (!url.searchParams.has('__v')) {
      url.searchParams.set('__v', String(buildVersion || Date.now().toString(36)))
    }
    // @ts-ignore: bypass cache in all modern browsers
    location.assign(url.toString(), { forceReload: true } as any)
  } catch {
    location.reload()
  }
}

// 3. Global error capture:
//    Vue runtime errors that contain 'Failed to fetch dynamically imported module'
//    or 'TypeError: error loading dynamically imported module' hit this branch.
//    We show a banner and auto hard-refresh after 1.5s.
const isChunkError = (err: any) => {
  if (!err) return false
  const msg: string = (typeof err === 'string' ? err : (err.message || err.stack || String(err)))
  if (!msg) return false
  return /failed to fetch dynamically imported module/i.test(msg)
    || /error loading dynamically imported module/i.test(msg)
    || /importing a module script failed/i.test(msg)
    || /chunkloaderror/i.test(msg)
}

onErrorCaptured((err, instance, info) => {
  if (isChunkError(err)) {
    triggerRecovery(String(err))
    return false // stop propagation after recording
  }
})

// Nuxt 3 exposes a global 'app:error' hook on the Nuxt app instance
const nuxt = useNuxtApp()
nuxt.hook('vue:error', (err) => {
  if (isChunkError(err)) triggerRecovery(String(err))
})
nuxt.hook('app:error', (err) => {
  if (isChunkError(err)) triggerRecovery(String(err))
})

// Unhandled promise rejections (Vite / Nuxt dynamic import manifests fail here)
if (typeof window !== 'undefined') {
  window.addEventListener('unhandledrejection', (e: any) => {
    const reason = e && e.reason
    if (isChunkError(reason)) {
      e.preventDefault()
      triggerRecovery(String(reason))
    }
  })
}
</script>

<style>
.recovery-banner {
  position: fixed;
  left: 50%;
  bottom: 32px;
  transform: translateX(-50%);
  z-index: 99999;
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 14px 20px;
  background: linear-gradient(135deg, #165dff 0%, #4080ff 100%);
  color: #fff;
  border-radius: 999px;
  box-shadow: 0 10px 30px rgba(22, 93, 255, .28), 0 4px 12px rgba(0,0,0,.08);
  max-width: calc(100vw - 32px);
  font-size: 14px;
}
.recovery-banner__msg { min-width: 0; flex: 1 1 auto; line-height: 1.45; }
.recovery-banner__btn {
  flex: 0 0 auto;
  background: #fff;
  color: #165dff;
  border: 0;
  border-radius: 999px;
  padding: 8px 18px;
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
  box-shadow: 0 2px 6px rgba(0,0,0,.06);
}
.recovery-banner__btn:hover { filter: brightness(.96); }

.banner-enter-active,
.banner-leave-active {
  transition: all .28s cubic-bezier(.22,.61,.36,1);
}
.banner-enter-from { opacity: 0; transform: translate(-50%, 24px); }
.banner-leave-to   { opacity: 0; transform: translate(-50%, 24px); }

@media (max-width: 640px) {
  .recovery-banner {
    bottom: 16px;
    padding: 12px 16px;
    font-size: 13px;
    gap: 12px;
  }
  .recovery-banner__btn { padding: 7px 14px; font-size: 13px; }
}
</style>
