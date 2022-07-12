
function replace_project_root_folder(path::AbstractString)
	replace(path, r"/*__PROJECT_ROOT_FOLDER__" => Config.PROJECT_ROOT_FOLDER)
end

"""
	api_file_search(
		request;
		search_limit::Regex = Config.FILE_SEARCH_LIMIT_GENERAL,
		file_type_limit::Regex = Config.FILE_SEARCH_LIMIT_FILE_TYPE,
		show_hidden_file::Bool = false,
		detect_existing_pcc_project_dirs::Bool = false,
		log_request::Bool = true
	)

List files and folders of a directory on server.

## Request

- `request[:path]::Vector`: the absolute path on server. The first element can be `"__PROJECT_ROOT_FOLDER__"`, which will be automatically replaced by `Config.PROJECT_ROOT_FOLDER`.

## Response

- `458`: the request is invalid, or the path is out of `search_limit`, or the path does not exist.

- `200`: successful. The returned data are documented as below.

### When `detect_existing_pcc_project_dirs == true`

Return data in JSON format:

```julia
Dict(
	"pcc_project_dirs" => pcc_project_dirs,          # Vector of PolyChrome project directories
	"dirs"             => dirs            ,          # Vector of normal directories
	"files"            => files           ,          # Vector of files matching `file_type_limit`
	"is_current_dir_a_project_dir" => true or false  # Bool
))
```

### When `detect_existing_pcc_project_dirs == false`

Return data in JSON format:

```julia
Dict(
	"dirs"  => dirs ,  # Vector of directories
	"files" => files,  # Vector of files matching `file_type_limit`
))
```
"""
function api_file_search(
	request;
	search_limit::Regex = Config.FILE_SEARCH_LIMIT_GENERAL,
	file_type_limit::Regex = Config.FILE_SEARCH_LIMIT_FILE_TYPE,
	show_hidden_file::Bool = false,
	detect_existing_pcc_project_dirs::Bool = false,
	log_request::Bool = true
)
	log_request && @info(request, TimeRequest = now())

	# if !is_allowed_origin(request)
	# 	return json_response(request, 458)
	# end

	if get(request, :path, "") == ""  # reject root folder /
		return json_response(request, 458)
	end

	if !isempty(request[:path]) && request[:path][1] == "__PROJECT_ROOT_FOLDER__"
		request[:path][1] = Config.PROJECT_ROOT_FOLDER
	end

	# abspath needed because Config.PROJECT_ROOT_FOLDER usually starts with "/"
	# adding another "/" will lead to out of search_limit
	path = "/" * join(request[:path], '/') |> abspath

	if !occursin(search_limit, path)
		return json_response(request, 458)
	end

	if !isdir(path)
		return json_response(request, 458)
	end


	pcc_project_dirs  = String[]
	dirs  = String[]
	files = String[]
	is_current_dir_a_project_dir = detect_existing_pcc_project_dirs && is_pcc_project_dir(path)

	files_and_dirs = readdir(path)
	for i in files_and_dirs
		show_hidden_file || occursin(r"^\.", i) && continue

		i_full_path = joinpath(path, i)
		if isdir(i_full_path)
			if detect_existing_pcc_project_dirs && is_pcc_project_dir(i_full_path)
				push!(pcc_project_dirs, i)
			else
				push!(dirs, i)
			end
		elseif isfile(i_full_path)
			if occursin(file_type_limit, i)
				push!(files, i)
			end
		elseif islink(i_full_path)
			# check whether the link is broken
			pwd_backup = pwd()
			dirname(i_full_path) == "" || cd(dirname(i_full_path))
	        i_full_path = basename(i_full_path)
	        n_follow_symlink = 0
	        while islink(i_full_path)
	            i_full_path = readlink(i_full_path)
	            dirname(i_full_path) == "" || cd(dirname(i_full_path))
	            i_full_path = basename(i_full_path)
	            n_follow_symlink += 1
	            n_follow_symlink > 10 && break
	        end
	        if isdir(i_full_path)
				if detect_existing_pcc_project_dirs && is_pcc_project_dir(i_full_path)
					push!(pcc_project_dirs, i)
				else
					push!(dirs, i)
				end
			elseif isfile(i_full_path)
				if occursin(file_type_limit, i)
					push!(files, i)
				end
			end
	        cd(pwd_backup)
		end
	end

	if detect_existing_pcc_project_dirs
		return json_response(request, 200, data = Dict(
			"pcc_project_dirs" => pcc_project_dirs,
			"dirs" => dirs,
			"files" => files,
			"is_current_dir_a_project_dir" => is_current_dir_a_project_dir  # Bool
		))
	else
		return json_response(request, 200, data = Dict(
			"dirs" => dirs,
			"files" => files
		))
	end
end

"""
	is_pcc_project_dir(dir::AbstractString)

"""
function is_pcc_project_dir(dir::AbstractString)
	isdir(dir) || (return false)
	files = readdir(dir)
	for file in files
		occursin(r"^pcc\-(\d+|args)\-", file) && (return true)
	end
	false
end

function is_parent_pcc_project_dir(path::AbstractString)
	occursin(r"/pcc\-(\d+|args|logs)\-[^/]+(/|$)", path)
end