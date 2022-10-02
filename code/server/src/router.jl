
# application
SERVER_TASK = @task nothing
schedule(SERVER_TASK)

function run_server(; host = Config.HOST, port = Config.PORT)
	global SERVER_TASK
	@app backend_server = (
		Mux.prod_defaults,
		page(respond("ClasnipServer")),

		### auth
		route("/pccau/get_token", api_get_token),
		route("/pccau/login", api_login),
		route("/pccau/register", api_register),
		route("/pccau/validate", api_validate_token),
		route("/pccau/logout", api_logout),

		### cnp new analysis
		route("/cnp/get_database", api_get_database),
		route("/cnp/submit_job_multi_db", api_new_analysis_multi_db),

		### cnp create database
		route("/cnp/check_database_name", api_validate_token, api_check_database_name),
		route("/cnp/rm_draft_database", api_validate_token, api_rm_draft_database),
		route("/cnp/create_database", api_validate_token, api_create_database),
		route("/cnp/upload_database", api_validate_token_header, api_upload_database),

		### cnp job
		# route("/cnp/job_detail", req -> api_validate_token(api_job_detail, req)),
		# route("/cnp/job_queue", req -> api_validate_token(api_job_queue, req)),
		# route("/cnp/job_cancel", req -> api_validate_token(api_job_cancel, req)),

		### cnp report
		route("/cnp/multi_report_query", api_multi_report_query),
		route("/cnp/file_viewer", api_file_viewer),
		route("/cnp/quasar_table_viewer", req -> api_file_viewer(req, to_quasar_table=true)),
		route("/cnp/classification_results_viewer", api_classification_results_viewer),

		### cnp user
		route("/cnp/analysis_list", api_validate_token, api_user_dir_list),
		route("/cnp/rm_clasnip_database", api_validate_token, api_rm_clasnip_database),

		### cnp server control
		route("/cnpctl/update_database", api_dynamic_key, api_update_database),
		route("/cnpctl/revise_retry", api_dynamic_key, api_revise_retry),

		route("/cnptst/echo", req -> response_with_header(req, 200, data = req)),
		Mux.notfound()
	)
	@info "Mux server is running at http://localhost:$(port)"
	# SERVER_TASK = serve(backend_server, host, port)
	# changed from Mux.serve: change @async to Threads.@spawn
	SERVER_TASK = Job(name="MUX SERVER", wall_time=Week(888), priority=0) do
		Mux.@errs HTTP.serve(Mux.http_handler(backend_server), host, port)
	end
	submit!(SERVER_TASK)
end

function stop_server()
	global SERVER_TASK
	cancel!(SERVER_TASK)
end

function restart_server()
	global SERVER_TASK
	try
		cancel!(SERVER_TASK)
	catch
		nothing
	end
	run_server()
end
