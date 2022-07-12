<template>
  <q-page padding>
    <div>
      <q-card class="q-mb-lg" flat>

      <!-- Your Analysis -->
      <!-- Your Analysis -->
      <!-- Your Analysis -->

        <q-card-section class="text-primary q-py-none">
          <span class="text-subtitle1">Your Analyses</span>
        </q-card-section>

        <q-list v-if="analyses.length === 0" dense padding>
          <q-item>
            <q-item-section>
              <q-item-label>
                You do not any analysis here.
              </q-item-label>
            </q-item-section>
          </q-item>
        </q-list>

        <!-- Use scroll area if more than 5 items, else not -->
        <q-scroll-area v-else-if="analyses.length > 5" style="height: 250px">
          <q-list dense padding>
            <q-item
              v-for="analysis in analyses" :key="analysis.name"
              clickable @click="goToReports(analysis.name)"
            >
              <q-item-section>
                <q-item-label>
                  {{ analysis.name.replace(/^[a-f0-9\-]+\./, '').replace(/_/g, ' ')}}
                </q-item-label>
                <q-item-label caption lines="2" style="font-family:monospace">
                  {{ analysis.name.replace(/\..*/, '')}}
                </q-item-label>
              </q-item-section>
              <q-item-section side>
                {{analysis.time.replace('T', ' ')}}
              </q-item-section>

            </q-item>
          </q-list>
        </q-scroll-area>

        <q-list v-else dense padding>
          <q-item
            v-for="analysis in analyses" :key="analysis.name"
            clickable @click="goToReports(analysis.name)"
          >
            <q-item-section>
              <q-item-label>
                {{ analysis.name.replace(/^[a-f0-9\-]+\./, '').replace(/_/g, ' ')}}
              </q-item-label>
              <q-item-label caption lines="2" style="font-family:monospace">
                {{ analysis.name.replace(/\..*/, '')}}
              </q-item-label>
            </q-item-section>
            <q-item-section side>
              {{analysis.time.replace('T', ' ')}}
            </q-item-section>

          </q-item>
        </q-list>
      </q-card>

      <!-- Your Database -->
      <!-- Your Database -->
      <!-- Your Database -->

      <q-card class="q-mb-lg" flat>
        <q-card-section class="text-primary q-py-none">
          <span class="text-subtitle1">Your Databases</span>
        </q-card-section>

        <q-list v-if="userDatabases.length === 0" dense padding>
          <q-item>
            <q-item-section>
              <q-item-label>
                You do not have any database here. Only finished databases are shown.
              </q-item-label>
            </q-item-section>
          </q-item>
        </q-list>

        <!-- Use scroll area if more than 5 items, else not -->
        <q-scroll-area v-else-if="userDatabases.length > 5" style="height: 250px">
          <q-list dense padding>
            <q-item
              v-for="dbName in userDatabases" :key="dbName"
              clickable
            >
              <q-item-section>
                <q-item-label>
                  {{ dbName }}
                </q-item-label>
                <q-item-label caption line="2">
                  Reference: {{databaseData[dbName].refGenome}}
                  <q-badge color=grey>
                    {{Object.keys(databaseData[dbName].groups).length}} groups
                    <q-tooltip>
                      <div v-for="group in Object.keys(databaseData[dbName].groups)" :key="group">
                        {{group}}: {{databaseData[dbName].groups[group]}}
                      </div>
                    </q-tooltip>
                  </q-badge>
                </q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-btn round outline size=xs icon='delete_outline' color="red" @click="deleteDbAsk(dbName)"/>
              </q-item-section>
            </q-item>
          </q-list>
        </q-scroll-area>

        <q-list v-else dense padding>
          <q-item
            v-for="dbName in userDatabases" :key="dbName"
            clickable
          >
            <q-item-section>
              <q-item-label>
                {{ dbName }}
              </q-item-label>
              <q-item-label caption line="2">
                Reference: {{databaseData[dbName].refGenome}}
                <q-badge color=grey>
                  {{Object.keys(databaseData[dbName].groups).length}} groups
                  <q-tooltip>
                    <div v-for="group in Object.keys(databaseData[dbName].groups).sort()" :key="group">
                      {{group}}: {{databaseData[dbName].groups[group]}}
                    </div>
                  </q-tooltip>
                </q-badge>
              </q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-btn round outline size=xs icon='delete_outline' color="red" @click="deleteDbAsk(dbName)"/>
            </q-item-section>
          </q-item>
        </q-list>
      </q-card>

    </div>
    <q-dialog v-model="popUpDelete" persistent>
      <q-card>
        <q-card-section class="row items-center" style="width:40em;">
          <q-avatar icon="priority_high" color="red-5" text-color="white" />
          <span class="q-ml-sm">Do you really want to delete the database:<br/> {{dbSelected}}?</span>
        </q-card-section>
        <q-card-section class="text-negative">
          There is no way to go back. Once it is done, you and the whole community can no longer access to the database anymore.
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" color="grey" @click="popUpDelete=false" v-close-popup />
          <q-btn flat label="Delete" color="red-5" @click="deleteDbConfirmed(dbSelected)"/>
        </q-card-actions>
      </q-card>
    </q-dialog>

  </q-page>
</template>

<script>
export default {
  name: 'User',

  data () {
    return {
      databaseData: null,
      userDatabases: [],
      analyses: [],
      popUpDelete: false,
      dbSelected: null,
      username: localStorage.getItem('username')
    }
  },

  created () {
    this.getDatabase()

    var jobData = {
      token: localStorage.getItem('token'),
      username: this.username
    }

    this.$axios
      .post(this.MUX_URL + '/cnp/analysis_list', JSON.stringify(jobData))
      .then(response => {
        this.analyses = response.data
      })
      .catch(error => {
        this.notifyError(error)
      })
  },

  methods: {
    getDatabase: function () {
      this.$axios
        .get(this.MUX_URL + '/cnp/get_database')
        .then(response => {
          this.databaseData = response.data
          this.userDatabases = []
          var dbKeys = Object.keys(response.data)
          dbKeys.forEach(key => {
            var owner = this.databaseData[key].owner
            if (owner !== null && owner === this.username) {
              this.userDatabases.push(key)
            }
          })
        })
        .catch(error => {
          this.notifyError(error)
        })
    },
    goToReports: function (jobName) {
      this.$router.push('/analysis/reports/' + jobName)
    },
    deleteDbAsk: function (dbName) {
      this.dbSelected = dbName
      this.popUpDelete = true
    },
    deleteDbConfirmed: function (dbName) {
      var jobData = {
        token: localStorage.getItem('token'),
        username: localStorage.getItem('username'),
        dbName: this.dbSelected
      }
      this.$axios
        .post(this.MUX_URL + '/cnp/rm_clasnip_database', JSON.stringify(jobData))
        .then(response => {
          this.notifyInfo('Database deleted.')
          this.getDatabase()
          this.popUpDelete = false
        })
        .catch(error => {
          this.notifyError(error)
        })
    }
  }
}
</script>
