<template>
  <div class="api-docs-page">
    <!-- ============ HERO ============ -->
    <section class="doc-hero">
      <div class="container doc-hero-inner">
        <div>
          <span class="hero-badge">开发者中心</span>
          <h1 class="doc-hero-title">API 接口与技术文档</h1>
          <p class="doc-hero-sub">
            架构方案、数据库设计、APP 接口清单、充值提现对接、宝塔部署指南一站式查阅。
          </p>
          <div class="doc-search-box">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.35-4.35"/></svg>
            <input
              v-model="searchKey"
              type="text"
              placeholder="搜索文档标题或分类，例如：API、数据库、部署..."
              class="doc-search-input"
            />
          </div>
        </div>
      </div>
    </section>

    <!-- ============ MAIN LAYOUT ============ -->
    <section class="container doc-layout">
      <!-- 侧栏 -->
      <aside class="doc-sidebar">
        <div class="side-sticky">
          <div v-for="cat in categories" :key="cat.key" class="side-group">
            <div class="side-group-title">{{ cat.label }}</div>
            <ul class="side-list">
              <li v-for="d in filteredByCat(cat.key)" :key="d.slug">
                <a
                  class="side-link"
                  :class="{ active: current === d.slug }"
                  @click.prevent="selectDoc(d.slug)"
                  :href="'#' + d.slug"
                >{{ d.title }}</a>
              </li>
            </ul>
            <p v-if="!filteredByCat(cat.key).length" class="side-empty">无匹配文档</p>
          </div>
        </div>
      </aside>

      <!-- 内容 -->
      <main class="doc-main" v-if="!loading && currentDoc">
        <nav class="doc-breadcrumb">
          <NuxtLink to="/docs">文档首页</NuxtLink>
          <span class="sep">/</span>
          <span class="cat">{{ currentDoc.doc.categoryLabel }}</span>
          <span class="sep">/</span>
          <span class="title">{{ currentDoc.doc.title }}</span>
        </nav>

        <header class="doc-header">
          <h1 class="doc-title">{{ currentDoc.doc.title }}</h1>
          <div class="doc-meta">
            <span class="doc-cat-tag" :class="'cat-' + currentDoc.doc.category">
              {{ currentDoc.doc.categoryLabel }}
            </span>
            <span class="doc-updated">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
              更新于 {{ formatDate(currentDoc.doc.updatedAt) }}
            </span>
          </div>
        </header>

        <article class="md-body" v-html="currentDoc.html"></article>

        <footer class="doc-footer-nav">
          <a v-if="prevDoc" class="foot-foot-item prev" @click.prevent="selectDoc(prevDoc.slug)" :href="'#' + prevDoc.slug">
            <span class="foot-foot-label">上一篇</span>
            <strong>{{ prevDoc.title }}</strong>
          </a>
          <a v-if="nextDoc" class="foot-foot-item next" @click.prevent="selectDoc(nextDoc.slug)" :href="'#' + nextDoc.slug">
            <span class="foot-foot-label">下一篇</span>
            <strong>{{ nextDoc.title }}</strong>
          </a>
        </footer>
      </main>

      <main v-else-if="loading" class="doc-main">
        <div class="doc-loading">
          <div class="spinner"></div>
          <p>正在加载文档...</p>
        </div>
      </main>
      <main v-else class="doc-main">
        <div class="doc-empty">
          <p>暂无匹配的文档，请尝试清除搜索关键词。</p>
          <button class="btn btn-primary btn-sm" @click="searchKey = ''">清除搜索</button>
        </div>
      </main>
    </section>
  </div>
</template>

<script setup lang="ts">
useHead({
  title: 'API 文档与技术参考 - ChatPulse 开发者中心',
  meta: [
    { name: 'description', content: 'ChatPulse IM 系统技术文档：架构方案、数据库设计、APP API 接口清单、充值提现对接、宝塔部署运维指南，所有文档可在线阅读。' },
    { name: 'keywords', content: 'ChatPulse API文档,Go IM 接口,APP API 接口,数据库设计,充值提现接口,宝塔部署IM,私有化部署文档,SDK对接文档' },
  ],
})

interface Doc {
  slug: string
  fileName: string
  title: string
  category: string
  categoryLabel: string
  order: number
  updatedAt: string
}
interface Category { key: string; label: string }

const route = useRoute()
const searchKey = ref('')
const loading = ref(true)
const categories = ref<Category[]>([])
const docs = ref<Doc[]>([])
const current = ref('')
const currentDoc = ref<{ doc: Doc; html: string; raw: string } | null>(null)

function formatDate(s: string) {
  if (!s) return '-'
  const d = new Date(s)
  if (isNaN(d as any)) return s
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

function filteredByCat(cat: string): Doc[] {
  const key = searchKey.value.trim().toLowerCase()
  return docs.value.filter(d => {
    if (d.category !== cat) return false
    if (!key) return true
    return d.title.toLowerCase().includes(key) || d.categoryLabel.toLowerCase().includes(key)
  })
}

const filteredList = computed(() => {
  const key = searchKey.value.trim().toLowerCase()
  if (!key) return docs.value
  return docs.value.filter(d =>
    d.title.toLowerCase().includes(key) || d.categoryLabel.toLowerCase().includes(key)
  )
})

const prevDoc = computed<Doc | null>(() => {
  const arr = filteredList.value
  const i = arr.findIndex(d => d.slug === current.value)
  if (i <= 0) return null
  return arr[i - 1]
})
const nextDoc = computed<Doc | null>(() => {
  const arr = filteredList.value
  const i = arr.findIndex(d => d.slug === current.value)
  if (i < 0 || i >= arr.length - 1) return null
  return arr[i + 1]
})

async function selectDoc(slug: string) {
  if (!slug) return
  loading.value = true
  currentDoc.value = null
  current.value = slug
  try {
    const res: any = await $fetch(`/api/docs?slug=${encodeURIComponent(slug)}`)
    if (res.code === 0) currentDoc.value = res.data
  } catch (err: any) {
    alert('加载文档失败: ' + (err?.data?.message || err?.message || ''))
  }
  loading.value = false
  if (typeof window !== 'undefined') window.scrollTo({ top: 0, behavior: 'smooth' })
}

onMounted(async () => {
  // 1) 加载文档列表
  let catFromUrl = (route.query.cat as string) || ''
  try {
    const res: any = await $fetch('/api/docs')
    if (res.code === 0) {
      categories.value = res.data.categories || []
      docs.value = res.data.list || []
    }
  } catch (err: any) {
    alert('加载文档列表失败: ' + (err?.data?.message || err?.message || ''))
  }

  // 2) 确定首篇：按 URL ?slug= 优先 → 按 ?cat= 选第一篇 → 默认第一篇
  let first = ''
  if (route.query.slug) first = String(route.query.slug)
  else if (catFromUrl && docs.value.length) {
    const catDoc = docs.value.find(d => d.category === catFromUrl)
    first = catDoc ? catDoc.slug : (docs.value[0]?.slug || '')
  }
  else if (docs.value.length) first = docs.value[0].slug
  if (first) await selectDoc(first)
  else loading.value = false
})
</script>

<style scoped>
.api-docs-page { min-height: 80vh; background: #f7f8fa; }

.doc-hero {
  background: linear-gradient(135deg, #165dff 0%, #4080ff 100%);
  color: #fff;
  padding: 64px 0 72px;
  position: relative;
  overflow: hidden;
}
.doc-hero::before {
  content: '';
  position: absolute; inset: 0;
  background-image: radial-gradient(circle at 20% 20%, rgba(255,255,255,.08) 0%, transparent 50%),
                    radial-gradient(circle at 80% 70%, rgba(255,255,255,.1) 0%, transparent 50%);
  pointer-events: none;
}
.doc-hero-inner { position: relative; max-width: 1100px; margin: 0 auto; padding: 0 24px; }
.hero-badge {
  display: inline-block; padding: 6px 14px;
  background: rgba(255,255,255,.15);
  border: 1px solid rgba(255,255,255,.25);
  border-radius: 999px; font-size: 13px; font-weight: 600; margin-bottom: 16px;
}
.doc-hero-title { font-size: 40px; font-weight: 900; letter-spacing: -.5px; margin: 0 0 10px; }
.doc-hero-sub { font-size: 16px; color: rgba(255,255,255,.9); margin: 0 0 24px; max-width: 760px; line-height: 1.7; }
.doc-search-box {
  display: flex; align-items: center; gap: 10px;
  background: #fff; padding: 8px 14px;
  border-radius: 12px; color: #86909c;
  max-width: 560px; box-shadow: 0 12px 28px rgba(13,17,23,.18);
}
.doc-search-input {
  flex: 1; border: none; outline: none; background: transparent;
  font-size: 15px; color: #1d2129; padding: 8px 0;
  font-family: inherit;
}

/* layout */
.doc-layout {
  max-width: 1320px;
  margin: -24px auto 60px;
  padding: 0 24px;
  display: grid;
  grid-template-columns: 260px 1fr;
  gap: 28px;
  align-items: start;
}

/* sidebar */
.doc-sidebar { position: relative; }
.side-sticky {
  position: sticky; top: 16px;
  background: #fff; border-radius: 14px;
  box-shadow: 0 1px 4px rgba(0,0,0,.04);
  padding: 16px;
}
.side-group { margin-bottom: 16px; }
.side-group:last-child { margin-bottom: 0; }
.side-group-title {
  font-size: 12px; font-weight: 700; color: #86909c;
  text-transform: uppercase; letter-spacing: .5px;
  margin-bottom: 8px; padding: 0 4px;
}
.side-list { list-style: none; margin: 0; padding: 0; }
.side-link {
  display: block; padding: 8px 10px; border-radius: 8px;
  color: #4e5969; font-size: 14px; text-decoration: none;
  transition: all .18s; cursor: pointer;
}
.side-link:hover { background: #f2f3f5; color: #1d2129; }
.side-link.active {
  background: #e8f3ff; color: #165dff; font-weight: 600;
}
.side-empty { font-size: 12px; color: #c9cdd4; padding: 4px; margin: 0; }

/* main */
.doc-main {
  background: #fff; border-radius: 14px;
  padding: 32px 36px;
  box-shadow: 0 1px 4px rgba(0,0,0,.04);
  min-height: 600px;
}

.doc-breadcrumb {
  font-size: 13px; color: #86909c;
  margin-bottom: 20px; display: flex; gap: 8px; flex-wrap: wrap;
}
.doc-breadcrumb a { color: #86909c; text-decoration: none; }
.doc-breadcrumb a:hover { color: #165dff; }
.doc-breadcrumb .sep { color: #c9cdd4; }
.doc-breadcrumb .cat { color: #4e5969; }
.doc-breadcrumb .title { color: #1d2129; font-weight: 600; }

.doc-header { margin-bottom: 24px; padding-bottom: 18px; border-bottom: 1px solid #f2f3f5; }
.doc-title { font-size: 30px; font-weight: 900; color: #1d2129; letter-spacing: -.3px; margin: 0 0 10px; }
.doc-meta { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
.doc-cat-tag {
  display: inline-block; padding: 3px 10px; border-radius: 4px;
  font-size: 12px; font-weight: 600; color: #fff;
}
.doc-cat-tag.cat-arch { background: #165dff; }
.doc-cat-tag.cat-api { background: #722ed1; }
.doc-cat-tag.cat-recharge { background: #23c343; }
.doc-cat-tag.cat-deploy { background: #f59e0b; }
.doc-updated { display: inline-flex; align-items: center; gap: 6px; font-size: 12px; color: #86909c; }

/* Markdown body */
.md-body { color: #2e2e2e; font-size: 15px; line-height: 1.75; word-wrap: break-word; }
.md-body :deep(h1) { font-size: 26px; font-weight: 800; margin: 36px 0 18px; padding-bottom: 10px; border-bottom: 1px solid #f2f3f5; }
.md-body :deep(h2) { font-size: 22px; font-weight: 800; margin: 30px 0 14px; padding-left: 12px; border-left: 4px solid #165dff; color: #1d2129; }
.md-body :deep(h3) { font-size: 18px; font-weight: 700; margin: 22px 0 10px; color: #1d2129; }
.md-body :deep(h4) { font-size: 16px; font-weight: 700; margin: 18px 0 8px; color: #1d2129; }
.md-body :deep(p) { margin: 10px 0; }
.md-body :deep(blockquote) {
  margin: 14px 0; padding: 10px 14px; border-left: 4px solid #4080ff;
  background: #eef4ff; color: #4e5969; border-radius: 4px;
}
.md-body :deep(ul), .md-body :deep(ol) { padding-left: 26px; margin: 10px 0; }
.md-body :deep(li) { margin: 4px 0; }
.md-body :deep(a) { color: #165dff; text-decoration: none; border-bottom: 1px solid rgba(22,93,255,.2); }
.md-body :deep(a:hover) { color: #4080ff; border-color: #4080ff; }
.md-body :deep(code) {
  font-family: 'JetBrains Mono', 'Fira Code', Menlo, Consolas, monospace;
  font-size: .9em; padding: 2px 6px; border-radius: 4px;
  background: #f2f3f5; color: #f5222d;
}
.md-body :deep(pre) {
  background: #0f172a; color: #e2e8f0; padding: 18px 20px;
  border-radius: 10px; overflow-x: auto; margin: 16px 0;
  box-shadow: inset 0 0 0 1px rgba(148,163,184,.1);
  line-height: 1.7;
}
.md-body :deep(pre code) {
  background: transparent; color: inherit; padding: 0;
}
.md-body :deep(table) {
  width: 100%; border-collapse: collapse; margin: 16px 0;
  background: #fff; border-radius: 10px; overflow: hidden;
  box-shadow: 0 0 0 1px #ebecef;
  font-size: 14px;
}
.md-body :deep(th) {
  background: #f7f8fa; color: #1d2129; font-weight: 700;
  padding: 12px 16px; text-align: left;
  border-bottom: 2px solid #ebecef;
  position: sticky; top: 0;
}
.md-body :deep(td) {
  padding: 10px 16px; border-bottom: 1px solid #f2f3f5; color: #4e5969;
  vertical-align: top;
}
.md-body :deep(tr:last-child td) { border-bottom: none; }
.md-body :deep(tr:hover) td { background: #fafbfc; }
.md-body :deep(hr) { border: none; border-top: 1px dashed #e5e6eb; margin: 28px 0; }
.md-body :deep(img) { max-width: 100%; border-radius: 8px; margin: 14px 0; box-shadow: 0 2px 10px rgba(0,0,0,.08); }
.md-body :deep(strong) { color: #1d2129; font-weight: 700; }

/* loading & empty */
.doc-loading, .doc-empty {
  padding: 80px 20px; text-align: center; color: #86909c;
}
.spinner {
  width: 36px; height: 36px; border-radius: 50%;
  border: 3px solid #e5e6eb; border-top-color: #165dff;
  animation: spin 1s linear infinite;
  margin: 0 auto 16px;
}
@keyframes spin { to { transform: rotate(360deg); } }

/* footer nav */
.doc-footer-nav {
  margin-top: 48px; padding-top: 24px;
  border-top: 1px solid #f2f3f5;
  display: grid; grid-template-columns: 1fr 1fr; gap: 16px;
}
.foot-foot-item {
  display: flex; flex-direction: column; gap: 4px;
  padding: 16px 20px; border-radius: 12px;
  border: 1px solid #e5e6eb;
  text-decoration: none; color: inherit; cursor: pointer;
  transition: all .2s;
}
.foot-foot-item:hover { border-color: #165dff; background: #f5f9ff; }
.foot-foot-item.next { text-align: right; grid-column-start: 2; }
.foot-foot-label { font-size: 12px; color: #86909c; }
.foot-foot-item strong { font-size: 16px; color: #1d2129; }

/* responsive */
@media (max-width: 1000px) {
  .doc-layout { grid-template-columns: 1fr; }
  .side-sticky { position: static; }
  .doc-main { padding: 24px; }
}
@media (max-width: 600px) {
  .doc-hero-title { font-size: 30px; }
  .doc-hero { padding: 48px 0 60px; }
  .doc-layout { margin-top: -16px; padding: 0 16px; }
  .doc-title { font-size: 22px; }
  .doc-footer-nav { grid-template-columns: 1fr; }
  .foot-foot-item.next { grid-column: auto; text-align: left; }
}
</style>
