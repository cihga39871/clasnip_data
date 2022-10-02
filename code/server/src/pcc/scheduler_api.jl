# TODO: api_job_detail, api_queue, api_cancel

"""
	api_job_detail(request)

Query job detail by job ID.

## Request

- `request[:path][1]`: job ID.

## Response

- `400`: (1) reject empty job ID or (2) multiple job ids.

- `462`: job ID not found.

- `200`: successful. Return data in JSON format:

```json
{
    "id"          : 63741916789241
    "name"        : "name of job"
    "user"        : "user of submission"
    "ncpu"        : 1
    "create_time" : "0000-01-01T00:00:00"
    "start_time"  : "0000-01-01T00:00:00"
    "stop_time"   : "0000-01-01T00:00:00"
    "wall_time"   : "1 week"
    "state"       : one of "queueing", "running", "done", "failed", "cancelled"
    "priority"    : 20
    "stdout_file" : "path of file"
    "stderr_file" : "path of file"
}
```
"""
function api_job_detail(request)
    if get(request, :path, "") == ""  # reject empty job id
		return json_response(request, 400)
	end
	if length(request[:path]) != 1  # multiple job ids? unknown
		return json_response(request, 400)
	end

	job_id = request[:path][1]
	job = job_query_by_id(job_id)

	if isnothing(job)
		return json_response(request, 462) # job not found
	end

	return json_response(request, 200, data = json(job))
end

"""
	api_job_queue(request; all=true)

Return the job queue (a vector of job details.)

## Request

Nothing is required.

## Response

- `200`: successful. Return data in JSON format:

```json
[
	{
	    "id"          : 63741916789241
	    "name"        : "name of job"
	    "user"        : "user of submission"
	    "ncpu"        : 1
	    "create_time" : "0000-01-01T00:00:00"
	    "start_time"  : "0000-01-01T00:00:00"
	    "stop_time"   : "0000-01-01T00:00:00"
	    "wall_time"   : "1 week"
	    "state"       : one of "queueing", "running", "done", "failed", "cancelled"
	    "priority"    : 20
	    "stdout_file" : "path of file"
	    "stderr_file" : "path of file"
	},
	{
		...
	}
]
```
"""
function api_job_queue(request; all=true)
	return json_response(request, 200, data = json_queue(all=all))
end


"""
	api_job_cancel(request)

Cancel a queuing or running job.

## Request

- `request[:path][1]`: job ID.

## Response

- `400`: (1) reject empty job ID or (2) multiple job ids.

- `462`: job ID not found.

- `200`: successfully cancelled the job.
"""
function api_job_cancel(request)
    if get(request, :path, "") == ""  # reject empty job query
		return json_response(request, 400)
	end
	if length(request[:path]) != 1  # multiple job id? unknown
		return json_response(request, 400)
	end

	job_id = request[:path][1]
	job = job_query_by_id(job_id)

	if isnothing(job)
		return json_response(request, 462) # job not found
	end

	cancel!(job)
	return json_response(request, 200)
end
