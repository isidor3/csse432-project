-- load namespace
local lanes = require("lanes").configure()
local socket = lanes.require("socket")
local HTTP = lanes.require("HTTP")
local requestReader = lanes.require("requestReader")
local router =lanes.require("router")

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




local linda = lanes.linda()

function main() 
	routerInstance = lanes.gen("*",router)(linda)
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
		
		-- Get some bytes from each client, and send any completed requests to the router
		result, err = coroutine.resume(requestReaderThread, clients, linda) 
		if not result then
			print(err)
			break
		end
		
		if routerInstance.status == "error" then
			print(routerInstance[1])
			break
		end
	end	
	
	for _,v in pairs(clients) do
		v:close()
	end
end

main()
