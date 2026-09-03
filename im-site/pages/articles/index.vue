<template>
  <div class="articles-page">
    <!-- ============ HERO ============ -->
    <section class="hero">
      <div class="hero-bg-deco" aria-hidden="true">
        <span class="orb orb-1"></span>
        <span class="orb orb-2"></span>
      </div>
      <div class="container hero-inner">
        <span class="hero-badge">ChatPulse 资讯中心</span>
        <h1 class="hero-title">资讯动态</h1>
        <p class="hero-subtitle">了解 IM 行业最新趋势与技术实践</p>
      </div>
    </section>

    <!-- ============ MAIN ============ -->
    <section class="section main-section">
      <div class="container">
        <div class="layout">
          <!-- Content column -->
          <div class="content-col">
            <!-- Category filter bar -->
            <div class="filter-bar">
              <button
                class="filter-chip"
                :class="{ active: category === '' }"
                @click="setCategory('')"
              >
                全部
              </button>
              <button
                v-for="c in categories"
                :key="c.name"
                class="filter-chip"
                :class="{ active: category === c.name }"
                @click="setCategory(c.name)"
              >
                {{ c.name }}
                <span class="chip-count">{{ c.count }}</span>
              </button>
            </div>

            <!-- Loading -->
            <div v-if="pending" class="state state-loading">
              <span class="spinner" aria-hidden="true"></span>
              <p>加载中…</p>
            </div>

            <!-- Error -->
            <div v-else-if="error" class="state state-error">
              <p>加载失败，请稍后重试。</p>
              <button class="btn btn-outline" @click="refresh()">重新加载</button>
            </div>

            <!-- Empty -->
            <div v-else-if="!articles.length" class="state state-empty">
              <span class="empty-icon" v-html="emptySvg" aria-hidden="true"></span>
              <p class="empty-text">暂无文章</p>
              <NuxtLink to="/articles" class="btn btn-outline">浏览全部</NuxtLink>
            </div>

            <!-- Article list -->
            <div v-else class="article-list">
              <article
                v-for="a in articles"
                :key="a.id"
                class="article-card"
              >
                <NuxtLink :to="`/articles/${a.slug}`" class="cover-link">
                  <div class="cover" :class="{ placeholder: !a.coverImage }">
                    <img
                      v-if="a.coverImage"
                      :src="a.coverImage"
                      :alt="a.title"
                      loading="lazy"
                    />
                    <span
                      v-else
                      class="cover-fallback"
                      v-html="coverFallbackSvg"
                      aria-hidden="true"
                    ></span>
                  </div>
                </NuxtLink>

                <div class="article-body">
                  <span class="article-cat">{{ a.category || '未分类' }}</span>
                  <h2 class="article-title">
                    <NuxtLink :to="`/articles/${a.slug}`">{{ a.title }}</NuxtLink>
                  </h2>
                  <p class="article-summary">{{ a.summary }}</p>
                  <div class="article-meta">
                    <span class="meta-item">
                      <span class="meta-icon" v-html="dateSvg" aria-hidden="true"></span>
                      {{ formatDate(a.createdAt) }}
                    </span>
                    <span class="meta-item">
                      <span class="meta-icon" v-html="eyeSvg" aria-hidden="true"></span>
                      {{ a.views ?? 0 }} 阅读
                    </span>
                    <span v-if="a.tags && a.tags.length" class="meta-tags">
                      <span v-for="t in a.tags" :key="t" class="tag">#{{ t }}</span>
                    </span>
                  </div>
                </div>
              </article>
            </div>

            <!-- Pagination -->
            <nav v-if="totalPages > 1" class="pagination">
              <button
                class="page-btn"
                :disabled="page <= 1"
                @click="goTo(page - 1)"
              >
                上一页
              </button>
              <span class="page-info">{{ page }} / {{ totalPages }}</span>
              <button
                class="page-btn"
                :disabled="page >= totalPages"
                @click="goTo(page + 1)"
              >
                下一页
              </button>
            </nav>
          </div>

          <!-- Sidebar (desktop only) -->
          <aside class="sidebar">
            <div class="card sidebar-card">
              <h3 class="sidebar-title">热门标签</h3>
              <div v-if="hotTags.length" class="tag-cloud">
                <NuxtLink
                  v-for="t in hotTags"
                  :key="t"
                  to="/articles"
                  class="cloud-tag"
                >
                  #{{ t }}
                </NuxtLink>
              </div>
              <p v-else class="sidebar-empty">暂无标签</p>
            </div>

            <div class="card sidebar-cta">
              <h3 class="sidebar-cta-title">需要定制 IM 系统？</h3>
              <p class="sidebar-cta-text">告诉我们您的需求，获取专属方案与报价</p>
              <NuxtLink to="/contact" class="btn btn-primary sidebar-cta-btn">
                立即咨询 →
              </NuxtLink>
            </div>
          </aside>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup>
useHead({
  title: '资讯动态 - ChatPulse IM',
  meta: [
    {
      name: 'description',
      content: 'ChatPulse IM系统最新动态、技术分享、行业资讯',
    },
  ],
})

const page = ref(1)
const category = ref('')
const pageSize = 10

const {
  data: articlesData,
  pending,
  error,
  refresh,
} = await useFetch('/api/articles', {
  query: computed(() => ({
    page: page.value,
    pageSize,
    category: category.value || undefined,
  })),
})

const { data: categoriesData } = await useFetch('/api/categories')

const articles = computed(() => articlesData.value?.data?.list || [])
const total = computed(() => articlesData.value?.data?.total || 0)
const totalPages = computed(() => Math.max(1, Math.ceil(total.value / pageSize)))
const categories = computed(() => categoriesData.value?.data || [])

const hotTags = computed(() => {
  const set = new Set()
  articles.value.forEach((a) => {
    a.tags?.forEach((t) => set.add(t))
  })
  return [...set]
})

function setCategory(c) {
  category.value = c
  page.value = 1
}

function goTo(p) {
  page.value = Math.min(Math.max(1, p), totalPages.value)
}

function formatDate(d) {
  if (!d) return ''
  const dt = new Date(d)
  if (isNaN(dt.getTime())) return ''
  const y = dt.getFullYear()
  const m = String(dt.getMonth() + 1).padStart(2, '0')
  const day = String(dt.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

watch(page, () => {
  if (import.meta.client) {
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }
})

const emptySvg =
  '<svg width="56" height="56" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="3" y="5" width="18" height="14" rx="2" stroke="#c9cdd4" stroke-width="1.6"/><path d="M7 9h10M7 12h10M7 15h6" stroke="#c9cdd4" stroke-width="1.6" stroke-linecap="round"/></svg>'

const coverFallbackSvg =
  '<svg width="40" height="40" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="3" y="4" width="18" height="16" rx="2" fill="#fff" opacity=".9"/><circle cx="8" cy="9" r="1.4" fill="#165dff"/><path d="M5 18l4-5 3 3 3-4 4 6H5z" fill="#165dff" opacity=".6"/></svg>'

const dateSvg =
  '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="3" y="5" width="18" height="16" rx="2" stroke="currentColor" stroke-width="1.8"/><path d="M3 9h18M8 3v4M16 3v4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>'

const eyeSvg =
  '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><circle cx="12" cy="12" r="3" stroke="currentColor" stroke-width="1.8"/></svg>'
</script>

<style scoped>
/* ============ HERO ============ */
.hero {
  position: relative;
  background: linear-gradient(135deg, #165dff 0%, #4080ff 100%);
  color: #fff;
  padding: 72px 0 80px;
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

.hero-badge {
  display: inline-block;
  padding: 7px 16px;
  font-size: 14px;
  font-weight: 600;
  color: #fff;
  background: rgba(255, 255, 255, 0.15);
  border: 1px solid rgba(255, 255, 255, 0.25);
  border-radius: 999px;
  margin-bottom: 20px;
  backdrop-filter: blur(8px);
}

.hero-title {
  font-size: 46px;
  font-weight: 900;
  line-height: 1.15;
  letter-spacing: -1px;
  margin-bottom: 18px;
}

.hero-subtitle {
  font-size: 18px;
  color: rgba(255, 255, 255, 0.9);
  font-weight: 400;
}

/* ============ LAYOUT ============ */
.main-section {
  background: var(--c-bg-2);
  min-height: 60vh;
}

.layout {
  display: grid;
  grid-template-columns: 1fr 320px;
  gap: 32px;
  align-items: start;
}

.content-col {
  min-width: 0;
}

/* ============ FILTER BAR ============ */
.filter-bar {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-bottom: 28px;
}

.filter-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 18px;
  font-size: 14px;
  font-weight: 600;
  color: var(--c-text-2);
  background: var(--c-bg-1);
  border: 1px solid var(--c-border);
  border-radius: 999px;
  cursor: pointer;
  transition: all 0.2s;
}

.filter-chip:hover {
  color: var(--c-primary);
  border-color: var(--c-primary-light);
}

.filter-chip.active {
  color: #fff;
  background: var(--c-gradient);
  border-color: transparent;
  box-shadow: 0 4px 12px rgba(22, 93, 255, 0.28);
}

.chip-count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 6px;
  font-size: 11px;
  font-weight: 700;
  color: var(--c-text-3);
  background: var(--c-bg-3);
  border-radius: 999px;
}

.filter-chip.active .chip-count {
  color: var(--c-primary);
  background: rgba(255, 255, 255, 0.85);
}

/* ============ ARTICLE LIST ============ */
.article-list {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.article-card {
  display: grid;
  grid-template-columns: 200px 1fr;
  gap: 20px;
  background: var(--c-bg-1);
  border: 1px solid var(--c-border);
  border-radius: var(--radius-lg);
  overflow: hidden;
  box-shadow: var(--shadow-card);
  transition: box-shadow 0.3s, transform 0.3s;
}

.article-card:hover {
  box-shadow: var(--shadow-lg);
  transform: translateY(-3px);
}

.cover-link {
  display: block;
  flex-shrink: 0;
}

.cover {
  width: 200px;
  height: 140px;
  overflow: hidden;
  position: relative;
  background: var(--c-bg-3);
}

.cover img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
  transition: transform 0.4s;
}

.article-card:hover .cover img {
  transform: scale(1.05);
}

.cover.placeholder {
  background: var(--c-gradient);
  display: flex;
  align-items: center;
  justify-content: center;
}

.cover-fallback {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  opacity: 0.85;
}

.article-body {
  display: flex;
  flex-direction: column;
  padding: 18px 22px 16px 0;
  min-width: 0;
}

.article-cat {
  display: inline-block;
  align-self: flex-start;
  padding: 3px 10px;
  font-size: 12px;
  font-weight: 600;
  color: var(--c-primary);
  background: var(--c-primary-bg);
  border-radius: 999px;
  margin-bottom: 8px;
}

.article-title {
  font-size: 20px;
  font-weight: 800;
  line-height: 1.35;
  letter-spacing: -0.3px;
  margin-bottom: 8px;
}

.article-title a {
  color: var(--c-text-1);
  transition: color 0.2s;
}

.article-title a:hover {
  color: var(--c-primary);
}

.article-summary {
  font-size: 14px;
  color: var(--c-text-2);
  line-height: 1.65;
  margin-bottom: 14px;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.article-meta {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 16px;
  margin-top: auto;
  font-size: 13px;
  color: var(--c-text-3);
}

.meta-item {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.meta-icon {
  display: inline-flex;
  align-items: center;
  color: var(--c-text-3);
}

.meta-tags {
  display: inline-flex;
  flex-wrap: wrap;
  gap: 8px;
}

.tag {
  font-size: 12px;
  color: var(--c-text-3);
}

/* ============ STATES ============ */
.state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 16px;
  padding: 72px 24px;
  text-align: center;
  background: var(--c-bg-1);
  border: 1px solid var(--c-border);
  border-radius: var(--radius-lg);
}

.state p {
  color: var(--c-text-3);
  font-size: 15px;
}

.spinner {
  width: 36px;
  height: 36px;
  border: 3px solid var(--c-border);
  border-top-color: var(--c-primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.empty-icon {
  display: inline-flex;
  margin-bottom: 4px;
}

.empty-text {
  font-size: 16px;
  font-weight: 600;
  color: var(--c-text-2);
}

/* ============ PAGINATION ============ */
.pagination {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 16px;
  margin-top: 36px;
}

.page-btn {
  padding: 9px 22px;
  font-size: 14px;
  font-weight: 600;
  color: var(--c-primary);
  background: var(--c-bg-1);
  border: 1px solid var(--c-border-2);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all 0.2s;
}

.page-btn:hover:not(:disabled) {
  background: var(--c-primary);
  color: #fff;
  border-color: var(--c-primary);
}

.page-btn:disabled {
  color: var(--c-text-4);
  background: var(--c-bg-3);
  border-color: var(--c-border);
  cursor: not-allowed;
}

.page-info {
  font-size: 14px;
  font-weight: 600;
  color: var(--c-text-2);
}

/* ============ SIDEBAR ============ */
.sidebar {
  display: flex;
  flex-direction: column;
  gap: 24px;
  position: sticky;
  top: 24px;
}

.sidebar-card {
  padding: 24px;
}

.sidebar-title {
  font-size: 17px;
  font-weight: 800;
  color: var(--c-text-1);
  margin-bottom: 16px;
  padding-bottom: 12px;
  border-bottom: 1px solid var(--c-border);
}

.tag-cloud {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.cloud-tag {
  padding: 5px 12px;
  font-size: 13px;
  color: var(--c-text-2);
  background: var(--c-bg-2);
  border: 1px solid var(--c-border);
  border-radius: 999px;
  transition: all 0.2s;
}

.cloud-tag:hover {
  color: var(--c-primary);
  background: var(--c-primary-bg);
  border-color: var(--c-primary-light);
}

.sidebar-empty {
  font-size: 14px;
  color: var(--c-text-3);
}

.sidebar-cta {
  padding: 28px 24px;
  background: linear-gradient(135deg, #165dff 0%, #4080ff 100%);
  border: none;
  color: #fff;
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}

.sidebar-cta-title {
  font-size: 19px;
  font-weight: 800;
  color: #fff;
  letter-spacing: -0.3px;
}

.sidebar-cta-text {
  font-size: 14px;
  color: rgba(255, 255, 255, 0.9);
  margin-bottom: 12px;
}

.sidebar-cta-btn {
  background: #fff;
  color: var(--c-primary);
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.18);
}

.sidebar-cta-btn:hover {
  background: #fff;
  color: var(--c-primary);
  transform: translateY(-2px);
}

/* ============ RESPONSIVE ============ */
@media (max-width: 960px) {
  .layout {
    grid-template-columns: 1fr;
  }
  .sidebar {
    display: none;
  }
  .hero-title {
    font-size: 38px;
  }
}

@media (max-width: 600px) {
  .hero {
    padding: 48px 0 56px;
  }
  .hero-title {
    font-size: 30px;
  }
  .hero-subtitle {
    font-size: 16px;
  }
  .article-card {
    grid-template-columns: 1fr;
  }
  .cover,
  .cover-link {
    width: 100%;
    height: 180px;
  }
  .article-body {
    padding: 18px 18px 16px;
  }
  .article-title {
    font-size: 18px;
  }
  .filter-chip {
    padding: 7px 14px;
    font-size: 13px;
  }
  .pagination {
    gap: 8px;
  }
  .page-btn {
    padding: 8px 16px;
  }
}
</style>
