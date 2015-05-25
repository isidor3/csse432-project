local HTTP = require "HTTP"
local re = require "re"
local lanes = require("lanes")

local function tp(table) 
	io.write("{")
	for k,v in pairs(table) do
		if k == nil or v == nil then io.write"nil" 
		elseif type(v) == "function" then io.write(k.."=function")
		elseif type(v) == "table" then --[[ /n ]] io.write(k.."=") tp(v)
		elseif type(v) == "string" then io.write(k.."=") io.write("\""..v.."\"")
		else io.write(tostring(k).."= ".. tostring(v)) end
		io.write(", ")
	end
	io.write("}")
end

local function cannedResponses(request)
	if not request then
		resp = HTTP.newResponse(400)
		resp.body = "<html><body><h2>"..resp.code_text.."</h2></body></html>"
		resp.headers["Content-Type"] = "text/html; charset=UTF-8"
		resp.headers["Connection"] = "close"
		return resp
	end
	
	if not request.headers.Host then 
		resp = HTTP.newResponse(400)
		resp.body = "<html><body><h2>Error: request must include 'Host' header.</h2></body></html>"
		resp.headers["Content-Type"] = "text/html; charset=UTF-8"
		resp.headers["Connection"] = "close"
		return resp
	end
	
	if request.http_version ~= "1.1" then
		resp = HTTP.newResponse(505)
		resp.body = "<html><body><h2>"..resp.code_text.."</h2></body></html>"
		resp.headers["Content-Type"] = "text/html; charset=UTF-8"
		resp.headers["Connection"] = "close"
		return resp
	end
end

local routeRequest, recvHeader, recvBody, recvChunked, recvExtraHeaders

-- Receive an HTTP header, then decide what to do next based on the header info
-- Can move to a chunked body, a regular byte-body, or simply routing the request
function recvHeader(index, client, data)
	data.timeouts = data.timeouts or 0
	data.buffer = data.buffer or {}
	
	local line, err, partial = client:receive()
	
	if not err then
		data.timeouts = 0
		data.buffer[#data.buffer+1] = line
		data.buffer[#data.buffer+1] = "\n"
		
		if line == "" then
			data.request = table.concat(data.buffer)
			data.buffer = {}
			data.request = HTTP.parseRequest(data.request)
			request = data.request
			
			cannedResponse = cannedResponses(request)
			if cannedResponse then
				client:send(cannedResponse:tostring())
				return false
			end
			
			--print"Received full header, parsing further"
			if request.headers["Transfer-Encoding"] == "chunked" then
				--print"Parsing as chunked data"
				data.func = recvChunked	
				return true
			elseif request.headers["Content-Length"] ~= nil then
				--print"Parsed as regular body"
				data.func = recvBody
				return true
			else
				--print"Parsed as finished packet"
				data.func = routeRequest
				return true
			end
		end
	else
		if err == "timeout" then
			if partial ~= "" then 
				data.buffer[#data.buffer+1] = partial 					
			end
			data.timeouts = data.timeouts + 1
			if data.timeouts >= 2100000 then
				--print"Connection timed out"
				return false 
			end
		else
			--print"Connection Closed"
			return false
		end
	end
			
	return true
end

-- Receive a simple "content-length" type body, assumed to come after a header that has already been received
function recvBody(index, client, data)
	data.bytesLeft = data.bytesLeft or tonumber(data.request.headers["Content-Length"])
	if not data.bytesLeft then --If we can't parse the content length, return 400
		client:send(cannedResponses(nil):tostring()) 
		return false
	end
	
	local line, err, partial = client:receive(data.bytesLeft)
	if not err then
		data.buffer[#data.buffer+1] = line
		data.timeouts = 0
		data.bytesLeft = nil
		data.request.body = table.concat(data.buffer)
		data.buffer = nil
		data.func = routeRequest
	else
		if err == "timeout" then
			if partial ~= "" then 
				data.buffer[#data.buffer+1] = partial
				data.bytesLeft = data.bytesLeft - #partial
			else
				data.timeouts = data.timeouts+1
				if data.timeouts >= 2100000 then
					--print"Connection timed out"
					return false
				end
			end
		else
			return false
		end
	end
	return true
end

local numStart = re.compile([=[ ([0-9] / [a-f] / [A-F])+ -> tohex (";" .*)? ]=], {tohex = function(x) return tonumber("0x"..x) end})

-- Receive a chunked body, assumed to come after a header that has already be received
function recvChunked(index, client, data)
	data.bytesLeft = data.bytesLeft or 0 
	data.inChunk = data.inChunk or false
	data.lastChunk = data.lastChunk or false
	data.miniBuffer = data.miniBuffer or {}
	
	if data.inChunk then
		local line, err, partial = client:receive(data.bytesLeft)
		if not err then
			data.buffer[#data.buffer+1] = line:sub(1,-3)
			data.timeouts = 0
			data.inChunk = false
			if data.lastChunk then
				data.request.body = table.concat(data.buffer)
				data.miniBufffer = nil
				data.buffer = {}
				data.func = recvExtraHeaders
			end
		else
			if err == "timeout" then
				if partial ~= "" then
					data.buffer[#data.buffer+1] = partial
					data.bytesLeft = data.bytesLeft - #partial
				else
					data.timeouts = data.timeouts+1
					if data.timeouts >= 2100000 then
						--print"Connection timed out"
						return false
					end
				end
			else
				return false
			end
		end
	else
	--Not in a chunk
		local line, err, partial = client:receive()
		if not err then
			newNum = numStart:match(table.concat(data.miniBuffer)..line)
			if not newNum then 
				--print("couldn't interpret number",line)
				--tp(data) print""
				client:send(cannedResponses(nil):tostring()) 
				return false
			end
			data.bytesLeft = newNum + 2
			--print("reading "..data.bytesLeft.." bytes")
			data.inChunk = true
			if data.bytesLeft == 2 then data.lastChunk = true end
		else
			if err == "timeout" then
				if partial ~= "" then
					data.miniBuffer[#data.miniBuffer+1] = partial
				else
					data.timeouts = data.timeouts+1
					if data.timeouts >= 2100000 then
						--print"Connection timed out"
						return false
					end
				end
			else
				return false
			end
		
		end
	end
	
	return true
end

-- Copy-pasta'd from the HTTP library, there's probably a better way to expose this
-- But For now it works.
local separators = lpeg.S("()<>@,;:\\\"<>/[]?={} \t")
local token = (lpeg.R"\32\126" - separators)^1
local CTL = lpeg.R"\00\31" + lpeg.S"\127"
local WS = lpeg.S(" \t")^1
local TEXT = lpeg.P(1) - CTL
local ENDL = lpeg.P"\r\n" + lpeg.P"\n"
local LWS = ENDL * WS
local quoted_string = lpeg.P"\"" * (lpeg.P(1) - "\"") * "\""

local function concat(s, s1)
	return s..s1
end

local 	field_value = lpeg.Cg(lpeg.Cf(lpeg.Cc("")* lpeg.C(TEXT^1) * ((LWS / " ") * lpeg.C(TEXT^1))^0 , concat), "value")
local 	header_name = lpeg.Cg( token, "name")
local message_header = header_name * WS^0 * ":" * WS^0 * field_value^-1 * WS^0 * ENDL
local headersPattern = lpeg.Ct( lpeg.Ct(message_header)^0) * ENDL
	
function recvExtraHeaders(index, client, data)
	data.timeouts = data.timeouts or 0
	data.buffer = data.buffer or {}
	
	local line, err, partial = client:receive()
	
	if not err then
		data.timeouts = 0
		data.buffer[#data.buffer+1] = line
		data.buffer[#data.buffer+1] = "\n"
		
		if line == "" then
			local headers = table.concat(data.buffer)
			headers = headersPattern:match(headers)
			for _,v in pairs(headers) do
				data.request.headers[v.name] = v.value
			end
			data.func = routeRequest
		end
	else
		if err == "timeout" then
			if partial ~= "" then 
				data.buffer[#data.buffer+1] = partial 					
			end
			data.timeouts = data.timeouts + 1
			if data.timeouts >= 2100000 then
				--print"Connection timed out"
				return false 
			end
		else
			--print"Connection Closed"
			return false
		end
	end
	return true
end

--Route the completed request to the proper destination
function routeRequest(index, client, data, linda)
	local request = data.request
	data.routedPackets = data.routedPackets + 1 or 0
	
	--Should be replaced
	
	linda:send("requests", {index, data.routedPackets, data.request})

	data.func = recvHeader
	return true
end

function requestReader(clients, linda)
	perConnectionData = {}
	waitingPackets = {}
	while 1 do
		for index,client in pairs(clients) do
			if not perConnectionData[index] then perConnectionData[index] = {func=recvHeader, routedPackets=0, deliveredPackets=1} end
			local data = perConnectionData[index]
			local nextFunc = data.func
			local keepData = nextFunc(index, client, data, linda)
			
			if not keepData then 
				client:close()
				perConnectionData[index] = nil 
				clients[index] = nil
			end
			
			-- Send any packets waiting to be sent
			key, val = linda:receive(0.001 ,"responses")
			if val then
				waitingPackets[val[1]] = waitingPackets[val[1]] or {}
				waitingPackets[val[1]][val[2]] = val[3]
			end
			
			local i = data.deliveredPackets
			while i <= data.routedPackets  do
				
				if waitingPackets[index] and waitingPackets[index][i] then
					client:send(waitingPackets[index][i])
					data.deliveredPackets = data.deliveredPackets + 1
					waitingPackets[index][i] = nil
					if waitingPackets[index] == {} then waitingPackets[index] = nil end
				else break end
				i = i + 1
			end
		end
		coroutine.yield()
		
	end

end

return requestReader
