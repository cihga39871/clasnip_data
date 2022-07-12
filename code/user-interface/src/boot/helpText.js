import Vue from 'vue'

Vue.prototype.tVar = function (x) {
  return '<span class="text-primary">' + x + '</span>'
}

Vue.prototype.tBr = function (num = 2) {
  var h = ''
  for (let index = 0; index < num; index++) {
    h += '<br/>'
  }
  return h
}

Vue.prototype.tPlain = function (x) {
  return x
}

Vue.prototype.tLine = function (x) {
  return x + this.tBr()
}

Vue.prototype.tTerm = function (name, description) {
  return this.tVar(name + ': ') + this.tPlain(description) + this.tBr()
}

Vue.prototype.tLink = function (description, link) {
  return '<a href="' + link + '">' + description + '</a>'
}
