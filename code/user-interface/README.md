# Clasnip web interface

Closely-related microorganism classification based on SNPs

## Install the dependencies

```bash
yarn
```

### Start the app in development mode (hot-code reloading, error reporting, etc.)

```bash
quasar dev
```

### Lint the files

```bash
yarn run lint
```

### Build the app for production

```bash
quasar build
```

### Start the app

```bash
quasar serve dist/spa --port 9888
```

### Customize the configuration

See [Configuring quasar.conf.js](https://quasar.dev/quasar-cli/quasar-conf-js).

## Access to Clasnip with Nginx

If you run the server and web app in *production* mode, Clasnip is ready at http://0.0.0.0:80/

If you run the server and web app in *development* mode, Clasnip is ready at http://0.0.0.0:9601/

## Access to Clasnip without Nginx

Please make sure `MUX_URL` is set to the server URL in `user-interface/src/boot/globalVariables.js`:

```javascript
// file user-interface/src/boot/globalVariables.js
Vue.prototype.MUX_URL = 'http://0.0.0.0:9889'
```

You can access to Clasnip from the same port as the web app: http://0.0.0.0:9888/ for production and http://0.0.0.0:9600/ for development.

## Troubleshoot: 404 not found

1. Please make sure `MUX_URL` is set correctly in `user-interface/src/boot/globalVariables.js`.

   - If you use Nginx, `Vue.prototype.MUX_URL = '/clsnpmx'`
   - If you does not use Nginx, it should set to the server URL.

2. If you use Nginx, please do not access to Clasnip using the port of the web app (9888 or 9600). You have to use the port described in `nginx_server*.conf` (80 or 9601)

3. Make sure both server and web app are running. If they are running, please make sure that both run in the same mode (development/production).

4. Check port settings:

   - Server: `server/config/Config.jl` and `server/config/config.secret.jl`
   - Web app: `user-interface/quasar.conf.js`
   - Nginx: `nginx_server.conf` and `nginx_server_dev.conf`
   - Server and web app can use different ports if specified in command-line arguments.