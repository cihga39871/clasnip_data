import Vue from 'vue'

// Declear global variables in all Vue.
// Then, variables can be assessed by this.VAR_NAME in *.vue files.
Vue.prototype.CLASNIP_VERSION = '0.0.1'
Vue.prototype.MUX_URL = '/clsnpmx' // use nginx to forward requests to server
// Vue.prototype.MUX_URL = 'http://0.0.0.0:9889' // without nginx: directly enter the server URL for local access.

Vue.prototype.FASTQ_MAX_SIZE = 650000 // maximum character count of fasta in new analysis
Vue.prototype.DB_FILE_MAX_SIZE_MB = 100 // maximum size in MB of compressed database file
