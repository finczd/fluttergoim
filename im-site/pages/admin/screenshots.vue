<template>
  <div class="screenshots-page">
    <div class="list-head">
      <h2>截图管理</h2>
      <div class="head-tip">首页轮播展示顺序：按列表从左到右、从上到下。可通过上下箭头调整顺序。</div>
    </div>

    <!-- 添加截图 -->
    <div class="card add-card">
      <h3>添加截图</h3>
      <div class="add-row">
        <input type="file" accept="image/*" class="file-input" @change="onFile" />
        <input v-model="newTitle" placeholder="标题（可选，留空将使用默认）" class="form-input title-input" />
        <button @click="addShot" :disabled="adding || !newUrl" class="btn-primary-sm">
          {{ adding ? '添加中...' : '添加' }}
        </button>
      </div>
      <div v-if="newUrl" class="preview-box">
        <img :src="newUrl" alt="预览" />
        <span class="hint">已选择图片，点击「添加」入库</span>
      </div>
    </div>

    <!-- 截图列表 -->
    <div v-if="loading" class="empty">加载中...</div>
    <div v-else-if="!shots.length" class="empty">暂无截图</div>
    <div v-else class="shot-grid">
      <div v-for="(s, idx) in shots" :key="s.id" class="shot-card">
        <!-- 顺序编号 + 移动按钮 -->
        <div class="shot-order-bar">
          <span class="order-num">#{{ idx + 1 }}</span>
          <div class="order-btns">
            <button
              @click="move(s, -1)"
              :disabled="idx === 0"
              class="order-btn"
              title="上移"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="18 15 12 9 6 15"/></svg>
            </button>
            <button
              @click="move(s, 1)"
              :disabled="idx === shots.length - 1"
              class="order-btn"
              title="下移"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"/></svg>
            </button>
          </div>
        </div>

        <!-- 图片：点击预览 -->
        <div class="shot-img-wrap" @click="previewShot = s">
          <img :src="s.url" :alt="s.title" class="shot-img" />
          <div class="shot-preview-mask">
            <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
            <span>点击预览</span>
          </div>
        </div>

        <div class="shot-body">
          <input v-model="s.title" class="form-input shot-title" placeholder="截图标题" />
          <div class="shot-actions">
            <button @click="saveTitle(s)" class="act-btn">保存标题</button>
            <button @click="removeShot(s)" class="act-btn danger">删除</button>
          </div>
        </div>
      </div>
    </div>

    <!-- 预览弹窗 -->
    <Teleport to="body">
      <transition name="modal-fade">
        <div v-if="previewShot" class="preview-mask" @click.self="previewShot = null">
          <button class="preview-close" @click="previewShot = null" aria-label="关闭">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
          <div class="preview-inner">
            <img :src="previewShot.url" :alt="previewShot.title" class="preview-img" />
          </div>
          <div class="preview-caption">
            <strong>#{{ shots.findIndex(x => x.id === previewShot.id) + 1 }}</strong>
            <span>{{ previewShot.title || '未命名' }}</span>
            <span class="preview-dim">{{ previewShot.url }}</span>
          </div>
        </div>
      </transition>
    </Teleport>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })

interface Shot {
  id: number
  url: string
  title: string
  order: number
}

const shots = ref<Shot[]>([])
const loading = ref(false)
const newUrl = ref('')
const newTitle = ref('')
const adding = ref(false)
const previewShot = ref<Shot | null>(null)

async function load() {
  loading.value = true
  try {
    // 后台列表统一走 /api/admin/screenshots（不要用公共 /api/screenshots），
    // 两边接口返回的字段结构不同：admin 是 { code, data: Array }，公共是带绝对 URL 归一化的。
    const res = await $fetch<any>('/api/admin/screenshots')
    if (res.code === 0) {
      const list: any[] = Array.isArray(res.data) ? res.data : (res.data?.list || [])
      shots.value = list.map((s: any) => ({
        id: s.id,
        url: s.url,
        title: s.title,
        order: s.order ?? s.sort_order ?? 0,
        // 页面模板有地方读 shots[].order，读 shots[].sort_order，各补一份
        sort_order: s.sort_order ?? s.order ?? 0,
      } as Shot))
    }
  } catch { /* ignore */ }
  loading.value = false
}

async function onFile(e: Event) {
  const target = e.target as HTMLInputElement
  const file = target.files?.[0]
  if (!file) return
  try {
    const fd = new FormData()
    fd.append('file', file)
    const res = await $fetch<{ code: number; data: { url: string }; message?: string }>(
      '/api/admin/upload', { method: 'POST', body: fd },
    )
    if (res.code === 0 && res.data?.url) {
      newUrl.value = res.data.url
    } else {
      alert(res.message || '上传失败')
    }
  } catch (err: any) {
    alert('上传失败: ' + (err?.data?.message || err?.message || ''))
  }
  target.value = ''
}

async function addShot() {
  if (!newUrl.value) { alert('请先选择并上传图片'); return }
  adding.value = true
  try {
    const res = await $fetch<{ code: number; message?: string }>(
      '/api/admin/screenshots',
      { method: 'POST', body: { url: newUrl.value, title: newTitle.value } },
    )
    if (res.code === 0) {
      newUrl.value = ''
      newTitle.value = ''
      await load()
    } else {
      alert(res.message || '添加失败')
    }
  } catch (err: any) {
    alert('添加失败: ' + (err?.data?.message || err?.message || ''))
  }
  adding.value = false
}

async function saveTitle(s: Shot) {
  try {
    const res = await $fetch<{ code: number; message?: string }>(
      `/api/admin/screenshots/${s.id}`,
      { method: 'PUT', body: { title: s.title } },
    )
    if (res.code === 0) alert('标题已保存')
    else alert(res.message || '保存失败')
  } catch (err: any) {
    alert('保存失败: ' + (err?.data?.message || err?.message || ''))
  }
}

async function removeShot(s: Shot) {
  if (!confirm(`确认删除「${s.title || '未命名'}」？`)) return
  try {
    await $fetch(`/api/admin/screenshots/${s.id}`, { method: 'DELETE' })
    await load()
  } catch (err: any) {
    alert('删除失败: ' + (err?.data?.message || err?.message || ''))
  }
}

/**
 * 调整顺序：与上一张或下一张互换 order，然后 PUT 两张更新
 * dir: -1 上移，+1 下移
 */
async function move(s: Shot, dir: -1 | 1) {
  const idx = shots.value.findIndex(x => x.id === s.id)
  const otherIdx = idx + dir
  if (idx < 0 || otherIdx < 0 || otherIdx >= shots.value.length) return
  const other = shots.value[otherIdx]
  const sOrder = s.order
  const oOrder = other.order
  try {
    // 并发更新两条
    await Promise.all([
      $fetch(`/api/admin/screenshots/${s.id}`, { method: 'PUT', body: { order: oOrder } }),
      $fetch(`/api/admin/screenshots/${other.id}`, { method: 'PUT', body: { order: sOrder } }),
    ])
    await load()
  } catch (err: any) {
    alert('调整顺序失败: ' + (err?.data?.message || err?.message || ''))
  }
}

onMounted(async () => {
  try { await $fetch('/api/admin/articles?pageSize=1') }
  catch { await navigateTo('/admin/login'); return }
  await load()
})
</script>

<style scoped>
.list-head {
  display: flex; align-items: center; justify-content: space-between;
  margin-bottom: 20px; flex-wrap: wrap; gap: 10px;
}
.list-head h2 { font-size: 20px; font-weight: 700; color: #1d2129; }
.head-tip { font-size: 13px; color: #86909c; }

.card {
  background: #fff; border-radius: 8px; padding: 20px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, .04);
}
.add-card { margin-bottom: 20px; }
.add-card h3 { font-size: 15px; font-weight: 600; color: #1d2129; margin: 0 0 14px; }

.add-row { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
.file-input {
  font-size: 13px; color: #4e5969;
  padding: 8px 10px; border: 1px solid #e5e6eb; border-radius: 6px; background: #fff;
}
.form-input {
  padding: 8px 12px; border: 1px solid #e5e6eb; border-radius: 6px;
  font-size: 14px; outline: none; background: #fff; transition: border-color .2s;
  font-family: inherit;
}
.form-input:focus { border-color: #165dff; }
.title-input { flex: 1; min-width: 200px; }

.btn-primary-sm {
  padding: 8px 18px; background: #165dff; color: #fff; border: none;
  border-radius: 8px; font-size: 14px; font-weight: 600; cursor: pointer;
}
.btn-primary-sm:hover { background: #4080ff; }
.btn-primary-sm:disabled { opacity: .6; cursor: not-allowed; }

.preview-box { margin-top: 12px; display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
.preview-box img { height: 80px; border-radius: 8px; border: 1px solid #e5e6eb; object-fit: contain; }
.hint { font-size: 13px; color: #86909c; }

.empty {
  text-align: center; color: #86909c; padding: 40px 0;
  background: #fff; border-radius: 8px; box-shadow: 0 1px 4px rgba(0,0,0,.04);
}

.shot-grid {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 16px;
}
.shot-card {
  background: #fff; border-radius: 8px; overflow: hidden;
  box-shadow: 0 1px 4px rgba(0, 0, 0, .04); display: flex; flex-direction: column;
  transition: box-shadow .2s, transform .2s;
}
.shot-card:hover { box-shadow: 0 6px 18px rgba(0,0,0,.1); transform: translateY(-2px); }

.shot-order-bar {
  display: flex; align-items: center; justify-content: space-between;
  padding: 8px 12px; background: #f7f8fa; border-bottom: 1px solid #f2f3f5;
}
.order-num {
  font-size: 12px; font-weight: 700;
  color: #165dff; background: #e8f3ff; padding: 2px 8px; border-radius: 4px;
}
.order-btns { display: flex; gap: 4px; }
.order-btn {
  width: 24px; height: 24px; border-radius: 4px;
  border: none; background: #fff; color: #4e5969;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; transition: all .2s;
  border: 1px solid #e5e6eb; padding: 0;
}
.order-btn:hover:not(:disabled) { background: #165dff; color: #fff; border-color: #165dff; }
.order-btn:disabled { opacity: .4; cursor: not-allowed; }

.shot-img-wrap {
  position: relative; cursor: zoom-in; background: #f7f8fa;
  width: 100%; aspect-ratio: 3 / 4; overflow: hidden;
}
.shot-img {
  width: 100%; height: 100%; object-fit: cover; display: block;
  transition: transform .3s;
}
.shot-img-wrap:hover .shot-img { transform: scale(1.04); }
.shot-preview-mask {
  position: absolute; inset: 0;
  background: linear-gradient(180deg, rgba(13,17,23,.1) 0%, rgba(13,17,23,.6) 100%);
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 6px; opacity: 0; transition: opacity .2s;
  color: #fff; font-size: 12px; font-weight: 600;
}
.shot-img-wrap:hover .shot-preview-mask { opacity: 1; }

.shot-body { padding: 12px; display: flex; flex-direction: column; gap: 10px; }
.shot-title { width: 100%; }
.shot-actions { display: flex; gap: 8px; }
.act-btn {
  padding: 5px 12px; border: none; border-radius: 6px; background: #f2f3f5;
  color: #4e5969; font-size: 13px; cursor: pointer; transition: all .2s;
}
.act-btn:hover { background: #e5e6eb; }
.act-btn.danger { color: #f53f3f; }
.act-btn.danger:hover { background: #ffece8; }

/* ============ 预览弹窗 ============ */
.preview-mask {
  position: fixed; inset: 0; z-index: 9999;
  background: rgba(0,0,0,.85);
  backdrop-filter: blur(4px);
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  padding: 40px 24px 80px;
}
.preview-close {
  position: fixed; top: 24px; right: 24px;
  width: 40px; height: 40px; border-radius: 50%;
  border: none; background: rgba(255,255,255,.1); color: #fff;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; transition: all .2s; z-index: 10000; padding: 0;
}
.preview-close:hover { background: rgba(255,255,255,.2); transform: rotate(90deg); }

.preview-inner {
  flex: 1; width: 100%; max-width: 700px;
  display: flex; align-items: center; justify-content: center;
  min-height: 0;
}
.preview-img {
  max-width: 100%; max-height: 100%;
  border-radius: 12px;
  box-shadow: 0 20px 60px rgba(0,0,0,.5);
  object-fit: contain;
  background: #fff;
}
.preview-caption {
  margin-top: 20px; display: flex; align-items: center; gap: 12px;
  color: #fff; font-size: 14px; flex-wrap: wrap; justify-content: center;
}
.preview-caption strong {
  padding: 2px 10px; background: #165dff; border-radius: 4px;
  font-size: 12px;
}
.preview-dim { color: #8b949e; font-size: 12px; word-break: break-all; }

.modal-fade-enter-active, .modal-fade-leave-active { transition: opacity .25s ease; }
.modal-fade-enter-from, .modal-fade-leave-to { opacity: 0; }
.modal-fade-enter-active .preview-img,
.modal-fade-leave-active .preview-img { transition: transform .3s ease, opacity .25s ease; }
.modal-fade-enter-from .preview-img,
.modal-fade-leave-to .preview-img { opacity: 0; transform: scale(.9); }
</style>
