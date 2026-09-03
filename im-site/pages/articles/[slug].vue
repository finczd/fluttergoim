<template>
  <div class="article-page">
    <!-- ============ NOT FOUND ============ -->
    <section v-if="!article" class="not-found">
      <div class="container nf-inner">
        <span class="nf-icon" v-html="nfSvg" aria-hidden="true"></span>
        <h1 class="nf-title">文章不存在</h1>
        <p class="nf-text">您访问的文章可能已被删除或链接有误</p>
        <NuxtLink to="/articles" class="btn btn-primary">返回资讯列表</NuxtLink>
      </div>
    </section>

    <template v-else>
      <!-- ============ HERO ============ -->
      <section class="hero">
        <div class="hero-bg-deco" aria-hidden="true">
          <span class="orb orb-1"></span>
          <span class="orb orb-2"></span>
        </div>
        <div class="container hero-inner">
          <span class="hero-cat">{{ article.category || '未分类' }}</span>
          <h1 class="hero-title">{{ article.title }}</h1>
          <div class="hero-meta">
            <span>{{ formatDate(article.createdAt) }}</span>
            <span class="dot-sep">·</span>
            <span>{{ article.views ?? 0 }} 阅读</span>
            <span class="dot-sep">·</span>
            <span>{{ article.category || '未分类' }}</span>
          </div>
        </div>
      </section>

      <!-- ============ ARTICLE BODY ============ -->
      <section class="section article-section">
        <div class="container">
          <div class="article-wrap">
            <!-- Cover image -->
            <img
              v-if="article.coverImage"
              :src="article.coverImage"
              :alt="article.title"
              class="cover"
            />

            <!-- Content -->
            <div class="prose" v-html="article.content"></div>

            <!-- Tags -->
            <div v-if="article.tags && article.tags.length" class="tags-row">
              <span class="tags-label">标签：</span>
              <span v-for="t in article.tags" :key="t" class="tag">#{{ t }}</span>
            </div>

            <!-- Share -->
            <div class="share-row">
              <span class="share-label">分享到：</span>
              <button class="share-btn wechat" @click="onShareWeChat">
                <span class="share-icon" v-html="wechatSvg" aria-hidden="true"></span>
                微信
              </button>
              <button class="share-btn weibo" @click="onShareWeibo">
                <span class="share-icon" v-html="weiboSvg" aria-hidden="true"></span>
                微博
              </button>
              <button class="share-btn copy" @click="onCopyLink">
                <span class="share-icon" v-html="copySvg" aria-hidden="true"></span>
                {{ copied ? '已复制' : '复制链接' }}
              </button>
            </div>
          </div>

          <!-- Prev / Next -->
          <nav class="prev-next">
            <div class="pn-card pn-prev">
              <span class="pn-label">
                <span class="pn-arrow" v-html="prevArrowSvg" aria-hidden="true"></span>
                上一篇
              </span>
              <span class="pn-title">已是最早文章</span>
            </div>
            <div class="pn-card pn-next">
              <span class="pn-label">
                下一篇
                <span class="pn-arrow" v-html="nextArrowSvg" aria-hidden="true"></span>
              </span>
              <span class="pn-title">已是最新文章</span>
            </div>
          </nav>
        </div>
      </section>

      <!-- ============ CTA ============ -->
      <section class="cta-section">
        <div class="container cta-inner">
          <h2 class="cta-title">想要搭建自己的 IM 系统？了解 ChatPulse</h2>
          <p class="cta-sub">源码交付 · 私有化部署 · 终身授权，开启您的专属即时通讯系统</p>
          <NuxtLink to="/pricing" class="btn btn-lg cta-btn">查看定价 →</NuxtLink>
        </div>
      </section>
    </template>
  </div>
</template>

<script setup>
const route = useRoute()
const config = useRuntimeConfig()

const { data: res } = await useAsyncData(
  () => `article:${route.params.slug}`,
  () => $fetch(`/api/articles/${route.params.slug}`).catch(() => ({ code: 404 })),
  { watch: [() => route.params.slug] }
)

const article = computed(() => {
  if (!res.value || res.value.code !== 0) return null
  return res.value.data
})

useHead(() => {
  if (!article.value) {
    return { title: '文章不存在 - ChatPulse IM' }
  }
  const a = article.value
  const meta = [
    { name: 'description', content: a.summary || a.title },
    { property: 'og:title', content: a.title },
    { property: 'og:description', content: a.summary || a.title },
  ]
  if (a.coverImage) {
    meta.push({ property: 'og:image', content: a.coverImage })
  }
  if (config.public.siteUrl) {
    meta.push({ property: 'og:url', content: `${config.public.siteUrl}/articles/${a.slug}` })
  }
  return {
    title: `${a.title} - ChatPulse IM`,
    meta,
  }
})

const copied = ref(false)

function formatDate(d) {
  if (!d) return ''
  const dt = new Date(d)
  if (isNaN(dt.getTime())) return ''
  const y = dt.getFullYear()
  const m = String(dt.getMonth() + 1).padStart(2, '0')
  const day = String(dt.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

function onShareWeChat() {
  // WeChat sharing typically requires the JS SDK; give a friendly hint instead.
  if (import.meta.client) {
    alert('请使用微信「扫一扫」或右上角菜单分享本页')
  }
}

function onShareWeibo() {
  if (!import.meta.client) return
  const url = window.location.href
  const title = article.value?.title || ''
  window.open(
    `https://service.weibo.com/share/share.php?url=${encodeURIComponent(url)}&title=${encodeURIComponent(title)}`,
    '_blank',
    'noopener,noreferrer'
  )
}

async function onCopyLink() {
  if (!import.meta.client || !navigator?.clipboard) return
  try {
    await navigator.clipboard.writeText(window.location.href)
    copied.value = true
    setTimeout(() => {
      copied.value = false
    }, 2000)
  } catch {
    /* ignore */
  }
}

const nfSvg =
  '<svg width="64" height="64" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><circle cx="12" cy="12" r="9" stroke="#165dff" stroke-width="1.8"/><path d="M9 15V9l6 6M15 9v6" stroke="#165dff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>'

const wechatSvg =
  '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M9 4C4.8 4 1.5 6.6 1.5 9.8c0 1.8 1 3.4 2.6 4.5l-.6 2 2.4-1.3c.8.2 1.6.4 2.5.4h.6c-.1-.4-.1-.8-.1-1.2 0-3 2.9-5.4 6.5-5.4h.6C16 6 12.8 4 9 4z" fill="#fff"/><path d="M22.5 14.2c0-2.6-2.6-4.8-5.8-4.8s-5.8 2.2-5.8 4.8 2.6 4.8 5.8 4.8c.7 0 1.4-.1 2-.3l2 1-.5-1.6c1.4-.9 2.3-2.3 2.3-3.9z" fill="#fff"/><circle cx="6.5" cy="8.5" r="0.7" fill="#165dff"/><circle cx="10.5" cy="8.5" r="0.7" fill="#165dff"/></svg>'

const weiboSvg =
  '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M10 13c-3.3 0-6 2-6 4.5S6.7 22 10 22s6-2 6-4.5S13.3 13 10 13z" fill="#fff"/><path d="M18 4c-1.6 0-3 .8-3.8 2-.4.6-.1 1.4.5 1.6.6.2 1.3 0 1.7-.5.4-.5 1-.8 1.6-.8 1.3 0 2.3 1 2.3 2.3 0 .6-.3 1.2-.8 1.6-.5.4-.5 1.2 0 1.6.5.4 1.2.4 1.6-.1 1-.9 1.7-2.1 1.7C20.4 7.6 19.6 4 18 4z" fill="#fff"/></svg>'

const copySvg =
  '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="8" y="8" width="12" height="12" rx="2" stroke="currentColor" stroke-width="1.8"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>'

const prevArrowSvg =
  '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M15 6l-6 6 6 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>'

const nextArrowSvg =
  '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M9 6l6 6-6 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>'
</script>

<style scoped>
/* ============ NOT FOUND ============ */
.not-found {
  padding: 96px 0;
  background: var(--c-bg-2);
}

.nf-inner {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  gap: 16px;
}

.nf-icon {
  display: inline-flex;
  margin-bottom: 4px;
}

.nf-title {
  font-size: 32px;
  font-weight: 900;
  color: var(--c-text-1);
  letter-spacing: -0.5px;
}

.nf-text {
  font-size: 15px;
  color: var(--c-text-3);
  margin-bottom: 12px;
}

/* ============ HERO ============ */
.hero {
  position: relative;
  background: linear-gradient(135deg, #165dff 0%, #4080ff 100%);
  color: #fff;
  padding: 64px 0 72px;
  overflow: hidden;
  text-align: center;
}

.hero-bg-deco {
  position: absolute;
  inset: 0;
  pointer-events: none;
  overflow: hidden;
}

.orb {
  position: absolute;
  border-radius: 50%;
  filter: blur(60px);
  opacity: 0.35;
}

.orb-1 {
  width: 320px;
  height: 320px;
  background: #6ea8ff;
  top: -100px;
  right: -60px;
}

.orb-2 {
  width: 260px;
  height: 260px;
  background: #0e42d2;
  bottom: -100px;
  left: -80px;
  opacity: 0.5;
}

.hero-inner {
  position: relative;
  z-index: 1;
  max-width: 760px;
}

.hero-cat {
  display: inline-block;
  padding: 5px 14px;
  font-size: 13px;
  font-weight: 600;
  color: #fff;
  background: rgba(255, 255, 255, 0.18);
  border: 1px solid rgba(255, 255, 255, 0.28);
  border-radius: 999px;
  margin-bottom: 18px;
  backdrop-filter: blur(8px);
}

.hero-title {
  font-size: 40px;
  font-weight: 900;
  line-height: 1.25;
  letter-spacing: -1px;
  margin-bottom: 16px;
}

.hero-meta {
  display: flex;
  align-items: center;
  justify-content: center;
  flex-wrap: wrap;
  gap: 10px;
  font-size: 14px;
  color: rgba(255, 255, 255, 0.92);
}

.dot-sep {
  color: rgba(255, 255, 255, 0.6);
}

/* ============ ARTICLE BODY ============ */
.article-section {
  background: var(--c-bg-1);
}

.article-wrap {
  max-width: 720px;
  margin: 0 auto;
  font-size: 16px;
  line-height: 1.8;
  color: var(--c-text-1);
}

.cover {
  width: 100%;
  max-height: 400px;
  object-fit: cover;
  border-radius: var(--radius-lg);
  margin-bottom: 32px;
  display: block;
}

/* Prose content styling (v-html, use :deep) */
.prose {
  font-size: 16px;
  line-height: 1.85;
  color: var(--c-text-1);
  word-break: break-word;
}

.prose :deep(h2) {
  font-size: 26px;
  font-weight: 800;
  color: var(--c-text-1);
  margin: 36px 0 16px;
  letter-spacing: -0.3px;
  line-height: 1.3;
}

.prose :deep(h3) {
  font-size: 20px;
  font-weight: 700;
  color: var(--c-text-1);
  margin: 28px 0 14px;
  line-height: 1.35;
}

.prose :deep(h4) {
  font-size: 17px;
  font-weight: 700;
  color: var(--c-text-1);
  margin: 22px 0 12px;
}

.prose :deep(p) {
  margin: 0 0 18px;
  color: var(--c-text-2);
  line-height: 1.85;
}

.prose :deep(ul),
.prose :deep(ol) {
  margin: 0 0 18px;
  padding-left: 24px;
  color: var(--c-text-2);
}

.prose :deep(ul) {
  list-style: disc;
}

.prose :deep(ol) {
  list-style: decimal;
}

.prose :deep(li) {
  margin: 6px 0;
  line-height: 1.75;
}

.prose :deep(li::marker) {
  color: var(--c-primary);
}

.prose :deep(a) {
  color: var(--c-primary);
  text-decoration: underline;
  text-underline-offset: 2px;
}

.prose :deep(a:hover) {
  color: var(--c-primary-light);
}

.prose :deep(strong) {
  font-weight: 700;
  color: var(--c-text-1);
}

.prose :deep(code) {
  font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace;
  font-size: 0.88em;
  padding: 2px 6px;
  background: var(--c-bg-3);
  color: var(--c-primary-dark);
  border-radius: 4px;
  word-break: break-word;
}

.prose :deep(pre) {
  margin: 0 0 20px;
  padding: 18px 20px;
  background: #1d2129;
  border-radius: var(--radius-md);
  overflow-x: auto;
  line-height: 1.6;
}

.prose :deep(pre code) {
  padding: 0;
  background: transparent;
  color: #e5e6eb;
  font-size: 14px;
}

.prose :deep(blockquote) {
  margin: 0 0 20px;
  padding: 14px 20px;
  background: var(--c-primary-bg);
  border-left: 4px solid var(--c-primary);
  border-radius: 0 var(--radius-sm) var(--radius-sm) 0;
  color: var(--c-text-2);
  font-style: normal;
}

.prose :deep(blockquote p) {
  margin-bottom: 0;
  color: var(--c-text-2);
}

.prose :deep(img) {
  max-width: 100%;
  height: auto;
  border-radius: var(--radius-md);
  margin: 20px 0;
  display: block;
}

.prose :deep(hr) {
  border: none;
  border-top: 1px solid var(--c-border);
  margin: 32px 0;
}

.prose :deep(table) {
  width: 100%;
  border-collapse: collapse;
  margin: 0 0 20px;
  font-size: 14px;
}

.prose :deep(th),
.prose :deep(td) {
  border: 1px solid var(--c-border);
  padding: 10px 14px;
  text-align: left;
  color: var(--c-text-2);
}

.prose :deep(th) {
  background: var(--c-bg-2);
  font-weight: 700;
  color: var(--c-text-1);
}

/* ============ TAGS ============ */
.tags-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  margin: 36px 0 24px;
  padding-top: 24px;
  border-top: 1px solid var(--c-border);
}

.tags-label {
  font-size: 14px;
  font-weight: 600;
  color: var(--c-text-3);
}

.tag {
  padding: 4px 12px;
  font-size: 13px;
  color: var(--c-primary);
  background: var(--c-primary-bg);
  border-radius: 999px;
}

/* ============ SHARE ============ */
.share-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 12px;
  padding: 20px 0 8px;
  border-top: 1px solid var(--c-border);
}

.share-label {
  font-size: 14px;
  font-weight: 600;
  color: var(--c-text-3);
  margin-right: 4px;
}

.share-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  font-size: 13px;
  font-weight: 600;
  color: var(--c-text-2);
  background: var(--c-bg-2);
  border: 1px solid var(--c-border);
  border-radius: 999px;
  cursor: pointer;
  transition: all 0.2s;
}

.share-btn:hover {
  color: var(--c-text-1);
  background: var(--c-bg-3);
}

.share-btn.wechat {
  color: #fff;
  background: var(--c-gradient-green);
  border-color: transparent;
}

.share-btn.wechat:hover {
  filter: brightness(1.05);
  color: #fff;
}

.share-btn.weibo {
  color: #fff;
  background: var(--c-gradient-orange);
  border-color: transparent;
}

.share-btn.weibo:hover {
  filter: brightness(1.05);
  color: #fff;
}

.share-btn.copy {
  color: var(--c-primary);
  background: var(--c-primary-bg);
  border-color: transparent;
}

.share-btn.copy:hover {
  background: var(--c-primary);
  color: #fff;
}

.share-icon {
  display: inline-flex;
  align-items: center;
}

/* ============ PREV / NEXT ============ */
.prev-next {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
  max-width: 720px;
  margin: 48px auto 0;
}

.pn-card {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 20px 22px;
  background: var(--c-bg-2);
  border: 1px solid var(--c-border);
  border-radius: var(--radius-md);
  transition: all 0.25s;
}

.pn-card:hover {
  background: var(--c-bg-1);
  border-color: var(--c-border-2);
  box-shadow: var(--shadow-sm);
}

.pn-next {
  text-align: right;
}

.pn-label {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  font-weight: 700;
  color: var(--c-primary);
}

.pn-next .pn-label {
  justify-content: flex-end;
}

.pn-arrow {
  display: inline-flex;
  align-items: center;
}

.pn-title {
  font-size: 15px;
  font-weight: 600;
  color: var(--c-text-3);
  line-height: 1.5;
}

/* ============ CTA ============ */
.cta-section {
  background: linear-gradient(135deg, #165dff 0%, #4080ff 100%);
  color: #fff;
  padding: 64px 0;
  text-align: center;
  position: relative;
  overflow: hidden;
}

.cta-inner {
  position: relative;
  z-index: 1;
}

.cta-title {
  font-size: 34px;
  font-weight: 900;
  letter-spacing: -1px;
  margin-bottom: 14px;
}

.cta-sub {
  font-size: 16px;
  color: rgba(255, 255, 255, 0.9);
  margin-bottom: 28px;
}

.cta-btn {
  background: #fff;
  color: var(--c-primary);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.2);
}

.cta-btn:hover {
  transform: translateY(-2px);
  background: #fff;
  color: var(--c-primary);
  box-shadow: 0 12px 32px rgba(0, 0, 0, 0.28);
}

/* ============ RESPONSIVE ============ */
@media (max-width: 900px) {
  .hero-title {
    font-size: 32px;
  }
  .prev-next {
    grid-template-columns: 1fr;
  }
  .pn-next {
    text-align: left;
  }
  .pn-next .pn-label {
    justify-content: flex-start;
  }
}

@media (max-width: 600px) {
  .hero {
    padding: 44px 0 52px;
  }
  .hero-title {
    font-size: 26px;
  }
  .hero-meta {
    font-size: 13px;
    gap: 8px;
  }
  .article-wrap {
    font-size: 15px;
  }
  .prose {
    font-size: 15px;
  }
  .prose :deep(h2) {
    font-size: 22px;
  }
  .prose :deep(h3) {
    font-size: 18px;
  }
  .cover {
    max-height: 240px;
    border-radius: var(--radius-md);
    margin-bottom: 24px;
  }
  .cta-title {
    font-size: 26px;
  }
  .cta-sub {
    font-size: 15px;
  }
  .share-btn {
    padding: 7px 13px;
    font-size: 12px;
  }
}
</style>
