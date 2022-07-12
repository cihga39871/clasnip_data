<template>
  <q-page class="flex flex-center bg-grey-2">
    <q-card style="width:30em" flat bordered>
      <q-card-section class="text-primary">
        <div style="font-size:1.35em">Register</div>
        <!-- <div class="text-subtitle2">by John Doe</div> -->
      </q-card-section>

      <q-card-section>
        <q-form
          @submit="onSubmit"
          @reset="onReset"
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

          <q-input
            outlined
            v-model="name"
            label="Name *"
            lazy-rules dense
            :rules="[ val => val && val.length > 0 || 'Please type your name']"
          />

          <q-input
            outlined
            v-model="email"
            label="Email *"
            lazy-rules dense
            :rules="[
              val => val && val !== '' || 'Please type your email',
              val => val && val.match(/^[^@]+@[^\.@]+\.[^@]+$/) || 'Please type a real email'
            ]"
          />

          <!-- <q-toggle v-model="accept" label="I accept the license and terms" /> -->

          <div>
            <q-btn label="Submit" outline class="text-primary" type="submit"/>
            <q-btn label="Reset" type="reset" flat class="q-ml-sm text-primary text-grey"/>
          </div>
        </q-form>
      </q-card-section>

    </q-card>
  </q-page>

</template>

<script>
export default {
  name: 'Register',

  data () {
    return {
      username: null,
      password: null,
      name: null,
      email: null,
      isPwd: true,
      accept: false
    }
  },

  methods: {
    onSubmit () {
      // TODO: register to server
      this.$axios.post(this.MUX_URL + '/pccau/register',
        this.username + '\n' + this.password + '\n' + JSON.stringify({
          name: this.name,
          email: this.email
        })
      )
        .then((response) => {
          this.notifyInfo('Registration successful. Please log in.')
          this.$router.push('/login')
        })
        .catch((error) => {
          this.notifyError(error)
        })
    },

    onReset () {
      this.username = null
      this.password = null
      this.name = null
      this.email = null
    }
  }
}
</script>
