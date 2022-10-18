<template>
  <div class="q-pa-md">
    <div class="q-pb-md q-pt-sm text-h6 text-blue">
      Clasnip Classification Reports
    </div>

    <q-slide-transition>
      <q-banner v-if="!dismissBanner && hasLogin" dense class="bg-green-2 q-mb-md" rounded>
        <template v-slot:avatar>
          <q-icon name="info" color="green" />
        </template>
        Forget Job ID? You can view your previous analyses on User page.
        <template v-slot:action>
          <q-btn flat color="green-5" label="Dismiss" @click="dismissBanner=true"/>
          <q-btn flat color="green-8" label="Go to User Space" @click="goTo('/user')"/>
        </template>
      </q-banner>
    </q-slide-transition>

    <q-slide-transition>
      <q-banner v-if="!dismissBanner && !hasLogin" dense class="bg-green-2 q-mb-md" rounded>
        <template v-slot:avatar>
          <q-icon name="info" color="green" />
        </template>
        Forget Job ID? Don't worry. You can view your analyses after logging in.
        <template v-slot:action>
          <q-btn flat color="green-5" label="Dismiss" @click="dismissBanner=true"/>
          <q-btn flat color="green-8" label="Register" @click="goTo('/register')"/>
          <q-btn flat color="green-8" label="Log In" @click="goTo('/login')"/>
        </template>
      </q-banner>
    </q-slide-transition>

    <div class="row q-pb-md">
      <div class="col">
        <div class="text-body2 text-grey-9">
          Report Query
        </div>

        <q-input outlined bottom-slots v-model="queryString" label="Job ID" dense style="font-family:monospace" v-on:keyup.enter="reportQuery()">
          <template v-slot:append>
            <q-icon v-if="queryString !== ''" name="close" @click="queryString = ''" class="cursor-pointer" />
          </template>

          <template v-slot:hint>
            <span style="font-family:Roboto">
            Job ID is provided after job submission in this format:</span>
            000000.999999//12345678-90ab-cdef-1234-567890abcdef.database1.database2
          </template>

          <template v-slot:after>
            <q-btn color="primary" round dense outline icon="send" @click="reportQuery()"/>
          </template>
        </q-input>
      </div>
    </div>

    <q-slide-transition>
      <div v-if="showReports">
        <div v-if="jobs.length > 0" class="q-pb-md">

          <div class="row q-pt-md q-pb-sm text-subtitle1 text-primary" >
            Job status
          </div>

          <div v-for="job in jobs" v-bind:key="job.id" class="row">
            <job-chip
              :id="job.id"
              :name="job.name"
              :state="job.state"
              :user="job.user"
              :createTime="job.create_time"
              :startTime="job.start_time"
              :stopTime="job.stop_time"
            />
          </div>
        </div>

        <div class="q-pb-md q-pt-md" v-if="classificationResults.length > 1">
          <q-banner dense class="bg-blue-2 q-mb-md" rounded>
            <template v-slot:avatar>
              <q-icon name="info" color="primary" />
            </template>
            The sample is compared against multiple databases. You can combine or seperate the classification summary.
            <template v-slot:action>
              <span class="text-grey-8 text-caps">SEPERATE</span>
              <q-toggle v-model="combineClassificationResults" />
              <span class="text-primary text-caps q-pr-md">COMBINE</span>
            </template>
          </q-banner>
        </div>

        <div v-if="failInfo.length > 0" class="q-pb-md">
          <div class="row q-pt-md q-pb-sm text-subtitle1 text-primary" >
            Classification Error Infomation
          </div>

          <div v-for="failText in failInfo" v-bind:key="failText">
            <div class="row q-pb-sm text-red">
              ⋅ {{ failText }}
            </div>
          </div>
        </div>

        <div v-if="classificationResults.length > 0">
          <q-slide-transition v-if="classificationResults.length > 1">
            <div v-show="combineClassificationResults">
              <div class="row">
                <div class="col q-pb-md">
                  <table-viewer
                    :link="classificationResults.join(':')"
                    label="Classification Summary"
                    subtitle="Multiple databases"
                    isClassificationSummary
                    autoLoad
                    flat
                    help
                    helpTitle="Explanation"
                    :helpHtml="helpClassificationSummary"
                    filter
                    filterColName="col6"
                    :filterValue="probability"
                    :filterValueMin="0"
                    :filterValueMax="1.0"
                    filterLabel="Show probability ≥"
                  />
                </div>
              </div>
            </div>
          </q-slide-transition>
          <q-slide-transition>
            <div v-show="!combineClassificationResults">
              <div class="row" v-for="classificationResult in classificationResults" v-bind:key="classificationResult">
                <div class="col q-pb-md">
                  <table-viewer
                    :link="classificationResult"
                    label="Classification Summary"
                    :subtitle="getDbName(classificationResult)"
                    isClassificationSummary
                    autoLoad
                    flat
                    help
                    helpTitle="Explanation"
                    :helpHtml="helpClassificationSummary"
                    filter
                    filterColName="col6"
                    :filterValue="probability"
                    :filterValueMin="0"
                    :filterValueMax="1.0"
                    filterLabel="Show probability ≥"
                  />
                </div>
              </div>
            </div>
          </q-slide-transition>
        </div>

        <div class="row q-pb-md" v-for="mlstTable in mlstTables" v-bind:key="mlstTable">
          <div class="col">
            <table-viewer
              :link="mlstTable"
              label="Multi Locus Sequence Typing (MLST)"
              :subtitle="getDbName(mlstTable)"
              height=0
              flat
              help
              helpTitle="Explanation"
              :helpHtml="helpMlst"
              :hideCols="['DEPTH']"
            />
          </div>
        </div>

        <div class="row">
          <div v-if="reports.seq" class="col q-pb-md">
            <file-viewer
              :link="reports.seq"
              label="Query Sequences"
              format="log"
              flat
            />
          </div>
        </div>

        <div class="row q-pt-md q-pb-md" v-for="log in logs" v-bind:key="log">
          <div class="col">
            <file-viewer
              :link="log"
              label="Log Info"
              :subtitle="getDbName(log)"
              format="log"
              flat
              :allowReload="false"
            />
          </div>
        </div>
      </div>
    </q-slide-transition>
  </div>
</template>

<script>
import FileViewer from '../components/FileViewer.vue'
import TableViewer from '../components/TableViewer.vue'
import JobChip from '../components/JobChip.vue'
// import HtmlViewer from '../components/HtmlViewer.vue'

export default {
  components: { FileViewer, TableViewer, JobChip },
  name: 'Reports',

  data () {
    return {
      hasLogin: false,
      dismissBanner: true,

      queryString: '',

      showReports: false,
      reports: null,
      databaseOptions: [],
      // jobState: 'unknown',
      // jobStateColor: 'warning',

      jobs: [],
      logs: [],
      classificationResults: [],
      combineClassificationResults: true,
      mlstTables: [],
      failInfo: [],

      probability: 0.05,

      helpClassificationSummary: '<span class="text-primary">PERCENT_MATCHED: </span> sequence identity. The ratio of MATCHED_SNP_SCORE and COVERED_SNP_SCORE.<br/><br/><span class="text-primary">MATCHED_SNP_SCORE: </span> sum of scores of all matched SNPs.<br/><br/><span class="text-primary">COVERED_SNP_SCORE: </span> SNP coverage. Sum of scores of all matched and unmatched SNPs.<br/><br/><span class="text-primary">CDF: </span> probability within GROUP. The percent of samples in this GROUP has lower sequence identity than the input sample.<br/><br/><span class="text-primary">PROBABILITY: </span> the probability of the sample is classified to LABELED_GROUP.<br/><br/>          If the deviation of two groups\' PERCENT_MATCHED are small, please double-check the exact SNP variations in the MLST table. <br/><br/>If COVERED_SNP_SCORE is small, it probably means insufficient SNPs were covered by your query sequences, so PERCENT_MATCHED may be stochastic and not predicted precisely.<br/><br/> The classification accuracy is based on your query sequences and the public database.',

      helpMlst: '<span class="text-primary">CHROM</span> and <span class="text-primary">POS: </span>the chromosome and position of the reference file in the database.<br/><br/><span class="text-primary">REF: </span> the base(s) of the reference.<br/><br/><span class="text-primary">GROUP COLUMNS: </span> The groups defined in the database. If a SNP is identical to REF, it will be marked as a dot. Numbers in brackets mean the SNP frequencies of all samples in the database group.<br/><br/><span class="text-primary">SAMPLE: </span> the SNP(s) of query sequences. If a SNP is identical to REF, it will be marked as a dot. <br/><br/><span class="text-primary">DEPTH: </span>can be ignored in most cases. The query sequences are cut to 120-bp subsequences, and DEPTH is the number of subsequences mapped to the location. If SAMPLE is not identical to REF, multiple depths are shown and splitted by comma (,), indicating the depths of REF and SNPs, respectively.<br/><br/><span class="text-primary">Visible columns: </span>You can select columns of interest using the Column button on the top right of the table.'
    }
  },

  // 3269715850055321.3269715850202822//5a71dd67-12c4-535b-bb08-adc3c6ecd91a.CLso_16s_test.clso_50s
  created () {
    this.hasLogin = this.hasToken()

    if (this.$route.params.queryString) {
      this.queryString = this.$route.params.queryString
      this.dismissBanner = true
      this.reportQuery()
    } else {
      this.queryString = this.getJobQueryString()
      this.dismissBanner = false
    }
  },

  watch: {
    jobs: { handler (n, o) { }, deep: true },
    logs: { handler (n, o) { }, deep: true },
    classificationResults: { handler (n, o) { }, deep: true },
    mlstTables: { handler (n, o) { }, deep: true },
    failInfo: { handler (n, o) { }, deep: true }
  },

  methods: {
    reportQuery: function () {
      if (this.queryString.length < 9) {
        this.notifyError('Job ID is invalid.')
        this.cleanReports()
        return
      }
      this.$axios.post(this.MUX_URL + '/cnp/multi_report_query', JSON.stringify({
        token: localStorage.getItem('token'),
        username: localStorage.getItem('username'),
        queryString: this.queryString
      }))
        .then((response) => {
          this.updateReports(response.data)
          this.notifyInfo('Reports found.')

          this.showReports = true
          this.updateJobQueryString(this.queryString) // to local storage
        })
        .catch((error) => {
          this.showReports = false
          this.notifyError(error)
        })

      this.updateDbOptions(x => { this.databaseOptions = x })
    },

    updateReports: function (data) {
      this.reports = data
      this.jobs = data.jobs
      this.logs = data.logs
      this.classificationResults = data.classificationResults
      this.combineClassificationResults = true
      this.mlstTables = data.mlstTables
      this.failInfo = data.classificationFailInfo
    },

    cleanReports: function () {
      this.showReports = false
      this.reports = null
      this.jobs = []
      this.logs = []
      this.classificationResults = []
      this.combineClassificationResults = true
      this.mlstTables = []
      this.failInfo = []
    },

    getDbName: function (path) {
      const formattedDbName = path.split('/').reverse()[1]
      for (let index = 0; index < this.databaseOptions.length; index++) {
        const element = this.databaseOptions[index]
        if (element.formattedDbName === formattedDbName) {
          return element.dbInfo.taxonomyName + ' (' + element.dbInfo.region + ') '
        }
      }
      return formattedDbName
    },

    goTo: function (routerLink) {
      this.$router.push(routerLink)
    }
  }
}
</script>
