<template>
  <q-layout view="hHh Lpr lFf">
    <q-header elevated>
      <q-banner v-if=false elevated dense class="bg-grey-3 text-primary" style="text-align:left">
        Banner.
      </q-banner>
      <q-toolbar>
        <q-btn
          flat
          dense
          round
          icon="img:icons/clasnip_logo_white.svg"
          aria-label="Menu"
          @click="leftDrawerOpen = !leftDrawerOpen"
        />

        <q-toolbar-title style="padding-top: 2px">
          <div class="flex flex-left" @click="clickLogo()" style="cursor:pointer">
            <img
              alt="Clasnip logo" height="21"
              style="filter: grayscale(100%) brightness(500%);"
              src="icons/clasnip_logo_word.svg"
            >
          </div>
        </q-toolbar-title>

        <div v-if="!hasToken()">
          <q-btn flat color="white" label="Register" @click="goTo('/register')" class="text-weight-regular"/>
          <q-btn flat color="white" label="Log In" @click="goTo('/login')" class="text-weight-regular"/>
        </div>
        <div v-else>
          {{ greeting }}, {{ userFullName }}!
          <q-btn flat color="white" label="Log out" @click="goTo('/logout') " class="text-weight-regular"/>
        </div>

        <a href="https://github.com/cihga39871/Clasnip.com/wiki/Clasnip" target="_blank" style="text-decoration:none;">
          <q-icon  size="sm" color="white" name="contact_support">
            <q-tooltip content-class="text-body2">Contact us on GitHub.</q-tooltip>
          </q-icon>
        </a>
      </q-toolbar>
    </q-header>

    <q-drawer
      v-model="leftDrawerOpen"
      show-if-above

      :mini="miniState"
      @mouseover="miniState = false"
      @mouseout="mouseOutDrawer()"

      :breakpoint="500"
      bordered
      content-class="bg-grey-3"
    >
      <q-list>

        <div v-for="item in this.$store.state.layout.analysisLinks" :key="item.title">
          <div v-bind:hidden="item.isHidden">
            <q-item clickable v-ripple @click="clickLink(item)" v-bind:active="item.isActive">
              <q-item-section v-if="item.icon" avatar>
                <q-icon :name="item.icon" />
              </q-item-section>

              <q-item-section>
                <q-item-label>{{ item.title }}</q-item-label>
              </q-item-section>
            </q-item>
          </div>
        </div>

        <q-separator></q-separator>

        <div v-for="item in this.$store.state.layout.settingLinks" :key="item.title">
          <div v-bind:hidden="item.isHidden">
            <q-item clickable v-ripple @click="clickLink(item)" v-bind:active="item.isActive">
              <q-item-section v-if="item.icon" avatar>
                <q-icon :name="item.icon" />
              </q-item-section>

              <q-item-section>
                <q-item-label>{{ item.title }}</q-item-label>
              </q-item-section>
            </q-item>
          </div>
        </div>

        <q-separator></q-separator>

        <div v-for="item in this.$store.state.layout.userLinks" :key="item.title">
          <div v-bind:hidden="item.isHidden">
            <q-item clickable v-ripple @click="clickLink(item)" v-bind:active="item.isActive">
              <q-item-section v-if="item.icon" avatar>
                <q-icon :name="item.icon" />
              </q-item-section>

              <q-item-section>
                <q-item-label>{{ item.title }}</q-item-label>
              </q-item-section>
            </q-item>
          </div>
        </div>

      </q-list>
    </q-drawer>

    <q-page-container>
      <router-view />
    </q-page-container>
  </q-layout>
</template>

<script>

const greetings = ['Welcome', 'Good day', 'Hey', 'Howdy', 'Hi', 'Hello', 'Bonjour', 'Greetings', 'Shalom', 'What\'s up', 'How are you']

export default {
  name: 'MainLayout',
  components: { },
  data () {
    return {
      leftDrawerOpen: false,
      miniState: false,
      currentRoutePath: '/',
      greeting: greetings[Math.floor(Math.random() * greetings.length)],
      get userFullName () { return localStorage.getItem('name') }
    }
  },

  methods: {
    clickLink: function (item) {
      this.$store.commit('layout/activateLink', item.title)
      this.$router.push(item.link)
    },
    clickLogo: function () {
      this.$store.commit('layout/activateLink', '')
      this.$router.push('/')
    },
    mouseOutDrawer: function () {
      this.miniState = this.currentRoutePath !== '/'
    },
    goTo: function (routerLink) {
      this.$router.push(routerLink)
    }
  },

  created () {
    this.currentRoutePath = this.$route.path
    this.$store.commit('layout/activateLink', this.currentRoutePath)

    if (this.hasToken()) {
      this.$axios.post(this.MUX_URL + '/pccau/validate', JSON.stringify({
        token: localStorage.getItem('token'),
        username: localStorage.getItem('username')
      }))
        .then((response) => {
          this.$store.commit('layout/userLinks')
        })
        .catch(() => {
          // this.notifyInfo('Connected to server as guest.')
          this.clearToken()
          this.$store.commit('layout/guestLinks')
        })
    } else {
      this.clearToken()
      this.$store.commit('layout/guestLinks')
    }
  },

  watch: {
    $route: function () {
      this.currentRoutePath = this.$route.path
      if (this.currentRoutePath === '/') {
        this.miniState = false
      }
      this.$store.commit('layout/activateLink', this.currentRoutePath)
    }
  }
}
</script>
