<template>
  <div class="q-pa-md">
    <q-slide-transition>
      <q-banner v-if="!dismissBanner && hasLogin" dense class="bg-green-2 q-mb-md" rounded>
        <template v-slot:avatar>
          <q-icon name="info" color="green" />
        </template>
        Forget Job ID? You can view your previous analyses on User page.
        <template v-slot:action>
          <q-btn flat color="green-5" label="Dismiss" @click="dismissBanner=true"/>
          <q-btn flat color="green-8" label="Go to User Page" @click="goTo('/user')"/>
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

        <q-input outlined bottom-slots v-model="queryString" label="Job ID" dense style="font-family:monospace">
          <template v-slot:append>
            <q-icon v-if="queryString !== ''" name="close" @click="queryString = ''" class="cursor-pointer" />
          </template>

          <template v-slot:hint>
            <span style="font-family:Roboto">
            Job ID is provided after job submission in this format:</span>
            000000000000000//12345678-90ab-cdef-1234-567890abcdef.database_name
          </template>

          <template v-slot:after>
            <q-btn color="primary" round dense outline icon="send" @click="reportQuery()"/>
          </template>
        </q-input>
      </div>
    </div>

    <q-slide-transition>
      <div v-if="showReports">
        <div class="q-pt-md q-pb-sm text-subtitle1 text-primary" v-if="jobState != 'unknown'">
            Job status
          <q-badge :color="jobStateColor">
            {{ jobState }}
          </q-badge>
        </div>

        <div class="row">
          <div v-if="reports.classificationResult" class="col q-pb-md">
            <table-viewer
              :link="reports.classificationResult"
              label="Classification Summary"
              checkClassificationSummary
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

        <div class="row">
          <div v-if="reports.mlstTable" class="col q-pb-md">
            <table-viewer
              :link="reports.mlstTable"
              label="Multi Locus Sequence Typing (MLST)"
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

        <div class="row q-pt-sm">
          <div v-if="reports.log" class="col">
            <file-viewer
              :link="reports.log"
              label="Log Info"
              format="log"
              flat
              :allowReload="jobState === 'running'"
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
// import HtmlViewer from '../components/HtmlViewer.vue'

export default {
  components: { FileViewer, TableViewer },
  name: 'Reports',

  data () {
    return {
      hasLogin: false,
      dismissBanner: true,

      queryInfo: null,
      jobID: null,
      jobName: null,
      queryString: '',

      showReports: false,
      reports: null,
      jobState: 'unknown',
      jobStateColor: 'warning',

      probability: 0.05,

      helpClassificationSummary: '<span class="text-primary">PERCENT_MATCHED: </span> sequence identity, the ratio of MATCHED_SNP_SCORE and COVERED_SNP_SCORE.<br/><br/><span class="text-primary">MATCHED_SNP_SCORE: </span> sum of scores of all matched SNPs.<br/><br/><span class="text-primary">COVERED_SNP_SCORE: </span> sum of scores of all matched and unmatched SNPs.<br/><br/><span class="text-primary">CDF: </span> the cumulated density where PERCENT_MATCHED falls in which quantile of estimated distribution of LABELED_GROUP samples in database.<br/><br/><span class="text-primary">PROBABILITY: </span> the probability of the sample is classified to LABELED_GROUP.<br/><br/>          If the deviation of two groups\' PERCENT_MATCHED are small, please double-check the exact SNP variations in the MLST table. <br/><br/>If COVERED_SNP_SCORE is small, it probably means insufficient SNPs were covered by your query sequences, so PERCENT_MATCHED may be stochastic and not predicted precisely.<br/><br/> The classification accuracy is based on your query sequences and the public database, and not guaranteed by Clasnip.',

      helpMlst: '<span class="text-primary">CHROM</span> and <span class="text-primary">POS: </span>the chromosome and position of the reference file in the database.<br/><br/><span class="text-primary">REF: </span> the base(s) of the reference.<br/><br/><span class="text-primary">GROUP COLUMNS: </span> The groups defined in the database. If a SNP is identical to REF, it will be marked as a dot. Numbers in brackets mean the SNP frequencies of all samples in the database group.<br/><br/><span class="text-primary">SAMPLE: </span> the SNP(s) of query sequences. If a SNP is identical to REF, it will be marked as a dot. <br/><br/><span class="text-primary">DEPTH: </span>can be ignored in most cases. The query sequences are cut to 120-bp subsequences, and DEPTH is the number of subsequences mapped to the location. If SAMPLE is not identical to REF, multiple depths are shown and splitted by comma (,), indicating the depths of REF and SNPs, respectively.<br/><br/><span class="text-primary">Visible columns: </span>You can select columns of interest using the Column button on the top right of the table.'
    }
  },

  created () {
    this.hasLogin = this.hasToken()

    if (this.$route.params.jobName) {
      this.jobName = this.$route.params.jobName
      this.jobID = ''
      this.queryInfo = { jobID: '', jobName: this.jobName, queryString: this.jobName }
      this.queryString = this.jobName
      this.dismissBanner = true
      this.reportQuery()
    } else {
      this.queryInfo = this.getJob()
      this.jobID = this.queryInfo.jobID
      this.jobName = this.queryInfo.jobName
      this.queryString = this.queryInfo.queryString
      this.dismissBanner = false
    }
  },

  watch: {
  },

  methods: {
    reportQuery: function () {
      this.$axios.post(this.MUX_URL + '/cnp/report_query', JSON.stringify({
        token: localStorage.getItem('token'),
        username: localStorage.getItem('username'),
        queryString: this.queryString
      }))
        .then((response) => {
          this.updateReports(response.data)
          this.notifyInfo('Reports found.')

          this.showReports = true
          var jobName = this.queryString.match(/[0-9a-f]{8}-.*/)
          jobName = jobName === null ? '' : jobName[0]
          var jobID = this.queryString.match(/^[0-9]{10,}/)
          jobID = jobID === null ? '' : jobID[0]
          this.updateJob(jobID, jobName)
        })
        .catch((error) => {
          this.showReports = false
          this.notifyError(error)
        })
    },

    updateReports: function (data) {
      this.reports = data
      if (data.job) {
        this.jobState = data.job.state
        switch (this.jobState) {
          case 'done':
            this.jobStateColor = 'positive'
            break
          case 'failed':
            this.jobStateColor = 'negative'
            break
          case 'cancelled':
            this.jobStateColor = 'negative'
            break
          default:
            this.jobStateColor = 'warning'
        }
        // if (this.queryString.match('^[0-9]+/*$') && this.jobState === 'queuing') {
        //   // If building database, it has many jobs to run, but only the last job is given to user. Prerequisite jobs may be running, but we do not know.
        //   this.jobState = 'queuing or running'
        // }
      } else {
        this.jobState = 'unknown'
        this.jobStateColor = 'warning'
      }
    },

    goTo: function (routerLink) {
      this.$router.push(routerLink)
    }
  }
}
</script>
