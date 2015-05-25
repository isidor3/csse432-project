local router = {}

local HTTP = {}
local function newResponse(code) 
	resp = {}
	resp.version = "HTTP/1.1"
	resp.code = code or 200
	resp.code_text = HTTP.codes[code] or "Unkown Response Code"
	resp.headers = {
		 Server = "DogeNozzle/0.0.1",
	}
	if code >= 200 then
		resp.headers.Date = os.date("!%a, %d %h %Y %T GMT")
	end
	
	
	resp.body = ""
	
	function resp:tostring()
		ret = {self.version, " ", self.code, " ", self.code_text, "\r\n",}
		if self.body then
			self.headers["Content-Length"] = #self.body
		end
		for k,v in pairs(self.headers) do
			ret[#ret+1] = k
			ret[#ret+1] = ":"
			ret[#ret+1] = v
			ret[#ret+1] = "\r\n"
		end	
		ret[#ret+1] = "\r\n"
		ret[#ret+1] = self.body
		return table.concat(ret)
	end
	
	return resp
end

local body  = "Hello World!"

local function start(linda)
while 1 do	
		
	local key, val = linda:receive("requests")
	local index = val[1]
	local number = val[2]
	local request = val[3]
		
	if request.uri.path[1] == "" then 
		if request.method == "GET" then
			--print"sending 200 OK"
			resp = newResponse(200)
			resp.body = "<html><body><h2>"..body.."</h2></body></html>"
			resp.headers["Content-Type"] = "text/html; charset=UTF-8"
			resp.headers["Connection"] = request.headers["Connection"]
			linda:send("responses", {index, number, resp:tostring()})
		elseif request.method == "POST" then
			body = request.body
			resp = newResponse(201)
			resp.headers["Connection"] = request.headers["Connection"]
			linda:send("responses", {index, number, resp:tostring()})
		elseif request.method == "PUT" then
			body = body..request.body
			resp = newResponse(202)
			resp.headers["Connection"] = request.headers["Connection"]
			linda:send("responses", {index, number, resp:tostring()})
		else
			resp = newResponse(405)
			resp.body = "<html><body><h2>Method not allowed!</h2></body></html>"
			resp.headers["Content-Type"] = "text/html; charset=UTF-8"
			resp.headers["Connection"] = request.headers["Connection"]
			linda:send("responses", {index, number, resp:tostring()})
		end
		--print("sending packet "..index..","..number)
	else 
		--print"sending 404 Not Found"
		resp = newResponse(404)
		resp.body = "<html><body><h2>Resource not found!</h2></body></html>"
		resp.headers["Content-Type"] = "text/html; charset=UTF-8"
		resp.headers["Connection"] = request.headers["Connection"]
		linda:send("responses", {index, number, resp:tostring()})
		--print("sending packet "..index..","..number)
	end
	
		
end
end

HTTP.codes = {
	[100] = "Continue",
	[101] = "Switching Protocols",
	[102] = "Processing",
	[200] = "OK",
	[201] = "Created",
	[202] = "Accepted",
	[203] = "Non-Authorative Information",
	[204] = "No Content",
	[205] = "Reset Content",
	[206] = "Partial Content",
	[207] = "Multi-Status",
	[208] = "Already Reported",
	[226] = "IM Used",
	[300] = "Multiple Choices",
	[301] = "Moved Permanently",
	[302] = "Found",
	[303] = "See Other",
	[304] = "Not Modified",
	[305] = "Use Proxy",
	[306] = "Switch Proxy",
	[307] = "Temporary Redirect",
	[308] = "Permanent Redirect",
	[400] = "Bad Request",
	[401] = "Unauthorized",
	[402] = "Payment Required",
	[403] = "Forbidden",
	[404] = "Not Found",
	[405] = "Method Not Allowed",
	[406] = "Not Acceptable",
	[407] = "Proxy Authentication Required",
	[408] = "Request Timeout",
	[409] = "Conflict",
	[410] = "Gone",
	[411] = "Length Required",
	[412] = "Precondition Failed",
	[413] = "Request Entity Too Large",
	[414] = "Request-URI Too Long",
	[415] = "Unsupported Media Type",
	[416] = "Requested Range Not Satifiable",
	[417] = "Expectation Failed",
	[418] = "I'm a teapot",
	[419] = "Authentication Timeout",
	[422] = "Unprocessable Entity",
	[423] = "Locked",
	[424] = "Failed Dependency",
	[426] = "Upgrade Required",
	[428] = "Precondition Required",
	[429] = "Too Many Requests",
	[431] = "Request Header Fields Too Large",
	[451] = "Unavailable For Legal Reasons",
	[500] = "Internal Server Error",
	[501] = "Not Implemented",
	[502] = "Bad Gateway",
	[503] = "Service Unavailable",
	[504] = "Gateway Timeout",
	[505] = "HTTP Version Not Supported",
	[506] = "Variant Also Negotiates",
	[507] = "Insufficient Storage",
	[508] = "Loop Detected",
	[510] = "Not Extended",
	[511] = "Network Authentication Required"
}

return start
