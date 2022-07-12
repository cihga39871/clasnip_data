<template>
<div>
  <div class="q-pa-md">
    <q-stepper v-model="step" ref="stepper" vertical animated>
      <!-- STEP 1 -->
      <!-- STEP 1 -->
      <!-- STEP 1 -->

      <q-step
        :name="1"
        title="New Analysis"
        icon="tab"
        :done="step > 1"
      >
        <div class="row">
          <div class="col">
            <!-- Description: only support CLso -->
            <div class="text-body2 text-grey-9">
              Select a database for classification.
            </div>

            <!-- Choose organism -->
            <q-select
              v-model="databaseOption"
              :options="databaseOptions"
              options-html
              outlined
              color="primary"
              dense
              class="q-pb-md"
            />

            <q-slide-transition>
              <div v-if="database" class="q-pb-md">
                <database-assessment
                  :dbName="databaseOption.value"
                  :dbInfo="databaseData[database]"
                  :dbAccuracy="databaseData[database].dbAccuracy"
                  :groups="databaseData[database].groups"
                  :refGenome="databaseData[database].refGenome"
                  :dbPath="databaseData[database].dbPath"
                  :dbType="databaseData[database].dbType"
                  :region="databaseData[database].region"
                  :taxonomyRank="databaseData[database].taxonomyRank"
                  :taxonomyName="databaseData[database].taxonomyName"
                  :date="databaseData[database].date"
                  :owner="databaseData[database].owner"
                />
              </div>
            </q-slide-transition>

            <div class="text-body2 text-grey-7">
              Microorganisms of interest not found in existing databases?
            </div>
            <q-btn
              outline color="grey-8"
              label="Create Your Own Database"
              @click="goToCreateDb()"
            />
          </div>
        </div>
      </q-step>

      <!-- STEP 2 -->
      <!-- STEP 2 -->
      <!-- STEP 2 -->

      <q-step :name="2" title="Query Sequences" icon="tab" :done="step > 2">
        <div class="text-body2 text-grey-9">
          Enter sequences related to {{ database }}.
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
            @click="helpSequence = true"
          />
          <br />
          <b>Caution:</b> multiple sequences are considered as different
          fragments from ONE sample. Results are based on the sample, not each
          fragment.
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

        <q-option-group
          v-model="optionsSelected"
          :options="optionsProvided"
          type="checkbox"
          class="text-grey-9"
        />

        <!-- Input email -->
        <!-- <div class="q-pt-md" style="max-width: 750px; font-family: monospace">
          <q-input outlined v-model="email" label="Email" dense />
        </div>
        <div class="text-caption text-grey-9">
          Enter Email to receive Clasnip result.
        </div> -->
      </q-step>

      <template v-slot:navigation>
        <q-stepper-navigation>
          <q-btn
            @click="confirmStep()"
            outline class="text-primary"
            :label="step === 2 ? 'Submit' : 'Continue'"
            :disable="disableConfirmStep"
          />
          <q-btn
            v-if="step > 1"
            flat
            outline class="text-grey q-ml-sm"
            @click="previousStep()"
            label="Back"
            :disable="disablePreviousStep"
          />
        </q-stepper-navigation>
      </template>
    </q-stepper>
  </div>

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
import DatabaseAssessment from '../components/DatabaseAssessment.vue'

export default {
  name: 'NewAnalysis',
  components: { DatabaseAssessment },

  data () {
    return {
      step: 1,
      disableConfirmStep: false,
      disablePreviousStep: false,

      // STEP 1
      database: null,
      databaseOption: null,
      databaseOptions: null,
      databaseData: null,

      // STEP 2
      helpSequence: false,
      sequences: '',
      email: localStorage.getItem('email'),
      optionsSelected: [],
      optionsProvided: [
        {
          label: 'The query sequences are parts from [organism].',
          value: 'opt1'
        }
      ],

      // After submission
      jobID: null,
      jobName: null,
      showSubmitResult: false
    }
  },

  created () {
    this.$axios
      .get(this.MUX_URL + '/cnp/get_database')
      .then(response => {
        this.databaseData = response.data
        var dbKeys = Object.keys(response.data)
        this.databaseOptions = dbKeys.map(key => {
          // var label = key + '; created by ' + this.databaseData[key].owner
          var db = this.databaseData[key]
          var label
          if (db.taxonomyName === '') {
            label = '<div class="row"><div class="col">' +
            key +
            '</div><div class="col-auto text-right text-grey"> [created by ' +
            db.owner + ']</div></div>'
          } else {
            label = '<div class="row"><div class="col">' +
              db.taxonomyName + ' (' + db.region + ') ' +
              '</div><div class="col-auto text-right text-grey"> [created by ' +
              db.owner + ' on ' + db.date + ']</div></div>'
          }
          return {
            label: label,
            value: key
          }
        })
      })
      .catch(error => {
        this.notifyError(error)
      })
  },

  methods: {
    confirmStep: function () {
      if (this.step === 1) {
        if (this.database) {
          this.optionsProvided[0].label = this.optionsProvided[0].label.replace(
            '[organism]',
            this.database
          )
          this.disableConfirmStep = false
          this.optionsSelected = []
          this.$refs.stepper.next()
        } else {
          this.notifyWarn('Please choose a database.')
        }
      } else if (this.step === 2) {
        if (this.optionsSelected.length !== this.optionsProvided.length) {
          this.notifyWarn('Cannot submit job without agreement.')
        } else if (this.sequences.length < 10) {
          this.notifyWarn('Invalid sequence.')
        } else if (this.sequences.length > this.FASTQ_MAX_SIZE) {
          this.notifyWarn('Sequences too long (> ' + this.FASTQ_MAX_SIZE + ' characters.)')
        } else {
          this.submitJob()
        }
      }
    },

    previousStep: function () {
      this.disableConfirmStep = false
      this.$refs.stepper.previous()
    },

    goToCreateDb: function () {
      this.$router.push('/analysis/createdb')
    },

    goToReports: function () {
      this.$router.push('/analysis/reports')
    },

    submitJob: function () {
      this.disableConfirmStep = true
      this.disablePreviousStep = true
      var jobData = {
        token: localStorage.getItem('token'),
        username: localStorage.getItem('username'),
        email: this.email,
        database: this.database,
        sequences: this.sequences
      }
      this.$axios
        .post(this.MUX_URL + '/cnp/submit_job', JSON.stringify(jobData))
        .then(response => {
          this.jobID = response.data.jobID
          this.jobName = response.data.jobName
          this.showSubmitResult = true
          this.updateJob(this.jobID, this.jobName) // to local storage
        })
        .catch(error => {
          this.disableConfirmStep = false
          this.disablePreviousStep = false
          this.notifyError(error)
        })
    },

    submitAnotherJob: function () {
      this.optionsSelected = []
      this.sequences = ''
      this.disableConfirmStep = false
      this.disablePreviousStep = false
    }

  },

  watch: {
    optionsSelected: function () {
      if (this.optionsSelected.length === this.optionsProvided.length) {
        this.disableConfirmStep = false
      } else {
        this.disableConfirmStep = true
      }
    },

    databaseOption: function () {
      if (this.databaseOption) {
        this.database = this.databaseOption.value
      } else {
        this.database = null
      }
    }
  }
}
</script>
