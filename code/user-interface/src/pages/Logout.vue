<template>
  <q-page padding style="font-family: Lato">
    <!-- content -->
    <q-dialog v-model="popUp" persistent>
      <q-card>
        <q-card-section class="row items-center" style="width:30em;">
          <q-avatar icon="priority_high" color="red-5" text-color="white" />
          <span class="q-ml-sm">Do you want to log out?</span>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" color="grey" @click="quitLogOut" v-close-popup />
          <q-btn outline label="Log out" color="red-5" @click="confirmLogOut" v-close-popup />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script>
export default {
  name: 'Logout',

  data () {
    return {
      popUp: true
    }
  },

  methods: {
    confirmLogOut () {
      this.$axios.post(this.MUX_URL + '/pccau/logout', JSON.stringify({
        token: localStorage.getItem('token'),
        username: localStorage.getItem('username')
      }))
      this.notifyInfo('Log out successful.')
      this.clearToken()
      this.$store.commit('layout/guestLinks')
      this.$router.push('/')
    },

    quitLogOut () {
      this.$router.push('/')
    }
  }
}
</script>
