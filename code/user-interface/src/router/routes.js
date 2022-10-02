
const routes = [
  {
    path: '/',
    component: () => import('layouts/MainLayout.vue'),
    children: [
      { path: '', component: () => import('pages/Index.vue') },
      { path: 'user', component: () => import('pages/User.vue'), meta: { requiresAuth: true } },
      { path: 'login', component: () => import('pages/Login.vue') },
      { path: 'logout', component: () => import('pages/Logout.vue') },
      { path: 'register', component: () => import('pages/Register.vue') }
    ]
  },

  {
    path: '/analysis',
    component: () => import('layouts/MainLayout.vue'),
    children: [
      {
        path: '',
        component: () => import('pages/NewAnalysis.vue'),
        meta: { requiresAuth: false }
      },

      {
        path: 'new_analysis',
        component: () => import('pages/NewAnalysis.vue'),
        meta: { requiresAuth: false }
      },

      {
        path: 'database_info',
        component: () => import('pages/DatabaseInfo.vue'),
        meta: { requiresAuth: false }
      },

      {
        path: 'database_info/:dbName',
        component: () => import('pages/DatabaseInfo.vue'),
        meta: { requiresAuth: false }
      },

      {
        path: 'reports',
        component: () => import('pages/Reports.vue'),
        meta: { requiresAuth: false }
      },

      {
        path: 'reports/:queryString',
        component: () => import('pages/Reports.vue'),
        meta: { requiresAuth: false }
      },

      {
        path: 'createdb',
        component: () => import('pages/CreateDatabase.vue'),
        meta: { requiresAuth: true }
      }
    ]
  },

  // Always leave this as last one,
  // but you can also remove it
  {
    path: '*',
    component: () => import('pages/Error404.vue')
  }
]

export default routes
