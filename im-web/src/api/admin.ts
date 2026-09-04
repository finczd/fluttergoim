import { http } from './http'
import type { ApiResp } from './auth'

// 管理后台 API
export const adminApi = {
  // 用户管理
  users: (params: { kw?: string; status?: number; dept?: number; page?: number; size?: number }) =>
    http.get<ApiResp<{ list: Array<Record<string, any>>; total: number }>>('/admin/users', { params }),
  userCreate: (payload: { account: string; password: string; nickname?: string; avatar?: string; departmentId?: number; role?: number }) =>
    http.post<ApiResp>('/admin/users', payload),
  userUpdate: (id: number, payload: { nickname?: string; avatar?: string; role?: number; shortId?: string | number }) =>
    http.put<ApiResp>(`/admin/users/${id}`, payload),
  userStatus: (id: number, status: number) => http.put<ApiResp>(`/admin/users/${id}/status`, { status }),
  userResetPwd: (id: number, password: string) => http.put<ApiResp>(`/admin/users/${id}/password`, { password }),
  // 充值（B-24）：服务端原子入账，返回落库后的真实余额，前端不得自行推算
  userRecharge: (id: number, amount: number, remark?: string) =>
    http.post<ApiResp<{ balance: number }>>(`/admin/users/${id}/recharge`, { amount, remark }),
  userWallet: (id: number) => http.get<ApiResp<{ userId: number; balance: number; frozen: number }>>(`/admin/users/${id}/wallet`),
  // 用户详情（查看详情弹窗）：资料 + 累计充值/提现 + 注册 IP/设备 + 统计
  userDetail: (id: number | string) =>
    http.get<ApiResp<Record<string, any>>>(`/admin/users/${id}/detail`),

  // 部门管理
  departments: () => http.get<ApiResp<Array<Record<string, any>>>>('/admin/departments'),
  deptCreate: (payload: { nameZh: string; nameEn?: string; parentId?: number; sort?: number }) =>
    http.post<ApiResp>('/admin/departments', payload),
  deptUpdate: (id: number, payload: { nameZh?: string; nameEn?: string; sort?: number }) =>
    http.put<ApiResp>(`/admin/departments/${id}`, payload),
  deptDelete: (id: number) => http.delete<ApiResp>(`/admin/departments/${id}`),

  // 系统配置
  configGet: (key: string) => http.get<ApiResp>(`/admin/configs/${key}`),
  configSet: (key: string, value: unknown) => http.put<ApiResp>(`/admin/configs/${key}`, { value }),

  // 自定义邀请码（一码关联多好友，注册自动加好友）
  inviteCodes: () => http.get<ApiResp<Array<Record<string, any>>>>('/admin/invite-friend-codes'),
  inviteCodeCreate: (payload: { code: string; friendIds: string[]; remark?: string }) =>
    http.post<ApiResp>('/admin/invite-friend-codes', payload),
  inviteCodeUpdate: (id: string | number, payload: { code?: string; friendIds?: string[]; remark?: string; enabled?: number }) =>
    http.put<ApiResp>(`/admin/invite-friend-codes/${id}`, payload),
  inviteCodeDelete: (id: string | number) => http.delete<ApiResp>(`/admin/invite-friend-codes/${id}`),

  // 智能小助手
  assistantConfigGet: () => http.get<ApiResp<Record<string, any>>>('/admin/assistant/config'),
  assistantConfigSet: (payload: { enabled: boolean; name: string; avatar?: string; autoAdd?: boolean; welcomeText?: string }) =>
    http.post<ApiResp>('/admin/assistant/config', payload),
  assistantPush: (payload: { userIds: string[]; userId?: string; content?: string; fileUrl?: string }) =>
    http.post<ApiResp>('/admin/assistant/push', payload),
  assistantConversations: () => http.get<ApiResp<Array<Record<string, any>>>>('/admin/assistant/conversations'),
  assistantMessages: (params: { userId: string; beforeMsgId?: string | number; limit?: number }) =>
    http.get<ApiResp<Array<Record<string, any>>>>('/admin/assistant/messages', { params }),

  // 小程序管理（H5 容器）
  apps: () => http.get<ApiResp<Array<Record<string, any>>>>('/admin/app-entries'),
  appCreate: (payload: { nameZh: string; nameEn?: string; icon?: string; url: string; category?: string; sort?: number; enabled?: boolean }) =>
    http.post<ApiResp>('/admin/app-entries', payload),
  appUpdate: (id: number, payload: { nameZh?: string; nameEn?: string; icon?: string; url?: string; category?: string; sort?: number; enabled?: boolean }) =>
    http.put<ApiResp>(`/admin/app-entries/${id}`, payload),
  appDelete: (id: number) => http.delete<ApiResp>(`/admin/app-entries/${id}`),

  // 群组管理
  groups: () => http.get<ApiResp<Array<Record<string, any>>>>('/admin/groups'),
  groupDisband: (id: string) => http.delete<ApiResp>(`/admin/groups/${id}`),
  groupMembers: (groupId: string, params?: { page?: number; size?: number }) =>
    http.get<ApiResp<{ list: Array<Record<string, any>>; total: number }>>(`/admin/groups/${groupId}/members`, { params }),
  groupMessages: (groupId: string, params?: { kw?: string; page?: number; size?: number }) =>
    http.get<ApiResp<{ list: Array<Record<string, any>>; total: number }>>(`/admin/groups/${groupId}/messages`, { params }),

  // 消息记录（审计）
  messages: (params: { kw?: string; convId?: string; userId?: string; type?: number; from?: number; to?: number; page?: number; size?: number }) =>
    http.get<ApiResp<{ list: Array<Record<string, any>>; total: number }>>('/admin/messages', { params }),
  // 屏蔽/恢复消息（blocked=false 恢复）
  messageBlock: (msgId: string, blocked = true) =>
    http.post<ApiResp>(`/admin/messages/${msgId}/block`, { blocked }),

  // 数据统计
  statsOverview: () => http.get<ApiResp<Record<string, any>>>('/admin/stats/overview'),
  statsMessages: (days = 7) => http.get<ApiResp<{ days: number; series: Array<{ day: string; count: number }> }>>('/admin/stats/messages', { params: { days } }),

  // 清空数据（危险操作：scope = users/chats/groups/recharge/withdraw/all；前端必须二次确认后再调用）
  dataClear: (scope: string) =>
    http.post<ApiResp<Record<string, any>>>('/admin/data/clear', { scope }),

  // 日志
  logs: (params: { page?: number; size?: number }) =>
    http.get<ApiResp<{ list: Array<Record<string, any>>; total: number }>>('/admin/logs', { params }),
  loginLogs: (params: { page?: number; size?: number }) =>
    http.get<ApiResp<{ list: Array<Record<string, any>>; total: number }>>('/admin/logs/login', { params }),

  // 保留靓号
  reservedShortIds: (params: { kw?: string; status?: number; source?: number; page?: number; size?: number }) =>
    http.get<ApiResp<{ list: Array<Record<string, any>>; total: number }>>('/admin/reserved-short-ids', { params }),
  reservedShortIdsBatch: (payload: {
    // 三种模式：range 范围 / list 列表 / rule 规则
    mode: 'range' | 'list' | 'rule' | 'manual' | string
    from?: number | string | bigint
    to?: number | string | bigint
    prefix?: string
    digits?: number
    count?: number
    list?: string[]
    remark?: string
    price?: number
    source?: number
    type?: number          // 1 普通 / 2 豹子号 / 3 顺子号 / 4 VIP
    ids?: string[]         // 兼容旧前端：ids 与 list 等价
  }) =>
    http.post<ApiResp<{ added: number; count: number }>>('/admin/reserved-short-ids/batch', payload),
  reservedShortIdRemark: (id: number | string, payload: { remark?: string; price?: number; type?: number }) =>
    http.put<ApiResp>(`/admin/reserved-short-ids/${id}/remark`, payload),
  reservedShortIdFrozen: (id: number | string, frozen: boolean) =>
    http.put<ApiResp>(`/admin/reserved-short-ids/${id}/frozen`, { frozen }),
  reservedShortIdDelete: (id: number | string) =>
    http.delete<ApiResp>(`/admin/reserved-short-ids/${id}`),
  // 分配给用户 / 解除分配（绑定账号列会对应更新）
  reservedShortIdAssign: (id: number | string, userId: number | string) =>
    http.put<ApiResp<{ userId?: number | string; nickname?: string; account?: string; shortId?: string }>>(
      `/admin/reserved-short-ids/${id}/assign`,
      { userId }
    ),
  reservedShortIdRelieve: (id: number | string) =>
    http.put<ApiResp>(`/admin/reserved-short-ids/${id}/relieve`, {}),

  // 系统健康检测
  healthCheck: (key: string) =>
    http.get<ApiResp<Record<string, any>>>(`/admin/health/${key}`),

  // 服务重启（systemd 托管环境）：target = api | gateway
  systemRestart: (target: 'api' | 'gateway') =>
    http.post<ApiResp<null>>('/admin/system/restart', { target }),

  /**
   * 后台文件上传：POST /api/v1/admin/upload（admin 接口，admin token 鉴权）。
   * 走 axios 而非 fetch，确保拦截器统一带 Authorization + 401 自动刷新；
   * 历史 bug：直接用 fetch('/api/v1/upload') 走用户接口，部分反向代环境下
   * FormData body 被吞，后端 FormFile("file") 拿不到 → 返回 1001「缺少文件」。
   * 改走 admin 接口 + axios 后该问题消失。返回 MinIO URL 字符串。
   *
   * 再次踩坑：显式 { 'Content-Type': 'multipart/form-data' } 会**覆盖** axios 自动加的 boundary，
   * 后端 c.Request.FormFile("file") 因缺少 boundary 解析失败 → 同样 1001。
   * 修复：删掉显式 headers，让 axios 检测到 FormData 时自动补齐 Content-Type（含 boundary）。
   */
  uploadFile: (file: File, dir = 'common/') => {
    const fd = new FormData()
    fd.append('file', file)
    fd.append('dir', dir)
    return http.post<ApiResp<{ url: string; object: string; size: number }>>(
      '/admin/upload',
      fd
    ).then(r => {
      if (r.data.code !== 0) throw new Error(r.data.message || '上传失败')
      return r.data.data.url
    })
  },

  // 财务
  financeRecords: (params: { kw?: string; type?: string; side?: string; page?: number; size?: number; from?: number; to?: number }) =>
    http.get<ApiResp<{ list: Array<Record<string, any>>; total: number }>>('/admin/finances', { params }),

  // ===== 支付配置 / 充值订单 / 提现订单 =====
  payConfigGet: () =>
    http.get<ApiResp<{
      enabled: boolean
      receiveWechatQrcodeUrl: string
      receiveAlipayQrcodeUrl: string
      receiveBankQrcodeUrl: string
      receiveBankInfo: { bankName: string; cardNo: string; accountName: string }
      rechargeTips: string
      withdrawEnabled: boolean
      withdrawMin: number
      withdrawMax: number
      withdrawFeeRate: number
      withdrawFeeMin: number
    }>>('/admin/pay-config'),
  payConfigSet: (payload: Record<string, unknown>) => http.put<ApiResp>('/admin/pay-config', payload),

  rechargeOrders: (params: { kw?: string; status?: number; page?: number; size?: number }) =>
    http.get<ApiResp<{ list: Array<Record<string, any>>; total: number }>>('/admin/recharge-orders', { params }),
  rechargeOrderApprove: (id: number | string) =>
    http.put<ApiResp<{ orderId: number | string; userId: number | string; amount: number; balance: number }>>(
      `/admin/recharge-orders/${id}/approve`,
      {}
    ),
  rechargeOrderReject: (id: number | string, reason: string) =>
    http.put<ApiResp>(`/admin/recharge-orders/${id}/reject`, { reason }),

  withdrawOrders: (params: { kw?: string; status?: number; type?: number; page?: number; size?: number }) =>
    http.get<ApiResp<{ list: Array<Record<string, any>>; total: number }>>('/admin/withdraw-orders', { params }),
  withdrawOrderApprove: (id: number | string) =>
    http.put<ApiResp<{ orderId: number | string; userId: number | string; amount: number; fee: number }>>(
      `/admin/withdraw-orders/${id}/approve`,
      {}
    ),
  withdrawOrderReject: (id: number | string, reason: string) =>
    http.put<ApiResp>(`/admin/withdraw-orders/${id}/reject`, { reason })
}

export const adminLogApi = {
  logs: (params: { page?: number; size?: number }) =>
    http.get<ApiResp<{ list: Array<Record<string, any>>; total: number }>>('/admin/logs', { params }),
  loginLogs: (params: { page?: number; size?: number }) =>
    http.get<ApiResp<{ list: Array<Record<string, any>>; total: number }>>('/admin/logs/login', { params })
}
