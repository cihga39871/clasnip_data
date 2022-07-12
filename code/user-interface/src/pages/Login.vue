<template>
  <q-page class="flex flex-center bg-grey-2">
    <q-card style="width:30em" flat bordered>
      <q-card-section class="text-primary">
        <div style="font-size:1.35em">Log in</div>
        <!-- <div class="text-subtitle2">by John Doe</div> -->
      </q-card-section>

      <q-card-section>
        <q-form
          @submit="onSubmit"
          @reset="onForget"
          class="q-gutter-md"
        >

          <q-input
            outlined
            v-model="username"
            label="Username *"
            lazy-rules dense
            :rules="[ val => val && val.length > 0 || 'Please type your username']"
          />

          <q-input
            outlined
            v-model="password"
            label="Password *"
            lazy-rules dense type="password"
            :rules="[ val => val && val.length > 0 || 'Please type your password']"
          />

          <div>
            <q-btn label="Submit" outline class="text-primary" type="submit"/>
            <q-btn label="Forget username or password" type="reset" flat class="q-ml-sm text-grey" />
          </div>
        </q-form>
      </q-card-section>

    </q-card>
  </q-page>

</template>

<script>

import sha3 from 'js-sha3'

export default {
  name: 'Login',

  data () {
    return {
      username: null,
      password: null,
      accept: false,
      value: null,
      token: null,
      passCode: null
    }
  },

  methods: {

    onSubmit () {
      this.$axios.post(this.MUX_URL + '/pccau/get_token',
        this.username
      )
        .then((response) => {
          this.value = (response.data.value)
          this.token = this.value.substring(0, this.value.length - 8)
          this.passCode = sha3.sha3_384(this.value.slice(-8) + this.password)
          this.passCode = sha3.sha3_384(this.token + this.passCode)

          this.$axios.post(this.MUX_URL + '/pccau/login',
            this.username + '\n' + this.passCode + '\n' + this.token
          )
            .then((response) => {
              this.notifyInfo('Log in successful.')
              this.updateToken(response.data)
              this.$store.commit('layout/userLinks')
              this.$router.push('/')
            })
            .catch((error) => {
              this.notifyError(error)
              this.clearToken()
              this.$store.commit('layout/guestLinks')
            })
        })
        .catch((error) => {
          this.notifyError(error)
          this.clearToken()
          this.$store.commit('layout/guestLinks')
          return null
        })
    },

    onForget () {
      this.notifyWarn('Please contact the maintainer.')
    }
  },

  created () {
    this.clearToken()
    this.$store.commit('layout/guestLinks')
  }
}
</script>
