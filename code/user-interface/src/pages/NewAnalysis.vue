<template>
  <div class="q-pa-md">
    <div class="q-pb-md q-pt-sm text-h6 text-blue">
      New Clasnip Analysis
    </div>
    <div class="text-body2 text-grey-9">
      Enter query sequence
    </div>

    <!-- Description: Sequence -->
    <div class="text-caption text-grey">
      A plain nucleotide sequence, or multiple sequences in FASTA format.
      <q-btn
        round
        size="xs"
        dense
        flat
        icon="help"
        color="grey"
        @click="helpSequence = true"
      />
      <br/>
      <b>Caution:</b> multiple sequences are considered as different
      fragments from ONE sample. Results are based on the sample, not each fragment.
    </div>

    <!-- Help dialog of FASTA format -->
    <q-dialog v-model="helpSequence">
      <q-card>
        <q-card-section>
          <div class="text-h6">FASTA Format</div>
        </q-card-section>
        <q-card-section class="q-pt-none">
          A sequence in FASTA format begins with a single-line description,
          followed by lines of sequence data. The description line (defline)
          is distinguished from the sequence data by a greater-than (">")
          symbol at the beginning. An example sequence in FASTA format is:
          <div class="q-pt-md" style="font-family: monospace">
            <q-input
              value=">JX624236.1 CLso WA-psyllids-1 16S-23S and 23S rRNA gene
GTTGATGGGGTCATTTGAGTTTATGTTAAGGGCCCATAGCTCAGGCGGTTAGAGTGCACCCCTGATAAGGGTGAGGTCGGTAGTTCGAATCTACCTGGGCCCACCATTCAATCAGGCAAGGGGCCGTAGCTCAGCTGGGAGAGCGCCTGCTTTGCAAGCAGGATGTCAGCGGTTCGATCCCGCTCGGCTCCACCAATTGCGAATTTATAGTTTTTTTGTTCTAGGGATTTTTTTTTAGAGCAATAGTTTTTTGAAAATTGAATAGAAGGTAGATTTTTTTGTATTTTTTATATTGGCATTGTATGCGATATGGGAGGTACCGACGTTGTATAACCGCACGTTGAAGATTTATCTCAGGAAATTGGTCTATTGAAAGAGCATAATTTATTTATGTTTTTTTAATTAAGAAACGTTTGTAATGAACTTTATGACGTATTGACAATGAGAGTGATCAAGCGCGATAAGGGCATTTGGTGGATGCCTTGGCATGCACAGGCGATGAAGGACGTAATACGCTGCGATAAGCTACGGGGAGCTGCAAATGAGCATTGATCCGTAGATTTCCGAATGGGGCAACCCACCTTAGGTGTCTAGGAAAGTATACTATTAAGGTTTAATTTTCTAGGTACTTGAAGGTATCTTTACCTGAATAAAATAGGGTAAAAGAAGCGAACGCAGGGAACTGAAACATCTAAGTACCTGTAGGAAAGGACATCAATTGAGACTCCGTTAGTAGTGGCGAGCGAACGCGGATCAGGCCAGTGGTAGGGAAGATTTAAGTAGAATTATCTGGGAAGGTAAGCCATAGAAGGTGATAGCCCCGTACACGTAATAATTTTTTCTATCCTTGAGTAGGGCGGGACACGTGAAATCCTGTTTGAAGATGGGGCGACCACGCTCCAAGCCTAAGTACTCGTGCATGACCGATAGTGAACCAGTACCGTG"
              outlined
              type="textarea"
              readonly
            />
          </div>
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="OK" color="primary" v-close-popup />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Input Sequence -->
    <div class="q-pb-md" style="max-width: 750px; font-family: monospace">
      <q-input v-model="sequences" outlined type="textarea" />
    </div>

    <!-- db -->
    <!-- db -->
    <!-- db -->

    <div class="row">
      <div class="col">
        <div class="text-body2 text-grey-9">
          Choose database(s) for classification
        </div>

        <!-- Choose organism -->
        <q-select
          v-model="selectedDatabases"
          :options="databaseOptions"
          options-html
          use-chips
          stack-label
          multiple
          counter
          outlined
          color="primary"
          dense options-dense
          class="q-pb-md"
        >
          <template v-slot:selected-item="scope">
            <div class="row">
            <q-chip
              removable
              dense
              @remove="scope.removeAtIndex(scope.index)"
              :tabindex="scope.tabindex"
              color="grey-3"
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

        <div v-if="selectedDatabases.length == 0" class="q-pb-lg">
          <div class="text-body2 text-grey-7">
            Microorganisms of interest not found in existing databases?
          </div>
          <q-btn
            outline color="grey-8" size="sm"
            label="Create Your Own Database"
            @click="goToCreateDb()"
          />
        </div>
        <div v-else class="q-pb-lg">
          <div class="text-body2 text-grey-7">
            You can also browse the detailed statistics of databases (optional)
          </div>
          <div class="q-pb-sm" v-for="selectedDatabase in selectedDatabases" v-bind:key="selectedDatabase.value" >
            <q-btn
              outline color="grey-8" size="sm"
              :label="selectedDatabase.dbInfo.taxonomyName + ' (' + selectedDatabase.dbInfo.region + ')'"
              no-caps
              @click="newTabDbInfo(selectedDatabase.value)"
          />
        </div>
        </div>
      </div>
    </div>

    <q-btn
      @click="confirmStep()"
      outline class="text-primary"
      label="Submit"
      :disable="disableConfirmStep"
    />

  <div padding style="">
    <!-- content -->
    <q-dialog v-model="showSubmitResult" persistent  style="width:60em;">
      <q-card>
        <q-card-section class="row items-center">
          <div class="col-auto">
            <q-avatar icon="done" color="green" text-color="white" />
          </div>
          <div class="col q-ml-md">
            <span class="" style="">
              Job submitted! <br/>
              Please copy and save the job identifier below for result query.<br/>
            </span>
              <span class="text-caption text-grey-9">{{jobID}}//{{jobName}}</span>
          </div>
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Submit another job" color="grey" @click="submitAnotherJob()" v-close-popup />
          <q-btn flat label="Job reports" color="green" @click="goToReports()" v-close-popup />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </div>
</div>

</template>

<script>
export default {
  name: 'NewAnalysis',
  components: { },

  data () {
    return {
      disableConfirmStep: false,

      // db
      selectedDatabases: [],
      databaseOptions: [],

      // seq
      helpSequence: false,
      sequences: '',
      email: localStorage.getItem('email'),

      // After submission
      jobID: null,
      jobName: null,
      showSubmitResult: false
    }
  },

  created () {
    this.updateDbOptions(dbOptions => { this.databaseOptions = dbOptions })
  },

  methods: {
    clickDBInfo: function (dbInfo) {
      this.database = dbInfo
      this.notifyWarn('Click db info')
    },

    confirmStep: function () {
      if (this.sequences.length < 10) {
        this.notifyWarn('Please enter a valid sequence.')
      } else if (this.sequences.length > this.FASTQ_MAX_SIZE) {
        this.notifyWarn('Sequences too long (> ' + this.FASTQ_MAX_SIZE + ' characters.)')
      } else if (this.selectedDatabases.length === 0) {
        this.notifyWarn('Please choose database(s).')
      } else {
        this.submitJob()
      }
    },

    goToCreateDb: function () {
      var routeData = this.$router.resolve({ path: '/analysis/createdb' })
      window.open(routeData.href, '_blank')
    },

    goToReports: function () {
      this.$router.push('/analysis/reports')
    },

    newTabDbInfo: function (dbName) {
      var routeData = this.$router.resolve({ path: 'database_info/' + dbName })
      window.open(routeData.href, '_blank')
    },

    submitJob: function () {
      this.disableConfirmStep = true
      var databases = this.selectedDatabases.map(x => { return x.value })
      var jobData = {
        token: localStorage.getItem('token'),
        username: localStorage.getItem('username'),
        email: this.email,
        databases: databases,
        sequences: this.sequences
      }
      this.$axios
        .post(this.MUX_URL + '/cnp/submit_job_multi_db', JSON.stringify(jobData))
        .then(response => {
          this.jobID = response.data.jobID
          this.jobName = response.data.jobName
          this.showSubmitResult = true
          this.updateJobQueryString(this.jobID + '//' + this.jobName) // to local storage
        })
        .catch(error => {
          this.disableConfirmStep = false
          this.notifyError(error)
        })
    },

    submitAnotherJob: function () {
      this.sequences = ''
      this.disableConfirmStep = false
    }

  },

  watch: {
  }
}
</script>
