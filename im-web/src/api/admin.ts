import { http } from './http'
import type { ApiResp } from './auth'

// 管理后台 API
export const adminApi = {
  // 用户管理
  users: (params: { kw?: string; status?: number; dept?: number; page?: number; size?: number }) =>
    http.get<ApiResp<{ list: Array<Record<string, any>>; total: number }>>('/admin/users', { params }),
  userCreate: (payload: { account: string; password: string; nickname?: string; departmentId?: number; role?: number }) =>
    http.post<ApiResp>('/admin/users', payload),
  userStatus: (id: number, status: number) => http.put<ApiResp>(`/admin/users/${id}/status`, { status }),
  userResetPwd: (id: number, password: string) => http.put<ApiResp>(`/admin/users/${id}/password`, { password }),

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

  // 智能小助手
  assistantConfigGet: () => http.get<ApiResp<Record<string, any>>>('/admin/assistant/config'),
  assistantConfigSet: (payload: { enabled: boolean; name: string; avatar?: string; autoAdd?: boolean; welcomeText?: string }) =>
    http.post<ApiResp>('/admin/assistant/config', payload),
  assistantPush: (payload: { userId: string; content?: string; fileUrl?: string }) =>
    http.post<ApiResp>('/admin/assistant/push', payload),

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

  // 消息记录（审计）
  messages: (params: { kw?: string; convId?: string; userId?: string; from?: number; to?: number; page?: number; size?: number }) =>
    http.get<ApiResp<{ list: Array<Record<string, any>>; total: number }>>('/admin/messages', { params }),

  // 数据统计
  statsOverview: () => http.get<ApiResp<Record<string, any>>>('/admin/stats/overview'),
  statsMessages: (days = 7) => http.get<ApiResp<{ days: number; series: Array<{ day: string; count: number }> }>>('/admin/stats/messages', { params: { days } }),

  // 日志
  logs: (params: { page?: number; size?: number }) =>
    http.get<ApiResp<{ list: Array<Record<string, any>>; total: number }>>('/admin/logs', { params }),
  loginLogs: (params: { page?: number; size?: number }) =>
    http.get<ApiResp<{ list: Array<Record<string, any>>; total: number }>>('/admin/logs/login', { params })
}

export const adminLogApi = {
  logs: (params: { page?: number; size?: number }) =>
    http.get<ApiResp<{ list: Array<Record<string, any>>; total: number }>>('/admin/logs', { params }),
  loginLogs: (params: { page?: number; size?: number }) =>
    http.get<ApiResp<{ list: Array<Record<string, any>>; total: number }>>('/admin/logs/login', { params })
}
