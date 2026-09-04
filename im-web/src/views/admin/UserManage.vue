<template>
  <div class="page">
    <a-card>
      <div class="toolbar">
        <a-input-search v-model="query.kw" placeholder="昵称 / 账号 / 手机号 / 邮箱 / 短ID" style="width: 280px" allow-clear @search="load(1)" />
        <a-select v-model="query.status" placeholder="状态" style="width: 120px" allow-clear @change="load(1)">
          <a-option :value="1">正常</a-option>
          <a-option :value="2">禁用</a-option>
        </a-select>
        <a-button type="primary" @click="openCreate">创建账号</a-button>
      </div>

      <a-table :data="list" :pagination="pagination" :loading="loading" row-key="id" @page-change="load" :scroll="{ x: 1400 }">
        <template #columns>
          <a-table-column title="用户" :width="240">
            <template #cell="{ record }">
              <div class="user-cell">
                <span class="avatar" :style="{ background: avatarColor(record.id) }">
                  <img v-if="record.avatar" :src="record.avatar" alt="" />
                  <template v-else>{{ (record.nickname || record.account || '?').slice(0, 1).toUpperCase() }}</template>
                </span>
                <div class="user-info">
                  <span class="nickname">{{ record.nickname || '-' }}</span>
                  <span class="account">{{ record.account }}</span>
                </div>
              </div>
            </template>
          </a-table-column>
          <a-table-column title="短ID" :width="110">
            <template #cell="{ record }">
              <span v-if="record.shortId" class="short-id">#{{ record.shortId }}</span>
              <span v-else class="muted">—</span>
            </template>
          </a-table-column>
          <a-table-column title="余额" :width="130" align="right">
            <template #cell="{ record }">
              <span class="balance">
                <IconGift /> {{ fmtMoney(record.balance ?? record.wallet?.balance ?? 0) }}
              </span>
            </template>
          </a-table-column>
          <a-table-column title="角色" :width="90">
            <template #cell="{ record }">
              <a-tag v-if="record.role === 3" color="orange">客服</a-tag>
              <a-tag v-else :color="record.role === 2 ? 'arcoblue' : 'gray'">{{ record.role === 2 ? '管理员' : '用户' }}</a-tag>
            </template>
          </a-table-column>
          <a-table-column title="状态" :width="90">
            <template #cell="{ record }">
              <a-tag :color="record.status === 1 ? 'green' : 'red'">{{ record.status === 1 ? '正常' : '禁用' }}</a-tag>
            </template>
          </a-table-column>
          <a-table-column title="最后登录IP" :width="140">
            <template #cell="{ record }">
              <span v-if="record.lastLoginIP || record.lastLoginIp" class="ip-chip">
                <IconLocation />
                {{ record.lastLoginIP || record.lastLoginIp }}
              </span>
              <span v-else class="muted">—</span>
            </template>
          </a-table-column>
          <a-table-column title="最后登录" :width="170">
            <template #cell="{ record }">
              <span v-if="record.lastLoginAt">{{ fmt(record.lastLoginAt) }}</span>
              <span v-else class="muted">从未登录</span>
            </template>
          </a-table-column>
          <a-table-column title="注册时间" :width="170">
            <template #cell="{ record }">{{ fmt(record.createdAt) }}</template>
          </a-table-column>
          <a-table-column title="操作" :width="360" fixed="right">
            <template #cell="{ record }">
              <a-space size="mini" style="flex-wrap:wrap">
                <a-switch :model-value="record.status === 1" size="small" @change="(v: any) => toggleStatus(record, !!v)" />
                <a-button size="mini" @click="openDetail(record)">详情</a-button>
                <a-button size="mini" @click="openEdit(record)">编辑</a-button>
                <a-button size="mini" status="warning" @click="resetPwd(record)">重置密码</a-button>
                <a-button size="mini" type="primary" :icon="IconGift" @click="openRecharge(record)">充值</a-button>
              </a-space>
            </template>
          </a-table-column>
        </template>
      </a-table>
    </a-card>

    <!-- 编辑 / 创建 通用弹窗 -->
    <a-modal v-model:visible="showUser" :title="editing.id ? '编辑用户' : '创建账号'" @ok="saveUser" :confirm-loading="saving" width="560">
      <a-form :model="editing" layout="vertical">
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="头像">
              <ImageUpload v-model="editing.avatar" dir="avatar/" round hint="可选" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="角色">
              <a-radio-group v-model="editing.role">
                <a-radio :value="1">用户</a-radio>
                <a-radio :value="2">管理员</a-radio>
                <a-radio :value="3">客服</a-radio>
              </a-radio-group>
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item :label="editing.id ? '账号（只读）' : '账号 / 手机号 / 邮箱'" :required="!editing.id">
              <a-input v-model="editing.account" :disabled="!!editing.id" placeholder="创建时必填" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item :label="editing.id ? '初始密码' : '密码'" :required="!editing.id">
              <a-input-password v-model="editing.password" :placeholder="editing.id ? '留空不修改密码' : '8-20 位含字母数字'" />
              <div v-if="editing.id" class="hint muted">保存为空不会修改；点击“重置密码”可一键设为 123456。</div>
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="昵称"><a-input v-model="editing.nickname" placeholder="显示名称" /></a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="分配靓号 / 短ID">
              <a-input v-model="editing.shortId" placeholder="如 10086，选填，需在保留靓号里" allow-clear />
              <div class="hint muted">用户唯一短号，创建后可重新分配。</div>
            </a-form-item>
          </a-col>
        </a-row>
      </a-form>
    </a-modal>

    <!-- 充值/扣款弹窗 -->
    <a-modal v-model:visible="showRecharge" title="充值 / 扣款（正数=充值，负数=扣款）" width="460" @ok="handleRechargeSubmit" @cancel="showRecharge = false" :confirm-loading="recharging" okText="确认提交" cancelText="取消">
      <a-form layout="vertical">
        <a-form-item label="目标用户">
          <a-input v-model="rechargeTarget.account" disabled />
        </a-form-item>
        <a-form-item label="当前余额">
          <a-input v-model="rechargeTarget.balance" disabled />
        </a-form-item>
        <a-form-item label="变动金额（支持负数）" required field="amount">
          <a-input-number ref="rechargeInputRef" v-model="rechargeAmount" :min="-999999" :max="999999" :precision="2" :step="10" style="width:100%" placeholder="例：100 充值 / -100 扣款" hide-button />
          <div style="margin-top:6px; color:var(--color-text-3); font-size:12px; line-height:1.6">
            💡 正数（如 <b>100</b>）→ 加钱，走「充值」流水；负数（如 <b>-100</b>）→ 扣钱，走「后台扣款」流水。<br/>
            <span style="color:var(--color-danger)">扣款时若用户可用余额不足，会直接报错，不会造成负数余额。</span>
          </div>
        </a-form-item>
        <a-form-item label="备注">
          <a-input v-model="rechargeRemark" placeholder="例：管理员手动充值 / 违规扣款" allow-clear />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 用户详情弹窗 -->
    <a-modal v-model:visible="showDetail" title="用户详情" :footer="false" width="680" unmount-on-close>
      <a-spin v-if="detailLoading" style="display:block;text-align:center;padding:40px 0" />
      <template v-else-if="detail">
        <div class="detail-head">
          <span class="avatar detail-avatar" :style="{ background: avatarColor(Number(detail.user?.id) || 0) }">
            <img v-if="detail.user?.avatar" :src="detail.user.avatar" alt="" />
            <template v-else>{{ (detail.user?.nickname || detail.user?.account || '?').slice(0, 1).toUpperCase() }}</template>
          </span>
          <div class="detail-head-info">
            <span class="detail-name">{{ detail.user?.nickname || '-' }}</span>
            <span class="detail-sub">{{ detail.user?.account }} · ID {{ detail.user?.id }}</span>
            <div class="detail-tags">
              <a-tag :color="detail.user?.status === 1 ? 'green' : 'red'">{{ detail.user?.status === 1 ? '正常' : '禁用' }}</a-tag>
              <a-tag color="gray">{{ ['未知', '用户', '管理员', '客服'][Number(detail.user?.role) || 0] || '用户' }}</a-tag>
              <a-tag v-if="detail.online" color="green">在线</a-tag>
              <a-tag v-else color="gray">离线</a-tag>
            </div>
          </div>
        </div>
        <a-descriptions :column="2" size="medium" bordered title="基础资料" style="margin-top:14px">
          <a-descriptions-item label="短ID">{{ detail.user?.shortId ? '#' + detail.user.shortId : '—' }}</a-descriptions-item>
          <a-descriptions-item label="个性签名">{{ detail.user?.signature || '—' }}</a-descriptions-item>
          <a-descriptions-item label="手机号">{{ detail.user?.phone || '—' }}</a-descriptions-item>
          <a-descriptions-item label="邮箱">{{ detail.user?.email || '—' }}</a-descriptions-item>
          <a-descriptions-item label="我的邀请码">{{ detail.user?.myInviteCode || '—' }}</a-descriptions-item>
          <a-descriptions-item label="注册时间">{{ fmt(detail.user?.createdAt) || '—' }}</a-descriptions-item>
        </a-descriptions>
        <a-descriptions :column="2" size="medium" bordered title="钱包（服务端为准）" style="margin-top:12px">
          <a-descriptions-item label="可用余额">¥ {{ fmtMoney(detail.user?.balance) }}</a-descriptions-item>
          <a-descriptions-item label="冻结金额">¥ {{ fmtMoney(detail.user?.frozen) }}</a-descriptions-item>
          <a-descriptions-item label="累计充值">¥ {{ fmtMoney(detail.totalRecharge) }}</a-descriptions-item>
          <a-descriptions-item label="累计提现">¥ {{ fmtMoney(detail.totalWithdraw) }}</a-descriptions-item>
        </a-descriptions>
        <a-descriptions :column="2" size="medium" bordered title="登录与注册" style="margin-top:12px">
          <a-descriptions-item label="最后登录 IP">{{ detail.user?.lastLoginIP || '—' }}</a-descriptions-item>
          <a-descriptions-item label="最后登录时间">{{ detail.user?.lastLoginAt ? fmt(detail.user.lastLoginAt) : '从未登录' }}</a-descriptions-item>
          <a-descriptions-item label="注册 IP">{{ detail.user?.registerIP || '—' }}</a-descriptions-item>
          <a-descriptions-item label="注册设备">{{ detail.user?.registerDevice || '—' }}</a-descriptions-item>
        </a-descriptions>
        <a-descriptions :column="2" size="medium" bordered title="统计" style="margin-top:12px">
          <a-descriptions-item label="好友数">{{ detail.friendCount ?? 0 }}</a-descriptions-item>
          <a-descriptions-item label="累计发送消息">{{ detail.msgCount ?? 0 }}</a-descriptions-item>
        </a-descriptions>
      </template>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Message, Modal } from '@arco-design/web-vue'
import { IconLocation, IconGift } from '@arco-design/web-vue/es/icon'
import { adminApi } from '@/api/admin'
import ImageUpload from './ImageUpload.vue'

const AVATAR_COLORS = ['#4E8CFF', '#7B61FF', '#FF7D00', '#00B42A', '#F53F3F', '#14C9C9']
function avatarColor(id: number) {
  return { backgroundColor: AVATAR_COLORS[id % AVATAR_COLORS.length] }
}
function fmt(v: string | number | Date) {
  if (!v) return ''
  const d = new Date(v)
  if (isNaN(+d)) return String(v)
  const p = (n: number) => n.toString().padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`
}
function fmtMoney(v: any) {
  const n = Number(v) || 0
  return n.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

const list = ref<Array<Record<string, any>>>([])
const loading = ref(false)
const query = reactive({ kw: '', status: undefined as number | undefined })
const pagination = reactive({ current: 1, pageSize: 10, total: 0, showTotal: true })

const showUser = ref(false)
const saving = ref(false)
const editing = reactive<{
  id?: number; account: string; password: string; nickname: string;
  avatar: string; role: number; shortId: string
}>({ account: '', password: '', nickname: '', avatar: '', role: 1, shortId: '' })

const showRecharge = ref(false)
const recharging = ref(false)
const rechargeTarget = reactive({ account: '', balance: '' })
const rechargeRecord = ref<Record<string, any> | null>(null)
const rechargeAmount = ref<number>(100)
const rechargeRemark = ref('')
const rechargeInputRef = ref<any>(null)
function commitAmount() {
  // 强制让 a-input-number 失焦 → 触发内部 precision/format，提交到 v-model
  try {
    const ae = document.activeElement as HTMLElement | null
    if (ae && (ae.tagName === 'INPUT' || ae.closest?.('.arco-input-number'))) {
      ae.blur()
    }
  } catch { /* ignore */ }
  // 从组件 ref 兜底读取（部分 Arco 版本暴露 inputValue）
  try {
    const el = rechargeInputRef.value
    if (el && typeof el.$el === 'object') {
      const input = el.$el.querySelector?.('input')
      if (input && typeof input.value === 'string' && input.value !== '') {
        const v = Number(input.value.replace(/,/g, ''))
        if (isFinite(v)) rechargeAmount.value = v
      }
    }
  } catch { /* ignore */ }
}
function handleRechargeSubmit() {
  commitAmount()
  // 再给一个微任务，确保 v-model 完成
  Promise.resolve().then(() => doRecharge())
}

onMounted(() => load(1))

// ===== 用户详情（查看详情） =====
const showDetail = ref(false)
const detailLoading = ref(false)
const detail = ref<Record<string, any> | null>(null)
async function openDetail(r: Record<string, any>) {
  showDetail.value = true
  detailLoading.value = true
  detail.value = null
  try {
    const { data } = await adminApi.userDetail(r.id)
    if (data.code === 0) {
      detail.value = data.data
    } else {
      Message.error(data.message || '读取详情失败')
    }
  } catch (e: any) {
    Message.error(e?.message || '读取详情失败（网络错误）')
  } finally {
    detailLoading.value = false
  }
}

async function load(page = pagination.current) {
  loading.value = true
  try {
    const { data } = await adminApi.users({ ...query, page, size: pagination.pageSize })
    if (data.code === 0) {
      list.value = (data.data?.list || []) as Array<Record<string, any>>
      pagination.total = data.data?.total ?? 0
      pagination.current = page
      return
    }
    Message.error(data?.message || '加载失败')
    list.value = []
    pagination.total = 0
  } catch (e: any) {
    Message.error(e?.message || '加载失败（网络错误）')
    list.value = []
    pagination.total = 0
  } finally {
    loading.value = false
  }
}

// ===== 注意：
// 1. 后台列表只以真实接口为准，不再用本地 meta 覆盖数据库值。
//    之前的 fallback 会把 meta 中的 nickname/avatar/shortId/status/role 盖掉真实接口返回，
//    导致 App 端改了资料后台看不到、后台改了资料 App 端也不生效（因为根本没写库）。
// 2. 不再生成 mock 用户；接口失败就显示空列表并报错。
// 3. 财务流水也只以 /admin/finances 和 wallet_transaction 为准，不再本地 appendFinanceRecord。


function openCreate() {
  Object.assign(editing, { id: undefined, account: '', password: '123456', nickname: '', avatar: '', role: 1, shortId: '' })
  showUser.value = true
}
function openEdit(r: Record<string, any>) {
  Object.assign(editing, {
    id: r.id, account: r.account || '', password: '',
    nickname: r.nickname || '', avatar: r.avatar || '',
    role: r.role ?? 1, shortId: r.shortId ? String(r.shortId) : ''
  })
  showUser.value = true
}

async function saveUser() {
  saving.value = true
  try {
    if (!editing.id) {
      // 创建
      if (!editing.account) return Message.error('请填写账号')
      if (!editing.password) return Message.error('请填写初始密码')
      const payload = {
        account: editing.account, password: editing.password,
        nickname: editing.nickname || undefined,
        avatar: editing.avatar || undefined,
        role: editing.role,
        shortId: editing.shortId || undefined
      }
      const { data } = await adminApi.userCreate(payload)
      if (!data || data.code !== 0) {
        return Message.error(data?.message || '创建失败，请检查账号是否已存在')
      }
      Message.success('创建成功')
    } else {
      // 更新
      const payload: any = {}
      if (editing.nickname !== undefined) payload.nickname = editing.nickname
      if (editing.avatar !== undefined) payload.avatar = editing.avatar
      if (editing.role !== undefined) payload.role = editing.role
      // 空字符串表示清空 shortId（置 null）；有值就原样传递；未填写不更新
      if (editing.shortId !== '') payload.shortId = editing.shortId || null
      // 并行：更新资料 + （若填了密码则改密）
      const tasks: Promise<any>[] = [adminApi.userUpdate(editing.id, payload)]
      if (editing.password) tasks.push(adminApi.userResetPwd(editing.id, editing.password))
      const results = await Promise.all(tasks)
      const failed = results.find((r) => r.data && r.data.code !== 0)
      if (failed) {
        return Message.error(failed.data.message || '保存失败')
      }
      Message.success('已保存')
    }
    showUser.value = false
    load(1)
  } catch (e: any) {
    Message.error(e?.message || '保存失败（网络错误）')
  } finally {
    saving.value = false
  }
}

async function toggleStatus(record: Record<string, any>, enabled: boolean) {
  try {
    const { data } = await adminApi.userStatus(record.id, enabled ? 1 : 2)
    if (data && data.code === 0) {
      record.status = enabled ? 1 : 2
      Message.success(enabled ? '已启用' : '已禁用')
      return
    }
    Message.error(data?.message || (enabled ? '启用失败' : '禁用失败'))
  } catch (e: any) {
    Message.error(e?.message || (enabled ? '启用失败' : '禁用失败'))
  } finally {
    // 无论成功失败都刷新一次列表（避免本地显示和 DB 不一致）
    load(pagination.current)
  }
}

async function resetPwd(record: Record<string, any>) {
  const name = record.nickname || record.account || '该用户'
  const ok = await new Promise<boolean>((r) => {
    Modal.confirm({
      title: `重置 ${name} 的密码`,
      content: `将把密码重置为默认值 123456。请在用户登录后提示其修改。`,
      okText: '重置为 123456',
      cancelText: '取消',
      onOk: () => r(true),
      onCancel: () => r(false)
    })
  })
  if (!ok) return
  try {
    const { data } = await adminApi.userResetPwd(record.id, '123456')
    if (data && data.code === 0) {
      Message.success(`已重置为 123456`)
    } else {
      Message.error(data?.message || '重置失败')
    }
  } catch (e: any) {
    Message.error(e?.message || '重置失败（网络错误）')
  }
}

// 充值
async function openRecharge(r: Record<string, any>) {
  rechargeRecord.value = r
  rechargeTarget.account = `${r.nickname || ''} (${r.account})`
  try {
    const { data } = await adminApi.userWallet(r.id)
    if (data.code === 0) {
      const bal = data.data?.balance
      rechargeTarget.balance = `¥ ${fmtMoney(bal ?? 0)}`
    } else {
      rechargeTarget.balance = `¥ ${fmtMoney(r.balance ?? 0)}`
      Message.warning(data?.message || '读取钱包失败，显示列表余额')
    }
  } catch (e: any) {
    rechargeTarget.balance = `¥ ${fmtMoney(r.balance ?? 0)}`
    Message.warning(e?.message || '读取钱包失败，显示列表余额')
  }
  rechargeAmount.value = 100
  rechargeRemark.value = '管理员手动充值'
  showRecharge.value = true
}
// 充值 / 扣款（B-24）
//
// 以前这里的写法有个致命问题：/admin/users/:id/recharge 后端**根本没注册**，
// 请求必然失败，然后被下面的 try/catch 吞掉，转而走「本地记账 fallback」——
// 把金额写进用户 meta 并追加一条前端自造的财务记录，界面提示"充值成功"。
// 结果：后台看着钱加上了，user.balance 列纹丝不动，App 端 `/wallet/me`
// 读的是真实余额，于是永远是老数字；财务页也多出一条对不上的假账。
//
// 现在：充值/扣款一律走服务端原子入账（写 user.balance + wallet_transaction），
// 失败就**明确报错**，绝不静默 fallback。余额以服务端返回值为准。
// 负数（如 -100）代表扣款；余额不足时后端直接返回 4101「余额不足」。
async function doRecharge() {
  if (!rechargeRecord.value) return
  commitAmount()
  if (!rechargeAmount.value || Number(rechargeAmount.value) === 0) return Message.error('请输入有效金额（正数=充值 / 负数=扣款，0 无效）')
  const amt = Number(rechargeAmount.value) || 0
  const isRecharge = amt > 0
  recharging.value = true
  try {
    const r = rechargeRecord.value
    const { data } = await adminApi.userRecharge(r.id, amt, rechargeRemark.value || undefined)
    if (!data || data.code !== 0) {
      // 不再 fallback：失败必须让管理员看见，否则又是一笔"后台说加了、用户没收到"的糊涂账
      const tip = isRecharge ? '充值失败，请稍后重试' : '扣款失败，请稍后重试'
      return Message.error(data?.message || tip)
    }
    // 余额一律以服务端为准（WalletApply 返回的是落库后的真实值）
    const next = Number(data.data?.balance ?? NaN)
    if (!isNaN(next) && isFinite(next)) {
      r.balance = next
      if (r.wallet) r.wallet.balance = next
    }
    const action = isRecharge ? `已充值 ¥${fmtMoney(amt)}` : `已扣款 ¥${fmtMoney(-amt)}`
    Message.success(`${action}，当前余额 ¥${fmtMoney(isNaN(next) ? 0 : next)}`)
    showRecharge.value = false
    load(1)
  } catch (e: any) {
    const tip = isRecharge ? '充值失败，请检查网络' : '扣款失败，请检查网络'
    Message.error(e?.message || tip)
  } finally {
    recharging.value = false
  }
}
</script>

<style scoped>
.toolbar { display: flex; gap: 12px; margin-bottom: 16px; flex-wrap: wrap; }
.muted { color: var(--app-text-3); }

.user-cell { display: flex; align-items: center; gap: 10px; }
.avatar {
  width: 36px; height: 36px;
  border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  color: #fff; font-size: 14px; font-weight: 600;
  overflow: hidden; flex-shrink: 0;
}
.avatar img { width: 100%; height: 100%; object-fit: cover; }
.user-info { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
.nickname { font-size: var(--app-font-size-base); color: var(--app-text-1); font-weight: var(--app-font-weight-medium); }
.account { font-size: var(--app-font-size-xs); color: var(--app-text-3); }

.short-id {
  font-family: ui-monospace, Menlo, Consolas, monospace;
  font-size: 13px;
  color: var(--app-primary);
  background: var(--app-primary-bg);
  border-radius: var(--app-radius-xs);
  padding: 2px 8px;
  font-weight: 600;
}

.ip-chip {
  display: inline-flex; align-items: center; gap: 4px;
  font-family: ui-monospace, Menlo, Consolas, monospace;
  font-size: 12px;
  color: var(--app-text-2);
  background: var(--app-border-2);
  border-radius: var(--app-radius-xs);
  padding: 2px 8px;
}
.ip-chip :deep(svg) { width: 12px; height: 12px; color: var(--app-primary); }

.balance {
  display: inline-flex; align-items: center; gap: 4px;
  font-family: ui-monospace, Menlo, Consolas, monospace;
  font-weight: 600; color: #c73110;
}
.balance :deep(svg) { width: 14px; height: 14px; color: #d48806; }
.hint { margin-top: 6px; font-size: 12px; }

/* 用户详情弹窗 */
.detail-head { display: flex; align-items: center; gap: 14px; }
.detail-avatar { width: 56px; height: 56px; font-size: 20px; }
.detail-head-info { display: flex; flex-direction: column; gap: 4px; min-width: 0; }
.detail-name { font-size: 16px; font-weight: var(--app-font-weight-medium); color: var(--app-text-1); }
.detail-sub { font-size: 12px; color: var(--app-text-3); }
.detail-tags { display: flex; gap: 6px; }
</style>
