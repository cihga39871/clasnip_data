<template>
  <div class="q-pb-md">

    <div class="text-subtitle1 text-primary q-pt-sm">
      Classification Groups
    </div>
    <div class="row">
      <div class="col-auto q-pr-lg"
        v-for="group in Object.keys(groups).sort()"
        :key="group"
      >
        {{ group }}
      </div>
    </div>

    <div v-if="dbAccuracy">
      <div class="text-subtitle1 text-primary q-pt-sm">
        Accuracy
      </div>
      <div class="text-body2">
        {{ (dbAccuracy * 100).toFixed(2) }}%
      </div>
      <div class="text-caption text-grey q-mt-none">
        The classification accuracy computed based on the database samples
      </div>
    </div>

    <div class="text-subtitle1 text-primary q-pt-sm">
      Metadata
    </div>
    <div class="row q-pb-md">
      <div class="col-auto q-pr-lg">
        <div class="row"> Taxonomy </div>
        <div class="row"> Region </div>
        <div class="row"> Database ID </div>
        <div class="row"> Reference Genome </div>
        <!-- <div class="row"> Created By </div> -->
        <!-- <div class="row"> Date Created </div> -->
      </div>
      <div class="col text-grey-9">
        <div class="row"> {{ taxonomyName }} ({{ taxonomyRank }}) </div>
        <div class="row"> {{ region }} ({{ dbType }}) </div>
        <div class="row"> {{ dbName }} </div>
        <div class="row"> {{ refGenome }} </div>
        <!-- <div class="row"> {{ owner }} </div> -->
        <!-- <div class="row"> {{ date }} </div> -->
      </div>
    </div>

    <!-- v-if and v-show are different:
    v-if destroys everything if set to false, so creates multiple request to host, so do v-if only once.
    v-show just hide things from users.
    -->
    <q-slide-transition v-if="downloadDetails">

      <div v-show="showDetails">
        <q-btn
          @click="showDetails = false"
          class="full-width q-mb-md"
          color="indigo-2"
          dense
          outline
          label="Hide Database Details"
          icon="expand_less"
        />

        <file-viewer
          v-if="dbType != 'single gene'"
          label="Group Similarity Based on Sample Identity (For Whole-Genome / Multiple-Gene Database)"
          :link="dbPath + '/plot.heatmap_identity.svg'"
          autoLoad
          format="svg"
          flat
        />

        <file-viewer
          v-if="dbType == 'single gene'"
          label="Group Similarity Based on SNP Differences (For Single-Gene Database)"
          :link="dbPath + '/plot.heatmap_snp_score.svg'"
          autoLoad
          format="svg"
          flat
          help
          helpTitle="Explanation"
          helpHtml="
            <span class='text-grey-9'>Number in black:
            the score of diverse SNP between two groups. </span><br /><br />

            <span class='text-grey'>Number in grey:
            the score of covered SNP in all groups. </span><br /><br />

            <span class='text-blue-10'>Cell color:
            darker color means higher similarity. </span><br /><br />

            <span class='text-grey'>Empty cell:
            the coverage of this group is too low, ie. the score of covered SNP < 5. </span><br /><br />
          "
        />

        <table-viewer
          label="Identity Quantile Statistics for Each Group"
          :link="dbPath + '/stat.accuracy_and_identity.txt'"
          autoLoad
          flat
          help
          helpTitle="Explanation"
          helpHtml="
            <span class='text-primary'>LABELED GROUP: </span>
            the group labeled in database. <br /><br />

            <span class='text-primary'>N SAMPLE: </span>
            the total number of samples with SNP coverage no less than 5. If all samples' coverages are less than 5, all samples are used. <br /><br />

            <span class='text-primary'>N ACCURATE: </span>
            the number of samples correctly classified. <br /><br />

            <span class='text-primary'>IDENTITY Q<span class='text-green'>5/25</span>: </span>
            the <span class='text-green'>5/25</span>th quantile of sample identity. <br /><br />

            <span class='text-primary'>TRUE POSITIVE RATE (SENSITIVITY): </span>
            the rate of N ACCURATE to N SAMPLE. <br /><br />
          "
        />

        <div v-if="dbType == 'single gene'">
          <table-viewer
            label="Classification Performance"
            :link="dbPath + '/stat.classifier_performance' + classificationPerformanceOption + '.txt'"
            autoLoad
            flat
            help
            helpTitle="Explanation"
            :helpHtml="helpClassificationPerformance"
            :hideCols="['TP', 'FP', 'TN', 'FN']"
          />
          <div class="row justify-center">
            <q-btn-toggle
              v-model="classificationPerformanceOption"
              dense unelevated flat no-caps
              toggle-color="grey-9" text-color="grey"
              :options="[
                { label: 'All Samples', value: '' },
                { label: 'Training Set', value: '.training' },
                { label: 'Test Set', value: '.test' }
              ]"
            />
            <q-btn round size="sm" dense flat icon="help" color="grey" @click="helpPopUpPerformance = true" />
            <q-dialog v-model="helpPopUpPerformance">
              <q-card>
                <q-card-section>
                  <div class="text-h6">Performance of different datasets</div>
                </q-card-section>
                <q-card-section class="q-pt-none">
                  <div v-html="helpPopUpPerformanceHtml" />
                </q-card-section>
                <q-card-actions align="right">
                  <q-btn flat label="OK" color="primary" v-close-popup />
                </q-card-actions>
              </q-card>
            </q-dialog>
          </div>
        </div>
        <div v-else>
          <table-viewer
            label="Classification Performance"
            :link="dbPath + '/stat.classifier_performance.txt'"
            autoLoad
            flat
            help
            helpTitle="Explanation"
            :helpHtml="helpClassificationPerformance"
            :hideCols="['TP', 'FP', 'TN', 'FN']"
          />
        </div>
        <!-- <img-carousel-viewer
          label="Identity Distributions for Different Groups"
          :links=fileLinks
          autoLoad="true"
          :refreshWatch=dbPath
          flat
        /> -->

        <table-viewer
          label="Mis-classified Samples"
          :link="dbPath + '/stat.wrongly_classified.txt'"
          autoLoad
          flat
          help
          helpTitle="Explanation"
          :helpHtml="helpSamples"
          :removeCols="['SAME', 'LABELED GROUP', 'TIED RANK']"
          :hideCols="['PROBABILITY']"
        />

        <table-viewer
          label="Low Coverage Samples"
          :link="dbPath + '/stat.low_coverages.txt'"
          autoLoad
          flat
          help
          helpTitle="Explanation"
          :helpHtml="helpSamples"
          :removeCols="['SAME', 'LABELED GROUP', 'TIED RANK']"
          :hideCols="['PROBABILITY']"
        />

        <q-btn
          @click="showDetails=false"
          class="full-width q-mt-sm"
          color="indigo-2" dense outline
          label="Hide Database Details"
          icon="expand_less"
        />

      </div>
    </q-slide-transition>

    <q-slide-transition>
      <q-btn
        v-if="!showDetails"
        @click="showDetails = downloadDetails = true"
        class="full-width"
        color="indigo-2"
        dense
        outline
        label="Show Database Details"
        icon="expand_more"
      />
    </q-slide-transition>

  </div>
</template>

<script>
import TableViewer from '../components/TableViewer.vue'
import FileViewer from '../components/FileViewer.vue'
// import ImgCarouselViewer from '../components/ImgCarouselViewer.vue'

export default {
  name: 'DatabaseAssessment',
  components: { TableViewer, FileViewer },
  props: {
    dbName: { default: null },
    dbInfo: { default: null },
    dbAccuracy: { default: null },
    groups: { default: null },
    refGenome: { default: null },
    dbType: { default: null },
    region: { default: null },
    taxonomyRank: { default: null },
    taxonomyName: { default: null },
    date: { default: '0000-00-00' },
    owner: { default: null },
    dbPath: { default: null }
  },
  data () {
    return {
      downloadDetails: false,
      showDetails: false,
      slide: 'style',
      fileLinks: [],
      classificationPerformanceOption: '',
      helpPopUpPerformance: false,

      helpSamples: '<span class="text-primary">GROUP: </span> the group labeled in database.<br/><br/>        <span class="text-primary">PERCENT MATCHED: </span> sequence identity, the ratio of MATCHED SNP SCORE and COVERED SNP SCORE.<br/><br/>       <span class="text-primary">MATCHED SNP SCORE: </span> sum of scores of all matched SNPs.<br/><br/>          <span class="text-primary">COVERED SNP SCORE: </span> sum of scores of all matched and unmatched SNPs. <br/><br/>          <span class="text-primary">RANK: </span> the rank of PERCENT MATCHED for the LABELED GROUP. <br/><br/>          <span class="text-primary">LABEL: </span> format in LABELED GROUP/SAMPLE NAME. <br/><br/>          <span class="text-primary">CDF: </span> the cumulated density where PERCENT MATCHED falls in which quantile of estimated distribution of LABELED GROUP samples in database.<br/><br/><span class="text-primary">PROBABILITY: </span> the probability of the sample is classified to LABELED GROUP.<br/><br/>          If COVERED SNP SCORE is small, it probably means insufficient SNPs were covered by your query sequences, so PERCENT MATCHED may be stochastic and not predicted precisely.<br/><br/> The classification accuracy is based on the public database, and not guaranteed by Clasnip.',

      // defined in created ()
      helpClassificationPerformance: '',
      helpPopUpPerformanceHtml: ''
    }
  },

  methods: {
    updateFileLinks: function () {
      var array = Object.keys(this.groups).sort()
      this.fileLinks = array.map(group => {
        var l = this.dbPath + '/plot.density_of_identity.' + group + '.svg'
        return l
      })
    }
  },

  created () {
    this.updateFileLinks()

    this.helpClassificationPerformance =
      this.tLink('The terminology and derivations can be found at this page.', 'https://en.wikipedia.org/wiki/Sensitivity_and_specificity') + this.tBr() +
      this.tTerm('TP (True Positive)', 'a test result that correctly indicates the presence of a condition or characteristic.') +
      this.tTerm('TN (True Negative)', 'a test result that correctly indicates the absence of a condition or characteristic.') +
      this.tTerm('FP (False Positive)', 'a test result which wrongly indicates that a particular condition or attribute is present.') +
      this.tTerm('FN (False Negative)', 'a test result which wrongly indicates that a particular condition or attribute is absent.') +
      this.tTerm('TPR (Sensitivity, Recall, Hit Rate, True Positive Rate)', 'TP / (TP + FN).') +
      this.tTerm('TNR (Specificity, Selectivity, True Negative Rate)', 'TN / (TN + FP).') +
      this.tTerm('PPV (Precision, Positive Predictive Value)', 'TP / (TP + FP).') +
      this.tTerm('NPV (Negative Predictive Value)', 'TN / (TN + FN).') +
      this.tTerm('FNR (Miss Rate, False Negative Rate)', '1 - TPR.') +
      this.tTerm('FPR (Fall-out, False Positive Rate)', '1 - TNR.') +
      this.tTerm('FDR (False Discovery Rate)', '1 - PPV.') +
      this.tTerm('FOR (False Omission Rate)', '1 - NPV.') +
      this.tTerm('ACC (Accuracy)', '(TP + TN) / (TP + TN + FP + FN).') +
      this.tTerm('F1 Score', 'the harmonic mean of precision and sensitivity.')

    this.helpPopUpPerformanceHtml =
      this.tLine('Clasnip evaluates single-gene database comprehensively using different portion of samples.') +
      this.tTerm('All Samples', 'The database are trained and performance are evaluated using all samples.') +
      this.tTerm('Training/Test Set', 'They are terms used in cross-validation. Cross-validation is a technique used to assess a classifier model and test its performance without overfitting. Clasnip uses three replicates of 2-fold cross-validation. In a 2-fold cross-validation, samples are evenly divided into two groups. The first group is used to train the model (training set), and the second group is used to test the model (test set). After recording the performance, it will use the second group as the training set, and the first group as the test set. Clasnip does three replications and summarize the performance of training and test sets. Standard deviation is shown in each cell.')
  },
  watch: {
    dbInfo: function () {
      this.updateFileLinks()
    }
  }
}
</script>
