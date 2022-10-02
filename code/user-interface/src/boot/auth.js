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

Vue.prototype.updateJobQueryString = function (jobQueryString) {
  localStorage.setItem('jobQueryString', jobQueryString)
}

Vue.prototype.getJobQueryString = function () {
  var jobQueryString = localStorage.getItem('jobQueryString')
  return jobQueryString
}

// Usage:
// this.updateDbOptions(res => { this.databaseOptions = res })
Vue.prototype.updateDbOptions = function (funcSuccess) {
  // [ {label: html_label, value: dbName, formattedDbName, dbInfo} ]
  Vue.prototype.$axios
    .get(Vue.prototype.MUX_URL + '/cnp/get_database')
    .then(response => {
      var dbKeys = Object.keys(response.data)
      var dbOptions = dbKeys.map(key => {
        var label
        var formattedDbName = key.replace(/[^A-Za-z0-9_]+/g, '_')
        var db = response.data[key]
        if (db.taxonomyName === '') {
          label = '<div class="row"><div class="col">' +
          key +
          '</div><div class="q-ml-sm col-auto text-right text-grey"> [created by ' +
          db.owner + ']</div></div>'
        } else {
          label = '<div class="row"><div class="col">' +
            db.taxonomyName + ' (' + db.region + ') ' +
            '</div><div class="q-ml-sm col-auto text-right text-grey"> [' + db.date + ']</div></div>'
        }
        return {
          label: label,
          value: key,
          formattedDbName: formattedDbName,
          dbInfo: db
        }
      })
      localStorage.setItem('dbOptions', JSON.stringify(dbOptions))
      funcSuccess(dbOptions)
    })
    .catch(error => {
      this.notifyError(error)
      localStorage.setItem('dbOptions', JSON.stringify([]))
    })
}
Vue.prototype.getDbOptions = function () {
  JSON.parse(localStorage.getItem('dbOptions'))
}
