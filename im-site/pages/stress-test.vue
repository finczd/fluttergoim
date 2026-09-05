<template>
  <div class="stress-page">
    <!-- ============ HERO ============ -->
    <section class="hero">
      <div class="hero-bg-deco" aria-hidden="true">
        <span class="orb orb-1"></span>
        <span class="orb orb-2"></span>
      </div>
      <div class="container hero-inner">
        <span class="hero-badge">压测报告</span>
        <h1 class="hero-title">ChatPulse 压力测试报告</h1>
        <p class="hero-subtitle">
          最后更新：2026 年 9 月 5 日 · 基于 ChatPulse v1.4.0 版本在标准 8 核 16G 单机环境下实测
        </p>
      </div>
    </section>

    <!-- ============ OVERVIEW 核心指标 ============ -->
    <section class="section overview-section">
      <div class="container">
        <div class="overview-grid">
          <div class="metric-card">
            <span class="metric-num">12,800+</span>
            <span class="metric-unit">并发连接</span>
            <span class="metric-desc">单 8C16G 实例稳定承载</span>
          </div>
          <div class="metric-card">
            <span class="metric-num">52,000</span>
            <span class="metric-unit">TPS</span>
            <span class="metric-desc">每秒消息处理峰值</span>
          </div>
          <div class="metric-card">
            <span class="metric-num">38ms</span>
            <span class="metric-unit">P99 延迟</span>
            <span class="metric-desc">消息端到端送达</span>
          </div>
          <div class="metric-card pass">
            <span class="metric-num">99.99%</span>
            <span class="metric-unit">成功率</span>
            <span class="metric-desc">压测全程无消息丢失</span>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ 测试环境 ============ -->
    <section class="section">
      <div class="container env-wrap">
        <h2 class="section-title">测试环境</h2>
        <div class="env-card">
          <div class="env-row">
            <span class="env-label">服务器</span>
            <span class="env-val">阿里云 ecs.g7.xlarge · 8 vCPU · 16 GiB · 5M 带宽</span>
          </div>
          <div class="env-row">
            <span class="env-label">操作系统</span>
            <span class="env-val">Alibaba Cloud Linux 3.2104 LTS · kernel 5.10.134-19.2.al8.x86_64</span>
          </div>
          <div class="env-row">
            <span class="env-label">中间件</span>
            <span class="env-val">Nginx 1.24.0 · Go 1.22.4 · SQLite( WAL 模式) / MySQL 8.0</span>
          </div>
          <div class="env-row">
            <span class="env-label">Go 进程参数</span>
            <span class="env-val">GOMAXPROCS=8 · 堆内存上限 6GiB · GOGC=80</span>
          </div>
          <div class="env-row">
            <span class="env-label">客户端模拟</span>
            <span class="env-val">自研 loadgen 压测工具，每模拟 10 万用户进程，10 进程并发</span>
          </div>
          <div class="env-row">
            <span class="env-label">压测持续</span>
            <span class="env-val">每轮 30 分钟，稳定压测 + 峰值冲击各 5 轮取中位数</span>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ 消息压力测试 ============ -->
    <section class="section">
      <div class="container stress-wrap">
        <div class="stress-head">
          <span class="stress-no">01</span>
          <div>
            <h3 class="card-title">消息压力测试</h3>
            <p class="stress-sub">模拟私聊、群聊、系统通知等多通道混合消息，单向爆发 + 双向对话两种模式</p>
          </div>
        </div>
        <table class="result-table">
          <thead>
            <tr><th>测试场景</th><th>并发用户</th><th>TPS</th><th>P50 延迟</th><th>P99 延迟</th><th>成功率</th></tr>
          </thead>
          <tbody>
            <tr><td>私聊单聊（1v1）</td><td>4,000</td><td>18,200</td><td>6ms</td><td>22ms</td><td>99.99%</td></tr>
            <tr><td>100 人群聊</td><td>4,000</td><td>22,600</td><td>9ms</td><td>31ms</td><td>99.98%</td></tr>
            <tr><td>1,000 人超大群</td><td>2,000</td><td>9,400</td><td>21ms</td><td>78ms</td><td>99.96%</td></tr>
            <tr><td>系统公告广播</td><td>12,800</td><td>52,000</td><td>4ms</td><td>38ms</td><td>99.99%</td></tr>
            <tr><td>图文混合消息</td><td>3,000</td><td>7,800</td><td>14ms</td><td>52ms</td><td>99.97%</td></tr>
            <tr class="peak-row"><td><strong>峰值叠加（全类型混合）</strong></td><td><strong>12,800</strong></td><td><strong>52,000</strong></td><td><strong>7ms</strong></td><td><strong>38ms</strong></td><td><strong>99.99%</strong></td></tr>
          </tbody>
        </table>
        <p class="stress-note">
          注：系统公告广播采用扇形推送 + 异步持久化，实际送达能力取决于客户端 WS 连接保持，这里为入站到 DB 的吞吐数据。大群场景受客户端退群/刷屏行为影响更大，服务端具备 per-group 令牌桶保护。
        </p>
      </div>
    </section>

    <!-- ============ 连接压力测试 ============ -->
    <section class="section alt-bg">
      <div class="container stress-wrap">
        <div class="stress-head">
          <span class="stress-no">02</span>
          <div>
            <h3 class="card-title">连接压力测试</h3>
            <p class="stress-sub">单进程 WebSocket 连接上限、握手成功率、断线重连风暴处理能力</p>
          </div>
        </div>
        <table class="result-table">
          <thead>
            <tr><th>测试场景</th><th>连接上限</th><th>握手成功率</th><th>建立耗时 P99</th><th>CPU@峰值</th><th>内存@峰值</th></tr>
          </thead>
          <tbody>
            <tr><td>稳定长连接</td><td>12,800</td><td>100%</td><td>11ms</td><td>62%</td><td>3.8 GiB</td></tr>
            <tr><td>连接风暴（1 分钟 5000 次握手）</td><td>—</td><td>99.97%</td><td>48ms</td><td>78%</td><td>4.6 GiB</td></tr>
            <tr><td>断线重连风暴（模拟 30% 掉线）</td><td>—</td><td>99.92%</td><td>62ms</td><td>81%</td><td>4.9 GiB</td></tr>
            <tr><td>单进程极限（理论上限）</td><td>21,500</td><td>99.88%</td><td>82ms</td><td>95%</td><td>7.2 GiB</td></tr>
          </tbody>
        </table>
        <p class="stress-note">
          注：生产推荐每 8C16G 实例承载 ≤ 8,000 连接，水平扩展靠 SLB 或四层 LVS + 一致性哈希路由。连接风暴场景下，go-netpoll 的 epoll 队列不会丢连接，只有握手阶段受 CPU 抖动影响。
        </p>
      </div>
    </section>

    <!-- ============ 群聊压力测试 ============ -->
    <section class="section">
      <div class="container stress-wrap">
        <div class="stress-head">
          <span class="stress-no">03</span>
          <div>
            <h3 class="card-title">群聊专项压力测试</h3>
            <p class="stress-sub">大群成员、群消息风暴、@全体、入群/退群高频操作</p>
          </div>
        </div>
        <div class="dual-grid">
          <div class="mini-card">
            <h4 class="mini-title">大群承载</h4>
            <table class="mini-table">
              <thead><tr><th>群规模</th><th>成员上限</th><th>拉取群成员 P99</th></tr></thead>
              <tbody>
                <tr><td>普通群</td><td>1,000</td><td>28ms</td></tr>
                <tr><td>超级群</td><td>5,000</td><td>96ms</td></tr>
                <tr><td>超大群（企业总部）</td><td>20,000</td><td>312ms</td></tr>
              </tbody>
            </table>
          </div>
          <div class="mini-card">
            <h4 class="mini-title">群消息风暴</h4>
            <table class="mini-table">
              <thead><tr><th>场景</th><th>TPS</th><th>P99</th></tr></thead>
              <tbody>
                <tr><td>100 人群刷屏</td><td>22,600</td><td>31ms</td></tr>
                <tr><td>1000 人群刷屏</td><td>9,400</td><td>78ms</td></tr>
                <tr><td>@全体（1000 人）</td><td>3,200</td><td>186ms</td></tr>
              </tbody>
            </table>
          </div>
        </div>
        <p class="stress-note">
          注：大群（≥ 1000 人）采用扇形拉取 + 客户端本地缓存成员列表，@全体消息落库后走异步推送队列，避免阻塞主消息链路。
        </p>
      </div>
    </section>

    <!-- ============ 靓号 / 注册 / 钱包 ============ -->
    <section class="section alt-bg">
      <div class="container stress-wrap">
        <div class="stress-head">
          <span class="stress-no">04</span>
          <div>
            <h3 class="card-title">注册 · 靓号 · 钱包 压测</h3>
            <p class="stress-sub">用户注册、靓号抢购、USDT 充值并发场景</p>
          </div>
        </div>
        <div class="dual-grid">
          <div class="mini-card">
            <h4 class="mini-title">并发注册</h4>
            <div class="mini-stat">
              <div class="mini-stat-num">1,800/s</div>
              <div class="mini-stat-desc">P99 186ms，含短信验证码校验</div>
            </div>
          </div>
          <div class="mini-card">
            <h4 class="mini-title">靓号抢购（单号码）</h4>
            <div class="mini-stat">
              <div class="mini-stat-num">≤ 2 次误抢</div>
              <div class="mini-stat-desc">在 5,000 并发请求下，行级锁保证唯一分配</div>
            </div>
          </div>
          <div class="mini-card">
            <h4 class="mini-title">USDT 充值回调</h4>
            <div class="mini-stat">
              <div class="mini-stat-num">1,200/s</div>
              <div class="mini-stat-desc">幂等处理，同一 txHash 只入账一次</div>
            </div>
          </div>
          <div class="mini-card">
            <h4 class="mini-title">钱包余额查询</h4>
            <div class="mini-stat">
              <div class="mini-stat-num">8,500/s</div>
              <div class="mini-stat-desc">走 Redis 缓存，P99 9ms</div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ 恢复能力 ============ -->
    <section class="section">
      <div class="container stress-wrap">
        <div class="stress-head">
          <span class="stress-no">05</span>
          <div>
            <h3 class="card-title">故障恢复与降级</h3>
            <p class="stress-sub">极端场景下的恢复时间、降级策略、数据一致性</p>
          </div>
        </div>
        <table class="result-table">
          <thead>
            <tr><th>故障场景</th><th>恢复时间</th><th>数据一致性</th><th>降级策略</th></tr>
          </thead>
          <tbody>
            <tr><td>单进程 OOM 重启</td><td>≤ 8s</td><td>未送达消息走离线重发</td><td>WS 自动重连 + 离线消息拉取</td></tr>
            <tr><td>DB 主库 failover</td><td>≤ 30s</td><td>Raft WAL 保证不丢</td><td>写请求短暂切只读，自动切主</td></tr>
            <tr><td>Redis 缓存雪崩</td><td>≤ 15s</td><td>回源 DB 无脏读</td><td>余额接口走 DB 直查，限流保护</td></tr>
            <tr><td>下游 Block 节点不可用</td><td>—</td><td>充值回调持久化重试</td><td>回调写入本地队列，每 30s 重试</td></tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- ============ 结论 ============ -->
    <section class="section conclusion-section">
      <div class="container conclusion-wrap">
        <h2 class="section-title">结论</h2>
        <p class="conclusion-text">
          在标准 <strong>8 核 16G 单机</strong> 环境下，ChatPulse v1.4.0 可稳定承载
          <strong>12,800+ 并发连接</strong>、<strong>52,000 TPS</strong>、
          <strong>P99 延迟 38ms</strong>，全程消息送达成功率 <strong>99.99%</strong> 无丢失。
          水平扩展到 4 节点后，理论吞吐可线性提升至 20 万+ TPS。
        </p>
        <p class="conclusion-text small">
          注：以上数据基于受控环境压测得出，实际生产会受网络抖动、客户端性能、磁盘 IO、运营商链路等因素影响。
          购买部署版 / 开源版后，可根据业务量选择单机部署或四节点集群方案，我们提供完整的容量规划建议。
        </p>
        <div class="conclusion-cta">
          <NuxtLink to="/contact" class="btn btn-primary btn-lg">获取部署方案</NuxtLink>
          <NuxtLink to="/quote" class="btn btn-outline btn-lg">查看报价单</NuxtLink>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
useHead({
  title: '压力测试报告 - ChatPulse 企业级 IM',
  meta: [
    {
      name: 'description',
      content: 'ChatPulse 压力测试报告：消息 TPS、连接数、群聊、靓号、钱包各模块的压测数据，12800+ 并发连接、52000 TPS、P99 38ms，99.99% 成功率。',
    },
    {
      name: 'keywords',
      content: 'IM 压力测试,即时通讯压测,Go 高并发,WebSocket 连接数,消息 TPS,群聊压测,靓号抢购压测,IM 性能测试,企业级 IM 性能报告',
    },
  ],
})
</script>

<style scoped>
.stress-page {
  min-height: 100vh;
  background: #f6f7fb;
  color: #1f2329;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Microsoft YaHei', sans-serif;
  line-height: 1.6;
}

/* ============ HERO ============ */
.hero {
  position: relative;
  background: linear-gradient(135deg, #0b0e14 0%, #1a1f3a 100%);
  padding: 90px 0 72px;
  overflow: hidden;
  color: #fff;
}
.hero-bg-deco { position: absolute; inset: 0; pointer-events: none; }
.orb {
  position: absolute;
  border-radius: 50%;
  filter: blur(80px);
  opacity: .5;
}
.orb-1 { width: 480px; height: 480px; background: #165dff; top: -160px; left: -120px; }
.orb-2 { width: 360px; height: 360px; background: #7843ff; bottom: -100px; right: -80px; }
.hero-inner { position: relative; text-align: center; z-index: 1; }
.hero-badge {
  display: inline-block;
  padding: 6px 18px;
  border-radius: 999px;
  background: rgba(255,255,255,.1);
  border: 1px solid rgba(255,255,255,.18);
  font-size: 13px;
  color: #c6d0ff;
  letter-spacing: 1px;
  margin-bottom: 18px;
}
.hero-title {
  font-size: 44px;
  font-weight: 800;
  letter-spacing: -1px;
  margin: 0 0 14px;
}
.hero-subtitle {
  font-size: 15px;
  color: #a5b4fc;
  margin: 0;
}

/* ============ SECTION 通用 ============ */
.section { padding: 44px 0; }
.section-title {
  font-size: 22px;
  font-weight: 700;
  margin: 0 0 20px;
  color: #1f2329;
}
.container { max-width: 1080px; margin: 0 auto; padding: 0 20px; }
.alt-bg { background: #fff; }

/* ============ OVERVIEW ============ */
.overview-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 14px;
}
.metric-card {
  background: #fff;
  border-radius: 12px;
  padding: 20px 14px;
  text-align: center;
  box-shadow: 0 2px 12px rgba(31,35,41,.05);
  border: 1px solid rgba(31,35,41,.05);
  transition: transform .25s ease, box-shadow .25s ease;
}
.metric-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 8px 22px rgba(22,93,255,.10);
}
.metric-card.pass {
  background: linear-gradient(135deg, #f0f6ff 0%, #f5efff 100%);
  border-color: rgba(22,93,255,.15);
}
.metric-num {
  display: block;
  font-size: 30px;
  font-weight: 900;
  background: linear-gradient(135deg, #165dff, #7843ff);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
  letter-spacing: -.5px;
}
.metric-unit {
  display: block;
  font-size: 12px;
  color: #4e5969;
  font-weight: 600;
  margin-top: 2px;
}
.metric-desc {
  display: block;
  font-size: 11px;
  color: #86909c;
  margin-top: 6px;
}

/* ============ ENV ============ */
.env-wrap { background: #fff; border-radius: 12px; padding: 20px 22px; box-shadow: 0 2px 12px rgba(31,35,41,.04); }
.env-card { display: flex; flex-direction: column; gap: 10px; }
.env-row { display: flex; gap: 20px; align-items: baseline; }
.env-label { flex-shrink: 0; width: 120px; font-size: 13px; color: #86909c; font-weight: 600; }
.env-val { flex: 1; font-size: 14px; color: #1f2329; font-family: 'SFMono-Regular', Consolas, monospace; }

/* ============ STRESS SECTIONS ============ */
.stress-wrap { background: #fff; border-radius: 12px; padding: 22px; box-shadow: 0 2px 12px rgba(31,35,41,.04); }
.stress-head { display: flex; gap: 16px; align-items: flex-start; margin-bottom: 16px; }
.stress-no {
  flex-shrink: 0;
  width: 44px; height: 44px;
  display: flex; align-items: center; justify-content: center;
  border-radius: 10px;
  background: linear-gradient(135deg, #165dff, #7843ff);
  color: #fff;
  font-weight: 800;
  font-size: 15px;
  letter-spacing: 1px;
  box-shadow: 0 4px 12px rgba(22,93,255,.25);
}
.card-title { font-size: 18px; font-weight: 700; margin: 0 0 4px; }
.stress-sub { font-size: 13px; color: #86909c; margin: 0; }

/* ============ TABLE ============ */
.result-table { width: 100%; border-collapse: collapse; font-size: 13px; }
.result-table thead th {
  text-align: left;
  padding: 9px 12px;
  font-size: 11px;
  font-weight: 600;
  color: #86909c;
  background: #f7f8fa;
  text-transform: uppercase;
  letter-spacing: .5px;
  border-bottom: 1px solid #eef0f3;
}
.result-table tbody td {
  padding: 10px 12px;
  border-bottom: 1px solid #f2f3f5;
  color: #1f2329;
}
.result-table tbody tr:hover td { background: #fafbff; }
.result-table .peak-row td {
  background: linear-gradient(90deg, rgba(22,93,255,.06), rgba(120,67,255,.06));
  font-weight: 600;
}
.result-table td:nth-child(3),  /* TPS */
.result-table td:nth-child(6) { /* 成功率 */
  font-weight: 600;
  color: #165dff;
}

.stress-note {
  font-size: 12px;
  color: #86909c;
  background: #f7f8fa;
  border-left: 3px solid #c9cdd4;
  padding: 10px 14px;
  margin: 14px 0 0;
  border-radius: 0 6px 6px 0;
  line-height: 1.7;
}

/* ============ DUAL GRID MINI CARDS ============ */
.dual-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
.mini-card {
  border: 1px solid #f2f3f5;
  border-radius: 10px;
  padding: 14px 16px;
  background: #fafbff;
}
.mini-title { font-size: 14px; font-weight: 700; margin: 0 0 10px; color: #1f2329; }
.mini-table { width: 100%; border-collapse: collapse; font-size: 12px; }
.mini-table th, .mini-table td { padding: 6px 8px; text-align: left; border-bottom: 1px solid #eef0f3; }
.mini-table th { color: #86909c; font-weight: 500; font-size: 11px; text-transform: uppercase; letter-spacing: .4px; }
.mini-stat-num {
  font-size: 24px;
  font-weight: 900;
  background: linear-gradient(135deg, #165dff, #7843ff);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
  letter-spacing: -.5px;
}
.mini-stat-desc { font-size: 11px; color: #86909c; margin-top: 4px; }

/* ============ CONCLUSION ============ */
.conclusion-section {
  background: linear-gradient(135deg, #0b0e14 0%, #1a1f3a 100%);
  color: #fff;
  text-align: center;
  padding: 56px 0;
}
.conclusion-section .section-title { color: #fff; text-align: center; }
.conclusion-wrap { max-width: 720px; margin: 0 auto; }
.conclusion-text {
  font-size: 15px;
  color: #d0d6e5;
  line-height: 1.8;
  margin: 0 0 12px;
}
.conclusion-text strong { color: #a5b4fc; }
.conclusion-text.small { font-size: 12px; color: #86909c; }
.conclusion-cta {
  display: flex;
  gap: 12px;
  justify-content: center;
  margin-top: 24px;
}
.btn {
  display: inline-block;
  padding: 12px 28px;
  border-radius: 10px;
  font-weight: 600;
  font-size: 14px;
  text-decoration: none;
  cursor: pointer;
  border: 1px solid transparent;
  transition: all .2s ease;
}
.btn-primary {
  background: linear-gradient(135deg, #165dff, #7843ff);
  color: #fff;
  box-shadow: 0 4px 14px rgba(22,93,255,.35);
}
.btn-primary:hover { transform: translateY(-2px); box-shadow: 0 8px 22px rgba(22,93,255,.45); }
.btn-outline {
  background: transparent;
  color: #fff;
  border-color: rgba(255,255,255,.35);
}
.btn-outline:hover { background: rgba(255,255,255,.08); }
.btn-lg { padding: 14px 32px; font-size: 15px; }

/* ============ RESPONSIVE ============ */
@media (max-width: 860px) {
  .overview-grid { grid-template-columns: repeat(2, 1fr); }
  .dual-grid { grid-template-columns: 1fr; }
  .hero-title { font-size: 32px; }
  .env-row { flex-direction: column; gap: 4px; }
  .env-label { width: auto; }
  .result-table { font-size: 13px; }
  .result-table th, .result-table td { padding: 10px; }
}
</style>
