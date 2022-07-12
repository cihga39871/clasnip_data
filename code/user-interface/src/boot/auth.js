import Vue from 'vue'

Vue.prototype.updateToken = function (obj) {
  localStorage.setItem('token', obj.token)
  localStorage.setItem('username', obj.username)
  localStorage.setItem('name', obj.name)
  localStorage.setItem('email', obj.email)
}

Vue.prototype.clearToken = function () {
  localStorage.removeItem('token')
  localStorage.removeItem('username')
  localStorage.removeItem('name')
  localStorage.removeItem('email')
}

Vue.prototype.hasToken = function () {
  var res = localStorage.getItem('token') !== null
  return res
}

Vue.prototype.updateJob = function (jobID, jobName) {
  localStorage.setItem('jobID', jobID)
  localStorage.setItem('jobName', jobName)
}
Vue.prototype.getJob = function () {
  var jobID = localStorage.getItem('jobID')
  var jobName = localStorage.getItem('jobName')
  var queryString = ''
  if (jobID !== null) {
    queryString = jobID + '//' + jobName
  }
  return {
    jobID: jobID,
    jobName: jobName,
    queryString: queryString
  }
}
