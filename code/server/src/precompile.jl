@info "Precompilation and tests start"

using Test

if "--dev" in ARGS
   url = "http://0.0.0.0:$(Config.PORT_DEV)"
else
   url = "http://0.0.0.0:$(Config.PORT)"
end

request = Dict{Any, Any}(:query => "", :method => "GET", :params => Dict{Any, Any}(), :path => SubString{String}[], :cookies => HTTP.Cookies.Cookie[], :uri => URI("/cnp/get_database"), :data => "", :headers => Pair{SubString{String}, SubString{String}}["Host" => "127.0.0.1:9889", "X-Real-IP" => "192.168.2.13", "X-Forwarded-For" => "192.168.2.13", "Connection" => "close", "Accept" => "application/json, text/plain, */*", "User-Agent" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.59 Safari/537.36 Edg/92.0.902.22", "DNT" => "1", "Referer" => "http://192.168.2.13:9890/", "Accept-Encoding" => "gzip, deflate", "Accept-Language" => "en-GB,en;q=0.9,en-US;q=0.8,zh-CN;q=0.7,zh;q=0.6"])

global token
global response
global res

@testset "Auth Api" begin
   @testset "register" begin
      body = """
      test
      fortestuseonly
      {"name": "Test Account", "email": "test@abc.def"}"""
      res = HTTP.request("POST", url * "/pccau/register", [], body, status_exception=false)
      @test res.status in (200, 457)
   end

   @testset "login and validate" begin
      # get token api
      body = "test"
      res = HTTP.request("POST", url * "/pccau/get_token", [], body, status_exception=false)
      @test res.status == 200

      # compute passcode
      data = JSON.parse(String(res.body))
      value = data["value"]
      token = value[1:end-8]
      salt = value[end-7:end]
      passcode = Auth.encrypt(Auth.encrypt("fortestuseonly", salt), token)

      # login api
      body = "test\n$passcode\n$token"
      res = HTTP.request("POST", url * "/pccau/login", [], body, status_exception=false)
      @test res.status == 200

      res2 = JSON.parse(String(res.body))
      global token = res2["token"]

      # validate api
      body_token = """{"username": "test", "token": "$(token)"}"""
      res = HTTP.request("POST", url * "/pccau/validate", [], body_token, status_exception=false)
      @test res.status == 202
   end
end


@testset "Datbase API" begin
   # check db name
   body = """{"token":"$token","username":"test","dbName":"precompile_test"}"""
   res = HTTP.request("POST", url * "/cnp/check_database_name", [], body, status_exception=false)
   response = JSON.parse(String(res.body))
   db_server_path = get(response, "dbServerPath", nothing)
   @test res.status == 200
   @test !isnothing(db_server_path)

   # uploading
   db_file = joinpath(@__DIR__, "..", "test_data", "clasnip_db_test.tar.xz")
   @test isfile(db_file)

   upload_body2 = HTTP.Form(["" => HTTP.Multipart("clasnip_db_test.tar.xz", open(db_file), "application/x-xz")])
   upload_header = [
      "Content-Type" => "multipart/form-data; boundary=$(upload_body2.boundary)",
      "Content-Length" => length(upload_body2),
      "dbName" => "precompile_test",
      "dbServerPath" => db_server_path,
      "token" => token,
      "username" => "test",
   ]
   res = HTTP.request("POST", url * "/cnp/upload_database", upload_header, upload_body2, status_exception=false)
   @test res.status == 200
   response = JSON.parse(String(res.body))

   # create db
   create_body = """
   {"token":"$token","username":"test","dbName":"precompile_test","dbServerPath":"$db_server_path","refGenome":{"valid":true,"filepath":"/clasnip_db_test/F/MH259699.1.16S.CLso-HF.fasta","group":"F","basename":"MH259699.1.16S.CLso-HF.fasta"},"dbType":"single gene","region":"test 16S gene","taxonomyRank":"species","taxonomyName":"taxname"}
   """
   create_res = HTTP.request("POST", url * "/cnp/create_database", [], create_body, status_exception=false)
   response = JSON.parse(String(create_res.body))
   create_job_id = response["jobID"]
   create_job = job_query(create_job_id)

   queue()
   # report query
   report_body = """{"token":"$token","username":"test","queryString":"$create_job_id//"}"""
   time_of_submit = now()
   while true
      report_res = HTTP.request("POST", url * "/cnp/report_query", [], report_body, status_exception=false)
      @test report_res.status == 200
      response = JSON.parse(String(report_res.body))
      println(Pipelines.stdout_origin, "    Waiting for db build: ($(response["job"]["name"])) $(response["job"]["state"])")
      if !(response["job"]["state"] in ("running", "queuing"))
         break
      end
      if now() - time_of_submit > Minute(10)
         @test @error "Time out for db build finished"
         break
      end
      sleep(10)
   end
   report_res = HTTP.request("POST", url * "/cnp/report_query", [], report_body, status_exception=false)
   @test report_res.status == 200
   println(Pipelines.stdout_origin, "    Waiting for db build: ($(response["job"]["name"])) $(response["job"]["state"])")
   response = JSON.parse(String(report_res.body))
   @test response["job"]["state"] == "done"


   @testset "Browsing databases" begin
      # get database
      res = HTTP.request("GET", url * "/cnp/get_database")
      @test res.status == 200
      response = JSON.parse(String(res.body))
      @test haskey(response, "precompile_test")
      db_path = response["precompile_test"]["dbPath"]

      # file viewer
      res = HTTP.request("POST", url * "/cnp/file_viewer", [], """{"token":null,"username":null,"filePath":"$(db_path)/plot.heatmap_snp_score.svg"}""", status_exception=false)
      @test res.status == 200

      # table viewer
      res = HTTP.request("POST", url * "/cnp/quasar_table_viewer", [], """{"token":null,"username":null,"filePath":"$(db_path)/stat.classifier_performance.txt"}""", status_exception=false)
      @test res.status == 200

      res = HTTP.request("POST", url * "/cnp/quasar_table_viewer", [], """{"token":null,"username":null,"filePath":"$(db_path)/stat.classifier_performance.training.txt"}""", status_exception=false)
      @test res.status == 200

      res = HTTP.request("POST", url * "/cnp/quasar_table_viewer", [], """{"token":null,"username":null,"filePath":"$(db_path)/stat.classifier_performance.test.txt"}""", status_exception=false)
      @test res.status == 200
   end

   @testset "New analysis" begin
      res = HTTP.request("POST", url * "/cnp/submit_job", [], """{"token":"$token","username":"test","email":"test@abc.def","database":"precompile_test","sequences":">JX624246.1 Candidatus Liberibacter solanacearum clone WA-psyllids-1 16S ribosomal RNA gene, partial sequence\\nGCGCTTATTTTTAATAGGAGCGGCAGACGGGTGAGTAACGCGTGGGAATCTACCTTTTTCTACGGGATAA\\nCGCACGGAAACGTGTGCTAATACCGTATACGCCCTGAGAAGGGGAAAGATTTATTGGAGAGAGATGAGCC\\nCGCGTTAGATTAGCTAGTTGGTGGGGTAAATGCCTACCAAGGCTACGATCTATAGCTGGTCTGAGAGGAC\\nGATCAGCCACACTGGGACTGAGACACGGCCCAGACTCCTACGGGAGGCAGCAGTGGGGAATATTGGACAA\\nTGGGGGCAACCCTGATCCAGCCATGCCGCGTGAGTGAAGAAGGCCTTAGGGTTGTAAAGCTCTTTCGCCG\\nGAGAAGATAATGACGGTATCCGGAGAAGAAGTCCCGGCTAACTTCGTGCCAGCAGCCGCGGTAATACGAA\\nGGGGGCGAGCGTTGTTCGGAATAACTGGGCGTAAAGGGCGCGTAGGCGGGTAATTAAGTTAGGGGTGAAA\\nTCCCAAGGCTCAACCTTGGAACTGCCTTTAATACTGGTTATCTAGAGTTTAGGAGAGGTGAGTGGAATTC\\nCGAGTGTAGAGGTGAAATTCGCAGATATTCGGAGGAACACCAGTGGCGAAGGCGGCTCACTGGCCTGATA\\nCTGACGCTGAGGCGCGAAAGCGTGGGGAGCAAACAGGATTAGATACCCTGGTAGTCCACGCTGTAAACGA\\nTGAGTGCTAGCTGTTGGGTGGTTTACCATTCAGTGGCGCAGCTAACGCATTAAGCACTCCGCCTGGGGAG\\nTACGGTCGCAAGATTAAAACTCAAAGGAATTGACGGGGGCCCGCACAAGCGGTGGAGCATGTGGTTTAAT\\nTCGATGCAACGCGCAGAACCTTACCAGCCCTTGACATATAGAGGACGATATCAGAGATGGTATTTTCTTT\\nTCGGAGACCTTTATACAGGTGCTGCATGGCTGTCGTCAGCTCGTGTCGTGAGATGTTGGGTTAAGTCCCG\\nCAACGAGCGCAACCCCTACCTCTAGTTGCCATCAAGTTTAGATTTTATCTAGATGTTGGGTACTTTATAG\\nGGACTGCCGGTGATAATCCGGAGGAAGGTGGGGATGACGTCAAGTCCTCATGGCCCTTATGGGCTGGGCT\\nACACACGTGCTACAATGGTGGTTACAATGGGTTGCGAAGTCGCGAGGC"}""", status_exception=false)
      @test res.status == 200
      response = JSON.parse(String(res.body))
   end

   @testset "Report Query" begin
      job_id = response["jobID"]
      job_name = response["jobName"]
      query_string = "$job_id//$job_name"
      res = HTTP.request("POST", url * "/cnp/report_query", [], """{"token":"$token","username":"test","queryString":"$query_string"}""", status_exception=false)
      @test res.status == 200
      response = JSON.parse(String(res.body))
      @test !isnothing(response["job"])

      time_of_submit = now()
      while true
         res = HTTP.request("POST", url * "/cnp/report_query", [], """{"token":"$token","username":"test","queryString":"$query_string"}""", status_exception=false)
         response = JSON.parse(String(res.body))

         println(Pipelines.stdout_origin, "    Waiting for analysis finish: ($(response["job"]["name"])) $(response["job"]["state"])")
         if !(response["job"]["state"] in ("running", "queuing"))
            break
         end
         if now() - time_of_submit > Minute(2)
            @test @error "Time out for new analysis"
            break
         end
         sleep(10)
      end
      res = HTTP.request("POST", url * "/cnp/report_query", [], """{"token":"$token","username":"test","queryString":"$query_string"}""", status_exception=false)
      @test res.status == 200
      response = JSON.parse(String(res.body))
      @test response["job"]["state"] == "done"

      # view results
      @test isfile(response["log"])
      res = HTTP.request("POST", url * "/cnp/file_viewer", [], """{"token":"$token","username":"test","filePath":"$(response["log"])"}""", status_exception=false)
      @test res.status == 200

      @test isfile(response["seq"])
      res = HTTP.request("POST", url * "/cnp/file_viewer", [], """{"token":"$token","username":"test","filePath":"$(response["seq"])"}""", status_exception=false)
      @test res.status == 200

      @test isfile(response["mlstTable"])
      res = HTTP.request("POST", url * "/cnp/quasar_table_viewer", [], """{"token":"$token","username":"test","filePath":"$(response["mlstTable"])"}""", status_exception=false)
      @test res.status == 200

      @test isfile(response["classificationResult"])
      res = HTTP.request("POST", url * "/cnp/quasar_table_viewer", [], """{"token":"$token","username":"test","filePath":"$(response["classificationResult"])"}""", status_exception=false)
      @test res.status == 200
   end
end


@testset "User" begin
   res = HTTP.request("POST", url * "/cnp/analysis_list", [], """{"token":"$token","username":"test"}""", status_exception=false)
   @test res.status == 200
end

@testset "Remove database" begin
   res = HTTP.request("POST", url * "/cnp/rm_clasnip_database", [], """{"token":"$token","username":"test","dbName":"precompile_test"}""", status_exception=false)
   @test res.status == 200
end

@testset "Log out" begin
   body_token = """{"username": "test", "token": "$token"}"""

   res = HTTP.request("POST", url * "/pccau/logout", [], body_token, status_exception=false)
   @test res.status == 202
   @test !haskey(Auth.token_dict, token)
end

@testset "Check database removed" begin
   res = HTTP.request("GET", url * "/cnp/get_database")
   @test res.status == 200
   response = JSON.parse(String(res.body))
   @test !haskey(response, "precompile_test")
end

@info "Precompilation and tests exit without errors."
@info "Clasnip server is ready at $url"
