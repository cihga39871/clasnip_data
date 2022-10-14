<template>
  <div class="q-pa-md">
    <div class="q-pb-md q-pt-sm text-h6 text-blue">
      Clasnip Database Information
    </div>
    <div class="row">
      <div class="col">
        <!-- Description: only support CLso -->
        <div class="text-body2 text-grey-9">
          Choose a clasnip database
        </div>

        <!-- Choose organism -->
        <q-select
          v-model="selectedDatabase"
          :options="databaseOptions"
          options-html
          outlined
          stack-label
          color="primary"
          dense options-dense
          class="q-pb-md"
        >
          <template v-slot:selected-item="scope">
            <div class="row">
            <q-chip
              dense
              color="white"
              text-color="primary"
              class="q-mr-md"
            >
              {{ scope.opt.dbInfo.taxonomyName }},
              <div class="text-green-9 q-pl-xs">
                {{ Object.keys(scope.opt.dbInfo.groups).length }}
                {{ scope.opt.dbInfo.groupBy }}
                ({{ scope.opt.dbInfo.region }})
              </div>
              <div class="q-ml-sm text-grey">[{{ scope.opt.dbInfo.date}}]</div>
            </q-chip>
            </div>
          </template>

          <template v-slot:no-option>
            <q-item>
              <q-item-section class="text-italic text-grey">
                No databases available
              </q-item-section>
            </q-item>
          </template>
        </q-select>

        <q-slide-transition >
          <div v-if="selectedDatabase != null" class="q-pb-md">
            <database-assessment
              :dbName="selectedDatabase.value"
              :dbInfo="selectedDatabase.dbInfo"
              :dbAccuracy="selectedDatabase.dbInfo.dbAccuracy"
              :groups="selectedDatabase.dbInfo.groups"
              :refGenome="selectedDatabase.dbInfo.refGenome"
              :dbPath="selectedDatabase.dbInfo.dbPath"
              :dbType="selectedDatabase.dbInfo.dbType"
              :region="selectedDatabase.dbInfo.region"
              :taxonomyRank="selectedDatabase.dbInfo.taxonomyRank"
              :taxonomyName="selectedDatabase.dbInfo.taxonomyName"
              :groupBy="selectedDatabase.dbInfo.groupBy"
              :date="selectedDatabase.dbInfo.date"
              :owner="selectedDatabase.dbInfo.owner"
            />
          </div>
        </q-slide-transition>

        <div class="q-pb-md">
          <div class="text-body2 text-grey-7">
            Microorganisms of interest not found in existing databases?
          </div>
          <q-btn
            outline color="grey-8" size="sm"
            label="Create Your Own Database"
            @click="goToCreateDb()"
          />
        </div>
      </div>
    </div>
  </div>

</template>

<script>
import DatabaseAssessment from '../components/DatabaseAssessment.vue'

export default {
  name: 'DatabaseInfo',
  components: { DatabaseAssessment },

  data () {
    return {
      step: 1,
      disableConfirmStep: false,
      disablePreviousStep: false,

      // STEP 1
      selectedDatabase: null,
      databaseOptions: []
    }
  },

  created () {
    this.updateDbOptions(dbOptions => {
      this.databaseOptions = dbOptions
      if (this.$route.params.dbName) {
        this.databaseOptions.forEach(element => {
          if (element.value === decodeURI(this.$route.params.dbName)) {
            this.selectedDatabase = element
          }
        })
      }
    })
  },

  methods: {
    goToCreateDb: function () {
      this.$router.push('/analysis/createdb')
    }
  },

  watch: {
  }
}
</script>
