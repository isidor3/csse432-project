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
local TEXT = (LWS + P(1) - CTL)
local quoted_string = P"\"" * (P(1) - "\"") * "\""

local HTTP = {}


local request = P{
"request";
request = V"Request_Line" * Ct(((Ct(V"message_header") * "\r\n")^0)) * "\r\n" * C(V"body"),
          
	Request_Line = C(V"Method") * " " * C(V"Request_URI")  * " " * "HTTP/1.1" * "\r\n",
		Method = P"CONNECT" + "GET" + "POST" + "DELETE" + 
		         "PUT" + "OPTIONS" + "TRACE" + token,
		Request_URI = P"/",--V"abs_path" + V"absoluteURI"  + V"authority" + P"*",
	
	message_header = C(token) * ":" * V"field_value"^-1,
		field_value = (LWS + C(V"field_content"))^0,
			field_content = -S(" \t") * (TEXT^1 + (token + separators + quoted_string)^1) * -S(" \t") ,
			
	body = P(1)^0
	
}


function HTTP.parseRequest(input) 
	return request:match(input)
end

function tp(table) 
	io.write("{ ")
	for k,v in ipairs(table) do
		if type(v) == "table" then io.write("\n") io.write(k.."= ") tp(v)
		elseif type(v) == "string" then io.write(k.."= ") io.write("\""..v.."\"")
		else io.write(k.."= ".. v) end
		io.write(", ")
	end
	io.write(" }\n")
end

return HTTP
