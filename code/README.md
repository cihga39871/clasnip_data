# Clasnip

Closely-related microorganism classification based on SNPs & multilocus sequencing typing (MLST)

## Installation guide

### Dependency

- 64-bit Linux system. Other Unix-like systems may work but are not tested.
- [Nginx ^1.22](https://nginx.org/en/download.html): an HTTP and reverse proxy server.

The following dependencies need to be installed manually and their excutables need to be found directly in PATH.

- [Julia language ^1.8](https://julialang.org/downloads/): the language used for the back-end server.
- [Samtools ^1.11](http://www.htslib.org/download/): a suite of programs for interacting with high-throughput sequencing data.
- [Bowtie2 ^2.3](https://github.com/BenLangmead/bowtie2): sequence alignment.
- [Freebayes ^1.3](https://github.com/freebayes/freebayes): genetic polymorphism discovery.
- [Yarn ^1.22.19](https://classic.yarnpkg.com/en/docs/install#debian-stable): a web package manager.
- [Quasar ^1.1.2](https://v1.quasar.dev/): a web framework.

### Nginx setup

1. Include `nginx_server.conf` and `nginx_server_dev.conf` under the http block of `/etc/nginx/nginx.conf` (the path of nginx config file may vary). 

   For example, the http block of `/etc/nginx/nginx.conf` could be:

    ```conf
    http {
        #some other settings;
        include /path/to/Clasnip/nginx_server.conf;
        include /path/to/Clasnip/nginx_server_dev.conf;
    }
    ```

2. Create a log folder: `mkdir -p /usr/local/clasnip/logs/`. If you do not have permission, you can also change the log folder defined in `nginx_server.conf` and `nginx_server_dev.conf`.

3. Start Nginx: `sudo nginx`, or reload Nginx: `sudo nginx -s reload`.

### Clasnip server configuration

The config file is located at `server/config/Config.jl`.

You can also put your secret config file under `server/config/config.secret.jl`. During startup of Clasnip server, it reads Config.jl and then config.secret.jl, so the settings in the secret file will overwrite the Config.jl file.

## Run / Host Clasnip

The Clasnip server and web application need to run separately.

- [Instructions to run the Clasnip server](server/README.md)
- [Instructions to run the web application](user-interface/README.md)
