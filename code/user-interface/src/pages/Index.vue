<template>
  <q-page class="q-pa-md flex justify-center">
    <div class="row vertical-middle">
      <div class="col-12 flex justify-center">
        <img
          alt="Clasnip logo"
          width="128"
          src="~assets/clasnip_logo_full.svg"
        >
      </div>
      <div class="col-12 flex justify-center q-pb-lg text-grey-9" style="text-align: center">
        Closely-related microorganism classification based on SNPs & multilocus sequencing typing (MLST)
        <br/>
        <br/>
      </div>
      <div class="col-12 flex justify-center">
        <div class="col-auto flex justify-center q-pb-lg q-px-sm">
          <q-btn outline no-caps stack color="blue-6" to="analysis/new_analysis" class="btn-fixed-width">
            <div>NEW CLASSIFICATION</div>
            <q-tooltip content-class="bg-blue-7 text-white shadow-4" :offset="[10, 10]">
              <div class="text-caption">Classify a nucleotide sequence to an database;</div>
              <div class="text-caption">Generate a MLST table for database groups and the sample.</div>
            </q-tooltip>

          </q-btn>
        </div>

        <div class="col-auto flex justify-center q-pb-lg q-px-sm">
          <q-btn outline color="purple-6" no-caps stack to="analysis/reports" class="btn-fixed-width">
            <div>ANALYSIS REPORT</div>
            <q-tooltip content-class="bg-purple-7 text-white shadow-4" :offset="[10, 10]">
              <div class="text-caption">If you did a clasnip analysis before,</div>
              <div class="text-caption">query the report using the job ID provided when submitting</div>
            </q-tooltip>
          </q-btn>
        </div>

        <div class="col-auto flex justify-center q-pb-lg q-px-sm">
          <q-btn outline color="green-6" no-caps stack @click="goToCreateDb" class="btn-fixed-width">
            <div>CREATE DATABASE</div>
            <q-tooltip content-class="bg-green-7 text-white shadow-4" :offset="[10, 10]">
              <div class="text-caption">Build your own database of closely-related microorganisms</div>
              <div class="text-caption">by providing a zipped file with grouped FASTA samples.</div>
            </q-tooltip>
          </q-btn>
        </div>

        <div class="col-auto flex justify-center q-pb-lg q-px-sm">
          <q-btn outline color="blue-grey-6" no-caps stack @click="goToUser" class="btn-fixed-width">
            <div>YOUR REPORTS & DATABASES</div>
            <q-tooltip content-class="bg-blue-grey-7 text-white shadow-4" :offset="[10, 10]">
              <div class="text-caption">Browse your previous analyses and manage the databases.</div>
            </q-tooltip>
          </q-btn>
        </div>
      </div>

    </div>

    <div class="col-12 flex content-end q-px-sm">
      <q-btn v-if="!hasLogin" size="sm" color="indigo-6" no-caps stack  to="register" class="q-mx-sm">
        <div>REGISTER</div>
      </q-btn>
      <q-btn v-if="!hasLogin" size="sm" flat color="indigo-6" no-caps stack  to="login" class="q-mx-sm">
        <div>LOG IN</div>
      </q-btn>
      <q-btn v-if="hasLogin" size="sm" flat color="red-9" no-caps stack  to="logout" class="q-mx-sm">
        <div>LOG OUT</div>
      </q-btn>
    </div>

  </q-page>
</template>

<script>
export default {
  name: 'PageIndex',

  data () {
    return {
      hasLogin: false
    }
  },

  methods: {
    goToCreateDb: function () {
      if (this.hasLogin) {
        this.$router.push('/analysis/createdb')
      } else {
        this.notifyInfo('You need to login to create database.')
      }
    },
    goToUser: function () {
      if (this.hasLogin) {
        this.$router.push('/user')
      } else {
        this.notifyInfo('You need to login to browse your reports and manage your databases.')
      }
    }
  },

  created () {
    this.hasLogin = this.hasToken()
  }
}
</script>
