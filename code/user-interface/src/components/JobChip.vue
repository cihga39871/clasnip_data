<template>
  <div class="q-pb-sm">
  <q-btn no-caps rounded size='md' :color="color" text-color="white" :icon="icon" :label="name">
    <q-tooltip  transition-show="jump-left" transition-hide="jump-right" anchor="center right" self="center left" :offset="[10, 10]" :content-class="'bg-' + color" content-style="font-size: 14px"> {{ state }}
    </q-tooltip>
  </q-btn>
  </div>
</template>

<script>
export default {
  name: 'JobChip',
  props: {
    id: { default: 0, type: Number },
    name: { default: 'Job', type: String },
    state: { default: 'unknown', type: String },
    user: { default: '', type: String },
    createTime: { default: '', type: String },
    startTime: { default: '', type: String },
    stopTime: { default: '', type: String }
  },
  data () {
    return {
      color: null,
      icon: 'event'
    }
  },
  methods: {
    updateState: function () {
      switch (this.state) {
        case 'done':
          this.color = 'positive'
          this.icon = 'check'
          break
        case 'failed':
          this.color = 'negative'
          this.icon = 'clear'
          break
        case 'cancelled':
          this.color = 'negative'
          this.icon = 'clear'
          break
        case 'running':
          this.color = 'info'
          this.icon = 'data_usage'
          break
        case 'queuing':
          this.color = 'secondary'
          this.icon = 'access_time'
          break
        default:
          this.color = 'warning'
          this.icon = 'access_time'
      }
    }
  },
  watch: {
    state: {
      immediate: true,
      handler: 'updateState'
    }
  }
}
</script>
