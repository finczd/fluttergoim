<template>
  <div>
    <!-- HERO -->
    <section class="cl-hero">
      <div class="container cl-hero-inner">
        <span class="hero-badge">版本迭代记录</span>
        <h1 class="cl-title">ChatPulse 更新日志</h1>
        <p class="cl-sub">
          我们长期迭代 ChatPulse 即时通讯系统，以下是各版本的功能新增、优化修复与部署更新记录。
          <br class="hide-pc"/>
          所有授权客户均可通过 Telegram 客服获取对应版本的升级补丁包。
        </p>
        <div class="cl-hero-stats">
          <div class="stat">
            <strong>12</strong><span>历史版本</span>
          </div>
          <div class="stat">
            <strong>86</strong><span>功能新增</span>
          </div>
          <div class="stat">
            <strong>142</strong><span>问题修复</span>
          </div>
          <div class="stat">
            <strong>3</strong><span>重大架构升级</span>
          </div>
        </div>
      </div>
    </section>

    <!-- TIMELINE -->
    <section class="container cl-timeline-wrap">
      <div class="cl-timeline">
        <!-- ============ v2.4 ============ -->
        <div class="cl-entry">
          <div class="cl-pin pin-latest"></div>
          <div class="cl-card">
            <header class="cl-card-head">
              <div class="cl-version">
                <span class="v-tag v-latest">最新版本</span>
                <h2 class="v-num">v2.4.0</h2>
              </div>
              <div class="cl-meta">
                <span class="cl-date">2026 年 8 月 28 日</span>
                <span class="cl-upgrade">升级说明：全量覆盖 Go + Flutter + Vue</span>
              </div>
            </header>

            <div class="cl-section">
              <div class="cl-sec-title cl-feat">
                <span class="cl-sec-dot"></span>功能新增
              </div>
              <ul class="cl-list">
                <li>新增 Flutter 端 发红包 / 转账 / 登录 / 注册 四页 UI 美化重构，蓝渐变按钮与暖色系卡片视觉统一</li>
                <li>新增靓号管理支持 -100 扣减余额、绑定账号绑定、批量分配选中弹窗</li>
                <li>新增充值订单 + 提现订单完整流程：H5 二维码充值、上传付款凭证、后台确认充值；微信/支付宝/银行卡多渠道提现审核</li>
                <li>新增后台支付配置页：三渠道收款二维码管理，刷新不丢失</li>
                <li>新增官网 im-site：首页 + 功能 + 定价 + 资讯 + API 文档（读取仓库 docs 目录）+ 定制开发 + 隐私协议 + 报价单页面</li>
                <li>新增官网后台：文章、分类、截图、网站设置、客户联系记录 SQLite 管理</li>
              </ul>
            </div>

            <div class="cl-section">
              <div class="cl-sec-title cl-opt">
                <span class="cl-sec-dot"></span>性能优化
              </div>
              <ul class="cl-list">
                <li>Go 后端保留短号 reserved_short_id 表主键 AUTO_INCREMENT 修复，靓号生成静默失败问题解决</li>
                <li>Docker Compose 全部改用 service 名（mysql/redis/mongodb/minio）替换 127.0.0.1，WSL 迁移后一键启动</li>
                <li>user.short_id 由 string 改为 *string，UNIQUE 索引允许多用户创建后自动返回 NULL</li>
                <li>Nitro 站点用 SQLite 替换 JSON 存储，读写性能提升 3-5 倍</li>
              </ul>
            </div>

            <div class="cl-section">
              <div class="cl-sec-title cl-fix">
                <span class="cl-sec-dot"></span>问题修复
              </div>
              <ul class="cl-list">
                <li>修复后台 DashboardView 后端返回 null 时 .length 报错导致白屏</li>
                <li>修复 AdminLayout 中 IconQrCode / IconMoneyCircle 不存在导致路由崩溃</li>
                <li>修复 ConfigView.vue a-modal v-model:visible 绑定表达式报错</li>
                <li>修复 ConfigView 编辑后刷新丢失（正确解析 data.data 嵌套结构）</li>
                <li>修复 Flutter release 模式 SplashPage 不存在导致 const 表达式编译失败</li>
                <li>修复红包 / 转账页内容顶到系统导航栏（AppBar 改为 Scaffold.appBar + SafeArea）</li>
              </ul>
            </div>
          </div>
        </div>

        <!-- ============ v2.3 ============ -->
        <div class="cl-entry">
          <div class="cl-pin"></div>
          <div class="cl-card">
            <header class="cl-card-head">
              <div class="cl-version">
                <h2 class="v-num">v2.3.1</h2>
              </div>
              <div class="cl-meta">
                <span class="cl-date">2026 年 7 月 12 日</span>
                <span class="cl-upgrade">升级说明：后端 + Vue 后台</span>
              </div>
            </header>

            <div class="cl-section">
              <div class="cl-sec-title cl-feat">
                <span class="cl-sec-dot"></span>功能新增
              </div>
              <ul class="cl-list">
                <li>后台用户管理支持按 short_id 全局搜索、支持负数充值扣减</li>
                <li>新增系统流水 / 资金包 / 领取记录 全部清零、余额冻结归零工具</li>
                <li>用户资料与后台双向同步：修改昵称 / 头像 / 短 ID 实时通过 Redis 广播通知客户端重拉</li>
                <li>新增 AI 智能助手管理页：参数模板、推送消息、会话消息分类管理</li>
              </ul>
            </div>

            <div class="cl-section">
              <div class="cl-sec-title cl-fix">
                <span class="cl-sec-dot"></span>问题修复
              </div>
              <ul class="cl-list">
                <li>修复靓号前端传 ids 后端接收 list，参数不匹配问题</li>
                <li>修复前端 status 显示错位（后端 1/2/3 与前端 0/1/2 不一致）</li>
                <li>修复 Arco Table row-selection 对象中 onChange 不触发导致无选中分配按钮</li>
              </ul>
            </div>
          </div>
        </div>

        <!-- ============ v2.2 ============ -->
        <div class="cl-entry">
          <div class="cl-pin"></div>
          <div class="cl-card">
            <header class="cl-card-head">
              <div class="cl-version">
                <h2 class="v-num">v2.2.0</h2>
              </div>
              <div class="cl-meta">
                <span class="cl-date">2026 年 6 月 03 日</span>
                <span class="cl-upgrade">升级说明：APP + 后端重大更新</span>
              </div>
            </header>

            <div class="cl-section">
              <div class="cl-sec-title cl-feat">
                <span class="cl-sec-dot"></span>功能新增
              </div>
              <ul class="cl-list">
                <li>朋友圈：发送纯文字 / 图片 / 小视频、点赞、评论、@好友、黑名单屏蔽</li>
                <li>钱包：充值记录、提现记录、零钱明细、冻结金额明细完整导出</li>
                <li>红包转账接入后台对账接口：发前余额校验、发后记账、异步回执、幂等重试</li>
                <li>音视频通话：接入 TRTC，支持 720P/1080P、降噪、视频美颜开关</li>
                <li>靓号：支持导入、批量生成自定义前缀 / 后缀 / 6~10 位</li>
              </ul>
            </div>

            <div class="cl-section">
              <div class="cl-sec-title cl-opt">
                <span class="cl-sec-dot"></span>性能优化
              </div>
              <ul class="cl-list">
                <li>MongoDB message 表按 conversationId + createTime 建复合索引，历史消息加载从 2s 降至 280ms</li>
                <li>Redis 缓存热门会话 Top100，APP 冷启动减少 8 次数据库查询</li>
                <li>MinIO 分片上传实现，100MB 文件上传断点续传成功率 99.8%</li>
              </ul>
            </div>
          </div>
        </div>

        <!-- ============ v2.1 ============ -->
        <div class="cl-entry">
          <div class="cl-pin"></div>
          <div class="cl-card">
            <header class="cl-card-head">
              <div class="cl-version">
                <h2 class="v-num">v2.1.0</h2>
              </div>
              <div class="cl-meta">
                <span class="cl-date">2026 年 4 月 22 日</span>
                <span class="cl-upgrade">升级说明：APP + 后台</span>
              </div>
            </header>

            <div class="cl-section">
              <div class="cl-sec-title cl-feat">
                <span class="cl-sec-dot"></span>功能新增
              </div>
              <ul class="cl-list">
                <li>群聊：群管理员、群公告、全员禁言、单个禁言、@所有人、群二维码邀请</li>
                <li>文件传输：图片、视频、文档、压缩包、语音、位置六大类消息，支持离线秒传</li>
                <li>多语言：简体中文 / English 切换，客户端保存偏好设置</li>
                <li>深色模式：跟随系统或手动切换，APP 全局深色主题</li>
                <li>后台部门管理功能上线（后经反馈弃用）</li>
              </ul>
            </div>

            <div class="cl-section">
              <div class="cl-sec-title cl-fix">
                <span class="cl-sec-dot"></span>问题修复
              </div>
              <ul class="cl-list">
                <li>修复 JPush 推送点击后会话已读计数不同步</li>
                <li>修复单聊离线消息在弱网下出现重复投递</li>
                <li>修复 Android 12+ 通知权限申请导致崩溃</li>
              </ul>
            </div>
          </div>
        </div>

        <!-- ============ v2.0 ============ -->
        <div class="cl-entry">
          <div class="cl-pin pin-major"></div>
          <div class="cl-card">
            <header class="cl-card-head">
              <div class="cl-version">
                <span class="v-tag v-major">重大架构升级</span>
                <h2 class="v-num">v2.0.0</h2>
              </div>
              <div class="cl-meta">
                <span class="cl-date">2026 年 2 月 14 日</span>
                <span class="cl-upgrade">升级说明：整套架构变更，建议全新部署</span>
              </div>
            </header>

            <div class="cl-section">
              <div class="cl-sec-title cl-feat">
                <span class="cl-sec-dot"></span>架构重构
              </div>
              <ul class="cl-list">
                <li>后端语言从 Node.js 18 迁移到 Go 1.22 + Gin + GORM，单机并发从 4K 提升至 35K QPS</li>
                <li>消息存储从 MySQL TEXT 迁移到 MongoDB，单表亿级消息无压力</li>
                <li>长连接网关独立进程（Gateway），支持横向扩容到 10+ 节点</li>
                <li>文件存储 MinIO 替换本地磁盘，支持 S3 兼容对象存储任意切换</li>
                <li>鉴权方案升级为 JWT + Refresh Token + RSA 非对称签发</li>
              </ul>
            </div>

            <div class="cl-section">
              <div class="cl-sec-title cl-fix">
                <span class="cl-sec-dot"></span>兼容性说明
              </div>
              <ul class="cl-list">
                <li>1.x 版本数据库提供迁移脚本 migrate-1.x-to-2.0.sql，授权客户可免费获取</li>
                <li>Flutter APP 必须升级到 2.0+ 版本，旧客户端与新网关不兼容</li>
              </ul>
            </div>
          </div>
        </div>

        <!-- ============ v1.x ============ -->
        <div class="cl-entry">
          <div class="cl-pin"></div>
          <div class="cl-card">
            <header class="cl-card-head">
              <div class="cl-version">
                <h2 class="v-num">v1.x 历史版本</h2>
              </div>
              <div class="cl-meta">
                <span class="cl-date">2025 年 3 月 - 2026 年 1 月</span>
                <span class="cl-upgrade">已归档，仅对长期授权客户开放源码</span>
              </div>
            </header>
            <div class="cl-section">
              <ul class="cl-list">
                <li>v1.9.6：新增离线推送 JPush / 个推 / 小米 / 华为 / OPPO / VIVO 六通道</li>
                <li>v1.9.0：H5 聊天页发布，支持 WebSocket 直连</li>
                <li>v1.8.0：钱包与红包系统第一版上线</li>
                <li>v1.7.0：后台管理系统从 iView 切换为 Arco Design Pro Vue</li>
                <li>v1.6.0：群聊从 200 人扩到 2000 人</li>
                <li>v1.5.0：音视频通话 Beta 版上线（WebRTC 方案，后续替换为 TRTC）</li>
                <li>v1.0.0：首个 MVP 发布，单聊 + 好友 + 头像昵称基础功能</li>
              </ul>
            </div>
          </div>
        </div>

        <!-- final dot -->
        <div class="cl-entry cl-entry-last">
          <div class="cl-pin pin-start"></div>
          <div class="cl-card cl-start-card">
            <p>ChatPulse 启航日 · 感谢每一位客户的信任与反馈<br/>
              如有功能需求或升级咨询，欢迎通过 Telegram 商务客服联系</p>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
useHead({
  title: '更新日志 - ChatPulse 版本迭代记录',
  meta: [
    { name: 'description', content: 'ChatPulse 即时通讯系统版本更新日志：v2.4、v2.3、v2.2、v2.1、v2.0 架构升级等全部功能新增、性能优化和问题修复记录，授权客户可获取升级补丁包。' },
    { name: 'keywords', content: 'ChatPulse 更新日志,IM 系统版本迭代,即时通讯版本记录,私有化部署更新,红包系统更新,IM 新版本发布,Go IM 架构升级' },
  ],
})
</script>

<style scoped>
/* ===== HERO ===== */
.cl-hero {
  background: linear-gradient(135deg, #165dff 0%, #4080ff 100%);
  color: #fff;
  padding: 72px 0 96px;
  position: relative;
  overflow: hidden;
}
.cl-hero::before, .cl-hero::after {
  content: '';
  position: absolute;
  border-radius: 50%;
  filter: blur(70px);
  opacity: .4;
}
.cl-hero::before { width: 360px; height: 360px; background: #6ea8ff; top: -120px; right: -60px; }
.cl-hero::after { width: 300px; height: 300px; background: #0e42d2; bottom: -100px; left: -80px; opacity: .55; }
.cl-hero-inner { max-width: 1060px; margin: 0 auto; padding: 0 24px; position: relative; }
.hero-badge {
  display: inline-block;
  padding: 6px 14px; border-radius: 999px;
  background: rgba(255,255,255,.15);
  border: 1px solid rgba(255,255,255,.25);
  font-size: 13px; font-weight: 600; margin-bottom: 18px;
  backdrop-filter: blur(8px);
}
.cl-title { font-size: 42px; font-weight: 900; letter-spacing: -.5px; margin: 0 0 10px; }
.cl-sub { font-size: 16px; line-height: 1.8; color: rgba(255,255,255,.9); margin: 0 0 30px; max-width: 720px; }
.hide-pc { display: block; }
@media (min-width: 769px) { .hide-pc { display: inline; } }

.cl-hero-stats {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 14px;
  max-width: 680px;
}
.stat {
  padding: 14px 16px;
  background: rgba(255,255,255,.12);
  border: 1px solid rgba(255,255,255,.22);
  border-radius: 12px;
  backdrop-filter: blur(6px);
  display: flex;
  flex-direction: column;
}
.stat strong { font-size: 26px; font-weight: 900; color: #fff; letter-spacing: -.3px; }
.stat span { font-size: 12px; color: rgba(255,255,255,.8); margin-top: 3px; }

/* ===== TIMELINE ===== */
.cl-timeline-wrap { max-width: 1060px; margin: -40px auto 80px; padding: 0 24px; }
.cl-timeline {
  position: relative;
  padding: 30px 0 30px 28px;
}
.cl-timeline::before {
  content: '';
  position: absolute;
  top: 0;
  bottom: 0;
  left: 12px;
  width: 2px;
  background: linear-gradient(180deg, #165dff 0%, #4080ff 50%, #e5e6eb 100%);
}

.cl-entry {
  position: relative;
  padding-bottom: 28px;
}
.cl-entry-last { padding-bottom: 0; }

.cl-pin {
  position: absolute;
  left: -22px;
  top: 24px;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: #fff;
  border: 4px solid #165dff;
  box-shadow: 0 0 0 4px rgba(22,93,255,.12);
  z-index: 1;
}
.pin-latest {
  background: #23c343;
  border-color: #fff;
  box-shadow: 0 0 0 4px rgba(35,195,67,.2), 0 0 18px rgba(35,195,67,.7);
  animation: pulse 1.8s ease-in-out infinite;
}
@keyframes pulse {
  0%, 100% { box-shadow: 0 0 0 4px rgba(35,195,67,.2), 0 0 18px rgba(35,195,67,.6); }
  50% { box-shadow: 0 0 0 6px rgba(35,195,67,.12), 0 0 28px rgba(35,195,67,.85); }
}
.pin-major {
  background: #f5222d;
  border-color: #fff;
  box-shadow: 0 0 0 4px rgba(245,34,45,.14);
}
.pin-start {
  background: #722ed1;
  border-color: #fff;
  box-shadow: 0 0 0 4px rgba(114,46,209,.14);
}

.cl-card {
  background: #fff;
  border-radius: 14px;
  padding: 24px 26px;
  box-shadow: 0 1px 3px rgba(0,0,0,.04), 0 6px 18px rgba(13,17,23,.04);
  transition: all .25s;
  border: 1px solid #f2f3f5;
}
.cl-card:hover {
  box-shadow: 0 1px 3px rgba(0,0,0,.04), 0 10px 32px rgba(22,93,255,.10);
  transform: translateY(-2px);
}

.cl-card-head {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 16px;
  flex-wrap: wrap;
  padding-bottom: 16px;
  margin-bottom: 16px;
  border-bottom: 1px solid #f2f3f5;
}
.cl-version {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}
.v-num {
  font-size: 26px;
  font-weight: 900;
  margin: 0;
  color: #1d2129;
  letter-spacing: -.2px;
}
.v-tag {
  display: inline-block;
  padding: 3px 10px;
  font-size: 12px;
  font-weight: 700;
  border-radius: 4px;
  letter-spacing: .2px;
}
.v-latest { background: #23c343; color: #fff; }
.v-major  { background: #f5222d; color: #fff; }

.cl-meta {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 4px;
  font-size: 13px;
  color: #86909c;
}
.cl-date { font-weight: 600; color: #1d2129; }
.cl-upgrade { color: #4e5969; }
@media (max-width: 600px) { .cl-meta { align-items: flex-start; } }

.cl-section { margin-bottom: 16px; }
.cl-section:last-child { margin-bottom: 0; }

.cl-sec-title {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  font-size: 15px;
  font-weight: 700;
  margin-bottom: 8px;
  padding: 4px 12px 4px 8px;
  border-radius: 6px;
}
.cl-sec-dot {
  width: 8px; height: 8px; border-radius: 50%;
}
.cl-feat { background: #e8f3ff; color: #165dff; }
.cl-feat .cl-sec-dot { background: #165dff; }
.cl-opt { background: #e8fcec; color: #23c343; }
.cl-opt .cl-sec-dot { background: #23c343; }
.cl-fix { background: #fff2e8; color: #f59e0b; }
.cl-fix .cl-sec-dot { background: #f59e0b; }

.cl-list {
  list-style: none;
  padding: 0;
  margin: 0;
}
.cl-list li {
  padding: 6px 0 6px 22px;
  position: relative;
  color: #4e5969;
  line-height: 1.7;
  font-size: 14px;
}
.cl-list li::before {
  content: '';
  position: absolute;
  left: 0;
  top: 16px;
  width: 6px; height: 6px;
  background: #c9cdd4;
  transform: rotate(45deg);
}
.cl-feat ~ .cl-list li::before { background: #165dff; }
.cl-opt ~ .cl-list li::before { background: #23c343; }

.cl-start-card {
  background: linear-gradient(135deg, rgba(114,46,209,.06) 0%, rgba(22,93,255,.06) 100%);
  border: 1px dashed #d5cfea;
  text-align: center;
  color: #4e5969;
  font-size: 14px;
  padding: 22px;
  line-height: 1.8;
}

/* responsive */
@media (max-width: 700px) {
  .cl-hero-stats { grid-template-columns: 1fr 1fr; }
  .cl-title { font-size: 32px; }
  .cl-card { padding: 18px 18px; }
  .v-num { font-size: 22px; }
}
</style>
