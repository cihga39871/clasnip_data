#= NOTE: define only unused status messages (used codes shown at end of the file)

Informational responses (100–199),
Successful responses (200–299),
Redirects (300–399),
Client errors (400–499),
and Server errors (500–599).
=#

HTTP.Messages.STATUS_MESSAGES[230] = "Registration is successful"


HTTP.Messages.STATUS_MESSAGES[455] = "Username and password not match"
HTTP.Messages.STATUS_MESSAGES[456] = "Invalid input: special characters not allowed"
HTTP.Messages.STATUS_MESSAGES[457] = "Username exists"
HTTP.Messages.STATUS_MESSAGES[458] = "Invalid path on server"
HTTP.Messages.STATUS_MESSAGES[459] = "Need login to access"
HTTP.Messages.STATUS_MESSAGES[460] = "Failed to log out"
HTTP.Messages.STATUS_MESSAGES[461] = "Project name (path) rejected by server"
HTTP.Messages.STATUS_MESSAGES[462] = "Job not found"
HTTP.Messages.STATUS_MESSAGES[463] = "File not found or no permission"
HTTP.Messages.STATUS_MESSAGES[464] = "File too large"
HTTP.Messages.STATUS_MESSAGES[465] = "Invalid sequences"
HTTP.Messages.STATUS_MESSAGES[467] = "Name exists"
HTTP.Messages.STATUS_MESSAGES[468] = "Upload failed"
HTTP.Messages.STATUS_MESSAGES[469] = "Unacceptable file type"
HTTP.Messages.STATUS_MESSAGES[470] = "Only one group in database"
HTTP.Messages.STATUS_MESSAGES[471] = "Value too long"
HTTP.Messages.STATUS_MESSAGES[472] = "Too many attempts: lock for a day"
HTTP.Messages.STATUS_MESSAGES[473] = "Password requirement not met: at least 6 characters"
HTTP.Messages.STATUS_MESSAGES[474] = "Password and username cannot be same"
HTTP.Messages.STATUS_MESSAGES[475] = "Name similar to existing ones: Distance < 3"
HTTP.Messages.STATUS_MESSAGES[476] = "Input too long"
HTTP.Messages.STATUS_MESSAGES[477] = "Fail to read file as table"

#= Used codes:
v[100] = "Continue"
v[101] = "Switching Protocols"
v[102] = "Processing"                            # RFC 2518 => obsoleted by RFC 4918
v[103] = "Early Hints"

v[200] = "OK"
v[201] = "Created"
v[202] = "Accepted"
v[203] = "Non-Authoritative Information"
v[204] = "No Content"
v[205] = "Reset Content"
v[206] = "Partial Content"
v[207] = "Multi-Status"                          # RFC 4918
v[208] = "Already Reported"                      # RFC5842
v[226] = "IM Used"                               # RFC3229

v[300] = "Multiple Choices"
v[301] = "Moved Permanently"
v[302] = "Moved Temporarily"
v[303] = "See Other"
v[304] = "Not Modified"
v[305] = "Use Proxy"
v[307] = "Temporary Redirect"
v[308] = "Permanent Redirect"                    # RFC7238

v[400] = "Bad Request"
v[401] = "Unauthorized"
v[402] = "Payment Required"
v[403] = "Forbidden"
v[404] = "Not Found"
v[405] = "Method Not Allowed"
v[406] = "Not Acceptable"
v[407] = "Proxy Authentication Required"
v[408] = "Request Time-out"
v[409] = "Conflict"
v[410] = "Gone"
v[411] = "Length Required"
v[412] = "Precondition Failed"
v[413] = "Request Entity Too Large"
v[414] = "Request-URI Too Large"
v[415] = "Unsupported Media Type"
v[416] = "Requested Range Not Satisfiable"
v[417] = "Expectation Failed"
v[418] = "I'm a teapot"                        # RFC 2324
v[421] = "Misdirected Request"                 # RFC 7540
v[422] = "Unprocessable Entity"                # RFC 4918
v[423] = "Locked"                              # RFC 4918
v[424] = "Failed Dependency"                   # RFC 4918
v[425] = "Unordered Collection"                # RFC 4918
v[426] = "Upgrade Required"                    # RFC 2817
v[428] = "Precondition Required"               # RFC 6585
v[429] = "Too Many Requests"                   # RFC 6585
v[431] = "Request Header Fields Too Large"     # RFC 6585
v[440] = "Login Timeout"
v[444] = "nginx error: No Response"
v[451] = "Unavailable For Legal Reasons"       # RFC7725
v[495] = "nginx error: SSL Certificate Error"
v[496] = "nginx error: SSL Certificate Required"
v[497] = "nginx error: HTTP -> HTTPS"
v[499] = "nginx error or Antivirus intercepted request or ArcGIS error"

v[500] = "Internal Server Error"
v[501] = "Not Implemented"
v[502] = "Bad Gateway"
v[503] = "Service Unavailable"
v[504] = "Gateway Time-out"
v[505] = "HTTP Version Not Supported"
v[506] = "Variant Also Negotiates"             # RFC 2295
v[507] = "Insufficient Storage"                # RFC 4918
v[508] = "Loop Detected"                       # RFC5842
v[509] = "Bandwidth Limit Exceeded"
v[510] = "Not Extended"                        # RFC 2774
v[511] = "Network Authentication Required"     # RFC 6585
v[520] = "CloudFlare Server Error: Unknown"
v[521] = "CloudFlare Server Error: Connection Refused"
v[522] = "CloudFlare Server Error: Connection Timeout"
v[523] = "CloudFlare Server Error: Origin Server Unreachable"
v[524] = "CloudFlare Server Error: Connection Timeout"
v[525] = "CloudFlare Server Error: Connection Failed"
v[526] = "CloudFlare Server Error: Invalid SSL Ceritificate"
v[527] = "CloudFlare Server Error: Railgun Error"
v[530] = "Site Frozen"
=#
