<template>
  <div>
    <div class="q-pa-md">
      <div class="q-pb-md q-pt-sm text-h6 text-blue">
        Create A Clasnip Database
      </div>

      <q-banner v-if="!hasLogin" dense class="bg-green-2 q-mb-md" rounded>
        <template v-slot:avatar>
          <q-icon name="info" color="green" />
        </template>
        You need to log in to create a database.
        <template v-slot:action>
          <q-btn flat color="green-8" label="Register" @click="goTo('/register')"/>
          <q-btn flat color="green-8" label="Log In" @click="goTo('/login')"/>
        </template>
      </q-banner>

      <q-stepper v-if="hasLogin" v-model="step" ref="stepper" vertical animated bordered flat>

        <!-- STEP 1 -->
        <!-- STEP 1 -->
        <!-- STEP 1 -->

        <q-step
          :name="1"
          title="Database ID"
          icon="tab"
          :done="step > 1"
        >
          <div class="row">
            <div class="col-9">
              <!-- Description: only support CLso -->
              <div class="text-body2 text-grey-9">
                Enter a new database name
              </div>

              <q-input outlined bottom-slots v-model="dbName" dense>
                <template v-slot:append>
                  <q-icon v-if="dbName !== ''" name="close" @click="dbName = ''" class="cursor-pointer" />
                </template>

                <!-- <template v-slot:hint>
                  Database name should be straight-forward.
                </template> -->

                <!-- <template v-slot:after>
                  <q-btn round dense flat icon="check" @click="reportQuery()"/>
                </template> -->
              </q-input>

            </div>
          </div>
        </q-step>

        <!-- STEP 2 -->
        <!-- STEP 2 -->
        <!-- STEP 2 -->

        <q-step :name="2" title="Database Information" icon="tab" :done="step > 2">
          <div class="">

            <div class="text-body2 text-grey-9">
              New database name
            </div>
            <q-input outlined bottom-slots v-model="dbName" dense readonly>
            </q-input>

            <div class="row">
              <div class="col-3-auto q-pr-lg q-pb-lg">
                <div class="text-body2 text-grey-9">
                  Taxonomic rank
                </div>
                <q-select outlined v-model="taxonomyRank" :options="taxonomyRankOptions" dense options-dense/>
              </div>

              <div class="col">
                <div class="text-body2 text-grey-9">
                  Taxonomic name (scientific name)
                </div>
                <q-input outlined bottom-slots v-model="taxonomyName" dense>
                </q-input>
              </div>
            </div>

            <div class="row">
              <div class="col-3-auto q-pr-lg q-pb-lg">
                <div class="text-body2 text-grey-9">
                  Database type
                </div>
                <q-select outlined v-model="dbType" :options="dbTypeOptions" dense options-dense/>
              </div>

              <div class="col">
                <div class="text-body2 text-grey-9">
                  Covered regions or genes
                </div>
                <q-input outlined bottom-slots v-model="region" dense :readonly="dbType === 'genomic' || dbType === 'genomic - all samples are assemblies'">
                </q-input>
              </div>
            </div>

            <div class="text-body2 text-grey-9">
              Samples are grouped by
            </div>
            <q-input outlined bottom-slots v-model="groupBy" dense placeholder="species, sub-species, haplotypes, strain groups, phylogroups, etc.">
            </q-input>

            <div class="text-body2 text-grey-9">
                Upload the compressed database file
            </div>
            <!-- Description: Sequence -->
            <div class="text-caption text-grey">
              <b>Instructions:</b>
              The file to be uploaded should be a compressed folder. <br/>
              The folder contains several subfolders, indicating classification groups. <br/>
              Sequences in Fasta format are placed under the subfolders. Each Fasta file is considered as one sample. <br/>
              <b>Accepted compressed method:</b> zip | tar.gz | tar.bz2 | tar.xz | tar.Z <br/>
              <b>Size limit:</b> {{ DB_FILE_MAX_SIZE_MB }}M
            </div>

            <q-uploader
              :url="this.MUX_URL + '/cnp/upload_database'"
              :headers="uploadHeaders"
              :disable="disableUpload"
              style="max-width: 600px"
              flat bordered
              :max-file-size="DB_FILE_MAX_SIZE_MB * 1024 * 1024"
              max-files="1"
              accept=".tar.gz, .zip, .tar.xz, .tar.z, .tar.Z, .tar.bz2, .tar"
              @rejected="onUploadReject"
              @failed="onUploadFailed"
              @uploaded="onUploadSuccess"
            >
              <template v-slot:header="scope">
                <div class="row no-wrap items-center q-pa-sm q-gutter-xs">
                  <q-btn v-if="scope.queuedFiles.length > 0" icon="clear_all" @click="scope.removeQueuedFiles" round dense flat >
                    <q-tooltip>Clear</q-tooltip>
                  </q-btn>
                  <q-btn v-if="scope.uploadedFiles.length > 0" icon="done_all" @click="scope.removeUploadedFiles" round dense flat >
                    <q-tooltip>Remove Uploaded Files.</q-tooltip>
                  </q-btn>
                  <q-spinner v-if="scope.isUploading" class="q-uploader__spinner" />
                  <div class="col">
                    <div class="q-uploader__title">Uploader</div>
                    <div class="q-uploader__subtitle">{{ scope.uploadSizeLabel }} / {{ scope.uploadProgressLabel }}</div>
                  </div>
                  <q-btn v-if="scope.canAddFiles" type="a" icon="add_box" round dense flat>
                    <q-uploader-add-trigger />
                    <q-tooltip>Pick Files</q-tooltip>
                  </q-btn>
                  <q-btn v-if="scope.canUpload" icon="cloud_upload" @click="scope.upload" round dense flat >
                    <q-tooltip>Upload Files</q-tooltip>
                  </q-btn>

                  <q-btn v-if="scope.isUploading" icon="clear" @click="scope.abort" round dense flat >
                    <q-tooltip>Abort Upload</q-tooltip>
                  </q-btn>
                </div>
              </template>
            </q-uploader>

          </div>
        </q-step>

        <q-step :name="3" title="File Confirmation & Reference Genome" icon="tab" :done="step > 2">

          <div class="text-body2 text-grey-9">
            New database name
          </div>
          <q-input outlined bottom-slots v-model="dbName" dense readonly>
          </q-input>

          <!-- {{this.fastaInfo}} -->

          <div class="text-body2 text-grey-9">
            Select the reference genome from the fasta list
          </div>
          <q-input color="orange" outlined dense readonly v-model="refGenomeText">
            <template v-if="refGenomeText !== 'Not selected'" v-slot:append>
              <q-icon name="cancel" @click.stop="refGenome = null" class="cursor-pointer" />
            </template>
          </q-input>
          <div class="text-caption text-grey">
            The reference genome should allow all other sequences to be mapped to. If any sequence in the database fails to map to the reference genome, it will not be analyzed.
          </div>

          <q-scroll-area style="height: 250px">
            <q-list dense bordered padding class="rounded-borders">
              <q-item
                v-for="file in fastaInfo" :key="file.filepath"
                :active="file.valid" active-class="text-primary"
                :clickable="file.valid" @click="chooseRef(file)"
              >
                <q-item-section avatar v-if="!file.valid">
                  <q-badge color="red-5" label="invalid" />
                </q-item-section>

                <q-item-section>
                  <q-item-label > {{ file.group}} / {{ file.basename }} </q-item-label>
                </q-item-section>

                <q-tooltip v-if="file.valid" anchor="center right" self="center left" :offset="[10, 10]">
                  Select as reference
                </q-tooltip>

              </q-item>
            </q-list>
          </q-scroll-area>

        </q-step>
        <template v-slot:navigation>
          <q-stepper-navigation>
            <q-btn
              @click="confirmStep()"
              color="primary"
              outline
              :label="step === 3 ? 'Submit' : 'Continue'"
              :disable="disableConfirmStep"
            />
            <q-btn
              v-if="step > 1"
              flat
              color="grey"
              @click="previousStep()"
              label="Cancel"
              class="q-ml-sm"
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
                <span class="text-caption text-grey-9">{{jobID}}</span>
            </div>
          </q-card-section>
          <q-card-actions align="right">
            <q-btn flat label="Submit another job" color="grey" @click="createAnotherDb()" v-close-popup />
            <q-btn flat label="Job status" color="green" @click="goTo('/analysis/reports')" v-close-popup />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </div>
  </div>
</template>

<script>
export default {
  name: 'CreateDatabase',

  data () {
    return {
      hasLogin: false,

      step: 1,
      disableConfirmStep: false,
      disablePreviousStep: false,

      dbName: '',
      dbServerPath: '',
      refGenome: null,
      refGenomeText: 'Not selected',
      dbType: '',
      dbTypeOptions: ['genomic', 'genomic - all samples are assemblies', 'multiple genes', 'single gene'],
      region: '',
      taxonomyRank: '',
      taxonomyRankOptions: ['strain', 'species', 'genus'],
      taxonomyName: '',
      groupBy: '',
      uploadHeaders: [
        { name: 'token', value: localStorage.getItem('token') },
        { name: 'username', value: localStorage.getItem('username') },
        { name: 'dbName', value: '' },
        { name: 'dbServerPath', value: '' }
      ],
      uploadSuccessful: false,
      disableUpload: false,

      fastaInfo: null, // [{valid::Bool, filepath, group, basename}]
      showSubmitResult: false,
      jobID: null
    }
  },

  created () {
    this.hasLogin = this.hasToken()
  },

  methods: {
    confirmStep: function () {
      if (this.step === 1) {
        this.checkDatabaseName()
      } else if (this.step === 2) {
        if (this.validateStep2Inputs()) {
          this.$refs.stepper.next()
        }
      } else if (this.step === 3) {
        this.disableConfirmStep = true
        this.disablePreviousStep = true
        this.createDatabase()
      }
    },

    previousStep: function (rmDraft = true) {
      this.disableConfirmStep = false
      this.disablePreviousStep = false
      this.disableUpload = false
      this.showSubmitResult = false
      this.uploadSuccessful = false
      if (rmDraft) {
        this.rmDraftDatabase()
      }
      this.refGenome = null
      this.refGenomeText = 'Not selected'
      this.$refs.stepper.goTo(1)
    },

    checkDatabaseName: function () {
      var jobData = {
        token: localStorage.getItem('token'),
        username: localStorage.getItem('username'),
        dbName: this.dbName
      }
      this.$axios
        .post(this.MUX_URL + '/cnp/check_database_name', JSON.stringify(jobData))
        .then(response => {
          this.uploadHeaders[2].value = this.dbName
          this.uploadHeaders[3].value = response.data.dbServerPath
          this.dbServerPath = response.data.dbServerPath
          this.disableConfirmStep = true
          this.$refs.stepper.next()
        })
        .catch(error => {
          this.notifyError(error)
        })
    },

    rmDraftDatabase: function () {
      var jobData = {
        token: localStorage.getItem('token'),
        username: localStorage.getItem('username'),
        dbServerPath: this.dbServerPath
      }
      this.$axios
        .post(this.MUX_URL + '/cnp/rm_draft_database', JSON.stringify(jobData))
        .then()
        .catch(error => {
          this.notifyError(error)
        })
    },

    onUploadReject: function () {
      this.notifyWarn('Fail to upload due to restrictions: file size < 60M, extension is .tar.gz, .zip, .tar.xz, .tar.z, .tar.Z, .tar.bz2, .tar')
    },
    onUploadFailed: function (info) {
      this.fastaInfo = null
      this.notifyError('Fail to upload. ' + info.xhr.statusText + ' (' + info.xhr.status + ')')
      this.handleCodeRedirect(info.xhr.status) // redirect to home
      // Caution: cannot send rmDraftDatabase because auth will fail!
      // if (info.xhr.status === 459 || info.xhr.status === 440) {
      //   this.rmDraftDatabase()
      // }
    },
    onUploadSuccess: function (info) {
      this.fastaInfo = JSON.parse(info.xhr.response)
      this.disableConfirmStep = false
      this.uploadSuccessful = true
    },
    chooseRef: function (file) {
      this.refGenome = file
    },

    validateStep2Inputs: function () {
      var checkTaxonomyRank = this.taxonomyRank !== ''
      var checkTaxonomyName = this.taxonomyName !== ''
      var checkDbType = this.dbType !== ''
      var checkRegion = this.region !== ''
      if (!checkTaxonomyRank) {
        this.notifyError('Please choose a taxonomy rank.')
      }
      if (!checkTaxonomyName) {
        this.notifyError('Please enter a taxonomy name.')
      }
      if (!checkDbType) {
        this.notifyError('Please choose a database type.')
      }
      if (!checkRegion) {
        this.notifyError('Please enter covered regions or genes.')
      }
      if (!this.uploadSuccessful) {
        this.notifyError('Please upload a database file.')
      }
      return checkTaxonomyRank & checkTaxonomyName & checkDbType & checkRegion & this.uploadSuccessful
    },

    createDatabase: function () {
      if (this.groupBy === '') {
        this.groupBy = 'groups' // default value
      }
      var jobData = {
        token: localStorage.getItem('token'),
        username: localStorage.getItem('username'),
        dbName: this.dbName,
        dbServerPath: this.dbServerPath,
        refGenome: this.refGenome,
        dbType: this.dbType,
        region: this.region,
        taxonomyRank: this.taxonomyRank,
        taxonomyName: this.taxonomyName,
        groupBy: this.groupBy
      }
      this.$axios
        .post(this.MUX_URL + '/cnp/create_database', JSON.stringify(jobData))
        // .post(this.MUX_URL + '/cnp/create_database', JSON.stringify(jobData))
        .then(response => {
          this.showSubmitResult = true
          this.jobID = response.data.jobID
          this.updateJobQueryString(response.data.jobID) // to local storage
        })
        .catch(error => {
          this.disableConfirmStep = false
          this.disablePreviousStep = false
          this.previousStep()
          this.notifyError(error)
        })
    },

    goTo: function (routerLink) {
      this.$router.push(routerLink)
    },

    createAnotherDb: function () {
      this.dbName = ''
      this.dbServerPath = ''
      this.dbType = ''
      this.region = ''
      this.taxonomyRank = ''
      this.taxonomyName = ''
      this.previousStep(false)
    }
  },

  watch: {
    refGenome: function () {
      if (this.refGenome === null) {
        this.refGenomeText = 'Not selected'
      } else {
        this.refGenomeText = this.refGenome.group + ' / ' + this.refGenome.basename
      }
      if (this.step === 3) {
        this.disableConfirmStep = this.refGenome === null
      }
    },

    dbType: function () {
      if (this.dbType === 'genomic') {
        this.region = 'genomic'
      } else if (this.dbType === 'genomic - all samples are assemblies') {
        this.region = 'genomic'
      } else {
        this.region = ''
      }
    }
  }
}
</script>
