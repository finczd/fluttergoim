import Database from 'better-sqlite3'
import { mkdirSync, existsSync, copyFileSync, readdirSync, statSync } from 'node:fs'
import { join, basename, extname } from 'node:path'
import bcrypt from 'bcryptjs'

const DATA_DIR = join(process.cwd(), 'data')
const DB_PATH = join(DATA_DIR, 'chatpulse.db')
const DB_SCHEMA_VERSION = 5 // 每次表结构变更需要补齐就 +1

let db: Database.Database | null = null

export function getDb(): Database.Database {
  if (db) {
    ensureSchemaVersion(db)
    return db
  }
  if (!existsSync(DATA_DIR)) mkdirSync(DATA_DIR, { recursive: true })
  db = new Database(DB_PATH)
  db.pragma('journal_mode = WAL')
  db.pragma('foreign_keys = ON')
  initTables(db)
  ensureSchemaVersion(db, true)
  migrateFromJson(db)
  syncDocsDirToContent()
  return db
}

/**
 * 防御性检查：按 PRAGMA user_version 判断数据库结构是否已经升级到最新版。
 * 若版本不足（0/小于 DB_SCHEMA_VERSION），再次调用 initTables 的补列逻辑，并强制刷新数据库版本号。
 * 这能避免：数据库文件已经生成但代码更新后新表/列缺失。
 */
function ensureSchemaVersion(d: Database.Database, forceInit = false) {
  let v = 0
  try { v = Number((d.pragma('user_version', { simple: true }) as any) || 0) } catch {}
  if (forceInit || v < DB_SCHEMA_VERSION) {
    try {
      // 重新执行补列逻辑（CREATE IF NOT EXISTS + safeAddColumn 都是幂等的）
      initTables(d)
      d.pragma(`user_version = ${DB_SCHEMA_VERSION}`)
    } catch (e) {
      console.error('[db] ensureSchemaVersion failed:', (e as Error).message)
    }
  }
}

function initTables(d: Database.Database) {
  d.exec(`
    CREATE TABLE IF NOT EXISTS site_config (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      site_title TEXT NOT NULL DEFAULT 'ChatPulse',
      site_description TEXT NOT NULL DEFAULT '',
      site_keywords TEXT NOT NULL DEFAULT '',
      logo TEXT NOT NULL DEFAULT '/favicon.svg',
      contact_telegram TEXT NOT NULL DEFAULT '',
      h5_demo_url TEXT NOT NULL DEFAULT '',
      -- 三档定价（USDT）：0 表示 面议/定制
      price_standard_usdt REAL NOT NULL DEFAULT 699,
      price_professional_usdt REAL NOT NULL DEFAULT 1399,
      price_enterprise_text TEXT NOT NULL DEFAULT '面议',
      price_period TEXT NOT NULL DEFAULT '终身授权',
      price_standard_note TEXT NOT NULL DEFAULT '适合中小企业，源码+基础功能',
      price_professional_note TEXT NOT NULL DEFAULT '全功能版，音视频+红包+AI助手',
      price_enterprise_note TEXT NOT NULL DEFAULT '独占授权，SLA保障，专属团队',
      -- Demo 下载地址（后台可配）
      android_download_url TEXT NOT NULL DEFAULT '',
      ios_download_url TEXT NOT NULL DEFAULT '',
      ios_self_sign_guide TEXT NOT NULL DEFAULT '请自行签名安装测试',
      admin_panel_url TEXT NOT NULL DEFAULT '',
      pc_client_url TEXT NOT NULL DEFAULT ''
    );

    CREATE TABLE IF NOT EXISTS categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE
    );

    CREATE TABLE IF NOT EXISTS articles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      slug TEXT NOT NULL UNIQUE,
      title TEXT NOT NULL,
      summary TEXT NOT NULL DEFAULT '',
      content TEXT NOT NULL DEFAULT '',
      cover TEXT NOT NULL DEFAULT '',
      category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
      tags TEXT NOT NULL DEFAULT '[]',
      status INTEGER NOT NULL DEFAULT 1, -- 0 draft, 1 published
      source TEXT NOT NULL DEFAULT 'manual', -- manual / ai
      ai_run_id INTEGER DEFAULT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_articles_status ON articles(status);
    CREATE INDEX IF NOT EXISTS idx_articles_created ON articles(created_at);
    CREATE INDEX IF NOT EXISTS idx_articles_source ON articles(source);

    CREATE TABLE IF NOT EXISTS screenshots (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      url TEXT NOT NULL,
      title TEXT NOT NULL DEFAULT '',
      sort_order INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS contacts (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      contact TEXT NOT NULL,
      message TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      is_read INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS idx_contacts_created ON contacts(created_at);

    /* ======= 新增：管理员账号 ======= */
    CREATE TABLE IF NOT EXISTS admin_users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      nickname TEXT NOT NULL DEFAULT '',
      role TEXT NOT NULL DEFAULT 'admin', -- admin / editor
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_login_at TEXT DEFAULT NULL,
      last_login_ip TEXT DEFAULT NULL,
      status INTEGER NOT NULL DEFAULT 1 -- 0 disabled, 1 enabled
    );
    CREATE INDEX IF NOT EXISTS idx_admin_users_username ON admin_users(username);

    /* ======= 新增：AI 配置（单例 id=1） ======= */
    CREATE TABLE IF NOT EXISTS ai_configs (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      provider TEXT NOT NULL DEFAULT 'deepseek',  -- deepseek / openai / custom
      api_base TEXT NOT NULL DEFAULT 'https://api.deepseek.com',
      api_key TEXT NOT NULL DEFAULT '',
      model TEXT NOT NULL DEFAULT 'deepseek-chat',
      temperature REAL NOT NULL DEFAULT 0.7,
      max_tokens INTEGER NOT NULL DEFAULT 2000,
      system_prompt TEXT NOT NULL DEFAULT '', -- 身份/人设
      default_topic_hint TEXT NOT NULL DEFAULT '', -- 生成文章时的话题倾向
      default_category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
      default_tags TEXT NOT NULL DEFAULT '[]',
      default_status INTEGER NOT NULL DEFAULT 1, -- 0 草稿 / 1 自动发布
      enabled INTEGER NOT NULL DEFAULT 0 -- 0 关闭 / 1 开启
    );

    /* ======= 新增：AI 定时发布任务配置（单例 id=1） ======= */
    CREATE TABLE IF NOT EXISTS ai_job_configs (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      enabled INTEGER NOT NULL DEFAULT 0,
      cron_expr TEXT NOT NULL DEFAULT '0 9 * * *', -- node-cron 表达式，默认每天 9:00
      max_articles_per_run INTEGER NOT NULL DEFAULT 1,
      auto_publish INTEGER NOT NULL DEFAULT 1,
      last_run_at TEXT DEFAULT NULL,
      next_run_at TEXT DEFAULT NULL
    );

    /* ======= 新增：AI 生成运行日志 ======= */
    CREATE TABLE IF NOT EXISTS ai_job_runs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      started_at TEXT NOT NULL,
      finished_at TEXT DEFAULT NULL,
      status INTEGER NOT NULL DEFAULT 0, -- 0 running / 1 success / 2 failed
      articles_count INTEGER NOT NULL DEFAULT 0,
      error_message TEXT NOT NULL DEFAULT '',
      trigger_type TEXT NOT NULL DEFAULT 'cron' -- cron / manual
    );
    CREATE INDEX IF NOT EXISTS idx_ai_job_runs_started ON ai_job_runs(started_at);
    CREATE INDEX IF NOT EXISTS idx_ai_job_runs_status ON ai_job_runs(status);

    /* ======= 新增：文档管理 docs（不再读磁盘 md） ======= */
    CREATE TABLE IF NOT EXISTS docs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      slug TEXT NOT NULL UNIQUE,
      title TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT 'arch',
      category_label TEXT NOT NULL DEFAULT '架构与设计',
      content TEXT NOT NULL DEFAULT '',
      order_num INTEGER NOT NULL DEFAULT 99,
      created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
    );
    CREATE INDEX IF NOT EXISTS idx_docs_slug ON docs(slug);
    CREATE INDEX IF NOT EXISTS idx_docs_cat ON docs(category);
  `)

  // ---------- site_config 单例行 ----------
  const row = d.prepare('SELECT id FROM site_config WHERE id = 1').get()
  if (!row) {
    d.prepare(`
      INSERT INTO site_config
      (id, site_title, site_description, site_keywords, logo, contact_telegram, h5_demo_url,
       price_standard_usdt, price_professional_usdt, price_enterprise_text, price_period,
       price_standard_note, price_professional_note, price_enterprise_note)
      VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      'ChatPulse - 企业级即时通讯系统 | 源码出售+定制开发',
      'ChatPulse 企业级即时通讯系统，Go + Vue + Flutter 全栈技术，支持单聊群聊、音视频通话、红包转账、朋友圈、靓号系统。源码出售、私有化部署、定制开发、终身授权。',
      '即时通讯系统,IM系统源码,企业通讯,聊天APP源码,Go IM,Flutter聊天,私有化部署IM,定制开发,ChatPulse',
      '/favicon.svg',
      '@ChatPulse_BD',
      'https://im.x123.wang/h5/',
      699, 1399, '面议', '终身授权',
      '适合中小企业，源码+基础功能+管理后台',
      '全功能版：音视频通话+红包转账+靓号+AI助手',
      '独占授权 / 定制开发：SLA 保障、专属技术团队'
    )
  }

  // 兼容旧数据库列
  const safeAddColumn = (table: string, col: string, def: string) => {
    const cols = d.prepare(`PRAGMA table_info(${table})`).all() as { name: string }[]
    if (!cols.some(c => c.name === col)) {
      d.prepare(`ALTER TABLE ${table} ADD COLUMN ${col} ${def}`).run()
    }
  }
  safeAddColumn('site_config', 'h5_demo_url', "TEXT NOT NULL DEFAULT ''")
  safeAddColumn('site_config', 'contact_telegram', "TEXT NOT NULL DEFAULT ''")
  safeAddColumn('site_config', 'contact_phone', "TEXT NOT NULL DEFAULT ''")
  safeAddColumn('site_config', 'contact_email', "TEXT NOT NULL DEFAULT ''")
  safeAddColumn('site_config', 'contact_wechat', "TEXT NOT NULL DEFAULT ''")
  safeAddColumn('site_config', 'contact_qq', "TEXT NOT NULL DEFAULT ''")
  safeAddColumn('site_config', 'android_download_url', "TEXT NOT NULL DEFAULT ''")
  safeAddColumn('site_config', 'ios_download_url', "TEXT NOT NULL DEFAULT ''")
  safeAddColumn('site_config', 'ios_self_sign_guide', "TEXT NOT NULL DEFAULT '请自行签名安装测试'")
  safeAddColumn('site_config', 'admin_panel_url', "TEXT NOT NULL DEFAULT ''")
  safeAddColumn('site_config', 'pc_client_url', "TEXT NOT NULL DEFAULT ''")
  safeAddColumn('site_config', 'price_standard_usdt',    'REAL NOT NULL DEFAULT 699')
  safeAddColumn('site_config', 'price_professional_usdt','REAL NOT NULL DEFAULT 1399')
  safeAddColumn('site_config', 'price_enterprise_text',  "TEXT NOT NULL DEFAULT '面议'")
  safeAddColumn('site_config', 'price_period',           "TEXT NOT NULL DEFAULT '终身授权'")
  safeAddColumn('site_config', 'price_standard_note',    "TEXT NOT NULL DEFAULT '适合中小企业，源码+基础功能'")
  safeAddColumn('site_config', 'price_professional_note',"TEXT NOT NULL DEFAULT '全功能版，音视频+红包+AI助手'")
  safeAddColumn('site_config', 'price_enterprise_note',  "TEXT NOT NULL DEFAULT '独占授权，SLA保障，专属团队'")

  // articles 新增 source / ai_run_id
  safeAddColumn('articles', 'source', "TEXT NOT NULL DEFAULT 'manual'")
  safeAddColumn('articles', 'ai_run_id', 'INTEGER DEFAULT NULL')

  // ---------- admin_users 默认 admin/admin123 ----------
  const adminCount = (d.prepare('SELECT COUNT(*) AS c FROM admin_users').get() as any).c
  if (adminCount === 0) {
    const hash = bcrypt.hashSync('admin123', 10)
    d.prepare(`
      INSERT INTO admin_users (username, password_hash, nickname, role, created_at, updated_at, status)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      'admin', hash, '超级管理员', 'admin',
      new Date().toISOString(), new Date().toISOString(), 1
    )
  }

  // ---------- ai_configs 默认值 ----------
  const aic = d.prepare('SELECT id FROM ai_configs WHERE id = 1').get()
  if (!aic) {
    const defaultPrompt = [
      '你是 ChatPulse 企业级 IM 系统的官方博客专栏作者，同时也是企业 SaaS、通讯软件、私有化部署、数字办公领域的资深编辑。',
      '要求：',
      '1. 输出一篇原创、通顺、逻辑清晰的中文资讯文章，围绕企业 IM、即时通讯系统、团队沟通效率提升、私有化部署、安全合规、AI + IM 结合、中小企业数字化转型、源码服务等相关主题。',
      '2. 结构：开头引入背景（2 段），主体干货点分 3-4 个小标题展开，结尾总结。',
      '3. 字数 1200-1800 字。',
      '4. 严禁出现任何关于 ChatPulse 竞品（钉钉、企业微信、飞书等）的负面评价或不实对比，保持中立专业。',
      '5. 输出仅包含文章正文 HTML（<p>、<h3>、<ul> 等简单标签），不要输出 markdown 标记、不要输出“好的”“以下是文章”等非正文内容。'
    ].join('\n')
    // 确保分类存在："行业资讯"
    let catId = (d.prepare('SELECT id FROM categories WHERE name = ?').get('行业资讯') as any)?.id
    if (!catId) {
      const info = d.prepare('INSERT INTO categories (name) VALUES (?)').run('行业资讯')
      catId = info.lastInsertRowid as number
    }
    d.prepare(`
      INSERT INTO ai_configs
      (id, provider, api_base, api_key, model, temperature, max_tokens, system_prompt,
       default_topic_hint, default_category_id, default_tags, default_status, enabled)
      VALUES (1, 'deepseek', 'https://api.deepseek.com', '', 'deepseek-chat', 0.7, 2400, ?,
              '企业IM、私有化部署、AI 赋能沟通、团队数字化、通讯安全合规', ?, '["行业观察","数字化转型"]', 1, 0)
    `).run(defaultPrompt, catId)
  }

  // ---------- ai_job_configs 默认值 ----------
  const ajc = d.prepare('SELECT id FROM ai_job_configs WHERE id = 1').get()
  if (!ajc) {
    d.prepare(`
      INSERT INTO ai_job_configs (id, enabled, cron_expr, max_articles_per_run, auto_publish, last_run_at, next_run_at)
      VALUES (1, 0, '0 9 * * *', 1, 1, NULL, NULL)
    `).run()
  }
}

/**
 * 启动时把已有的 JSON 数据导入到 SQLite 表中（一次性）。
 * 若对应表已有数据，则跳过该表的导入，避免重复。
 */
function migrateFromJson(d: Database.Database) {
  const { readFileSync, existsSync } = require('node:fs')
  const dataDir = join(process.cwd(), 'data')

  // categories
  const catCount = (d.prepare('SELECT COUNT(*) as c FROM categories').get() as any).c
  if (catCount === 0) {
    const p = join(dataDir, 'categories.json')
    if (existsSync(p)) {
      try {
        const list = JSON.parse(readFileSync(p, 'utf-8'))
        const ins = d.prepare('INSERT OR IGNORE INTO categories (name) VALUES (?)')
        for (const n of list) ins.run(typeof n === 'string' ? n : n.name)
      } catch {}
    }
  }

  // articles
  const artCount = (d.prepare('SELECT COUNT(*) as c FROM articles').get() as any).c
  if (artCount === 0) {
    const p = join(dataDir, 'articles')
    if (existsSync(p)) {
      const { readdirSync } = require('node:fs')
      const insert = d.prepare(`
        INSERT OR IGNORE INTO articles
        (slug, title, summary, content, cover, category_id, tags, status, source, ai_run_id, created_at, updated_at)
        VALUES (@slug, @title, @summary, @content, @cover, @category_id, @tags, @status, 'manual', NULL, @created_at, @updated_at)
      `)
      let files: string[] = []
      try { files = readdirSync(p) } catch {}
      for (const f of files) {
        if (!f.endsWith('.json')) continue
        try {
          const a = JSON.parse(readFileSync(join(p, f), 'utf-8'))
          const catId: number | null = a.category
            ? ((d.prepare('SELECT id FROM categories WHERE name = ?').get(a.category) as any)?.id || null)
            : null
          insert.run({
            slug: a.slug || f.replace('.json', ''),
            title: a.title || '',
            summary: a.summary || '',
            content: a.content || '',
            cover: a.cover || '',
            category_id: catId,
            tags: a.tags ? JSON.stringify(a.tags) : '[]',
            status: a.published ? 1 : 0,
            created_at: a.createdAt || new Date().toISOString(),
            updated_at: a.updatedAt || new Date().toISOString(),
          })
        } catch {}
      }
    }
  }

  // screenshots
  const shotCount = (d.prepare('SELECT COUNT(*) as c FROM screenshots').get() as any).c
  if (shotCount === 0) {
    const ins = d.prepare('INSERT INTO screenshots (url, title, sort_order) VALUES (?, ?, ?)')
    // 1) 优先从 data/screenshots.json 导入（老数据兼容）
    const p = join(dataDir, 'screenshots.json')
    let imported = 0
    if (existsSync(p)) {
      try {
        const list = JSON.parse(readFileSync(p, 'utf-8'))
        for (let i = 0; i < list.length; i++) {
          const s = list[i]
          ins.run(s.url, s.title || '', s.order ?? i)
          imported++
        }
      } catch {}
    }
    // 2) JSON 文件里没有（新库初始化）时写入用户 17 张正式产品截图。
    //    只存"相对路径" /uploads/1.jpg ~ 17.jpg：
    //    - 渲染时 /api/screenshots 会按"当前访问域名"自动拼完整 URL；
    //    - 这样 www.x123.wang、localhost:3000、任意未来新域名都能正常显示。
    if (imported === 0) {
      const defaults: [string, string][] = [
        ['/uploads/1.jpg',  '单聊界面'],
        ['/uploads/2.jpg',  '群聊功能'],
        ['/uploads/3.jpg',  '通讯录'],
        ['/uploads/4.jpg',  '登录注册'],
        ['/uploads/5.jpg',  '朋友圈'],
        ['/uploads/6.jpg',  '个人中心'],
        ['/uploads/7.jpg',  '红包功能'],
        ['/uploads/8.jpg',  '转账功能'],
        ['/uploads/9.jpg',  '音视频通话'],
        ['/uploads/10.jpg', '管理后台'],
        ['/uploads/11.jpg', '消息列表'],
        ['/uploads/12.jpg', '会话搜索'],
        ['/uploads/13.jpg', '我的钱包'],
        ['/uploads/14.jpg', '好友详情'],
        ['/uploads/15.jpg', '群组设置'],
        ['/uploads/16.jpg', '靓号中心'],
        ['/uploads/17.jpg', 'AI 助手'],
      ]
      for (let i = 0; i < defaults.length; i++) {
        ins.run(defaults[i][0], defaults[i][1], i)
      }
    }
  }

  // contacts
  const conCount = (d.prepare('SELECT COUNT(*) as c FROM contacts').get() as any).c
  if (conCount === 0) {
    const p = join(dataDir, 'contacts')
    if (existsSync(p)) {
      const { readdirSync } = require('node:fs')
      const insert = d.prepare(`
        INSERT OR IGNORE INTO contacts (id, name, contact, message, created_at, is_read)
        VALUES (?, ?, ?, ?, ?, ?)
      `)
      let files: string[] = []
      try { files = readdirSync(p) } catch {}
      for (const f of files) {
        if (!f.endsWith('.json')) continue
        try {
          const c = JSON.parse(readFileSync(join(p, f), 'utf-8'))
          insert.run(c.id, c.name, c.contact, c.message || '', c.createdAt, c.read ? 1 : 0)
        } catch {}
      }
    }
  }
}

/**
 * 需求 2：把仓库 docs 目录的 md 文件复制到 im-site/content/docs/
 *  让前端展示 / 资源上传始终从 im-site 目录内读取，不再依赖兄弟目录软链
 *  同时保留 resolveDocsDir 回退逻辑
 */
export function syncDocsDirToContent() {
  const { mkdirSync, existsSync, copyFileSync, readdirSync, statSync } = require('node:fs')
  const cwd = process.cwd()
  // 源目录候选：d:\im-project\docs（相对 im-site 的兄弟路径 ../docs）
  const sourceCandidates = [join(cwd, '..', 'docs'), join(cwd, 'docs')]
  let source = ''
  for (const s of sourceCandidates) {
    try { if (statSync(s).isDirectory()) { source = s; break } } catch {}
  }
  if (!source) return // 没找到源就跳过
  const target = join(cwd, 'content', 'docs')
  try {
    mkdirSync(target, { recursive: true })
    const files = readdirSync(source)
    for (const f of files) {
      if (!f.toLowerCase().endsWith('.md')) continue
      const srcFile = join(source, f)
      const dstFile = join(target, f)
      let needCopy = true
      try {
        const s1 = statSync(srcFile).mtimeMs
        const s2 = statSync(dstFile).mtimeMs
        needCopy = s1 > s2
      } catch { needCopy = true }
      if (needCopy) copyFileSync(srcFile, dstFile)
    }
    // 顺带把 public 目录下也做个软链用的路径：docs/ → /content/docs
    const pubDocs = join(cwd, 'public', 'docs')
    try { mkdirSync(pubDocs, { recursive: true }) } catch {}
  } catch (err) {
    console.warn('[syncDocsDirToContent] failed:', err)
  }
}

/**
 * 解析 docs 目录（优先用 content/docs，没的话回退到 ../docs）
 */
export function resolveDocsDir(): string {
  const cwd = process.cwd()
  const candidates = [
    join(cwd, 'content', 'docs'),  // 同步过来的正式目标路径
    join(cwd, '..', 'docs'),
    join(cwd, 'docs'),
  ]
  for (const p of candidates) {
    try { if (statSync(p).isDirectory()) return p } catch {}
  }
  try {
    const fallback = join(cwd, 'content', 'docs')
    mkdirSync(fallback, { recursive: true })
    return fallback
  } catch { return join(process.cwd(), 'docs') }
}
