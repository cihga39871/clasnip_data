export default function () {
  return {

    analysisLinks: [
      {
        title: 'New Analysis',
        icon: 'add_box',
        link: '/analysis/new_analysis'
      },
      {
        title: 'Reports',
        icon: 'summarize',
        link: '/analysis/reports'
      },
      {
        title: 'Database Information',
        icon: 'assessment',
        link: '/analysis/database_info'
      },
      {
        title: 'Create Database',
        icon: 'addchart',
        link: '/analysis/createdb'
      }
    ],

    settingLinks: [
      {
        title: 'Settings',
        icon: 'settings',
        link: '/settings',
        isHidden: true
      }
    ],

    userLinks: [
      {
        title: 'User Space',
        icon: 'person',
        link: '/user',
        isHidden: true
      },
      {
        title: 'Log In',
        icon: 'login',
        link: '/login'
      },
      {
        title: 'Log Out',
        icon: 'eject',
        link: '/logout',
        isHidden: true
      },
      {
        title: 'Register',
        icon: 'person_add',
        link: '/register'
      }
    ]

  }
}
