<template>
  <AdminLayout :activeTab="activeTab" :me="me" @changeTab="switchTab" @openChangePassword="switchTab('change-password')">

    <!-- ============ TAB 1: 文章管理 ============ -->
    <div v-show="activeTab === 'articles'">
      <div v-if="!editing" class="card list-view">
        <div class="list-head">
          <h2>文章管理</h2>
          <button @click="startNew" class="btn-primary-sm">+ 新建文章</button>
        </div>
        <div class="filter-bar">
          <input v-model="filterTitle" placeholder="搜索标题..." class="filter-input" />
          <select v-model="filterCategory" class="filter-select">
            <option value="">全部分类</option>
            <option v-for="c in categories" :key="c.id" :value="c.name">{{ c.name }}</option>
          </select>
          <button class="btn-grey" @click="loadArticles()">查询</button>
        </div>
        <table class="data-table">
          <thead><tr><th>标题</th><th>分类</th><th>状态</th><th>创建时间</th><th>操作</th></tr></thead>
          <tbody>
            <tr v-if="articlesLoading"><td colspan="5" class="empty-row">加载中...</td></tr>
            <tr v-else-if="!articles.length"><td colspan="5" class="empty-row">暂无文章，点击右上角新建</td></tr>
            <tr v-for="a in articles" :key="a.id">
              <td class="td-title">{{ a.title || '(无标题)' }}</td>
              <td>{{ a.category || '-' }}</td>
              <td><span :class="['tag', a.published ? 'tag-green' : 'tag-grey']">{{ a.published ? '已发布' : '草稿' }}</span></td>
              <td>{{ fmt(a.createdAt) }}</td>
              <td class="td-actions">
                <button @click="startEdit(a)" class="act-btn">编辑</button>
                <button @click="togglePublish(a)" class="act-btn">{{ a.published ? '撤回' : '发布' }}</button>
                <button @click="confirmDelete(a)" class="act-btn danger">删除</button>
              </td>
            </tr>
          </tbody>
        </table>
        <Pagination v-if="articlesTotalPages > 1" v-model:page="articlesPage" :total="articlesTotal" :pageSize="articlesPageSize" @change="loadArticles()" />
      </div>
      <div v-else class="card">
        <div class="list-head">
          <h2>{{ articleForm.id ? '编辑文章' : '新建文章' }}</h2>
          <div class="edit-actions">
            <button @click="editing = false" class="btn-grey">返回列表</button>
            <button @click="saveArticle(false)" :disabled="articleSaving" class="btn-grey">{{ articleSaving ? '保存中...' : '存为草稿' }}</button>
            <button @click="saveArticle(true)" :disabled="articleSaving" class="btn-primary-sm">{{ articleSaving ? '保存中...' : (articleForm.published ? '保存并发布' : '发布') }}</button>
          </div>
        </div>
        <Msg :msg="articleMsg" />
        <div class="form-grid">
          <div class="form-main">
            <FormField label="标题" required><input v-model="articleForm.title" class="form-input" @input="autoSlug" /></FormField>
            <FormField label="URL 别名 (slug)" hint="用于 URL 路径，如 /articles/my-slug"><input v-model="articleForm.slug" class="form-input" /></FormField>
            <FormField label="摘要"><textarea v-model="articleForm.summary" rows="2" class="form-input" /></FormField>
            <FormField label="正文" required><textarea v-model="articleForm.content" rows="20" class="form-input code-input" /><small>支持简单 HTML 标签（p、h2、ul 等）</small></FormField>
          </div>
          <div class="form-side">
            <FormField label="分类">
              <input v-model="articleForm.category" list="article-cat-list" class="form-input" />
              <datalist id="article-cat-list"><option v-for="c in categories" :key="c.id" :value="c.name" /></datalist>
            </FormField>
            <FormField label="标签（逗号分隔）"><input v-model="articleTagsText" class="form-input" /></FormField>
            <FormField label="封面图片 URL">
              <input v-model="articleForm.coverImage" class="form-input" />
              <img v-if="articleForm.coverImage" :src="articleForm.coverImage" class="cover-preview" />
            </FormField>
            <FormField label="发布状态">
              <label class="switch-row"><input type="checkbox" v-model="articleForm.published" /><span>{{ articleForm.published ? '已发布' : '草稿' }}</span></label>
            </FormField>
          </div>
        </div>
      </div>
    </div>

    <!-- ============ TAB 2: 基本设置 ============ -->
    <div v-show="activeTab === 'settings'">
      <div class="card">
        <div class="list-head"><h2>基本设置</h2></div>
        <Msg :msg="settingsMsg" />
        <div class="form-grid">
          <div class="form-main">
            <FormField label="站点标题"><input v-model="siteCfg.siteTitle" class="form-input" /></FormField>
            <FormField label="站点描述"><textarea v-model="siteCfg.siteDescription" rows="3" class="form-input" /></FormField>
            <FormField label="关键词（逗号分隔）"><input v-model="siteCfg.siteKeywords" class="form-input" /></FormField>
            <FormField label="LOGO 路径"><input v-model="siteCfg.logo" class="form-input" /></FormField>
          </div>
          <div class="form-side">
            <FormField label="Telegram 联系"><input v-model="siteCfg.contactTelegram" class="form-input" /></FormField>
            <FormField label="微信号"><input v-model="siteCfg.contactWechat" class="form-input" /></FormField>
            <FormField label="QQ"><input v-model="siteCfg.contactQq" class="form-input" /></FormField>
            <FormField label="联系电话"><input v-model="siteCfg.contactPhone" class="form-input" /></FormField>
            <FormField label="联系邮箱"><input v-model="siteCfg.contactEmail" class="form-input" /></FormField>
            <FormField label="H5 Demo URL"><input v-model="siteCfg.h5DemoUrl" class="form-input" /></FormField>
          </div>
        </div>

        <!-- Demo 下载地址 -->
        <div class="card" style="margin-top:16px">
          <div class="list-head"><h2>Demo 下载地址</h2></div>
          <Msg :msg="settingsMsg" />
          <div class="form-grid">
            <div class="form-main">
              <FormField label="Android APK 下载地址">
                <input v-model="siteCfg.androidDownloadUrl" class="form-input" placeholder="https://xxx.com/app.apk" />
              </FormField>
              <FormField label="iOS 下载地址（可选，留空则显示自签名提示）">
                <input v-model="siteCfg.iosDownloadUrl" class="form-input" placeholder="https://xxx.com/app.ipa 或 App Store 链接" />
              </FormField>
              <FormField label="iOS 安装提示文案">
                <input v-model="siteCfg.iosSelfSignGuide" class="form-input" placeholder="请自行签名安装测试" />
              </FormField>
              <FormField label="后台管理地址">
                <input v-model="siteCfg.adminPanelUrl" class="form-input" placeholder="https://xxx.com/admin" />
              </FormField>
              <FormField label="PC 客户端下载地址">
                <input v-model="siteCfg.pcClientUrl" class="form-input" placeholder="https://xxx.com/client.exe" />
              </FormField>
            </div>
            <div class="form-side">
              <div class="info-box">
                <div style="font-size:13px;color:#4e5969;line-height:1.7">
                  配置后，<a href="/download" target="_blank" style="color:#165dff">/download</a> 下载页和 <a href="/demo" target="_blank" style="color:#165dff">/demo</a> 体验页会自动使用这些地址。<br/>
                  Android 用户访问下载页直接显示 APK 下载按钮。<br/>
                  iOS 用户会提示联系客服并自动跳转 Telegram。
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 定价管理（USDT）卡片 -->
      <div class="card">
        <div class="list-head"><h2>定价管理（USDT）</h2></div>
        <div class="form-grid">
          <div class="form-main">
            <FormField label="周期（显示在卡片顶部，如 终身授权）">
              <input v-model="pricingCfg.pricePeriod" class="form-input" placeholder="例：终身授权" />
            </FormField>

            <div class="pricing-row">
              <FormField label="标准版 价格（USDT，填 0 表示面议）" required>
                <input type="number" min="0" step="1" v-model.number="pricingCfg.priceStandardUsdt" class="form-input" />
              </FormField>
              <FormField label="标准版 备注/副标题（note）">
                <textarea v-model="pricingCfg.priceStandardNote" rows="1" class="form-input" placeholder="如：适合中小企业，源码+基础功能"></textarea>
              </FormField>
            </div>

            <div class="pricing-row">
              <FormField label="专业版 价格（USDT，填 0 表示面议）" required>
                <input type="number" min="0" step="1" v-model.number="pricingCfg.priceProfessionalUsdt" class="form-input" />
              </FormField>
              <FormField label="专业版 备注/副标题（note）">
                <textarea v-model="pricingCfg.priceProfessionalNote" rows="1" class="form-input" placeholder="如：全功能版，音视频+红包+AI助手"></textarea>
              </FormField>
            </div>

            <div class="pricing-row">
              <FormField label="企业版 自定义文本（可填 面议 / 定制 或数字）" required>
                <input v-model="pricingCfg.priceEnterpriseText" class="form-input" placeholder="例：面议 / 定制 / 9999" />
              </FormField>
              <FormField label="企业版 备注/副标题（note）">
                <textarea v-model="pricingCfg.priceEnterpriseNote" rows="1" class="form-input" placeholder="如：独占授权，SLA保障，专属团队"></textarea>
              </FormField>
            </div>
          </div>
          <div class="form-side">
            <div class="info-box">
              <div class="info-row"><span>说明：</span></div>
              <div style="font-size:13px;color:#4e5969;line-height:1.7">
                所有价格字段以 USDT 为单位。<br/>
                标准版 / 专业版：填入数字（不包含千分位逗号）。<br/>
                填写 0 表示显示「面议」。<br/>
                企业版：可填任意文本（「面议」「定制」或具体数字/金额）。<br/>
                显示层会自动加上 USDT 标志和千分位格式。
              </div>
            </div>
            <button class="btn-primary-sm" @click="saveSiteConfig()" :disabled="siteCfgSaving" style="margin-top:12px">
              {{ siteCfgSaving ? '保存中...' : '保存（基础设置 + 定价）' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- ============ TAB 3: 截图管理 ============ -->
    <div v-show="activeTab === 'screenshots'" class="card">
      <div class="list-head">
        <h2>截图管理</h2>
        <button @click="screenshotAdding = true" class="btn-primary-sm">+ 添加截图</button>
      </div>
      <Msg :msg="screenshotMsg" />
      <div v-if="screenshotsLoading" class="empty-row">加载中...</div>
      <div v-else-if="!screenshots.length" class="empty-row">暂无截图</div>
      <div v-else class="shots-grid">
        <div v-for="s in screenshots" :key="s.id" class="shot-card">
          <img :src="s.url" :alt="s.title" />
          <input v-model="s.title" placeholder="标题" class="form-input" @change="saveShotMeta(s)" />
          <div class="shot-actions">
            <button class="btn-grey" :disabled="screenshots[0]?.id === s.id" @click="moveShot(s, -1)">上移</button>
            <button class="btn-grey" :disabled="screenshots[screenshots.length - 1]?.id === s.id" @click="moveShot(s, 1)">下移</button>
            <button class="act-btn danger" @click="removeShot(s)">删除</button>
          </div>
        </div>
      </div>
      <Modal v-if="screenshotAdding" title="添加截图" @close="screenshotAdding = false">
        <FormField label="图片 URL" required><input v-model="newShot.url" class="form-input" /></FormField>
        <FormField label="标题"><input v-model="newShot.title" class="form-input" /></FormField>
        <div class="modal-actions">
          <button class="btn-grey" @click="screenshotAdding = false">取消</button>
          <button class="btn-primary-sm" @click="addShot">添加</button>
        </div>
      </Modal>
    </div>

    <!-- ============ TAB 4 (docs): 文档管理 ============ -->
    <div v-show="activeTab === 'docs'">
      <!-- CALLOUT 编辑说明 -->
      <div class="card docs-callout">
        <div class="docs-callout-head">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#165dff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
          <strong>文档管理</strong>
          <button class="btn-primary-sm" @click="newDoc()" style="margin-left:auto">+ 新建文档</button>
        </div>
        <ul class="docs-callout-list">
          <li>文档保存在 SQLite 数据库中，不再依赖服务器文件系统。</li>
          <li>直接在此页面新建、编辑、删除文档；保存后官网 <code>/api-docs</code> 页面即时生效。</li>
          <li>支持完整 Markdown（GFM），包括表格、代码块、列表、锚点链接。</li>
        </ul>
      </div>

      <!-- 主工作区 -->
      <div class="card docs-workspace">
        <div class="docs-list-panel">
          <div class="panel-head">
            <h3>文档列表</h3>
            <button class="btn-grey" @click="loadDocsList()" :disabled="docsListLoading">刷新</button>
          </div>
          <div v-if="docsListLoading" class="empty-row">加载中...</div>
          <div v-else-if="!docsList.length" class="empty-row">暂无文档，点击上方「+ 新建文档」开始</div>
          <ul v-else class="docs-list">
            <li
              v-for="d in docsList"
              :key="d.slug"
              :class="['docs-item', { active: currentDocSlug === d.slug }]"
              @click="loadDocContent(d.slug)"
            >
              <div class="item-title">{{ d.title }}</div>
              <div class="item-meta">
                <span class="item-cat">{{ d.categoryLabel }}</span>
                <span class="item-size">{{ fmtSize(d.size) }}</span>
              </div>
              <div class="item-bottom">
                <span class="item-file">/{{ d.slug }}</span>
                <span class="item-size">{{ d.mtime ? new Date(d.mtime).toLocaleString('zh-CN', { year:'numeric', month:'2-digit', day:'2-digit' }).replace(/\//g,'-') : '' }}</span>
              </div>
            </li>
          </ul>
        </div>

        <div class="docs-edit-panel">
          <!-- 元数据条 -->
          <div v-if="currentDocSlug" class="doc-meta-bar">
            <div class="meta-row">
              <label>标题</label>
              <input v-model="docTitle" class="doc-input" placeholder="文档标题" @input="onTitleInput" />
            </div>
            <div class="meta-row">
              <label>Slug</label>
              <input v-model="docSlugInput" class="doc-input" placeholder="自动根据标题生成" @input="titleSlugUserEdited = true" />
            </div>
            <div class="meta-row">
              <label>分类</label>
              <select v-model="docCategory" class="doc-input">
                <option value="arch">架构与设计</option>
                <option value="api">APP API 文档</option>
                <option value="recharge">充值提现</option>
                <option value="deploy">部署运维</option>
                <option value="custom">定制开发</option>
                <option value="other">其他</option>
              </select>
            </div>
            <div class="meta-row">
              <label>排序</label>
              <input v-model.number="docOrder" type="number" class="doc-input" placeholder="数字越小越靠前" />
            </div>
          </div>

          <!-- 编辑器工具栏 -->
          <div v-if="currentDocSlug" class="doc-toolbar">
            <div class="doc-toolbar-left">
              <button class="tb-btn" title="粗体 Ctrl+B" @click="wrapSel('**','**')"><b>B</b></button>
              <button class="tb-btn" title="斜体 Ctrl+I" @click="wrapSel('*','*')"><i>I</i></button>
              <button class="tb-btn" title="删除线" @click="wrapSel('~~','~~')"><s>S</s></button>
              <span class="tb-sep"></span>
              <button class="tb-btn" title="H1" @click="prefixLine('# ')">H1</button>
              <button class="tb-btn" title="H2" @click="prefixLine('## ')">H2</button>
              <button class="tb-btn" title="H3" @click="prefixLine('### ')">H3</button>
              <span class="tb-sep"></span>
              <button class="tb-btn" title="无序列表" @click="prefixLine('- ')"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><circle cx="4" cy="6" r="1"/><circle cx="4" cy="12" r="1"/><circle cx="4" cy="18" r="1"/></svg></button>
              <button class="tb-btn" title="有序列表" @click="prefixLine('1. ')"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="10" y1="6" x2="21" y2="6"/><line x1="10" y1="12" x2="21" y2="12"/><line x1="10" y1="18" x2="21" y2="18"/><text x="2" y="9" font-size="7" fill="currentColor" stroke="none">1</text><text x="2" y="15" font-size="7" fill="currentColor" stroke="none">2</text><text x="2" y="21" font-size="7" fill="currentColor" stroke="none">3</text></svg></button>
              <button class="tb-btn" title="引用" @click="prefixLine('> ')">"</button>
              <span class="tb-sep"></span>
              <button class="tb-btn" title="链接" @click="insertMarkdown('[链接文字](url)')"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg></button>
              <button class="tb-btn" title="图片" @click="insertMarkdown('![图片](url)')"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg></button>
              <button class="tb-btn" title="行内代码" @click="wrapSel('`','`')"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg></button>
              <button class="tb-btn" title="代码块" @click="wrapSel('\n```\n','\n```\n')"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M9 8l-3 4 3 4M15 8l3 4-3 4"/></svg></button>
              <button class="tb-btn" title="表格" @click="insertMarkdown('\n| 列1 | 列2 | 列3 |\n| --- | --- | --- |\n| A   | B   | C   |\n')"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="1"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="3" y1="15" x2="21" y2="15"/><line x1="9" y1="3" x2="9" y2="21"/><line x1="15" y1="3" x2="15" y2="21"/></svg></button>
              <span class="tb-sep"></span>
              <button class="tb-btn" title="分隔线" @click="insertAtCursor('\n\n---\n\n')">—</button>
            </div>
            <div class="doc-toolbar-right">
              <span class="tb-status">{{ docContent.length }} 字</span>
              <button class="tb-btn" :class="{ active: showPreview }" @click="showPreview = !showPreview" title="预览">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
                {{ showPreview ? '隐藏预览' : '预览' }}
              </button>
            </div>
          </div>

          <!-- 顶栏（标题 + 保存/删除） -->
          <div class="panel-head">
            <div class="edit-info">
              <span v-if="currentDocSlug" class="current-filename">
                编辑中：<strong>{{ docTitle || currentDocSlug }}</strong>
              </span>
              <span v-else class="current-filename placeholder">请在左侧选择一个文档，或点击「+ 新建文档」</span>
            </div>
            <div class="edit-actions">
              <button
                v-if="currentDocSlug"
                class="btn-danger-sm"
                @click="deleteDoc"
                :disabled="docSaving"
              >删除</button>
              <button
                class="btn-primary-sm"
                :disabled="!currentDocSlug || docSaving || !docDirty"
                @click="saveDoc()"
              >
                {{ docSaving ? '保存中...' : '保存' }}
              </button>
            </div>
          </div>

          <div v-if="saveDocToast" :class="['docs-toast', saveDocToast.ok ? 'ok' : 'err']" style="margin: 12px 0">
            {{ saveDocToast.text }}
          </div>

          <!-- 编辑区（分屏：左编辑 + 右预览） -->
          <div v-if="currentDocSlug" class="doc-edit-body" :class="{ 'doc-split': showPreview }">
            <div class="doc-editor-pane">
              <textarea
                ref="docTextareaEl"
                class="doc-textarea"
                v-model="docContent"
                :disabled="!currentDocSlug"
                placeholder="在此编辑 Markdown 源码..."
                spellcheck="false"
                @scroll="syncPreviewScroll"
              />
            </div>
            <div v-if="showPreview" class="doc-preview-pane">
              <div class="doc-preview-head">预览</div>
              <div class="doc-preview-body markdown-body" v-html="renderedPreview"></div>
            </div>
          </div>
          <div v-else class="doc-empty-hint">
            <div class="doc-empty-icon">
              <svg width="56" height="56" viewBox="0 0 24 24" fill="none" stroke="#c9cdd4" stroke-width="1.2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>
            </div>
            <p>请在左侧选择一个文档开始编辑</p>
            <p class="hint-sub">或点击右上角「+ 新建文档」创建新文档</p>
          </div>
        </div>
      </div>
    </div>

    <!-- ============ TAB 5: 联系记录 ============ -->
    <div v-show="activeTab === 'contacts'" class="card">
      <div class="list-head">
        <h2>联系记录</h2>
        <div>
          <span class="count-flag">未读 {{ contactsUnread }}</span>
          <button class="btn-grey" style="margin-left:8px" @click="markAllContactsRead()">全部标为已读</button>
        </div>
      </div>
      <Msg :msg="contactsMsg" />
      <table class="data-table">
        <thead><tr><th>姓名</th><th>联系方式</th><th>留言</th><th>时间</th><th>状态</th><th>操作</th></tr></thead>
        <tbody>
          <tr v-if="contactsLoading"><td colspan="6" class="empty-row">加载中...</td></tr>
          <tr v-else-if="!contacts.length"><td colspan="6" class="empty-row">暂无联系记录</td></tr>
          <tr v-for="c in contacts" :key="c.id" :class="{ rowNew: !c.is_read }">
            <td>{{ c.name }}</td>
            <td class="td-contact">{{ c.contact }}</td>
            <td class="td-title">{{ c.message || '-' }}</td>
            <td>{{ fmt(c.createdAt) }}</td>
            <td><span :class="['tag', c.is_read ? 'tag-grey' : 'tag-blue']">{{ c.is_read ? '已读' : '未读' }}</span></td>
            <td class="td-actions">
              <button @click="readContact(c)" class="act-btn">{{ c.is_read ? '详情' : '查看' }}</button>
              <button @click="removeContact(c)" class="act-btn danger">删除</button>
            </td>
          </tr>
        </tbody>
      </table>
      <Pagination v-if="contactsTotalPages > 1" v-model:page="contactsPage" :total="contactsTotal" :pageSize="contactsPageSize" @change="loadContacts()" />

      <Modal v-if="contactDetail" title="联系记录详情" @close="contactDetail = null">
        <div class="detail-row"><span class="label">姓名：</span>{{ contactDetail.name }}</div>
        <div class="detail-row"><span class="label">联系方式：</span>{{ contactDetail.contact }}</div>
        <div class="detail-row"><span class="label">时间：</span>{{ fmt(contactDetail.createdAt) }}</div>
        <div class="detail-row"><span class="label">留言：</span></div>
        <div class="detail-msg">{{ contactDetail.message || '(空)' }}</div>
      </Modal>
    </div>

    <!-- ============ TAB 5: 账号管理 ============ -->
    <div v-show="activeTab === 'users'" class="card">
      <div class="list-head">
        <h2>账号管理</h2>
        <button v-if="me?.role === 'admin'" @click="openUserModal('add')" class="btn-primary-sm">+ 新增管理员</button>
      </div>
      <template v-if="me?.role !== 'admin'">
        <div class="permission-denied">
          <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#f53f3f" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
          <div>权限不足：仅管理员角色可查看和管理账号列表</div>
        </div>
      </template>
      <template v-else>
        <Msg :msg="usersMsg" />
        <table class="data-table">
          <thead><tr><th>账号</th><th>昵称</th><th>角色</th><th>状态</th><th>最后登录IP</th><th>最后登录时间</th><th>操作</th></tr></thead>
          <tbody>
            <tr v-if="usersLoading"><td colspan="7" class="empty-row">加载中...</td></tr>
            <tr v-else-if="!users.length"><td colspan="7" class="empty-row">暂无账号</td></tr>
            <tr v-for="u in users" :key="u.id">
              <td>{{ u.username }}</td>
              <td>{{ u.nickname || '-' }}</td>
              <td><span :class="['tag', u.role === 'admin' ? 'tag-blue' : 'tag-green']">{{ u.role === 'admin' ? '管理员' : '编辑' }}</span></td>
              <td>
                <label class="switch-row">
                  <input type="checkbox" :checked="u.status === 1" @change="toggleUserStatus(u)" />
                  <span>{{ u.status === 1 ? '启用' : '禁用' }}</span>
                </label>
              </td>
              <td>{{ u.lastLoginIp || '-' }}</td>
              <td>{{ fmt(u.lastLoginAt) }}</td>
              <td class="td-actions">
                <button @click="openUserModal('edit', u)" class="act-btn">编辑</button>
                <button @click="openResetPwd(u)" class="act-btn">重置密码</button>
                <button v-if="u.id !== me?.id" @click="removeUser(u)" class="act-btn danger">删除</button>
              </td>
            </tr>
          </tbody>
        </table>

        <Modal v-if="userModal" :title="userModal.mode === 'add' ? '新增管理员' : '编辑管理员'" @close="userModal = null">
          <FormField label="账号" required :hint="userModal.mode === 'edit' ? '创建后不可修改' : '3-20 位字母/数字/下划线'">
            <input v-model="userModal.form.username" :disabled="userModal.mode === 'edit'" class="form-input" />
          </FormField>
          <FormField v-if="userModal.mode === 'add'" label="密码" required hint="至少 6 位">
            <input v-model="userModal.form.password" type="password" class="form-input" />
          </FormField>
          <FormField label="昵称"><input v-model="userModal.form.nickname" class="form-input" /></FormField>
          <FormField label="角色">
            <select v-model="userModal.form.role" class="form-input">
              <option value="admin">管理员 (admin)</option>
              <option value="editor">编辑 (editor)</option>
            </select>
          </FormField>
          <FormField label="状态">
            <select v-model="userModal.form.status" class="form-input">
              <option :value="1">启用</option>
              <option :value="0">禁用</option>
            </select>
          </FormField>
          <FormField v-if="userModal.mode === 'edit'" label="设置新密码（可选）" hint="留空表示不修改">
            <input v-model="userModal.form.newPassword" type="password" class="form-input" />
          </FormField>
          <div v-if="userModal.error" class="banner banner-error">{{ userModal.error }}</div>
          <div class="modal-actions">
            <button class="btn-grey" @click="userModal = null">取消</button>
            <button class="btn-primary-sm" :disabled="userModal.saving" @click="submitUser">
              {{ userModal.saving ? '提交中...' : (userModal.mode === 'add' ? '新增' : '保存') }}
            </button>
          </div>
        </Modal>

        <Modal v-if="resetPwdModal" title="重置密码" @close="resetPwdModal = null">
          <div class="modal-hint">将为用户 <strong>{{ resetPwdModal.username }}</strong> 设置新密码</div>
          <FormField label="新密码" required hint="至少 6 位"><input v-model="resetPwdModal.newPassword" type="password" class="form-input" /></FormField>
          <div v-if="resetPwdModal.error" class="banner banner-error">{{ resetPwdModal.error }}</div>
          <div class="modal-actions">
            <button class="btn-grey" @click="resetPwdModal = null">取消</button>
            <button class="btn-primary-sm" :disabled="resetPwdModal.saving" @click="submitResetPwd">{{ resetPwdModal.saving ? '提交中...' : '确认重置' }}</button>
          </div>
        </Modal>
      </template>
    </div>

    <!-- ============ TAB 6: AI 管理 ============ -->
    <div v-show="activeTab === 'ai'">
      <!-- A. 提供商配置 -->
      <div class="card">
        <div class="list-head"><h2>A. AI 提供商配置</h2></div>
        <Msg :msg="aiCfgMsg" />
        <div class="form-grid">
          <div class="form-main">
            <div class="row-2">
              <FormField label="服务商">
                <select v-model="aiCfg.provider" class="form-input">
                  <option value="deepseek">DeepSeek</option>
                  <option value="openai">OpenAI / 兼容协议</option>
                  <option value="custom">自定义</option>
                </select>
              </FormField>
              <FormField label="模型名"><input v-model="aiCfg.model" class="form-input" placeholder="deepseek-chat / gpt-4o-mini" /></FormField>
            </div>
            <FormField label="API Base"><input v-model="aiCfg.api_base" class="form-input" placeholder="https://api.deepseek.com" /></FormField>
            <FormField label="API Key" hint="为了安全，保存后只显示首尾，修改请直接填写完整新值；保持原 Key 请用 *** 开头">
              <input v-model="aiCfg.api_key" type="text" class="form-input" placeholder="sk-..." />
            </FormField>
            <div class="row-2">
              <FormField :label="`温度 Temperature (${aiCfg.temperature})`">
                <div class="range-row">
                  <input type="range" min="0" max="2" step="0.1" v-model.number="aiCfg.temperature" class="range-input" />
                  <input type="number" min="0" max="2" step="0.1" v-model.number="aiCfg.temperature" class="num-input" />
                </div>
              </FormField>
              <FormField label="最大输出 tokens">
                <input type="number" min="256" step="1" v-model.number="aiCfg.max_tokens" class="form-input" />
              </FormField>
            </div>
            <FormField label="系统人设 Prompt (system_prompt)">
              <textarea v-model="aiCfg.system_prompt" rows="6" class="form-input" placeholder="你是 ChatPulse 专栏作者..." />
            </FormField>
            <FormField label="生成话题倾向词（逗号分隔，default_topic_hint）">
              <textarea v-model="aiCfg.default_topic_hint" rows="2" class="form-input" placeholder="企业IM、私有化部署、AI 赋能沟通..." />
            </FormField>
          </div>
          <div class="form-side">
            <FormField label="默认分类">
              <select v-model="aiCfg.default_category_id" class="form-input">
                <option :value="null">（不设置）</option>
                <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
              </select>
            </FormField>
            <FormField label="默认标签（逗号或 JSON 数组）">
              <textarea v-model="aiCfg.default_tags_text" rows="2" class="form-input" placeholder='如：行业观察,数字化转型 或 ["行业观察"]' />
            </FormField>
            <FormField label="默认发布状态">
              <select v-model="aiCfg.default_status" class="form-input">
                <option :value="0">草稿</option>
                <option :value="1">已发布</option>
              </select>
            </FormField>
            <FormField label="启用开关">
              <label class="switch-row"><input type="checkbox" v-model="aiCfg.enabled_bool" /><span>{{ aiCfg.enabled_bool ? '已启用' : '已关闭' }}</span></label>
            </FormField>
            <div class="side-actions">
              <button class="btn-primary-sm" :disabled="aiCfgSaving" @click="saveAiConfig">{{ aiCfgSaving ? '保存中...' : '保存配置' }}</button>
              <button class="btn-grey" :disabled="aiCfgSaving || testingConn" @click="testAiConnection">{{ testingConn ? '测试中...' : '测试连接（生成 2 句产品介绍）' }}</button>
            </div>
          </div>
        </div>
        <Modal v-if="testResultModal" title="AI 连接测试结果" @close="testResultModal = null">
          <div v-if="testingConn" class="empty-row">生成中，请稍候...</div>
          <div v-else-if="testResultModal.error" class="banner banner-error">{{ testResultModal.error }}</div>
          <div v-else>
            <div class="detail-row"><span class="label">生成文章 ID：</span>{{ testResultModal.id }}</div>
            <div class="detail-row"><span class="label">标题：</span>{{ testResultModal.title }}</div>
            <div class="detail-row"><span class="label">slug：</span><code>{{ testResultModal.slug }}</code></div>
            <div class="detail-hint">已写入 articles 表，可在文章管理中查看。</div>
          </div>
        </Modal>
      </div>

      <!-- B. 定时任务设置 -->
      <div class="card" style="margin-top:20px">
        <div class="list-head"><h2>B. 定时发布任务设置</h2></div>
        <Msg :msg="jobCfgMsg" />
        <div class="form-grid">
          <div class="form-main">
            <FormField label="启用定时任务">
              <label class="switch-row"><input type="checkbox" v-model="jobCfg.enabled_bool" /><span>{{ jobCfg.enabled_bool ? '已启用' : '已关闭' }}</span></label>
            </FormField>
            <FormField label="Cron 表达式" hint='5 字段格式：分 时 日 月 周（例：0 9 * * * 表示每天 09:00）'>
              <input v-model="jobCfg.cron_expr" class="form-input" />
            </FormField>
            <div class="preset-row">
              <button v-for="p in cronPresets" :key="p.label" class="preset-btn" @click="jobCfg.cron_expr = p.expr">{{ p.label }}</button>
            </div>
            <div class="row-2">
              <FormField label="每次生成文章数量">
                <input type="number" min="1" max="50" v-model.number="jobCfg.max_articles_per_run" class="form-input" />
              </FormField>
              <FormField label="自动发布（否则为草稿）">
                <label class="switch-row"><input type="checkbox" v-model="jobCfg.auto_publish_bool" /><span>{{ jobCfg.auto_publish_bool ? '已启用' : '草稿' }}</span></label>
              </FormField>
            </div>
          </div>
          <div class="form-side">
            <div class="info-box">
              <div class="info-row"><span>上次运行时间：</span>{{ jobCfg.last_run_at ? fmt(jobCfg.last_run_at) : '（无）' }}</div>
              <div class="info-row"><span>预计下次运行：</span>{{ jobCfg.nextRunAt ? fmt(jobCfg.nextRunAt) : '（未启用/无效表达式）' }}</div>
            </div>
            <button class="btn-primary-sm" :disabled="jobCfgSaving" @click="saveJobConfig">{{ jobCfgSaving ? '保存中...' : '保存任务设置' }}</button>
          </div>
        </div>
      </div>

      <!-- C. 立即生成 -->
      <div class="card" style="margin-top:20px">
        <div class="list-head"><h2>C. 立即生成文章</h2></div>
        <Msg :msg="manualMsg" />
        <div class="form-grid">
          <div class="form-main">
            <div class="row-2">
              <FormField label="生成篇数">
                <input type="number" min="1" max="50" v-model.number="manualCount" class="form-input" />
              </FormField>
              <div><label class="label">&nbsp;</label>
                <button class="btn-primary-sm" :disabled="manualRunning" @click="triggerManual">{{ manualRunning ? '任务已发起，等待完成...' : '立即生成' }}</button>
              </div>
            </div>
            <FormField label="自定义话题（可选，留空走默认倾向）">
              <textarea v-model="manualCustomTopic" rows="2" class="form-input" placeholder="例：2026 年企业 IM 的 5 大趋势" />
            </FormField>
          </div>
          <div class="form-side">
            <div class="info-box">
              <div class="info-row"><span>当前触发 Run ID：</span>{{ latestRunId || '（无）' }}</div>
              <div class="info-row"><span>状态：</span>
                <span :class="['tag', latestRunStatusTag()]">{{ latestRunStatusText() }}</span>
              </div>
              <div class="info-row"><span>生成文章数：</span>{{ latestRun?.articles_count ?? 0 }}</div>
              <div v-if="latestRun?.error_message" class="err-line">错误：{{ latestRun.error_message }}</div>
            </div>
          </div>
        </div>
      </div>

      <!-- D. 运行日志 -->
      <div class="card" style="margin-top:20px">
        <div class="list-head"><h2>D. 运行日志</h2><button class="btn-grey" @click="loadRuns()">刷新</button></div>
        <table class="data-table">
          <thead><tr><th>ID</th><th>触发方式</th><th>开始时间</th><th>完成时间</th><th>状态</th><th>生成数</th><th>错误信息</th></tr></thead>
          <tbody>
            <tr v-if="runsLoading"><td colspan="7" class="empty-row">加载中...</td></tr>
            <tr v-else-if="!runs.length"><td colspan="7" class="empty-row">暂无运行记录</td></tr>
            <tr v-for="r in runs" :key="r.id">
              <td>#{{ r.id }}</td>
              <td><span :class="['tag', r.trigger_type === 'cron' ? 'tag-blue' : 'tag-green']">{{ r.trigger_type === 'cron' ? 'cron' : 'manual' }}</span></td>
              <td>{{ fmt(r.started_at) }}</td>
              <td>{{ r.finished_at ? fmt(r.finished_at) : '-' }}</td>
              <td>
                <span :class="['tag', r.status === 0 ? 'tag-grey' : (r.status === 1 ? 'tag-green' : 'tag-red')]">
                  {{ r.status === 0 ? '运行中' : (r.status === 1 ? '成功' : '失败') }}
                </span>
              </td>
              <td>{{ r.articles_count }}</td>
              <td>
                <span v-if="!r.error_message">-</span>
                <span v-else class="err-toggle" @click="showRunError(r)">{{ r.error_message.slice(0, 40) }}{{ r.error_message.length > 40 ? '...' : '' }} <small>[展开]</small></span>
              </td>
            </tr>
          </tbody>
        </table>
        <Pagination v-if="runsTotalPages > 1" v-model:page="runsPage" :total="runsTotal" :pageSize="runsPageSize" @change="loadRuns()" />

        <Modal v-if="runErrorModal" title="错误详情" @close="runErrorModal = null">
          <pre class="err-pre">{{ runErrorModal }}</pre>
        </Modal>
      </div>
    </div>

    <!-- ============ TAB 7: 修改密码 ============ -->
    <div v-show="activeTab === 'change-password'" class="card change-pwd-card">
      <div class="list-head"><h2>修改密码</h2></div>
      <Msg :msg="changePwdMsg" />
      <div class="pwd-form">
        <FormField label="当前密码" required><input v-model="changePwd.old" type="password" class="form-input" /></FormField>
        <FormField label="新密码" required hint="至少 6 位"><input v-model="changePwd.new" type="password" class="form-input" /></FormField>
        <FormField label="确认新密码" required hint="需与新密码相同"><input v-model="changePwd.confirm" type="password" class="form-input" /></FormField>
        <div class="side-actions">
          <button class="btn-primary-sm" :disabled="changePwd.saving" @click="submitChangePwd">{{ changePwd.saving ? '提交中...' : '修改密码' }}</button>
        </div>
      </div>
    </div>

  </AdminLayout>
</template>

<script setup lang="ts">
import { pinyin } from 'pinyin-pro'
import { marked } from 'marked'
import AdminLayout from '../../layouts/admin.vue'
import Pagination from '../../components/admin/Pagination.vue'
import Modal from '../../components/admin/Modal.vue'
import Msg from '../../components/admin/Msg.vue'
import FormField from '../../components/admin/FormField.vue'

definePageMeta({ layout: false })
useHead({ title: '后台管理 - ChatPulse' })

type TabName = 'articles' | 'settings' | 'screenshots' | 'docs' | 'contacts' | 'users' | 'ai' | 'change-password'
const route = useRoute()
const router = useRouter()

function readTab(): TabName {
  const fromHash = (route.hash || '').replace(/^#/, '')
  const fromQuery = route.query.tab as string
  const src = fromHash || fromQuery
  const allowed: TabName[] = ['articles', 'settings', 'screenshots', 'docs', 'contacts', 'users', 'ai', 'change-password']
  if (allowed.includes(src as TabName)) return src as TabName
  return 'articles'
}
const activeTab = ref<TabName>(readTab())
watch([() => route.hash, () => route.query], () => { activeTab.value = readTab() })

function switchTab(t: string) {
  const tab = t as TabName
  activeTab.value = tab
  const target = router.resolve({ path: '/admin', hash: `#${tab}`, query: {} })
  if (target.href !== (route.fullPath || '')) {
    router.replace(target).catch(() => {
      if (typeof window !== 'undefined') window.location.hash = `#${tab}`
    })
  }
}

// =============== 公共 ===============
interface Me { id: number; username: string; nickname: string; role: string; status: number; lastLoginAt?: string; lastLoginIp?: string }
const me = ref<Me | null>(null)
async function loadMe() {
  try {
    const res = await $fetch<any>('/api/admin/me')
    if (res.code === 0) me.value = res.data
    else throw new Error(res.message || '')
  } catch { await navigateTo('/admin/login') }
}
function fmt(s: string) {
  if (!s) return ''
  const d = new Date(s)
  if (isNaN(d.getTime())) return s
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}

// =============== TAB 1 文章 ===============
const articles = ref<any[]>([])
const articlesLoading = ref(false)
const articlesPage = ref(1)
const articlesPageSize = 20
const articlesTotal = ref(0)
const articlesTotalPages = computed(() => Math.max(1, Math.ceil(articlesTotal.value / articlesPageSize)))
const filterTitle = ref('')
const filterCategory = ref('')
const categories = ref<any[]>([])
const editing = ref(false)
const articleSaving = ref(false)
const articleForm = ref<any>({ id: '', slug: '', title: '', summary: '', content: '', coverImage: '', category: '行业资讯', published: false })
const articleTagsText = ref('')
const articleMsg = ref<{ok:boolean;text:string}|null>(null)

async function loadCategories() { try { const r = await $fetch<any>('/api/categories'); if (r.code===0) categories.value = r.data || [] } catch {} }
async function loadArticles() {
  articlesLoading.value = true
  try {
    const r = await $fetch<any>('/api/admin/articles', { params: { page: articlesPage.value, pageSize: articlesPageSize, category: filterCategory.value || undefined } })
    if (r.code === 0) {
      let list = r.data.list || []
      if (filterTitle.value) list = list.filter((a:any) => (a.title||'').toLowerCase().includes(filterTitle.value.toLowerCase()))
      articles.value = list; articlesTotal.value = r.data.total
    }
  } catch {}
  articlesLoading.value = false
}
function startNew() { editing.value = true; articleMsg.value = null; articleForm.value = { id:'', slug:'', title:'', summary:'', content:'', coverImage:'', category: (categories.value[0]?.name || '行业资讯'), published:false }; articleTagsText.value='' }
function startEdit(a: any) { editing.value = true; articleMsg.value = null; articleForm.value = { ...a }; articleTagsText.value = (a.tags||[]).join(', ') }
function autoSlug() {
  if (!articleForm.value.id) articleForm.value.slug = (articleForm.value.title||'').toLowerCase().replace(/[^a-z0-9\u4e00-\u9fa5]+/g,'-').replace(/^-+|-+$/g,'').slice(0,80)
}
async function saveArticle(publish: boolean) {
  articleMsg.value = null
  if (!articleForm.value.title?.trim() || !articleForm.value.content?.trim()) { articleMsg.value = {ok:false, text:'请填写标题和正文'}; return }
  articleSaving.value = true
  const payload = { ...articleForm.value, tags: articleTagsText.value.split(/[,，]/).map((t:string)=>t.trim()).filter(Boolean), published: publish }
  try {
    const r: any = articleForm.value.id
      ? await $fetch(`/api/admin/articles/${articleForm.value.id}`, { method: 'PUT', body: payload })
      : await $fetch('/api/admin/articles', { method: 'POST', body: payload })
    if (r.code === 0) {
      if (!articleForm.value.id) articleForm.value.id = r.data.id
      articleMsg.value = { ok: true, text: '保存成功' }
      await loadArticles(); await loadCategories()
    } else articleMsg.value = { ok:false, text: r.message || '保存失败' }
  } catch (e: any) { articleMsg.value = { ok:false, text: e.data?.message || e.message || '保存失败' } }
  finally { articleSaving.value = false }
}
async function confirmDelete(a: any) { if (!confirm(`确认删除「${a.title||'无标题'}」？此操作不可恢复。`)) return; try { await $fetch(`/api/admin/articles/${a.id}`, { method: 'DELETE' }); await loadArticles(); await loadCategories() } catch (e:any) { alert('删除失败：' + (e.data?.message||'')) } }
async function togglePublish(a: any) { try { await $fetch(`/api/admin/articles/${a.id}`, { method:'PUT', body:{ published: !a.published } }); await loadArticles() } catch (e:any) { alert('操作失败：'+(e.data?.message||'')) } }

// =============== TAB 2 基本设置 ===============
const siteCfg = ref<any>({})
const siteCfgSaving = ref(false)
const settingsMsg = ref<{ok:boolean;text:string}|null>(null)
// 定价表单（与基本设置共用同一个 PUT API，一并提交）
const pricingCfg = ref<any>({
  pricePeriod: '终身授权',
  priceStandardUsdt: 699,
  priceStandardNote: '',
  priceProfessionalUsdt: 1399,
  priceProfessionalNote: '',
  priceEnterpriseText: '面议',
  priceEnterpriseNote: '',
})
async function loadSiteConfig() {
  try {
    const r = await $fetch<any>('/api/site-config')
    if (r.code === 0) {
      siteCfg.value = { ...r.data }
      const p = r.data.pricing || {}
      pricingCfg.value = {
        pricePeriod: p.period || '终身授权',
        priceStandardUsdt: Number(p.standard?.usdt ?? 699),
        priceStandardNote: p.standard?.note || '',
        priceProfessionalUsdt: Number(p.professional?.usdt ?? 1399),
        priceProfessionalNote: p.professional?.note || '',
        priceEnterpriseText: p.enterprise?.text || '面议',
        priceEnterpriseNote: p.enterprise?.note || '',
      }
      // 补齐基础字段：确保 PUT API 中的其他联系方式也被包含（DB 有列但 GET/PUT 之前可能漏了）
      const sc = siteCfg.value
      if (!('contact_wechat' in sc) && !('contactWechat' in sc)) sc.contactWechat = sc.contact_wechat || ''
      if (!('contact_qq' in sc) && !('contactQq' in sc)) sc.contactQq = sc.contact_qq || ''
      if (!('contact_phone' in sc) && !('contactPhone' in sc)) sc.contactPhone = sc.contact_phone || ''
      if (!('contact_email' in sc) && !('contactEmail' in sc)) sc.contactEmail = sc.contact_email || ''
      if (!('android_download_url' in sc) && !('androidDownloadUrl' in sc)) sc.androidDownloadUrl = sc.android_download_url || ''
      if (!('admin_panel_url' in sc) && !('adminPanelUrl' in sc)) sc.adminPanelUrl = sc.admin_panel_url || ''
      if (!('pc_client_url' in sc) && !('pcClientUrl' in sc)) sc.pcClientUrl = sc.pc_client_url || ''
    }
  } catch {}
}
async function saveSiteConfig() {
  siteCfgSaving.value = true; settingsMsg.value = null
  // 合并基础字段 + 定价字段，一次性提交
  const body = {
    ...siteCfg.value,
    ...pricingCfg.value,
    // 联系方式字段（从 snake_case / camelCase 兼容）：
    contactWechat: siteCfg.value.contactWechat ?? siteCfg.value.contact_wechat ?? '',
    contactQq: siteCfg.value.contactQq ?? siteCfg.value.contact_qq ?? '',
    contactPhone: siteCfg.value.contactPhone ?? siteCfg.value.contact_phone ?? '',
    contactEmail: siteCfg.value.contactEmail ?? siteCfg.value.contact_email ?? '',
    androidDownloadUrl: siteCfg.value.androidDownloadUrl ?? siteCfg.value.android_download_url ?? '',
    adminPanelUrl: siteCfg.value.adminPanelUrl ?? siteCfg.value.admin_panel_url ?? '',
    pcClientUrl: siteCfg.value.pcClientUrl ?? siteCfg.value.pc_client_url ?? '',
  }
  try {
    const r = await $fetch<any>('/api/admin/site-config', { method: 'PUT', body })
    if (r.code === 0) {
      settingsMsg.value = { ok: true, text: '保存成功' }
      // 回填返回的最新 pricing
      Object.assign(siteCfg.value, r.data)
      const pu = r.data.pricing
      if (pu) {
        pricingCfg.value.pricePeriod = pu.period || pricingCfg.value.pricePeriod
        pricingCfg.value.priceStandardUsdt = Number(pu.standard?.usdt ?? 0)
        pricingCfg.value.priceStandardNote = pu.standard?.note || ''
        pricingCfg.value.priceProfessionalUsdt = Number(pu.professional?.usdt ?? 0)
        pricingCfg.value.priceProfessionalNote = pu.professional?.note || ''
        pricingCfg.value.priceEnterpriseText = pu.enterprise?.text || '面议'
        pricingCfg.value.priceEnterpriseNote = pu.enterprise?.note || ''
      }
    } else {
      settingsMsg.value = { ok: false, text: r.message || '保存失败' }
    }
  } catch (e: any) {
    settingsMsg.value = { ok: false, text: e.data?.message || e.message || '保存失败' }
  } finally {
    siteCfgSaving.value = false
  }
}

// =============== TAB 3 截图 ===============
const screenshots = ref<any[]>([])
const screenshotsLoading = ref(false)
const screenshotMsg = ref<{ok:boolean;text:string}|null>(null)
const screenshotAdding = ref(false)
const newShot = ref({ url: '', title: '' })
/**
 * 统一后端字段名：
 *   /api/admin/screenshots GET 返回 []{ id, url, title, order }
 *   内部 move/save 需要 sort_order，加载时同步一份；存库时两者都发一份兼容旧/新接口。
 */
async function loadScreenshots() {
  screenshotsLoading.value = true
  try {
    const r = await $fetch<any>('/api/admin/screenshots')
    if (r.code === 0) {
      const list: any[] = Array.isArray(r.data) ? r.data : (r.data?.list || [])
      screenshots.value = list.map(s => ({
        ...s,
        order: s.order ?? s.sort_order ?? 0,
        sort_order: s.sort_order ?? s.order ?? 0,
      })).sort((a, b) => a.sort_order - b.sort_order)
    }
  } catch {}
  screenshotsLoading.value = false
}
async function addShot() {
  screenshotMsg.value = null
  try {
    const r = await $fetch<any>('/api/admin/screenshots', { method: 'POST', body: newShot.value })
    if (r.code === 0) {
      screenshotAdding.value = false
      newShot.value = { url: '', title: '' }
      await loadScreenshots()
      screenshotMsg.value = { ok: true, text: '添加成功' }
    } else {
      screenshotMsg.value = { ok: false, text: r.message || '添加失败' }
    }
  } catch (e: any) {
    screenshotMsg.value = { ok: false, text: e.data?.message || e.message || '添加失败' }
  }
}
async function saveShotMeta(s: any) {
  try {
    await $fetch<any>(`/api/admin/screenshots/${s.id}`, {
      method: 'PUT',
      body: { title: s.title, sort_order: s.sort_order, order: s.sort_order },
    })
  } catch {}
}
async function moveShot(s: any, dir: number) {
  const idx = screenshots.value.findIndex(x => x.id === s.id); if (idx < 0) return
  const target = idx + dir; if (target < 0 || target >= screenshots.value.length) return
  const other = screenshots.value[target]
  const tmp = s.sort_order; s.sort_order = other.sort_order; other.sort_order = tmp
  try {
    await $fetch<any>(`/api/admin/screenshots/${s.id}`, { method: 'PUT', body: { sort_order: s.sort_order, order: s.sort_order } })
    await $fetch<any>(`/api/admin/screenshots/${other.id}`, { method: 'PUT', body: { sort_order: other.sort_order, order: other.sort_order } })
  } catch {}
  screenshots.value = [...screenshots.value].sort((a, b) => a.sort_order - b.sort_order)
}
async function removeShot(s: any) {
  if (!confirm(`确认删除截图「${s.title || s.url}」？`)) return
  try {
    const r = await $fetch<any>(`/api/admin/screenshots/${s.id}`, { method: 'DELETE' })
    if (r.code === 0) { await loadScreenshots(); screenshotMsg.value = { ok: true, text: '已删除' } }
  } catch {}
}

// =============== TAB (docs) 文档管理 ===============
const docsList = ref<any[]>([])
const docsListLoading = ref(false)
const currentDocSlug = ref<string | null>(null)
const currentDocFileName = ref<string>('')
const originalDocContent = ref<string>('')
const docContent = ref<string>('')
const docSaving = ref(false)
const docDirty = computed(() => currentDocSlug.value != null && docContent.value !== originalDocContent.value)
const saveDocToast = ref<null | { ok: boolean; text: string }>(null)

// 文档元数据（SQLite 模式）
const docId = ref(0)
const docTitle = ref('')
const docSlugInput = ref('')
const docCategory = ref('arch')
const docOrder = ref(99)

function fmtSize(bytes: number) {
  if (!bytes) return '0 B'
  if (bytes < 1024) return bytes + ' B'
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB'
  return (bytes / 1024 / 1024).toFixed(2) + ' MB'
}

async function loadDocsList() {
  docsListLoading.value = true
  try {
    const r = await $fetch<any>('/api/admin/docs/list')
    if (r.code === 0) docsList.value = r.data?.list || []
  } catch {}
  docsListLoading.value = false
}

async function loadDocContent(slug: string) {
  saveDocToast.value = null
  try {
    const r = await $fetch<any>('/api/admin/docs/content', { params: { slug } })
    if (r.code === 0) {
      currentDocSlug.value = slug
      docId.value = r.data.id || 0
      docTitle.value = r.data.title || slug
      docSlugInput.value = r.data.slug || slug
      docCategory.value = r.data.category || 'arch'
      docOrder.value = Number(r.data.order ?? 99)
      originalDocContent.value = r.data.content
      docContent.value = r.data.content
    } else {
      alert('读取失败：' + (r.message || ''))
    }
  } catch (e: any) {
    alert('读取失败：' + (e.data?.message || e.message || ''))
  }
}

async function saveDoc() {
  if (!currentDocSlug.value) return
  docSaving.value = true
  saveDocToast.value = null
  try {
    const r = await $fetch<any>('/api/admin/docs/content', {
      method: 'PUT',
      body: {
        id: docId.value,
        slug: docSlugInput.value.trim(),
        title: docTitle.value.trim(),
        category: docCategory.value,
        order: docOrder.value,
        content: docContent.value,
      },
    })
    if (r.code === 0) {
      originalDocContent.value = docContent.value
      // 如果 slug 被规范化改过，同步 UI
      if (r.data?.slug && r.data.slug !== currentDocSlug.value) {
        currentDocSlug.value = r.data.slug
        docSlugInput.value = r.data.slug
      }
      saveDocToast.value = { ok: true, text: r.message || '保存成功，官网即时生效' }
      setTimeout(() => { if (saveDocToast.value?.ok) saveDocToast.value = null }, 4000)
      await loadDocsList()
    } else {
      saveDocToast.value = { ok: false, text: r.message || '保存失败' }
    }
  } catch (e: any) {
    saveDocToast.value = { ok: false, text: e.data?.message || e.message || '保存失败' }
  } finally {
    docSaving.value = false
  }
}

// 文档编辑器 — 预览 / 工具栏 / 拼音 slug 自动生成
const showPreview = ref(false)
const docTextareaEl = ref<HTMLTextAreaElement | null>(null)

marked.setOptions({ breaks: true, gfm: true })
const renderedPreview = computed(() => marked.parse(docContent.value || '') as string)

// 中文标题 → 拼音 slug
function titleToSlug(title: string): string {
  if (!title) return ''
  const py = pinyin(title.trim(), { pattern: 'first', toneType: 'none', nonZh: 'consecutive' })
  return py
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

function onTitleInput() {
  // 新建时（slug 和 title 一起初始化）才自动同步 slug
  // 如果用户手动改过 slug，就不再覆盖
  if (!titleSlugUserEdited.value) {
    docSlugInput.value = titleToSlug(docTitle.value)
  }
}

// 工具栏：操作 textarea
function insertAtCursor(text: string) {
  const el = docTextareaEl.value
  if (!el) { docContent.value += text; return }
  const s = el.selectionStart, e = el.selectionEnd
  const before = docContent.value.slice(0, s)
  const after = docContent.value.slice(e)
  docContent.value = before + text + after
  requestAnimationFrame(() => {
    el.focus()
    el.selectionStart = el.selectionEnd = s + text.length
  })
}
function wrapSel(left: string, right: string) {
  const el = docTextareaEl.value
  if (!el) return
  const s = el.selectionStart, e = el.selectionEnd
  const sel = docContent.value.slice(s, e) || '文本'
  const before = docContent.value.slice(0, s)
  const after = docContent.value.slice(e)
  docContent.value = before + left + sel + right + after
  requestAnimationFrame(() => {
    el.focus()
    el.selectionStart = s + left.length
    el.selectionEnd = s + left.length + sel.length
  })
}
function prefixLine(prefix: string) {
  const el = docTextareaEl.value
  if (!el) return
  const s = el.selectionStart, e = el.selectionEnd
  // 找到当前行的开始
  const before = docContent.value.slice(0, s)
  const after = docContent.value.slice(e)
  const lineStart = before.lastIndexOf('\n') + 1
  const newBefore = docContent.value.slice(0, lineStart) + prefix
  const newSelStart = s + prefix.length
  const newSelEnd = e + prefix.length
  docContent.value = newBefore + docContent.value.slice(lineStart, e) + after
  requestAnimationFrame(() => {
    el.focus()
    el.selectionStart = newSelStart
    el.selectionEnd = newSelEnd
  })
}
function insertMarkdown(template: string) {
  const el = docTextareaEl.value
  if (!el) return
  // 把模板中的 (url) 当成选中位置
  const marker = 'url'
  const idx = template.indexOf(marker)
  if (idx >= 0) {
    const s = el.selectionStart
    const before = docContent.value.slice(0, s)
    const after = docContent.value.slice(el.selectionEnd)
    docContent.value = before + template + after
    requestAnimationFrame(() => {
      el.focus()
      const cursor = s + idx
      el.selectionStart = el.selectionEnd = cursor
    })
  } else {
    insertAtCursor(template)
  }
}
function syncPreviewScroll() { /* 暂不做同步 */ }

// 标题被用户手动改 slug 标记
const titleSlugUserEdited = ref(false)

async function newDoc() {
  // 不弹窗，直接新建一条空文档（标题"未命名文档" + slug auto），选中后进入编辑
  try {
    const defaultTitle = '未命名文档'
    const slug = titleToSlug(defaultTitle) || `doc-${Date.now().toString().slice(-6)}`
    const r = await $fetch<any>('/api/admin/docs/content', {
      method: 'PUT',
      body: { slug, title: defaultTitle, category: 'arch', order: 99, content: '' },
    })
    if (r.code === 0) {
      titleSlugUserEdited.value = false
      await loadDocsList()
      await loadDocContent(r.data.slug)
      saveDocToast.value = { ok: true, text: '已创建新文档，编辑标题后自动生成 slug' }
      setTimeout(() => { if (saveDocToast.value?.ok) saveDocToast.value = null }, 3000)
      // 聚焦标题输入框
      await nextTick()
      // 让 slug 输入框监听后续手动改动
    } else {
      alert('创建失败：' + (r.message || ''))
    }
  } catch (e: any) {
    alert('创建失败：' + (e.data?.message || e.message || ''))
  }
}

async function deleteDoc() {
  if (!currentDocSlug.value) return
  if (!confirm(`确认删除文档「${docTitle.value || currentDocSlug.value}」？\n此操作不可恢复，官网 /api-docs 页面将同步移除。`)) return
  try {
    const r = await $fetch<any>('/api/admin/docs/content', {
      method: 'DELETE',
      params: { slug: currentDocSlug.value },
    })
    if (r.code === 0) {
      saveDocToast.value = { ok: true, text: '删除成功' }
      currentDocSlug.value = null
      docId.value = 0
      docTitle.value = ''
      docSlugInput.value = ''
      docContent.value = ''
      originalDocContent.value = ''
      await loadDocsList()
      setTimeout(() => { saveDocToast.value = null }, 3000)
    } else {
      alert('删除失败：' + (r.message || ''))
    }
  } catch (e: any) {
    alert('删除失败：' + (e.data?.message || e.message || ''))
  }
}

// =============== TAB 5 联系记录 ===============
const contacts = ref<any[]>([])
const contactsLoading = ref(false)
const contactsPage = ref(1)
const contactsPageSize = 20
const contactsTotal = ref(0)
const contactsTotalPages = computed(() => Math.max(1, Math.ceil(contactsTotal.value / contactsPageSize)))
const contactsUnread = computed(() => contacts.value.filter(c => !c.is_read).length)
const contactsMsg = ref<{ok:boolean;text:string}|null>(null)
const contactDetail = ref<any>(null)
async function loadContacts() { contactsLoading.value = true; try { const r = await $fetch<any>('/api/admin/contacts', { params:{ page: contactsPage.value, pageSize: contactsPageSize } }); if (r.code===0) { contacts.value = r.data.list || []; contactsTotal.value = r.data.total } } catch {} contactsLoading.value = false }
async function readContact(c: any) { contactDetail.value = c; if (!c.is_read) { try { await $fetch<any>(`/api/admin/contacts/${c.id}`, { method:'PUT', body:{ is_read: 1 } }); c.is_read = 1 } catch {} } }
async function markAllContactsRead() { try { const r = await $fetch<any>('/api/admin/contacts', { method:'PUT', body:{ markAllRead: 1 } }); if (r.code===0) await loadContacts() } catch {} }
async function removeContact(c: any) { if (!confirm('确认删除该联系记录？')) return; try { const r = await $fetch<any>(`/api/admin/contacts/${c.id}`, { method:'DELETE' }); if (r.code===0) { contacts.value = contacts.value.filter(x => x.id !== c.id) } } catch {} }

// =============== TAB 5 账号管理 ===============
const users = ref<any[]>([])
const usersLoading = ref(false)
const usersMsg = ref<{ok:boolean;text:string}|null>(null)
const userModal = ref<null | { mode: 'add'|'edit'; target?: any; form: any; error?: string; saving: boolean }>(null)
const resetPwdModal = ref<null | { id: number; username: string; newPassword: string; saving: boolean; error?: string }>(null)
async function loadUsers() { usersLoading.value = true; try { const r = await $fetch<any>('/api/admin/users'); if (r.code===0) users.value = r.data || [] } catch {} usersLoading.value = false }
function openUserModal(mode: 'add'|'edit', u?: any) {
  usersMsg.value = null
  userModal.value = {
    mode,
    target: u,
    saving: false,
    form: mode === 'add' ? { username:'', password:'', nickname:'', role:'editor', status:1 } : { username: u.username, nickname: u.nickname || '', role: u.role, status: u.status, newPassword: '' }
  }
}
async function toggleUserStatus(u: any) {
  const next = u.status === 1 ? 0 : 1
  try {
    const r = await $fetch<any>('/api/admin/users', { method:'PUT', body:{ id: u.id, status: next } })
    if (r.code===0) u.status = next
    else throw new Error(r.message||'')
  } catch (e: any) { u.status = u.status /* rollback UI */; alert(e.data?.message || e.message || '修改失败') }
}
async function submitUser() {
  if (!userModal.value) return
  const m = userModal.value; m.saving = true; m.error = ''
  try {
    if (m.mode === 'add') {
      if (!/^[A-Za-z0-9_]{3,20}$/.test(m.form.username)) { m.error = '账号必须为 3-20 位字母/数字/下划线'; return }
      if (!m.form.password || m.form.password.length < 6) { m.error = '密码至少 6 位'; return }
      const r = await $fetch<any>('/api/admin/users', { method:'POST', body: m.form })
      if (r.code !== 0) throw new Error(r.message||'')
    } else {
      const payload = { id: m.target.id, nickname: m.form.nickname, role: m.form.role, status: m.form.status, newPassword: m.form.newPassword || undefined }
      const r = await $fetch<any>('/api/admin/users', { method:'PUT', body: payload })
      if (r.code !== 0) throw new Error(r.message||'')
    }
    userModal.value = null
    usersMsg.value = { ok: true, text: '操作成功' }
    await loadUsers()
  } catch (e: any) { m.error = e.data?.message || e.message || '操作失败' }
  finally { m.saving = false }
}
function openResetPwd(u: any) { resetPwdModal.value = { id: u.id, username: u.username, newPassword:'', saving: false } }
async function submitResetPwd() {
  if (!resetPwdModal.value) return
  const m = resetPwdModal.value; m.saving = true; m.error = ''
  try {
    if (!m.newPassword || m.newPassword.length < 6) { m.error = '新密码至少 6 位'; return }
    const r = await $fetch<any>('/api/admin/users', { method:'PUT', body:{ id: m.id, newPassword: m.newPassword } })
    if (r.code !== 0) throw new Error(r.message||'')
    resetPwdModal.value = null
    usersMsg.value = { ok: true, text: '密码已重置' }
  } catch (e: any) { m.error = e.data?.message || e.message || '操作失败' }
  finally { m.saving = false }
}
async function removeUser(u: any) { if (!confirm(`确认删除账号「${u.username}」？`)) return; try { const r = await $fetch<any>('/api/admin/users', { method:'DELETE', body:{ id: u.id } }); if (r.code===0) { users.value = users.value.filter(x=>x.id!==u.id); usersMsg.value={ok:true,text:'已删除'} } } catch (e:any) { usersMsg.value = { ok:false, text: e.data?.message||e.message||'删除失败' } } }

// =============== TAB 6 AI 管理 ===============
interface AiCfgState {
  provider: string; api_base: string; api_key: string; model: string; temperature: number; max_tokens: number;
  system_prompt: string; default_topic_hint: string; default_category_id: number | null;
  default_tags_json: string; default_tags_text: string; default_status: number; enabled_bool: boolean;
  default_category_name?: string | null
}
const aiCfg = reactive<AiCfgState>({
  provider:'deepseek', api_base:'https://api.deepseek.com', api_key:'', model:'deepseek-chat',
  temperature:0.7, max_tokens:2400, system_prompt:'', default_topic_hint:'', default_category_id:null,
  default_tags_json:'[]', default_tags_text:'', default_status:1, enabled_bool:false
})
const aiCfgSaving = ref(false)
const aiCfgMsg = ref<{ok:boolean;text:string}|null>(null)
const testingConn = ref(false)
const testResultModal = ref<null | { id?: number; title?: string; slug?: string; error?: string }>(null)

function tagsTextToJson(t: string): string {
  if (!t) return '[]'
  try { const v = JSON.parse(t); if (Array.isArray(v)) return JSON.stringify(v) } catch {}
  return JSON.stringify(t.split(/[,，]/).map(s => s.trim()).filter(Boolean))
}

async function loadAiConfig() {
  try {
    const r = await $fetch<any>('/api/admin/ai-config')
    if (r.code === 0) {
      const c = r.data.config || {}
      aiCfg.provider = c.provider || 'deepseek'
      aiCfg.api_base = c.api_base || ''
      aiCfg.api_key = c.api_key || ''
      aiCfg.model = c.model || 'deepseek-chat'
      aiCfg.temperature = Number(c.temperature ?? 0.7)
      aiCfg.max_tokens = Number(c.max_tokens ?? 2400)
      aiCfg.system_prompt = c.system_prompt || ''
      aiCfg.default_topic_hint = c.default_topic_hint || ''
      aiCfg.default_category_id = c.default_category_id ?? null
      aiCfg.default_tags_json = JSON.stringify(Array.isArray(c.default_tags) ? c.default_tags : [])
      aiCfg.default_tags_text = Array.isArray(c.default_tags) ? c.default_tags.join(', ') : ''
      aiCfg.default_status = Number(c.default_status ?? 1)
      aiCfg.enabled_bool = c.enabled === 1
      aiCfg.default_category_name = c.default_category_name || null
    }
  } catch {}
}
async function saveAiConfig() {
  aiCfgSaving.value = true; aiCfgMsg.value = null
  const tagsJson = tagsTextToJson(aiCfg.default_tags_text)
  const body = {
    provider: aiCfg.provider,
    api_base: aiCfg.api_base,
    api_key: aiCfg.api_key,
    model: aiCfg.model,
    temperature: aiCfg.temperature,
    max_tokens: aiCfg.max_tokens,
    system_prompt: aiCfg.system_prompt,
    default_topic_hint: aiCfg.default_topic_hint,
    default_category_id: aiCfg.default_category_id ?? null,
    default_tags: tagsJson,
    default_status: aiCfg.default_status,
    enabled: aiCfg.enabled_bool ? 1 : 0,
  }
  try {
    const r = await $fetch<any>('/api/admin/ai-config', { method:'PUT', body })
    if (r.code === 0) {
      aiCfgMsg.value = { ok: true, text: '保存成功' }
      if (r.data?.api_key) aiCfg.api_key = r.data.api_key
    } else aiCfgMsg.value = { ok:false, text: r.message || '保存失败' }
  } catch (e: any) { aiCfgMsg.value = { ok:false, text: e.data?.message || e.message || '保存失败' } }
  finally { aiCfgSaving.value = false }
}
async function testAiConnection() {
  testingConn.value = true
  testResultModal.value = {}
  try {
    const r = await $fetch<any>('/api/admin/generate-single', { method:'POST', body:{ customTopic:'写一段2句话的 ChatPulse 产品介绍' } })
    if (r.code === 0) testResultModal.value = { id: r.data.id, title: r.data.title, slug: r.data.slug }
    else testResultModal.value = { error: r.message || '生成失败' }
  } catch (e: any) { testResultModal.value = { error: e.data?.message || e.message || '生成失败' } }
  finally { testingConn.value = false }
}

// B. 定时任务
interface JobCfgState { enabled_bool: boolean; cron_expr: string; max_articles_per_run: number; auto_publish_bool: boolean; last_run_at?: string | null; nextRunAt?: string | null }
const jobCfg = reactive<JobCfgState>({ enabled_bool:false, cron_expr:'0 9 * * *', max_articles_per_run:1, auto_publish_bool:true })
const jobCfgSaving = ref(false)
const jobCfgMsg = ref<{ok:boolean;text:string}|null>(null)
const cronPresets = [
  { label: '每天 09:00', expr: '0 9 * * *' },
  { label: '每天 18:00', expr: '0 18 * * *' },
  { label: '每周一 10:00', expr: '0 10 * * 1' },
  { label: '每 2 天 9:30', expr: '30 9 */2 * *' },
  { label: '每小时整点', expr: '0 * * * *' },
]
async function loadJobConfig() {
  try {
    const r = await $fetch<any>('/api/admin/ai-job-config')
    if (r.code === 0 && r.data) {
      jobCfg.enabled_bool = r.data.enabled === 1
      jobCfg.cron_expr = r.data.cron_expr || '0 9 * * *'
      jobCfg.max_articles_per_run = Number(r.data.max_articles_per_run ?? 1)
      jobCfg.auto_publish_bool = r.data.auto_publish === 1
      jobCfg.last_run_at = r.data.last_run_at || null
      jobCfg.nextRunAt = r.data.nextRunAt || r.data.next_run_at || null
    }
  } catch {}
}
async function saveJobConfig() {
  jobCfgSaving.value = true; jobCfgMsg.value = null
  try {
    const r = await $fetch<any>('/api/admin/ai-job-config', { method:'PUT', body:{
      enabled: jobCfg.enabled_bool ? 1 : 0,
      cron_expr: jobCfg.cron_expr,
      max_articles_per_run: jobCfg.max_articles_per_run,
      auto_publish: jobCfg.auto_publish_bool ? 1 : 0,
    }})
    if (r.code===0) {
      jobCfgMsg.value = { ok:true, text:'保存成功' }
      if (r.data) { jobCfg.last_run_at = r.data.last_run_at || null; jobCfg.nextRunAt = r.data.nextRunAt || r.data.next_run_at || null }
    } else jobCfgMsg.value = { ok:false, text: r.message||'保存失败' }
  } catch (e: any) { jobCfgMsg.value = { ok:false, text: e.data?.message || e.message || '保存失败' } }
  finally { jobCfgSaving.value = false }
}

// C. 立即生成
const manualCount = ref(1)
const manualCustomTopic = ref('')
const manualRunning = ref(false)
const manualMsg = ref<{ok:boolean;text:string}|null>(null)
const latestRunId = ref<number | null>(null)
const latestRun = ref<any>(null)
function latestRunStatusTag() {
  const s = latestRun.value?.status
  if (s === 0) return 'tag-grey'
  if (s === 1) return 'tag-green'
  if (s === 2) return 'tag-red'
  return 'tag-grey'
}
function latestRunStatusText() {
  const s = latestRun.value?.status
  if (latestRunId.value == null) return '无'
  if (s === 0) return '运行中'
  if (s === 1) return '成功'
  if (s === 2) return '失败'
  return '未知'
}
async function triggerManual() {
  manualRunning.value = true; manualMsg.value = null
  try {
    let r: any
    if (manualCount.value <= 1 && manualCustomTopic.value.trim()) {
      // 单篇 + 自定义话题优先使用 generateSingle，复用测试逻辑；否则仍走 runAiArticleJob（不带 customTopic）
      r = await $fetch<any>('/api/admin/generate-single', { method:'POST', body:{ customTopic: manualCustomTopic.value.trim() } })
      if (r.code === 0) {
        manualMsg.value = { ok: true, text: `已生成文章「${r.data.title}」(ID: ${r.data.id})` }
      } else throw new Error(r.message||'')
    } else {
      r = await $fetch<any>('/api/admin/ai-job-run/trigger', { method:'POST', body:{ count: manualCount.value } })
      if (r.code !== 0) throw new Error(r.message||'')
      latestRunId.value = r.data.runId
      manualMsg.value = { ok: true, text: `已发起任务 runId=${r.data.runId}，稍后查看状态` }
      setTimeout(() => loadRuns(true), 1500)
    }
  } catch (e: any) { manualMsg.value = { ok:false, text: e.data?.message || e.message || '生成失败' } }
  finally { manualRunning.value = false }
}

// D. 运行日志
const runs = ref<any[]>([])
const runsLoading = ref(false)
const runsPage = ref(1)
const runsPageSize = 20
const runsTotal = ref(0)
const runsTotalPages = computed(() => Math.max(1, Math.ceil(runsTotal.value / runsPageSize)))
const runErrorModal = ref<string | null>(null)
async function loadRuns(pickLatest = false) {
  runsLoading.value = true
  try {
    const r = await $fetch<any>('/api/admin/ai-job-runs', { params:{ page: runsPage.value, pageSize: runsPageSize } })
    if (r.code === 0) { runs.value = r.data.list || []; runsTotal.value = r.data.total }
    if (pickLatest && latestRunId.value != null) {
      latestRun.value = runs.value.find(x => x.id === latestRunId.value) || null
      if (!latestRun.value) {
        try {
          const r2 = await $fetch<any>('/api/admin/ai-job-runs', { params:{ page:1, pageSize:100 } })
          latestRun.value = (r2.data?.list || []).find((x:any) => x.id === latestRunId.value) || null
        } catch {}
      }
    }
  } catch {}
  runsLoading.value = false
}
function showRunError(r: any) { runErrorModal.value = r.error_message || '' }

// =============== TAB 7 修改密码 ===============
const changePwd = reactive({ old:'', new:'', confirm:'', saving:false })
const changePwdMsg = ref<{ok:boolean;text:string}|null>(null)
async function submitChangePwd() {
  changePwdMsg.value = null
  if (!changePwd.old || !changePwd.new || !changePwd.confirm) { changePwdMsg.value = { ok:false, text:'请完整填写所有字段' }; return }
  if (changePwd.new.length < 6) { changePwdMsg.value = { ok:false, text:'新密码长度至少 6 位' }; return }
  if (changePwd.new !== changePwd.confirm) { changePwdMsg.value = { ok:false, text:'两次输入的新密码不一致' }; return }
  changePwd.saving = true
  try {
    const r = await $fetch<any>('/api/admin/change-password', { method:'POST', body:{ oldPassword: changePwd.old, newPassword: changePwd.new } })
    if (r.code === 0) { changePwdMsg.value = { ok:true, text:'密码修改成功' }; changePwd.old=''; changePwd.new=''; changePwd.confirm='' }
    else changePwdMsg.value = { ok:false, text: r.message || '修改失败' }
  } catch (e: any) { changePwdMsg.value = { ok:false, text: e.data?.message || e.message || '修改失败' } }
  finally { changePwd.saving = false }
}

// =============== onMounted ===============
onMounted(async () => {
  await loadMe()
  if (!me.value) return
  await Promise.all([loadCategories(), loadArticles(), loadSiteConfig(), loadScreenshots(), loadContacts(), loadUsers(), loadAiConfig(), loadJobConfig(), loadRuns(), loadDocsList()])
})
</script>

<style scoped>
.card { background: #fff; border-radius: 14px; padding: 20px 24px; box-shadow: 0 1px 4px rgba(0,0,0,.04); }
.card + .card { margin-top: 20px; }
.list-head { display:flex; align-items:center; justify-content:space-between; margin-bottom:18px; }
.list-head h2 { font-size:20px; font-weight:700; color:#1d2129; margin:0; }
.edit-actions { display:flex; gap:8px; }

.btn-primary-sm { padding: 8px 18px; background:#165dff; color:#fff; border:none; border-radius:8px; font-size:14px; font-weight:600; cursor:pointer; }
.btn-primary-sm:hover { background:#4080ff; }
.btn-primary-sm:disabled { opacity:.6; cursor:not-allowed; }
.btn-danger-sm { padding: 8px 18px; background:#fff; color:#e03131; border:1px solid #ffc9c9; border-radius:8px; font-size:14px; font-weight:500; cursor:pointer; }
.btn-danger-sm:hover { background:#fff5f5; border-color:#ff8787; }
.btn-danger-sm:disabled { opacity:.5; cursor:not-allowed; }
.btn-grey { padding: 8px 18px; background:#f2f3f5; color:#4e5969; border:none; border-radius:8px; font-size:14px; font-weight:500; cursor:pointer; }
.btn-grey:hover { background:#e5e6eb; }
.btn-grey:disabled { opacity:.6; cursor:not-allowed; }

.filter-bar { display:flex; gap:12px; margin-bottom:16px; flex-wrap: wrap; }
.filter-input, .filter-select { padding: 8px 12px; border:1px solid #e5e6eb; border-radius:6px; font-size:14px; outline:none; background:#fff; }
.filter-input { flex:1; max-width:360px; }
.filter-input:focus, .filter-select:focus { border-color:#165dff; }

.data-table { width:100%; border-collapse:collapse; background:#fff; border-radius:8px; overflow:hidden; box-shadow:0 1px 4px rgba(0,0,0,.04); margin-top: 4px; }
.data-table th { padding:12px 16px; text-align:left; font-size:13px; font-weight:600; color:#86909c; background:#f7f8fa; border-bottom:1px solid #e5e6eb; }
.data-table td { padding:12px 16px; font-size:14px; color:#1d2129; border-bottom:1px solid #f2f3f5; vertical-align:middle; }
.empty-row { text-align:center; color:#86909c; padding:32px 0 !important; }
.td-title { max-width:320px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.td-contact { font-family: Consolas, monospace; font-size: 13px; }
.td-actions { white-space:nowrap; }
.act-btn { padding: 4px 10px; border:none; border-radius:4px; background:#f2f3f5; color:#4e5969; font-size:13px; cursor:pointer; margin-right:4px; transition: all .2s; }
.act-btn:hover { background:#e5e6eb; }
.act-btn.danger { color:#f53f3f; }
.act-btn.danger:hover { background:#ffece8; }
.tag { display:inline-block; padding: 2px 8px; border-radius:4px; font-size:12px; font-weight:500; }
.tag-green { background:#e8ffea; color:#00b42a; }
.tag-grey { background:#f2f3f5; color:#86909c; }
.tag-blue { background:#e8f3ff; color:#165dff; }
.tag-red { background:#ffece8; color:#f53f3f; }

.rowNew { background: #fff8ea; }

.count-flag { display:inline-block; padding: 2px 8px; border-radius: 10px; background: #ffece8; color: #f53f3f; font-size: 12px; font-weight:600; }

.form-grid { display:grid; grid-template-columns: 1fr 320px; gap:24px; }
@media (max-width: 900px) { .form-grid { grid-template-columns: 1fr; } }
.form-main, .form-side { display:flex; flex-direction:column; gap: 4px; }
.row-2 { display:grid; grid-template-columns: 1fr 1fr; gap: 16px; }
.form-field { margin-bottom: 14px; display:flex; flex-direction:column; gap:6px; }
.form-field .label { display:block; font-size:14px; font-weight:500; color:#4e5969; margin-bottom: 2px; }
.req { color:#f53f3f; }
.form-field small { color:#86909c; font-size:12px; }
.form-input { width:100%; padding:10px 14px; border:1px solid #e5e6eb; border-radius:10px; font-size:14px; outline:none; background:#fff; transition: border-color .2s, box-shadow .2s; font-family:inherit; box-sizing: border-box; }
.form-input:focus { border-color:#165dff; box-shadow:0 0 0 3px rgba(22,93,255,.12); }
select.form-input { appearance: auto; }
.code-input { font-family: Consolas, Monaco, monospace; font-size:13px; line-height:1.6; }
.cover-preview { width:100%; max-height:120px; object-fit:cover; border-radius:8px; margin-top:8px; }
.switch-row { display:flex; align-items:center; gap:8px; cursor:pointer; user-select:none; }
.switch-row input { width:18px; height:18px; }
.range-row { display:flex; align-items:center; gap: 10px; }
.range-input { flex:1; accent-color:#165dff; }
.num-input { width: 80px; padding: 6px 8px; border: 1px solid #e5e6eb; border-radius: 8px; text-align:right; font-size:14px; outline:none; }
.num-input:focus { border-color:#165dff; }
.side-actions { display:flex; flex-direction:column; gap: 8px; margin-top: 8px; }

.banner { padding: 10px 14px; border-radius: 8px; font-size: 13px; margin-bottom: 14px; line-height: 1.5; }
.banner-success { background:#e8ffea; color:#00b42a; }
.banner-error { background:#ffece8; color:#f53f3f; }

.permission-denied { padding: 60px 20px; text-align: center; color: #4e5969; display:flex; flex-direction:column; align-items:center; gap:12px; }

.shots-grid { display:grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap:16px; }
.shot-card { border: 1px solid #e5e6eb; border-radius:12px; padding:12px; display:flex; flex-direction:column; gap:10px; background:#fafbfc; }
.shot-card img { width:100%; height:160px; object-fit:cover; border-radius:8px; background:#e5e6eb; }
.shot-actions { display:flex; gap: 6px; flex-wrap: wrap; }

.info-box { background:#f7f8fa; border-radius:12px; padding:14px; display:flex; flex-direction:column; gap:8px; }
.info-row { display:flex; justify-content:space-between; font-size:13px; color:#4e5969; gap:8px; }
.info-row span:first-child { color:#86909c; flex-shrink:0; }
.err-line { color:#f53f3f; font-size:13px; margin-top:8px; word-break: break-all; }

.preset-row { display:flex; flex-wrap: wrap; gap: 8px; margin-bottom: 8px; }
.preset-btn { padding:6px 12px; background:#eef2ff; color:#165dff; border:1px solid #cdd7ff; border-radius:999px; font-size:12px; cursor:pointer; transition: all .2s; }
.preset-btn:hover { background:#d7e3ff; }

.modal-hint { padding: 6px 10px; background:#f7f8fa; border-radius:8px; color:#4e5969; font-size:13px; margin-bottom: 10px; }
.detail-row { font-size: 14px; color: #1d2129; margin-bottom: 6px; line-height: 1.6; }
.detail-row .label { color: #86909c; margin-right: 4px; }
.detail-msg { padding: 10px 12px; background:#f7f8fa; border-radius:8px; white-space: pre-wrap; line-height:1.6; font-size:14px; color:#1d2129; }
.err-toggle { color:#f53f3f; cursor:pointer; text-decoration: underline; }
.err-pre { background:#1d2129; color:#e5e6eb; padding:12px; border-radius:8px; white-space: pre-wrap; word-break: break-all; font-size:13px; line-height:1.6; max-height: 60vh; overflow:auto; }

.change-pwd-card { max-width: 560px; }
.pwd-form { display:flex; flex-direction:column; gap: 4px; }

/* 分页在组件内实现，这里给基础兼容 */
.modal-actions { display:flex; justify-content:flex-end; gap:8px; margin-top:16px; }

/* ============ 定价管理 ============ */
.pricing-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}
@media (max-width: 900px) {
  .pricing-row { grid-template-columns: 1fr; }
}

/* ============ 文档管理 ============ */
.docs-callout {
  background: linear-gradient(135deg, #eef5ff 0%, #f0f7ff 100%);
  border: 1px solid #cddcff;
}
.docs-callout-head {
  display: flex;
  align-items: center;
  gap: 10px;
  color: #0e42d2;
  font-size: 16px;
  margin-bottom: 10px;
}
.docs-callout-head strong { color: #0e42d2; }
.docs-callout-list {
  margin: 0;
  padding-left: 20px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.docs-callout-list li {
  font-size: 14px;
  line-height: 1.75;
  color: #1d2129;
}
.docs-callout-list code {
  display: inline-block;
  padding: 1px 6px;
  background: #fff;
  border: 1px solid #cddcff;
  border-radius: 4px;
  color: #165dff;
  font-size: 13px;
  font-family: Consolas, Monaco, monospace;
}

.docs-workspace {
  margin-top: 20px;
  display: grid;
  grid-template-columns: 320px 1fr;
  gap: 20px;
  padding: 0;
  overflow: hidden;
}
@media (max-width: 900px) {
  .docs-workspace { grid-template-columns: 1fr; }
}

.docs-list-panel,
.docs-edit-panel {
  display: flex;
  flex-direction: column;
  min-height: 0;
}
.docs-list-panel {
  border-right: 1px solid #eef0f3;
}
@media (max-width: 900px) {
  .docs-list-panel { border-right: none; border-bottom: 1px solid #eef0f3; }
}

.panel-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 20px;
  border-bottom: 1px solid #eef0f3;
  gap: 12px;
}
.panel-head h3 {
  margin: 0;
  font-size: 16px;
  font-weight: 700;
  color: #1d2129;
}
.edit-info { display:flex; align-items:center; }
.current-filename {
  display: inline-block;
  padding: 4px 10px;
  background: #f7f8fa;
  border: 1px solid #e5e6eb;
  border-radius: 6px;
  font-family: Consolas, Monaco, monospace;
  font-size: 13px;
  color: #1d2129;
}
.current-filename.placeholder {
  color: #86909c;
  background: transparent;
  border: 1px dashed #c9cdd4;
}

.docs-list {
  list-style: none;
  margin: 0;
  padding: 8px;
  overflow-y: auto;
  max-height: 70vh;
}
.docs-item {
  padding: 12px 14px;
  border-radius: 10px;
  cursor: pointer;
  display: flex;
  flex-direction: column;
  gap: 6px;
  transition: all .2s;
  border: 1px solid transparent;
}
.docs-item:hover {
  background: #f7f8fa;
}
.docs-item.active {
  background: #e8f3ff;
  border-color: #b9cdff;
}

/* 文档元数据编辑栏（标题/slug/分类/排序） */
.doc-meta-bar {
  display: grid;
  grid-template-columns: 1fr 1fr 140px 100px;
  gap: 10px;
  padding: 12px 14px;
  background: #f7f8fa;
  border-radius: 10px;
  margin-bottom: 10px;
  border: 1px solid #eef0f3;
}
.meta-row {
  display: flex;
  align-items: center;
  gap: 6px;
  min-width: 0;
}
.meta-row label {
  font-size: 12px;
  color: #86909c;
  font-weight: 500;
  white-space: nowrap;
  flex-shrink: 0;
}
.doc-input {
  flex: 1;
  min-width: 0;
  padding: 6px 10px;
  border: 1px solid #d9dde4;
  border-radius: 6px;
  font-size: 13px;
  background: #fff;
  color: #1d2129;
  outline: none;
  transition: border-color .2s, box-shadow .2s;
}
.doc-input:focus {
  border-color: #165dff;
  box-shadow: 0 0 0 3px rgba(22,93,255,.12);
}
.doc-input::placeholder { color: #c9cdd4; }
@media (max-width: 900px) {
  .doc-meta-bar { grid-template-columns: 1fr 1fr; }
}
.item-title {
  font-size: 14px;
  font-weight: 600;
  color: #1d2129;
  line-height: 1.4;
}
.item-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}
.item-cat {
  font-size: 12px;
  color: #165dff;
  background: #e8f3ff;
  padding: 2px 8px;
  border-radius: 4px;
  font-weight: 500;
}
.item-bottom {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 12px;
  color: #86909c;
}
.item-file {
  font-family: Consolas, Monaco, monospace;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 70%;
}

.doc-textarea {
  width: 100%;
  height: 100%;
  min-height: 520px;
  padding: 20px 22px;
  border: none;
  resize: none;
  outline: none;
  background: #fff;
  font-family: -apple-system, BlinkMacSystemFont, Consolas, 'JetBrains Mono', monospace;
  font-size: 15px;
  line-height: 1.7;
  color: #1d2129;
  box-sizing: border-box;
  tab-size: 2;
}
.doc-textarea:disabled {
  background: #fafbfc;
  color: #86909c;
  cursor: not-allowed;
}
.doc-textarea::placeholder {
  color: #c9cdd4;
}

/* ============ 编辑器工具栏 ============ */
.doc-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 10px;
  background: #fafbfc;
  border-top: 1px solid #eef0f3;
  border-bottom: 1px solid #eef0f3;
  flex-wrap: wrap;
  gap: 4px;
}
.doc-toolbar-left,
.doc-toolbar-right {
  display: flex;
  align-items: center;
  gap: 2px;
}
.tb-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 30px;
  height: 28px;
  padding: 0 8px;
  border: none;
  border-radius: 6px;
  background: transparent;
  color: #4e5969;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: background .15s, color .15s, transform .1s;
  line-height: 1;
}
.tb-btn:hover {
  background: #e8f3ff;
  color: #165dff;
}
.tb-btn:active { transform: scale(.94); }
.tb-btn.active {
  background: #165dff;
  color: #fff;
}
.tb-sep {
  width: 1px;
  height: 18px;
  background: #e5e6eb;
  margin: 0 4px;
}
.tb-status {
  font-size: 12px;
  color: #86909c;
  margin-right: 6px;
  font-variant-numeric: tabular-nums;
}

/* ============ 分屏编辑区 ============ */
.doc-edit-body {
  display: flex;
  min-height: 560px;
  border: 1px solid #eef0f3;
  border-top: none;
  border-radius: 0 0 10px 10px;
  overflow: hidden;
  background: #fff;
}
.doc-editor-pane {
  flex: 1;
  min-width: 0;
  position: relative;
  background: #fff;
}
.doc-split .doc-editor-pane {
  border-right: 1px solid #eef0f3;
}
.doc-preview-pane {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  background: #fafbfc;
}
.doc-preview-head {
  padding: 8px 14px;
  font-size: 12px;
  font-weight: 600;
  color: #86909c;
  text-transform: uppercase;
  letter-spacing: .5px;
  background: #f2f3f5;
  border-bottom: 1px solid #eef0f3;
}
.doc-preview-body {
  flex: 1;
  overflow-y: auto;
  padding: 24px 28px;
  font-size: 15px;
  line-height: 1.75;
  color: #1d2129;
}

/* ============ Markdown 预览样式 ============ */
.markdown-body h1,
.markdown-body h2,
.markdown-body h3,
.markdown-body h4 {
  color: #1d2129;
  font-weight: 600;
  margin: 24px 0 12px;
  line-height: 1.35;
}
.markdown-body h1 { font-size: 26px; padding-bottom: 8px; border-bottom: 1px solid #eef0f3; }
.markdown-body h2 { font-size: 22px; padding-bottom: 6px; border-bottom: 1px solid #eef0f3; }
.markdown-body h3 { font-size: 18px; }
.markdown-body p { margin: 0 0 14px; }
.markdown-body ul,
.markdown-body ol { margin: 0 0 14px; padding-left: 24px; }
.markdown-body li { margin-bottom: 4px; }
.markdown-body blockquote {
  margin: 14px 0;
  padding: 10px 16px;
  background: #f0f5ff;
  border-left: 3px solid #165dff;
  color: #4e5969;
  border-radius: 0 6px 6px 0;
}
.markdown-body code {
  background: #f2f3f5;
  color: #e03131;
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 13.5px;
  font-family: 'JetBrains Mono', Consolas, monospace;
}
.markdown-body pre {
  background: #1d2129;
  color: #fff;
  padding: 16px 18px;
  border-radius: 8px;
  overflow-x: auto;
  margin: 14px 0;
  font-size: 13.5px;
  line-height: 1.6;
}
.markdown-body pre code {
  background: transparent;
  color: inherit;
  padding: 0;
  font-size: inherit;
}
.markdown-body table {
  width: 100%;
  border-collapse: collapse;
  margin: 14px 0;
  font-size: 14px;
}
.markdown-body th,
.markdown-body td {
  border: 1px solid #e5e6eb;
  padding: 8px 12px;
  text-align: left;
}
.markdown-body th {
  background: #f7f8fa;
  font-weight: 600;
}
.markdown-body hr {
  border: none;
  border-top: 1px solid #e5e6eb;
  margin: 24px 0;
}
.markdown-body a {
  color: #165dff;
  text-decoration: none;
}
.markdown-body a:hover { text-decoration: underline; }
.markdown-body img {
  max-width: 100%;
  border-radius: 6px;
  margin: 8px 0;
}

/* ============ 空态（未选文档时） ============ */
.doc-empty-hint {
  min-height: 520px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  border: 1px dashed #e5e6eb;
  border-top: none;
  border-radius: 0 0 10px 10px;
  background: #fafbfc;
  color: #86909c;
  gap: 6px;
}
.doc-empty-icon {
  margin-bottom: 4px;
  opacity: .8;
}
.doc-empty-hint p { margin: 0; font-size: 14px; color: #4e5969; }
.doc-empty-hint .hint-sub { font-size: 12px; color: #c9cdd4; }

.docs-toast {
  padding: 10px 14px;
  border-radius: 8px;
  font-size: 13px;
  line-height: 1.6;
  margin-top: 10px;
  white-space: pre-wrap;
}
.docs-toast.ok {
  background: #e8ffea;
  color: #007a1f;
  border: 1px solid #b7eb8f;
}
.docs-toast.err {
  background: #ffece8;
  color: #b4251a;
  border: 1px solid #ffccc7;
}
</style>
