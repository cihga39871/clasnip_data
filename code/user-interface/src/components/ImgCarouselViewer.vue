<template>

    <q-card
      v-if="(hideWhenFail && fileData.length > 0) || !hideWhenFail"
      class="q-py-none"
      :flat="flat ? true : false"
    >
      <q-card-section :class="flat ? 'text-primary q-pl-none' : 'text-primary bg-grey-2'">
        <span class="text-subtitle1">{{ label === 'auto' ? baseName(links[0]) : label }}</span>
        <span v-if="help">
          <q-btn round size="xs" dense flat icon="help" color="grey" @click="helpPopUp = true" />
        </span>
        <span>
          <q-btn
            class="q-ml-md"
            v-if="!autoLoad && (fileData.length === 0 || allowReload)"
            size="sm"
            :flat="flat ? true : false"
            color="white"
            text-color="grey-8"
            :label="fileData.length === 0 ? 'Show' : 'Reload'"
            @click="batchDownload(links)"
          />
        </span>
      </q-card-section>

      <q-separator v-if="flat ? false : true" />

      <q-card-section v-if="fileData.length > 0">
        <div class="column items-center">
          <div
            v-for="data in fileData" :key="data"
            :name="fileData.indexOf(data)"
          >
            <img class="col"
              v-if="fileData.indexOf(data) + 1 == densityPlotId" :src="data"
            />
          </div>
          <q-pagination class="col"
            v-model="densityPlotId"
            color="grey-8"
            :max="fileData.length"
            max-pages="10"
            direction-links
            boundary-numbers
          />
        </div>
      </q-card-section>

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
  name: 'ImgCarouselViewer',
  props: {
    // caution: many props may not work properly!!
    // TODO: fix unused ones
    refreshWatch: { default: 'no change' }, // if this variable is changed, the whole thing will be refresh. If only update links, Vue will not watch the contents in it.
    links: {
      type: Array,
      required: true
    },
    label: {
      type: String,
      default: 'auto'
    },
    format: {
      type: String,
      default: 'svg' // can be plain, log, json, svg
    },
    height: {
      default: 400
    },
    width: {
      default: 600
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
    flat: { default: false, type: Boolean }
  },
  data () {
    return {
      fileData: [],
      helpPopUp: false,
      slide: 1,
      densityPlotId: 1,
      hideWhenFail: this.autoLoad
    }
  },
  methods: {
    download: function (link) {
      this.$axios
        .post(
          this.MUX_URL + '/cnp/file_viewer',
          JSON.stringify({
            token: localStorage.getItem('token'),
            username: localStorage.getItem('username'),
            filePath: link
          })
        )
        .then(response => {
          if (this.format === 'log') {
            this.fileData.push(this.formatLog(response.data))
          } else if (this.format === 'json') {
            this.fileData.push(this.formatJson(response.data))
          } else if (this.format === 'svg') {
            this.fileData.push(this.formatSvg(response.data))
          } else {
            this.fileData.push(this.formatPlain(response.data))
          }
        })
        .catch(error => {
          this.notifyError(error)
        })
    },
    batchDownload: function (links) {
      this.fileData = []
      links.forEach(link => {
        this.download(link)
      })
    },
    baseName: function (str) {
      var base = String(str).substring(str.lastIndexOf('/') + 1)
      return base
    },
    formatPlain: function (str) {
      var str2 = str.replace(/\n/g, '<br/>')
      return str2
    },
    formatLog: function (str) {
      return str
    },
    formatJson: function (str) {
      var str2 = JSON.stringify(str, null, 2).replace(/\n/g, '<br/>')
      return str2
    },
    formatSvg: function (str) {
      str = str.replace(/\n/g, '').replace(/<\?xml.*\?>/, '')
      var str2 = 'data:image/svg+xml;base64,' + btoa(str)
      return str2
    }
  },

  mounted () {
    if (this.autoLoad) {
      this.batchDownload(this.links)
    }
  },

  watch: {
    refreshWatch: function () {
      this.fileData = []
      this.helpPopUp = false
      this.slide = 1
      this.densityPlotId = 1
      if (this.autoLoad) {
        this.batchDownload(this.links)
      }
    }
  }
}
</script>
