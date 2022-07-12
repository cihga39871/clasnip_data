<template>

    <q-card
      v-if="(hideWhenFail && !fail) || !hideWhenFail"
      :flat="flat ? true : false"
    >
      <q-card-section :class="flat ? 'text-primary q-py-none q-pl-none' : 'text-primary q-py-none bg-grey-2'">
        <div class="row">
          <div class="col q-py-md">
            <span class="text-subtitle1">{{ label === 'auto' ? baseName(link) : label }}</span>
            <span v-if="help">
              <q-btn round size="sm" dense flat icon="help" color="grey" @click="helpPopUp = true" />
            </span>
            <span>
              <q-btn
                class="q-ml-md"
                v-if="!autoLoad && (fileData === null || allowReload)"
                size="sm"
                color="white"
                :flat="flat ? true : false"
                text-color="grey-8"
                :label="fileData === null ? 'Show' : 'Reload'"
                @click="download(link)"
              />
            </span>
          </div>

          <div class="col-2 q-pt-sm q-mt-xs q-pr-sm" v-if="fileData !== null">
            <q-input
              v-if="filter"
              outlined
              dense
              v-model="filterValue"
              :label="filterLabel"
            />
          </div>

          <div class="col-2 q-pt-sm q-mt-xs" v-if="fileData !== null">
            <q-select
              v-if="rowData.length > 0"
              v-model="visibleColumns"
              multiple
              outlined
              dense
              options-dense
              :display-value="$q.lang.table.columns"
              emit-value
              map-options
              :options="columns"
              option-value="name"
              options-cover
              style="min-width: 150px; height: 0px;"
            />
          </div>
        </div>

      </q-card-section>

      <q-separator v-if="flat ? false : true" />

      <q-slide-transition>

        <q-card-section v-if="fileData !== null" class="q-pa-none">

          <div v-if="rowData.length > 0">
              <q-table
                dense
                class="no-shadow"
                :visible-columns="visibleColumns"
                :virtual-scroll="height > 0"
                :style="height > 0 ? 'height: ' + height + 'px' : ''"
                :data="rowData"
                :columns="columns"
                :row-key="row => row.name"
              />
          </div>
          <div v-else-if="!checkClassificationSummary" class="text-grey">
            <span>
              <q-icon name="warning" />
              No data available.
            </span>
          </div>

          <div v-if="checkClassificationSummary" class="q-gutter-sm">

            <div v-if="rowData.length == this.fileData.row_data.length" class="text-green">
              <span>
                <q-icon name="info" />
                All groups are shown.
              </span>
            </div>

            <div v-if="rowData.length == 0" class="text-negative">
              <span>
                <q-icon name="warning" />
                The sample is not classified to any group under the given P value ({{filterValue}}). Please decrease P value threshold, and check possible sequencing errors.
              </span>
            </div>

            <div v-if="rowData.length > 0 && rowData[0].col4 < 20" class="text-yellow-10">
              <span>
                <q-icon name="warning" />
                The sample may not have enough overlapped SNPs with the database (COVERED_SNP_SCORE &lt; 20). Please interpret results carefully.
              </span>
            </div>

          </div>

        </q-card-section>

      </q-slide-transition>

      <q-dialog v-model="helpPopUp">
        <q-card>
          <q-card-section>
            <div class="text-h6">{{ helpTitle }}</div>
          </q-card-section>
          <q-card-section class="q-pt-none">
            <div v-html="helpHtml" />
          </q-card-section>
          <q-card-actions align="right">
            <q-btn flat label="OK" color="primary" v-close-popup />
          </q-card-actions>
        </q-card>
      </q-dialog>

    </q-card>

</template>

<script>
export default {
  name: 'TableViewer',
  props: {
    link: {
      type: String,
      required: true
    },
    label: {
      type: String,
      default: 'auto'
    },
    height: {
      default: 0
    },
    autoLoad: {
      type: Boolean,
      default: false
    },
    allowReload: {
      type: Boolean,
      default: false
    },
    help: {
      type: Boolean,
      default: false
    },
    helpTitle: {
      type: String,
      default: ''
    },
    helpHtml: {
      type: String,
      default: ''
    },
    removeCols: {
      default: function () { return [] }
    },
    hideCols: {
      default: function () { return [] }
    },
    filter: {
      type: Boolean,
      default: false
    },
    filterColName: {
      type: String,
      default: 'col0'
    },
    filterMethod: {
      type: Function,
      default: (data, threshold) => data >= threshold
    },
    filterValue: {
      default: 0.05
    },
    filterValueMin: { default: null },
    filterValueMax: { default: null },
    filterLabel: {
      type: String,
      default: 'Filter'
    },
    flat: {
      default: false,
      type: Boolean
    },
    checkClassificationSummary: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      fileData: null,
      rowData: null,
      columns: null,
      visibleColumns: null,
      helpPopUp: false,
      hideWhenFail: this.autoLoad,
      fail: false
    }
  },
  methods: {
    download: function (link) {
      this.$axios
        .post(
          this.MUX_URL + '/cnp/quasar_table_viewer',
          JSON.stringify({
            token: localStorage.getItem('token'),
            username: localStorage.getItem('username'),
            filePath: link
          })
        )
        .then(response => {
          this.fileData = response.data
          this.formatData()
          this.filterRowData()
          this.filterCols()
          this.fail = false
        })
        .catch(error => {
          this.fileData = null
          this.rowData = null
          this.columns = null
          this.visibleColumns = null
          this.fail = true
          this.notifyError(error)
        })
    },
    baseName: function (str) {
      var base = String(str).substring(str.lastIndexOf('/') + 1)
      return base
    },
    formatData: function () {
      // column labels: change _ to blank
      this.fileData.columns.forEach((row, idx) => {
        this.fileData.columns[idx].label = row.label.replaceAll('_', ' ')
      })
    },
    filterRowData: function () {
      if (this.filter) {
        this.rowData = []
        this.fileData.row_data.forEach(row => {
          if (this.filterMethod(row[[this.filterColName]], this.filterValue)) {
            this.rowData.push(row)
          }
        })
      } else {
        this.rowData = this.fileData.row_data
      }
    },
    filterCols: function () {
      // remove cols
      if (this.removeCols && this.removeCols.length > 0) {
        this.columns = []
        this.fileData.columns.forEach(col => {
          if (!this.removeCols.includes(col.name) && !this.removeCols.includes(col.label)) {
            this.columns.push(col)
          }
        })
      } else {
        this.columns = this.fileData.columns
      }
      // hide but not removel cols
      if (this.hideCols && this.hideCols.length > 0) {
        this.visibleColumns = []
        this.columns.forEach(col => {
          if (!this.hideCols.includes(col.name) && !this.hideCols.includes(col.label)) {
            this.visibleColumns.push(col.name)
          }
        })
      } else {
        this.visibleColumns = this.columns.map(col => col.name)
      }
    }
  },

  mounted () {
    if (this.autoLoad) {
      this.download(this.link)
    }
  },

  watch: {
    link: function () {
      if (this.autoLoad) {
        this.download(this.link)
      } else {
        this.fileData = null
        this.rowData = null
        this.columns = null
        this.fail = false
      }
    },
    filterValue: function () {
      if (parseFloat(this.filterValueMin) && parseFloat(this.filterValue) < parseFloat(this.filterValueMin)) {
        this.filterValue = parseFloat(this.filterValueMin)
      } else if (parseFloat(this.filterValueMax) && parseFloat(this.filterValue) > parseFloat(this.filterValueMax)) {
        this.filterValue = parseFloat(this.filterValueMax)
      }
      this.filterRowData()
    }
  }
}
</script>
