-- load namespace
local socket = require("socket")
local HTTP = require("HTTP")
local lanes = require "lanes".configure()
local router = require "router"

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

local function cannedResponses(request)
	if not request then
		resp = HTTP.newResponse(400)
		resp.body = "<html><body><h2>"..resp.code_text.."</h2></body></html>"
		resp.headers["Content-Type"] = "text/html; charset=UTF-8"
		resp.headers["Connection"] = "close"
		clien:send(resp:tostring())
	end
	
	if not request.headers.Host then 
		resp = HTTP.newResponse(400)
		resp.body = "<html><body><h2>Error: request must include 'Host' header.</h2></body></html>"
		resp.headers["Content-Type"] = "text/html; charset=UTF-8"
		resp.headers["Connection"] = "close"
		client:send(resp:tostring())
	end
	
	if request.http_version ~= "1.1" then
		resp = HTTP.newResponse(505)
		resp.body = "<html><body><h2>"..resp.code_text.."</h2></body></html>"
		resp.headers["Content-Type"] = "text/html; charset=UTF-8"
		resp.headers["Connection"] = "close"
		client:send(resp:tostring())
	end
end

local linda = lanes.linda()
lanes.gen(router.start)(linda)

local function requestReader(clients)
	partialRequests = {}
	timeouts = {}
	while 1 do
		for index,client in pairs(clients) do
			if not partialRequests[index] then partialRequests[index] = {} end
			if not timeouts[index] then timeouts[index] = 0 end
			requestTable = partialRequests[index]	

			local line, err, partial = client:receive()
			if not err then 
				requestTable[#requestTable+1] = line
				requestTable[#requestTable+1] = "\n"
				if line == "" then
					request = table.concat(requestTable)
					request = HTTP.parseRequest(request)
			
					cannedResponse = cannedResponses(request)
					if cannedResponse then
						client:send(cannedResponse:tostring())
					end
			
			
					--Should be replaced
					if request.uri.path[1] == "" then 
						resp = HTTP.newResponse(200)
						resp.body = "<html><body><h2>Hello World!</h2></body></html>"
						resp.headers["Content-Type"] = "text/html; charset=UTF-8"
						resp.headers["Connection"] = "close"
						client:send(resp:tostring()) 

					else 
						resp = HTTP.newResponse(404)
						resp.headers["Connection"] = "close"
						resp.body = "<html><body><h2>Resource not found!</h2></body></html>"
						resp.headers["Content-Type"] = "text/html; charset=UTF-8"
						client:send(resp:tostring())
					end
				end
			else 
				if partial ~= "" then 
					requestTable[#requestTable+1] = partial 					
				end
				timeouts[index] = timeouts[index] + 1
				if timeouts[index] >= 1500 then client:close() clients[index] = nil end
			end
			
		end
		clients = coroutine.yield()
	end

end

local function main() 
	local server = assert(socket.bind("*", 8080))
	server:settimeout(0.001)
	local ip, port = server:getsockname()
	print("DogeNozzle/0.0.1 running on port " .. port)
	
	local nextClient = 1
	local clients = {}
	local requestReaderThread = coroutine.create(requestReader)
	-- loop forever waiting for clients
	while 1 do
		-- wait for a connection from any client
		local client, err = server:accept()
		if not err then
			client:settimeout(0.001)
			clients[nextClient] = client
			nextClient = nextClient + 1
		end
		result, err = coroutine.resume(requestReaderThread, clients) 
		if not result then
			print(err)
			break
		end
	end	
	
	for _,v in pairs(clients) do
		v:close()
	end
end

main()
