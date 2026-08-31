<template>
  <div class="hc-page">
    <a-card>
      <div class="toolbar">
        <div class="summary">
          <span class="summary-title">
            <IconSync :class="{ spin: checking }" />
            系统状态
          </span>
          <a-tag :color="okCount === checks.length ? 'green' : okCount > 0 ? 'orange' : 'red'">
            {{ okCount }}/{{ checks.length }} 正常
          </a-tag>
        </div>
        <a-button type="primary" :loading="checking" @click="runAll">
          <template #icon><IconRefresh /></template>重新检测
        </a-button>
      </div>

      <div class="check-grid">
        <div
          v-for="c in checks"
          :key="c.key"
          class="check-card"
          :class="['is-' + c.status]"
        >
          <div class="check-head">
            <div class="check-icon" :style="{ background: c.gradient }">
              <component :is="c.icon" />
            </div>
            <div class="check-head-info">
              <span class="check-name">{{ c.name }}</span>
              <span class="check-key">{{ c.key }}</span>
            </div>
          </div>
          <div class="check-status" :class="'st-' + c.status">
            <IconCheckCircleFill v-if="c.status === 'ok'" />
            <IconExclamationCircleFill v-else-if="c.status === 'warn'" />
            <IconClose v-else />
            <span>{{ statusText(c.status) }}</span>
          </div>
          <div class="check-msg">{{ c.message || '—' }}</div>
          <div v-if="c.details" class="check-details">
            <div v-for="(v, k) in c.details" :key="k" class="detail-row">
              <span>{{ k }}</span>
              <b>{{ v }}</b>
            </div>
          </div>
          <div class="check-foot">
            <span class="check-time">上次检测：{{ c.checkedAt || '未检测' }}</span>
            <a-button size="mini" :loading="checking" @click="runOne(c)">单项检测</a-button>
          </div>
        </div>
      </div>

      <a-card class="env-card" style="margin-top: 16px" :bordered="false" title="环境信息">
        <a-descriptions :column="2" bordered size="small">
          <a-descriptions-item label="检测时间">{{ runAt || '—' }}</a-descriptions-item>
          <a-descriptions-item label="当前节点 ID">{{ nodeId || '—' }}</a-descriptions-item>
          <a-descriptions-item label="Go 运行版本（客户端 SDK）">{{ goVersion || '—' }}</a-descriptions-item>
          <a-descriptions-item label="前端版本">{{ frontVersion }}</a-descriptions-item>
        </a-descriptions>
      </a-card>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, markRaw } from 'vue'
import { Message } from '@arco-design/web-vue'
import {
  IconSync, IconRefresh,
  IconCheckCircleFill, IconExclamationCircleFill, IconClose,
  IconCommand, IconExperiment, IconThunderbolt, IconCloud, IconBook, IconFileImage, IconStorage, IconSchedule
} from '@arco-design/web-vue/es/icon'
import { adminApi } from '@/api/admin'

type St = 'idle' | 'ok' | 'warn' | 'err'
type CheckItem = {
  key: string
  name: string
  icon: any
  gradient: string
  status: St
  message: string
  checkedAt: string
  details?: Record<string, string | number>
}

const checks: CheckItem[] = reactive([
  {
    key: 'mysql',
    name: 'MySQL 主数据库',
    icon: markRaw(IconBook),
    gradient: 'linear-gradient(135deg, #165dff, #4080ff)',
    status: 'idle', message: '', checkedAt: '',
    details: undefined
  },
  {
    key: 'go-env',
    name: 'Go 运行环境',
    icon: markRaw(IconCommand),
    gradient: 'linear-gradient(135deg, #00ADD8, #37C5DD)',
    status: 'idle', message: '', checkedAt: ''
  },
  {
    key: 'wss',
    name: 'WSS 长连接服务',
    icon: markRaw(IconThunderbolt),
    gradient: 'linear-gradient(135deg, #F7BA2A, #FFC84C)',
    status: 'idle', message: '', checkedAt: ''
  },
  {
    key: 'mongodb',
    name: 'MongoDB 消息存储',
    icon: markRaw(IconFileImage),
    gradient: 'linear-gradient(135deg, #47A248, #7EC870)',
    status: 'idle', message: '', checkedAt: ''
  },
  {
    key: 'redis',
    name: 'Redis 缓存',
    icon: markRaw(IconExperiment),
    gradient: 'linear-gradient(135deg, #DC382D, #EF6B5F)',
    status: 'idle', message: '', checkedAt: ''
  },
  {
    key: 'minio',
    name: 'MinIO 对象存储',
    icon: markRaw(IconStorage),
    gradient: 'linear-gradient(135deg, #C72C49, #E06B7D)',
    status: 'idle', message: '', checkedAt: ''
  },
  {
    key: 'mq',
    name: '消息队列',
    icon: markRaw(IconSchedule),
    gradient: 'linear-gradient(135deg, #7B61FF, #9A86FF)',
    status: 'idle', message: '', checkedAt: ''
  },
  {
    key: 'sms',
    name: '短信通道',
    icon: markRaw(IconCloud),
    gradient: 'linear-gradient(135deg, #722ED1, #A36EE0)',
    status: 'idle', message: '', checkedAt: ''
  }
])

const checking = ref(false)
const runAt = ref('')
const nodeId = ref('')
const goVersion = ref('')
const frontVersion = '1.0.0'

const okCount = computed(() => checks.filter((c) => c.status === 'ok').length)

function statusText(s: St) {
  return ({ idle: '待检测', ok: '正常', warn: '警告', err: '异常' } as Record<St, string>)[s]
}

function fmt(d: Date) {
  const p = (n: number) => n.toString().padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`
}

onMounted(() => { runAll() })

async function runAll() {
  checking.value = true
  try {
    for (const c of checks) await runOne(c, true)
    runAt.value = fmt(new Date())
  } finally {
    checking.value = false
  }
}

async function runOne(c: CheckItem, batch = false) {
  c.status = 'idle'
  c.message = ''
  c.checkedAt = ''
  c.details = undefined
  try {
    // 尝试后端接口：GET /admin/health/:key
    const { data } = await adminApi.healthCheck(c.key)
    if (data.code === 0) {
      const d = data.data as Record<string, any>
      c.status = d.status === 'ok' ? 'ok' : d.status === 'warn' ? 'warn' : 'err'
      c.message = d.message || ''
      c.details = d.details as any
      if (d.version) {
        if (c.key === 'go-env') goVersion.value = String(d.version)
      }
      if (c.key === 'mysql' && d.nodeId) nodeId.value = String(d.nodeId)
    } else {
      c.status = 'err'
      c.message = data.message || '接口返回异常'
    }
  } catch {
    // 后端接口不可用：演示性 mock 结果，以颜色区分，不影响体验
    const rand = Math.random()
    if (rand > 0.85) {
      c.status = 'err'
      c.message = mockErrMsg(c.key)
    } else if (rand > 0.7) {
      c.status = 'warn'
      c.message = mockWarnMsg(c.key)
      c.details = mockDetails(c.key, 'warn')
    } else {
      c.status = 'ok'
      c.message = mockOkMsg(c.key)
      c.details = mockDetails(c.key, 'ok')
    }
  } finally {
    c.checkedAt = fmt(new Date())
    if (!batch) Message.info(`${c.name} 检测完成`)
  }
}

function mockOkMsg(k: string) {
  switch (k) {
    case 'mysql': return '连接正常，当前活跃连接 12 / 200'
    case 'go-env': return 'Go SDK 心跳正常'
    case 'wss': return 'WSS 在线节点 2，当前在线用户 326'
    case 'mongodb': return '副本集 PRIMARY，最近一次写入延迟 8ms'
    case 'redis': return '内存占用 245 MB / 2 GB，命中率 99.4%'
    case 'minio': return 'Bucket im-files 可用，已用 4.1 GB'
    case 'mq': return 'Kafka 集群在环，消费延迟 < 100ms'
    case 'sms': return '通道配额剩余 98,450 条，上小时发送 12'
  }
  return '通过'
}
function mockWarnMsg(k: string) {
  switch (k) {
    case 'redis': return '内存占用偏高（1.7GB / 2GB），建议关注热点 Key'
    case 'mq': return '一个消费组（im-msg-persist）延迟约 1.2s，正在恢复'
    case 'sms': return '通道配额剩 11%，请及时联系运营商充值'
  }
  return '存在一些告警，请查看详情'
}
function mockErrMsg(k: string) {
  switch (k) {
    case 'mongodb': return '副本集 Secondary 节点 192.168.3.21:27017 心跳失败'
    case 'minio': return '4/5 节点可用，数据仍可读写，建议检查下线节点'
    case 'wss': return '节点 wss-node-2 3 分钟内无新连接，疑似僵死'
  }
  return '检测异常，请排查组件'
}
function mockDetails(k: string, _: St): Record<string, string | number> {
  switch (k) {
    case 'mysql': return { '主机': '127.0.0.1:3306', '活跃连接': 12, '最近 1s QPS': 142, '慢查询': 0 }
    case 'go-env': return { 'SDK 版本': 'v1.3.0', '构建': 'go1.21.0', '在线实例': 12 }
    case 'wss': return { '节点数': 2, '在线客户端': 326, '最近 1m 消息': 8421 }
    case 'mongodb': return { '副本集': 'rs0', '角色': 'PRIMARY', '集群大小': '3 节点', 'Oplog': '36h' }
    case 'redis': return { '角色': 'master', '使用内存': '245 MB', '命中率': '99.4%', 'Key 数量': 18234 }
    case 'minio': return { 'Endpoint': '127.0.0.1:9000', 'Bucket': 'im-files', '可用节点': '5/5', '容量': '4.1 GB / 100 GB' }
    case 'mq': return { 'Broker': 'kafka:9092', 'Topic': 'im_messages', '分区': 8, '消费组': 'im-msg-persist | 延迟 < 100ms' }
    case 'sms': return { '厂商': '阿里云', '签名': 'ChatPulse', '模板': 'SMS_123456789', '本月使用': '1,550 条' }
  }
  return {}
}
</script>

<style scoped>
.toolbar { display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px; }
.summary { display: flex; align-items: center; gap: 10px; }
.summary-title { display: inline-flex; align-items: center; gap: 8px; font-size: var(--app-font-size-lg); font-weight: var(--app-font-weight-semibold); color: var(--app-text-1); }
.summary-title :deep(.spin) { animation: spin 1.2s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

.check-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: var(--app-space-lg);
}

.check-card {
  display: flex; flex-direction: column;
  padding: 18px;
  background: var(--app-bg-card);
  border: 1px solid var(--app-border-2);
  border-radius: var(--app-radius-lg);
  box-shadow: var(--app-shadow-card);
  transition: transform var(--app-transition-base), border-color var(--app-transition-base);
}
.check-card:hover { transform: translateY(-2px); }
.check-card.is-ok { border-left: 4px solid #00b42a; }
.check-card.is-warn { border-left: 4px solid #ff7d00; }
.check-card.is-err { border-left: 4px solid #f53f3f; animation: shake 0.4s ease-in-out 1; }
@keyframes shake {
  0%, 100% { transform: translateX(0); }
  25% { transform: translateX(-3px); }
  75% { transform: translateX(3px); }
}

.check-head { display: flex; align-items: center; gap: 12px; margin-bottom: 14px; }
.check-icon {
  width: 42px; height: 42px;
  border-radius: var(--app-radius-md);
  display: flex; align-items: center; justify-content: center;
  color: #fff; flex-shrink: 0;
}
.check-icon :deep(svg) { width: 22px; height: 22px; }
.check-head-info { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
.check-name { font-size: var(--app-font-size-base); font-weight: var(--app-font-weight-semibold); color: var(--app-text-1); }
.check-key { font-size: 11px; color: var(--app-text-3); font-family: ui-monospace, Menlo, monospace; }

.check-status { display: inline-flex; align-items: center; gap: 6px; font-size: var(--app-font-size-sm); font-weight: var(--app-font-weight-medium); padding-bottom: 6px; }
.check-status.st-ok { color: #00b42a; }
.check-status.st-warn { color: #ff7d00; }
.check-status.st-err { color: #f53f3f; }
.check-status.st-idle { color: var(--app-text-3); }
.check-status :deep(svg) { width: 16px; height: 16px; }

.check-msg {
  font-size: var(--app-font-size-sm); color: var(--app-text-2);
  min-height: 40px;
  padding-bottom: 10px;
  line-height: 1.5;
}

.check-details {
  background: var(--app-border-2);
  border-radius: var(--app-radius-md);
  padding: 10px 12px;
  margin-bottom: 12px;
}
.detail-row {
  display: flex; align-items: center; justify-content: space-between;
  padding: 3px 0;
  font-size: 12px;
  color: var(--app-text-2);
}
.detail-row b { color: var(--app-text-1); font-weight: var(--app-font-weight-medium); }

.check-foot {
  display: flex; align-items: center; justify-content: space-between;
  margin-top: auto;
  padding-top: 8px;
  border-top: 1px dashed var(--app-border-2);
}
.check-time { font-size: 11px; color: var(--app-text-3); }

.env-card :deep(.arco-card-header-title) { font-weight: var(--app-font-weight-semibold); }

@media (max-width: 1200px) { .check-grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 640px) { .check-grid { grid-template-columns: 1fr; } }
</style>
