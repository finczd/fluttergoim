/**
 * ====================================================================
 *   ChatPulse im-site 数据库修复脚本
 *   作用：对已存在的 data/chatpulse.db 补建缺失表（admin_users / ai_*）和字段
 *   运行：node _repair-db.cjs
 *   不需要重启开发服务器，运行完即可直接登录。
 * ====================================================================
 */
const Database = require('better-sqlite3')
const bcrypt = require('bcryptjs')
const path = require('path')
const fs = require('fs')

const DATA_DIR = path.join(__dirname, 'data')
const DB_PATH = path.join(DATA_DIR, 'chatpulse.db')
console.log('\n[repair] 目标数据库：', DB_PATH)
console.log('[repair] 存在？', fs.existsSync(DB_PATH))

if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true })
const db = new Database(DB_PATH)
db.pragma('journal_mode = WAL')
db.pragma('foreign_keys = ON')

// ========================================================
//  1) site_config 表 + 新增列
// ========================================================
console.log('\n[1/7] 建/补 site_config 表 ...')
const hasConfig = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='site_config'").get()
if (!hasConfig) {
  db.exec(`
    CREATE TABLE site_config (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      site_title TEXT NOT NULL DEFAULT 'ChatPulse',
      site_description TEXT NOT NULL DEFAULT '',
      site_keywords TEXT NOT NULL DEFAULT '',
      logo TEXT NOT NULL DEFAULT '/favicon.svg',
      contact_telegram TEXT NOT NULL DEFAULT '',
      h5_demo_url TEXT NOT NULL DEFAULT '',
      price_standard_usdt REAL NOT NULL DEFAULT 699,
      price_professional_usdt REAL NOT NULL DEFAULT 1399,
      price_enterprise_text TEXT NOT NULL DEFAULT '面议',
      price_period TEXT NOT NULL DEFAULT '终身授权',
      price_standard_note TEXT NOT NULL DEFAULT '适合中小企业，源码+基础功能',
      price_professional_note TEXT NOT NULL DEFAULT '全功能版，音视频+红包+AI助手',
      price_enterprise_note TEXT NOT NULL DEFAULT '独占授权，SLA保障，专属团队',
      android_download_url TEXT NOT NULL DEFAULT '',
      admin_panel_url TEXT NOT NULL DEFAULT '',
      pc_client_url TEXT NOT NULL DEFAULT ''
    );
  `)
  console.log('       已创建新表')
} else {
  // 补列
  const cols = db.prepare("PRAGMA table_info(site_config)").all().map(c => c.name)
  const need = [
    ['site_title',         "TEXT NOT NULL DEFAULT 'ChatPulse'"],
    ['site_description',   "TEXT NOT NULL DEFAULT ''"],
    ['site_keywords',      "TEXT NOT NULL DEFAULT ''"],
    ['logo',               "TEXT NOT NULL DEFAULT '/favicon.svg'"],
    ['contact_telegram',   "TEXT NOT NULL DEFAULT ''"],
    ['h5_demo_url',        "TEXT NOT NULL DEFAULT ''"],
    ['contact_phone',      "TEXT NOT NULL DEFAULT ''"],
    ['contact_email',      "TEXT NOT NULL DEFAULT ''"],
    ['contact_wechat',     "TEXT NOT NULL DEFAULT ''"],
    ['contact_qq',         "TEXT NOT NULL DEFAULT ''"],
    ['price_standard_usdt',    'REAL NOT NULL DEFAULT 699'],
    ['price_professional_usdt','REAL NOT NULL DEFAULT 1399'],
    ['price_enterprise_text',  "TEXT NOT NULL DEFAULT '面议'"],
    ['price_period',           "TEXT NOT NULL DEFAULT '终身授权'"],
    ['price_standard_note',    "TEXT NOT NULL DEFAULT '适合中小企业，源码+基础功能'"],
    ['price_professional_note',"TEXT NOT NULL DEFAULT '全功能版，音视频+红包+AI助手'"],
    ['price_enterprise_note',  "TEXT NOT NULL DEFAULT '独占授权，SLA保障，专属团队'"],
    ['android_download_url',   "TEXT NOT NULL DEFAULT ''"],
    ['admin_panel_url',        "TEXT NOT NULL DEFAULT ''"],
    ['pc_client_url',           "TEXT NOT NULL DEFAULT ''"],
  ]
  for (const [name, def] of need) {
    if (!cols.includes(name)) {
      db.prepare(`ALTER TABLE site_config ADD COLUMN ${name} ${def}`).run()
      console.log(`       ADD COLUMN site_config.${name}`)
    }
  }
}
// 单例行（不存在则插入）
const row = db.prepare('SELECT id FROM site_config WHERE id = 1').get()
if (!row) {
  db.prepare(`INSERT INTO site_config (id, site_title, site_description, site_keywords, logo, contact_telegram, h5_demo_url)
              VALUES (1, ?, ?, ?, ?, ?, ?)`).run(
    'ChatPulse - 企业级即时通讯系统 | 源码出售+定制开发',
    'ChatPulse 企业级即时通讯系统，Go + Vue + Flutter 全栈技术，支持单聊群聊、音视频通话、红包转账、朋友圈、靓号系统。源码出售、私有化部署、定制开发、终身授权。',
    '即时通讯系统,IM系统源码,企业通讯,聊天APP源码,Go IM,Flutter聊天,私有化部署IM,定制开发,ChatPulse',
    '/favicon.svg', '@ChatPulse_BD', 'https://im.x123.wang/h5/'
  )
  console.log('       site_config 插入单例行')
}

// ========================================================
//  2) categories
// ========================================================
console.log('[2/7] 建 categories 表 ...')
db.exec(`CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE
)`)

// ========================================================
//  3) articles + screenshots + contacts（已存在就跳过，但需补列）
// ========================================================
console.log('[3/7] 建 articles / screenshots / contacts 表 ...')

const safeAddColumn = (table, col, def) => {
  const cols = db.prepare(`PRAGMA table_info(${table})`).all().map(c => c.name)
  if (!cols.includes(col)) {
    try {
      db.prepare(`ALTER TABLE ${table} ADD COLUMN ${col} ${def}`).run()
      console.log(`       ADD ${table}.${col}`)
    } catch (e) { console.warn(`       WARN add ${table}.${col}: ${e.message}`) }
  }
}

db.exec(`CREATE TABLE IF NOT EXISTS articles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  summary TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL DEFAULT '',
  cover TEXT NOT NULL DEFAULT '',
  category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  tags TEXT NOT NULL DEFAULT '[]',
  status INTEGER NOT NULL DEFAULT 1,
  source TEXT NOT NULL DEFAULT 'manual',
  ai_run_id INTEGER DEFAULT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);`)
safeAddColumn('articles', 'source',   "TEXT NOT NULL DEFAULT 'manual'")
safeAddColumn('articles', 'ai_run_id', 'INTEGER DEFAULT NULL')
try { db.exec(`CREATE INDEX IF NOT EXISTS idx_articles_status  ON articles(status);`)  } catch(e){ console.warn('idx1',e.message) }
try { db.exec(`CREATE INDEX IF NOT EXISTS idx_articles_created ON articles(created_at);`)} catch(e){ console.warn('idx2',e.message) }
try { db.exec(`CREATE INDEX IF NOT EXISTS idx_articles_source  ON articles(source);`)  } catch(e){ console.warn('idx3',e.message) }

db.exec(`CREATE TABLE IF NOT EXISTS screenshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  url TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0
);`)

// ---- 补默认截图记录：若截图表为空，写入用户 17 张正式产品图 ----
//      统一只存"相对 URL" /uploads/1.jpg ~ 17.jpg；
//      前台接口 /api/screenshots 会按当前访问域名自动拼成绝对地址，
//      所以 www.x123.wang / localhost:3000 / 任意新域名都能正确显示。
{
  const shotCount = db.prepare('SELECT COUNT(*) AS c FROM screenshots').get().c
  if (shotCount === 0) {
    const defaults = [
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
    const ins = db.prepare('INSERT INTO screenshots (url, title, sort_order) VALUES (?, ?, ?)')
    for (let i = 0; i < defaults.length; i++) ins.run(defaults[i][0], defaults[i][1], i)
    console.log(`       screenshots 写入 ${defaults.length} 条默认截图记录`)
  } else {
    console.log(`       screenshots 已有 ${shotCount} 条，保持原样`)
  }
}

db.exec(`CREATE TABLE IF NOT EXISTS contacts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  contact TEXT NOT NULL,
  message TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  is_read INTEGER NOT NULL DEFAULT 0
);`)
try { db.exec(`CREATE INDEX IF NOT EXISTS idx_contacts_created ON contacts(created_at);`) } catch(e){}

// ========================================================
//  4) admin_users + 默认账号 admin/admin123
// ========================================================
console.log('[4/7] 建 admin_users 表 + 默认 admin 账号 ...')
db.exec(`CREATE TABLE IF NOT EXISTS admin_users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  nickname TEXT NOT NULL DEFAULT '',
  role TEXT NOT NULL DEFAULT 'admin',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  last_login_at TEXT DEFAULT NULL,
  last_login_ip TEXT DEFAULT NULL,
  status INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_admin_users_username ON admin_users(username);`)

const adminCount = db.prepare('SELECT COUNT(*) AS c FROM admin_users').get().c
if (adminCount === 0) {
  const hash = bcrypt.hashSync('admin123', 10)
  const now = new Date().toISOString()
  db.prepare(`INSERT INTO admin_users
    (username, password_hash, nickname, role, created_at, updated_at, status)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `).run('admin', hash, '超级管理员', 'admin', now, now, 1)
  console.log('       创建默认管理员：admin / admin123')
} else {
  console.log(`       admin_users 已有 ${adminCount} 个账号，保留原账号`)
}

// ========================================================
//  5) ai_configs 默认配置（确保分类行业资讯存在）
// ========================================================
console.log('[5/7] 建 ai_configs 表 ...')
db.exec(`CREATE TABLE IF NOT EXISTS ai_configs (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  provider TEXT NOT NULL DEFAULT 'deepseek',
  api_base TEXT NOT NULL DEFAULT 'https://api.deepseek.com',
  api_key TEXT NOT NULL DEFAULT '',
  model TEXT NOT NULL DEFAULT 'deepseek-chat',
  temperature REAL NOT NULL DEFAULT 0.7,
  max_tokens INTEGER NOT NULL DEFAULT 2000,
  system_prompt TEXT NOT NULL DEFAULT '',
  default_topic_hint TEXT NOT NULL DEFAULT '',
  default_category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  default_tags TEXT NOT NULL DEFAULT '[]',
  default_status INTEGER NOT NULL DEFAULT 1,
  enabled INTEGER NOT NULL DEFAULT 0
)`)

const aic = db.prepare('SELECT id FROM ai_configs WHERE id = 1').get()
if (!aic) {
  const defaultPrompt = [
    '你是 ChatPulse 企业级 IM 系统的官方博客专栏作者，同时也是企业 SaaS、通讯软件、私有化部署、数字办公领域的资深编辑。',
    '要求：',
    '1. 输出一篇原创、通顺、逻辑清晰的中文资讯文章，围绕企业 IM、即时通讯系统、团队沟通效率提升、私有化部署、安全合规、AI + IM 结合、中小企业数字化转型、源码服务等相关主题。',
    '2. 结构：开头引入背景（2 段），主体干货点分 3-4 个小标题展开，结尾总结。',
    '3. 字数 1200-1800 字。',
    '4. 严禁出现任何关于 ChatPulse 竞品（钉钉、企业微信、飞书等）的负面评价或不实对比，保持中立专业。',
    '5. 输出仅包含文章正文 HTML（<p>、<h3>、<ul> 等简单标签），不要输出 markdown 标记、不要输出好的或以下是文章等非正文内容。'
  ].join('\n')
  // 确保分类 行业资讯
  let catId = (db.prepare("SELECT id FROM categories WHERE name='行业资讯'").get() || {}).id
  if (!catId) {
    const info = db.prepare("INSERT INTO categories (name) VALUES ('行业资讯')").run()
    catId = info.lastInsertRowid
  }
  db.prepare(`INSERT INTO ai_configs
    (id, provider, api_base, api_key, model, temperature, max_tokens, system_prompt,
     default_topic_hint, default_category_id, default_tags, default_status, enabled)
    VALUES (1,'deepseek','https://api.deepseek.com','','deepseek-chat',0.7,2400,?,
            '企业IM、私有化部署、AI 赋能沟通、团队数字化、通讯安全合规', ?, '["行业观察","数字化转型"]', 1, 0)
  `).run(defaultPrompt, catId)
  console.log('       ai_configs 插入默认值（deepseek）')
}

// ========================================================
//  6) ai_job_configs
// ========================================================
console.log('[6/7] 建 ai_job_configs 表 ...')
db.exec(`CREATE TABLE IF NOT EXISTS ai_job_configs (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  enabled INTEGER NOT NULL DEFAULT 0,
  cron_expr TEXT NOT NULL DEFAULT '0 9 * * *',
  max_articles_per_run INTEGER NOT NULL DEFAULT 1,
  auto_publish INTEGER NOT NULL DEFAULT 1,
  last_run_at TEXT DEFAULT NULL,
  next_run_at TEXT DEFAULT NULL
)`)
const ajc = db.prepare('SELECT id FROM ai_job_configs WHERE id = 1').get()
if (!ajc) {
  db.prepare(`INSERT INTO ai_job_configs
    (id, enabled, cron_expr, max_articles_per_run, auto_publish, last_run_at, next_run_at)
    VALUES (1, 0, '0 9 * * *', 1, 1, NULL, NULL)`).run()
  console.log('       ai_job_configs 插入默认值（每天 09:00，禁用）')
}

// ========================================================
//  7) ai_job_runs
// ========================================================
console.log('[7/7] 建 ai_job_runs 表 ...')
db.exec(`CREATE TABLE IF NOT EXISTS ai_job_runs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  started_at TEXT NOT NULL,
  finished_at TEXT DEFAULT NULL,
  status INTEGER NOT NULL DEFAULT 0,
  articles_count INTEGER NOT NULL DEFAULT 0,
  error_message TEXT NOT NULL DEFAULT '',
  trigger_type TEXT NOT NULL DEFAULT 'cron'
);
CREATE INDEX IF NOT EXISTS idx_ai_job_runs_started ON ai_job_runs(started_at);
CREATE INDEX IF NOT EXISTS idx_ai_job_runs_status ON ai_job_runs(status);`)

// ========================================================
//  完成验证
// ========================================================
console.log('\n---------- 验证表结构 ----------')
const tables = db.prepare("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").all()
for (const t of tables) console.log('  +', t.name)

console.log('\n---------- admin_users ----------')
const users = db.prepare('SELECT id, username, role, status FROM admin_users').all()
for (const u of users) console.log(`  #${u.id}  ${u.username}  (role=${u.role}, enabled=${u.status})`)
const u = db.prepare('SELECT password_hash FROM admin_users WHERE username=?').get('admin')
if (u) {
  const ok = bcrypt.compareSync('admin123', u.password_hash)
  console.log(`  admin123 密码校验: ${ok ? 'PASS (bcrypt)' : 'FAIL — 可能密码已自定义或哈希错误'}`)
}

// 设置 PRAGMA user_version 防止未来重复跑重复插入
db.pragma('user_version = 2')
console.log('\n[OK] 数据库修复完成。PRAGMA user_version = 2。直接登录后台即可：admin / admin123')
db.close()
