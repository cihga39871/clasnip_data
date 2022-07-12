import Vue from 'vue'

Vue.prototype.handleCodeRedirect = function (code) {
  if (code === 459 || code === 440) {
    this.$router.push('/login')
  }
}

Vue.prototype.notifyError = function (error) {
  var message

  if (error.response !== undefined && error.response.status !== undefined) {
    this.handleCodeRedirect(error.response.status)
    message = error.response.statusText + ' (' + error.response.status + ')'
  } else if (typeof error === 'string') {
    message = error
  } else {
    message = 'Error.'
  }

  this.$q.notify({
    color: 'red-5',
    textColor: 'white',
    message:
      message,
    icon: 'report_problem'
  })
}

Vue.prototype.notifyInfo = function (response) {
  var message

  if (response.status !== undefined) {
    this.handleCodeRedirect(response.status)
    message = response.statusText + ' (' + response.status + ')'
  } else if (typeof response === 'string') {
    message = response
  } else {
    message = ''
  }

  this.$q.notify({
    color: 'green-5',
    textColor: 'white',
    message: message,
    icon: 'info'
  })
}

Vue.prototype.notifyWarn = function (response) {
  var message

  if (response.status !== undefined) {
    this.handleCodeRedirect(response.status)
    message = response.statusText + ' (' + response.status + ')'
  } else if (typeof response === 'string') {
    message = response
  } else {
    message = ''
  }

  this.$q.notify({
    color: 'yellow-5',
    textColor: 'black',
    message: message,
    icon: 'warning'
  })
}
