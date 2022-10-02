<template>

    <q-card
      v-if="(hideWhenFail && !fail) || !hideWhenFail"
      class="q-py-none"
      :flat="flat ? true : false"
    >
      <q-card-section :class="flat ? 'text-primary q-pl-none q-py-none' : 'text-primary bg-grey-2'">
        <span class="text-subtitle1">{{ label === 'auto' ? baseName(link) : label }}</span>
        <span v-if="help">
          <q-btn round size="xs" dense flat icon="help" color="grey" @click="helpPopUp = true" />
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
        <div class="text-subtitle2 text-secondary" v-if="subtitle.length > 0" >{{ subtitle }}</div>
      </q-card-section>

      <q-separator v-if="flat ? false : true" />

      <q-slide-transition>

        <q-card-section v-if="fileData !== null" :class="flat && 'q-px-none q-py-none'">
          <div>
            <div v-if="height > 0">
              <q-scroll-area :style="'height: ' + height + 'px'" >
                <div v-if="format === 'log'">
                <div style="font-family: monospace">
                  <q-input :value="fileData" type="textarea" readonly borderless/>
                </div>
              </div>
              <div v-else>
                <div v-html="fileData"></div>
              </div>
              </q-scroll-area>
            </div>

            <div v-else>
              <div v-if="format === 'log'">
                <div style="font-family: monospace">
                  <q-input :value="fileData" type="textarea" readonly borderless/>
                </div>
              </div>
              <div v-else class="column items-center">
                <div v-html="fileData" class=col></div>
              </div>
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
  name: 'FileViewer',
  props: {
    link: {
      type: String,
      required: true
    },
    label: {
      type: String,
      default: 'auto'
    },
    subtitle: {
      type: String,
      default: ''
    },
    format: {
      type: String,
      default: 'plain' // can be plain, log, json, svg
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
    flat: { default: false, type: Boolean }
  },
  data () {
    return {
      fileData: null,
      helpPopUp: false,
      hideWhenFail: this.autoLoad,
      fail: false
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
            this.fileData = this.formatLog(response.data)
          } else if (this.format === 'json') {
            this.fileData = this.formatJson(response.data)
          } else if (this.format === 'svg') {
            this.fileData = this.formatSvg(response.data)
          } else {
            this.fileData = this.formatPlain(response.data)
          }
          this.fail = false
        })
        .catch(error => {
          this.fileData = null
          this.fail = true
          this.notifyError(error)
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
      var str2 = '<img src=\'data:image/svg+xml;base64,' + btoa(str) + '\'>'
      return str2
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
        this.fail = false
      }
    }
  }
}
</script>
