local lpeg = require 'lpeg'
local re = require 're'

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
local Cs = lpeg.Cs

-----------------
-- URL Parsing --
-----------------
--Percent Encoding
local function percentToChar(s) return string.char(tonumber("0x"..s:sub(2))) end
local percentEncoded = (P"%" * R"09" * R"09") / percentToChar
local percentDecoder = Cs( (percentEncoded + P(1))^0 ) * -1

--URI Parsing
local uriParser = re.compile([=[
      uri <- {| (scheme ":" )? ("//" authority)? path ("?" query)? ("#" fragment)? |}
   scheme <- {:scheme: [^:/?#]+ :}
authority <- {:authority: [^/?#]* :}
     path <- {:path: {| path_segment |} / [^?#]* :}
	path_segment <-  "/"? {[^/?#]*} ("/" {[^/?#]*})*
    query <- {:query: [^#]* :}
 fragment <- {:fragment: .* :}

]=])

---------------------
-- Request Parsing --
---------------------

local separators = S("()<>@,;:\\\"<>/[]?={} \t")
local token = (R"\32\126" - separators)^1
local CTL = R"\00\31" + S"\127"
local WS = S(" \t")^1
local TEXT = P(1) - CTL
local ENDL = P"\r\n" + P"\n"
local LWS = ENDL * WS
local quoted_string = P"\"" * (P(1) - "\"") * "\""

local function concat(s, s1)
	return s..s1
end

--This might look cleaner if re-written using regex syntax (as the uri parser)
--But it currently works, so I won't mess with it for now.
local requestParser = P{
"requestC";
requestC = Ct(V"request"),
request = V"Request_Line" * V"headers" * ENDL * V"body",
          
	Request_Line = V"Method" * WS * V"Request_URI"  * WS * V"http_version" * WS^0 * ENDL,
		Method = Cg(token, "method"),
		Request_URI = Cg( (P(1) - (WS+ENDL))^0 ,"uri"),
		http_version = P"HTTP/" * Cg(token, "http_version"),
		
	headers = Cg(Ct( Ct(V"message_header")^0) , "headers"),
	
	message_header = V"header_name" * WS^0 * ":" * WS^0 * V("field_value")^-1 * WS^0 * ENDL,
		header_name = Cg( token, "name"),
		field_value = Cg(Cf(Cc("")* C(TEXT^1) * ((LWS / " ") * C(TEXT^1))^0 , concat), "value"),
			
	body = Cg( P(1)^0, "body")
}



---------------
-- Functions --
--------------- 
local HTTP = {}

function HTTP.parseRequest(input) 
	request = requestParser:match(input)
	if not request then return nil end
	
	uri = uriParser:match(percentDecoder:match(request.uri))
	--If we can't parse the URI, just return nil
	--There may be cases where this isn't desired, but it saves some checking outside
	if uri then 
		uri.string = request.uri
		request.uri = uri
	else return nil end
	
	newHeaders = {}
	for _,v in pairs(request.headers) do
		newHeaders[v.name] = v.value
	end
	request.headers = newHeaders
	return request
end


----------------
-- Unit Tests --
---------------- 
local TEST = false
if TEST then

local function tp(table) 
	io.write("{")
	for k,v in pairs(table) do
		if k == nil or v == nil then io.write"nil" end
		if type(v) == "table" then --[[ /n ]] io.write(k.."=") tp(v)
		elseif type(v) == "string" then io.write(k.."=") io.write("\""..v.."\"")
		else io.write(k.."= ".. v) end
		io.write(", ")
	end
	io.write("}")
end

local function assertRequest(name, request)
	result = HTTP.parseRequest(request)
	if not result then 
		print(name.." : \27[31mFAIL!\27[0m")
		return false;
	else
		print(name.." : \27[32mSUCCESS!\27[0m" ) tp(result) print""
		return true;
	end
end

local function assertURI(name, uri)
	result = uriParser:match(uri)
	if not result then 
		print(name.." : \27[31mFAIL!\27[0m")
		return false;
	else
		print(name.." : \27[32mSUCCESS!\27[0m" )
		return true;
	end
end

print "-- Beginning unit tests! --"
print '\27[33m--> Testing URIs\27[0m'

assertURI("Simplest uri", '/')

print '\27[33m--> Testing HTTP requests\27[0m'

assertRequest("Simplest Request", [[
GET / HTTP/1.1

]])

assertRequest("Involved URI", [[
GET /x/y/z/stuff.html?asd=123&sdf=234 HTTP/1.1

]])

assertRequest("Absolute URI", [[
GET http://example.com/subdir/file.html?asd=123&jkl=qwe HTTP/1.1

]])

assertRequest("Headers", [[
PUT /stuff/things.txt HTTP/1.1
Content-Type:application/json
Content-Length:0

]])

assertRequest("headers w/ whitespace", [[
POST /stuff/things.html HTTP/1.1
Content-Type : 	application/json
Content-Stuff  	:   	some random string and stuff

]])

assertRequest("headers w/ leading whitespace", [[
POST http://example.com/stuff/things.html#fragmentstuff HTTP/1.1
Content-Type : application/json
Content-Stuff : Just a long string, that the client
 decided to split up over multiple lines
 	and indent seperately.

]])

assertRequest("percent encoded", [[
GET http://www.example.com/stuff/things.html?foo=data%20with%20spaces;bar=nospaces#fragment HTTP/1.1
Content-Type : application/json

body text]])

assertRequest("has Body", [[
POST /stuff/thungs HTTP/1.1

body text]])

print "-- End unit tests! --"
print "\n"

end


return HTTP
