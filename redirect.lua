--[[
    PurpleTrain HTTP Redirect Server
    Anthony Brosnan, April 2023
]]--

--/Main Variables/--------------------------------------------------------------
local httpServer = require('http.server')
local httpHeaders = require('http.headers')


--/Functions/-----------------------------------------------------------------
local function onStream(server, stream)
    print('REDIRECT')
    
    local headers = stream:get_headers()
    if not headers then return end

    local method = tostring(headers:get(':method'))
    if not method == 'GET'then return end

    local newHeaders = httpHeaders.new()
    newHeaders:append(":status", "301")
    newHeaders:append("Location", 'https://purpletrain.net/')
    stream:write_headers(newHeaders, true, 10)
end


--/Server Loop/-----------------------------------------------------------------
local interface = 'enp2s0' --get local IP from this interface
local ipWithSubnet = io.popen("ip -4 -o address show dev " .. interface .. " | awk '{print $4}'")
local ip = string.match(ipWithSubnet:read("*a"), '(.-)/')
ipWithSubnet:close()

local server = assert(httpServer.listen({
    host = ip,
    port = 80,
    tls = false,
    intra_stream_timeout = 5,
    onstream = onStream
}))

assert(server:listen())

while 1 do
    local _, err = pcall(server:loop()) --pcall if production
    if err then
        print(err)
    end
end