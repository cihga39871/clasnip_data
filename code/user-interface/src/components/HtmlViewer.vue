<template>
  <q-list bordered>
    <q-expansion-item
      group="somegroup"
      icon="attachment"
      :label="baseName(link)"
      header-class="text-grey-8"
    >
      <q-card>
        <q-card-section>
          <q-btn
            size="sm"
            color="white"
            text-color="grey-8"
            label="Show in a new tab"
            @click.prevent="download(link)"
          />
        </q-card-section>
      </q-card>
    </q-expansion-item>
  </q-list>
</template>

<script>
export default {
  name: 'HtmlViewer',
  props: {
    link: {
      type: String,
      required: true
    }
  },
  data () {
    return {
      disableDownload: false
    }
  },
  methods: {
    download: function (link) {
      if (this.disableDownload) {
        return
      }
      this.$axios
        .post(
          this.MUX_URL + '/pcc/file_viewer',
          JSON.stringify({
            token: localStorage.getItem('token'),
            username: localStorage.getItem('username'),
            filePath: link
          })
        )
        .then(response => {
          // open a new tab
          const blob = new Blob([response.data], { type: 'text/html' })
          const link = document.createElement('a')
          link.href = URL.createObjectURL(blob)
          link.target = '_blank'
          link.click()
          URL.revokeObjectURL(link.href)
        })
        .catch(error => {
          this.disableDownload = false
          this.notifyError(error)
        })
    },
    baseName: function (str) {
      var base = String(str).substring(str.lastIndexOf('/') + 1)
      return base
    }
  }
}
</script>
