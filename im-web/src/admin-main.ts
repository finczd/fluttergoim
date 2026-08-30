import { createApp } from 'vue'
import { createPinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import ArcoVue from '@arco-design/web-vue'
import ArcoVueIcon from '@arco-design/web-vue/es/icon'
import '@arco-design/web-vue/dist/arco.css'
import AdminApp from './views/admin/AdminApp.vue'
import { i18n } from './i18n'

// 管理后台独立入口：只含后台路由与后台登录页
const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/admin/users' },
    { path: '/login', name: 'admin-login', component: () => import('./views/admin/AdminLogin.vue') },
    {
      path: '/admin',
      component: () => import('./views/admin/AdminLayout.vue'),
      meta: { requiresAdmin: true },
      children: [
        { path: '', redirect: '/admin/users' },
        { path: 'users', component: () => import('./views/admin/UserManage.vue') },
        { path: 'groups', component: () => import('./views/admin/GroupManage.vue') },
        { path: 'messages', component: () => import('./views/admin/MessageQuery.vue') },
        { path: 'stats', component: () => import('./views/admin/StatsView.vue') },
        { path: 'configs', component: () => import('./views/admin/ConfigView.vue') },
        { path: 'apps', component: () => import('./views/admin/AppEntries.vue') },
        { path: 'logs', component: () => import('./views/admin/LogView.vue') }
      ]
    }
  ]
})

// 后台守卫：未登录一律进后台登录页
router.beforeEach((to) => {
  if (to.path !== '/login' && !localStorage.getItem('im-token')) return '/login'
  return true
})

createApp(AdminApp)
  .use(createPinia())
  .use(router)
  .use(i18n)
  .use(ArcoVue)
  .use(ArcoVueIcon)
  .mount('#app')
