import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', name: 'login', component: () => import('@/views/LoginView.vue') },
    {
      path: '/',
      component: () => import('@/views/WorkspaceView.vue'),
      children: [
        { path: '', redirect: '/chat' },
        { path: 'chat', name: 'chat', component: () => import('@/views/ChatView.vue') },
        { path: 'contacts', name: 'contacts', component: () => import('@/views/ContactsView.vue') },
        { path: 'calls', name: 'calls', component: () => import('@/views/CallsView.vue') }
      ]
    },
    // 管理后台（独立布局）
    {
      path: '/admin',
      component: () => import('@/views/admin/AdminLayout.vue'),
      meta: { requiresAdmin: true },
      children: [
        { path: '', redirect: '/admin/users' },
        { path: 'users', component: () => import('@/views/admin/UserManage.vue') },
        { path: 'departments', component: () => import('@/views/admin/DepartmentManage.vue') },
        { path: 'groups', component: () => import('@/views/admin/GroupManage.vue') },
        { path: 'messages', component: () => import('@/views/admin/MessageQuery.vue') },
        { path: 'stats', component: () => import('@/views/admin/StatsView.vue') },
        { path: 'configs', component: () => import('@/views/admin/ConfigView.vue') },
        { path: 'apps', component: () => import('@/views/admin/AppEntries.vue') },
        { path: 'nodes', component: () => import('@/views/admin/NodeManage.vue') },
        { path: 'assistant', component: () => import('@/views/admin/AssistantManage.vue') },
        { path: 'logs', component: () => import('@/views/admin/LogView.vue') }
      ]
    }
  ]
})

// 登录守卫（阶段 1 完善：校验 JWT）
router.beforeEach((to) => {
  const token = localStorage.getItem('im-token')
  if (to.path !== '/login' && !token) return '/login'
  return true
})

export default router
