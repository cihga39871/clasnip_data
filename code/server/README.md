# Clasnip Server

## Run Clasnip Server

```bash
bash clasnip_data/code/server/start_server.bash
```

It also accepts arguments:
```
-h, --help      Show this help page.
--keep          Keep the server run in backend (add a sleep loop at the end).
--host HOST     Up server to HOST:PORT.
--port PORT     Up server to HOST:PORT.
--dev           Up server to HOST:PORT_DEV.
--no-precompile Do not run the precompile (and test) task.
```

Note: Changing any .jl files during hosting takes effects immediately, but API and tasks related to HTTP probably will not change, you can enter `restart_server()` to reload the HTTP task.
