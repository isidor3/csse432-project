local lpeg = require 'lpeg'

local P = lpeg.P
local S = lpeg.S
local R = lpeg.R
local V = lpeg.V

local C = lpeg.C
local Carg = lpeg.Carg
local Cb = lpeg.Cb
local Cc = lpeg.Cc
local Cf = lpeg.Cf
local Cg = lpeg.Cg
local Ct = lpeg.Ct

local separators = S("()<>@,;:\\\"<>/[]?={} \t")
local token = (R("\040\176") - separators)^1
local CTL = R"\000\037" + S"\177"
local LWS = (P"\r\n")^-1 * S(" \t")^1 / " "
local TEXT = P(1) - CTL
local quoted_string = P"\"" * (P(1) - "\"") * "\""

local HTTP = {}

local function string_fold(s, s1)
	return s..s1
end

local request = P{
"request";
request = Ct(V"Request_Line" * Cg(Ct((Ct(V"message_header") * "\r\n")^0), "headers") * "\r\n" * Cg(V"body", "body")),
          
	Request_Line = Cg(V"Method", "method") * " " * Cg(V"Request_URI", "uri")  * " " * "HTTP/1.1" * "\r\n",
		Method = P"CONNECT" + "GET" + "POST" + "DELETE" + 
		         "PUT" + "OPTIONS" + "TRACE" + token,
		Request_URI = P(1) - S(" \t\r\n"),--V"abs_path" + V"absoluteURI"  + V"authority" + P"*",
	
	message_header = Cg(token, "header") * ":" * V"field_value"^-1,
		field_value = Cg(Cf((LWS + C(V"field_content"))^0, string_fold), "value"),
			field_content = -S(" \t") * (TEXT^1 + (token + separators + quoted_string)^1) * -S(" \t") ,
			
	body = P(1)^0
	
}


function HTTP.parseRequest(input) 
	return request:match(input)
end

function HTTP.newResponse(code) 
	resp = {}
	resp.version = "HTTP/1.1"
	resp.code = code or 200
	resp.code_text = HTTP.codes[code] or ""
	resp.headers = {
		{header = "Server", value = "DogeNozzle/0.0.1"}
	}
	resp.body = ""
	
	function resp:addHeader(h,v)
		if type(h) == "string" and type(v) == "string" then
			self.headers[#(self.headers)+1] = {header = h, value = v}
		end
		return self
	end
	function resp:tostring()
		ret = {self.version, " ", self.code, " ", self.code_text, "\r\n",}
		for _,v in pairs(self.headers) do
			ret[#ret+1] = v.header
			ret[#ret+1] = ": "
			ret[#ret+1] = v.value
			ret[#ret+1] = "\r\n"
		end	
		ret[#ret+1] = "\r\n"
		ret[#ret+1] = self.body
		return table.concat(ret)
	end
	
	return resp
end

function tp(table) 
	io.write("{ ")
	for k,v in pairs(table) do
		if k == nil or v == nil then io.write"nil" end
		if type(v) == "table" then io.write("\n") io.write(k.."= ") tp(v)
		elseif type(v) == "string" then io.write(k.."= ") io.write("\""..v.."\"")
		else io.write(k.."= ".. v) end
		io.write(", ")
	end
	io.write(" }\n")
end

HTTP.codes = {
	[100] = "Continue",
	[101] = "Switching Protocols",
	[102] = "Processing",
	[200] = "OK",
	[201] = "Created",
	[202] = "Acceppted",
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

return HTTP
