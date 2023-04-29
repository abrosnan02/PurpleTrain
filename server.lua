--[[
    PurpleTrain HTTP Server
    Anthony Brosnan, January 2023 - April 2023
]]--

--/Main Variables/--------------------------------------------------------------
local httpServer = require('http.server')
local httpHeaders = require('http.headers')
local tls = require('http.tls')
local netUrl = require('net.url')
local opensslContext = require('openssl.ssl.context')
local x509 = require('openssl.x509')
local chain = require('openssl.x509.chain')
local pkey = require('openssl.pkey')
local json = require('dkjson')
local api = require('modules/apihandler')


--/UI/--------------------------------------------------------------------------
local serverPath = 'main'
local port = 443 --if staging change port
if arg[1] == '-s' then
    port = 3000
    serverPath = 'staging'
end


--/Main Functions/--------------------------------------------------------------
local function sendFile(stream, fileName, contentType, method)
    local headers = httpHeaders.new()
    local file = io.open(fileName, 'rb')

    if file then
        headers:append(":status", "200")
        headers:append("content-type", contentType)
        headers:append('access-control-allow-origin', '*')
        headers:append("cache-control", "no-cache")
        --headers:append('content-security-policy', "default-src 'self'; script-src https://purpletrain.net")

        stream:write_headers(headers, false)
        stream:write_body_from_file({
            file = file
        })
        file:close()
    end
end

local function send(stream, data, contentType, method)
    local headers = httpHeaders.new()
    headers:append(":status", "200")
    headers:append("content-type", contentType)
    headers:append('access-control-allow-origin', '*')

    stream:write_headers(headers, false)
    stream:write_body_from_string(data)
end


local allowedPaths = {
    --Main
    ['/'] = {path = 'index.html', mime = 'text/html', stat = function() end},
    ['/style.css'] = {path = 'style.css', mime = 'text/css'},
    ['/client.js'] = {path = 'client.js', mime = 'text/javascript'},
    ['/fonts/Inter.var.woff2'] = {path = 'fonts/Inter.var.woff2', mime = 'font/woff'},
    ['/robots.txt'] = {path = 'robots.txt', mime = 'text/plain'},

    --Images
    ['/favicon.ico'] = {path = 'images/favicon.ico', mime = 'image/x-icon'},
    ['/images/swap.svg'] = {path = 'images/swap.svg', mime = 'image/svg+xml'},
    ['/images/calendar.svg'] = {path = 'images/calendar.svg', mime = 'image/svg+xml'},
    ['/images/alert.svg'] = {path = 'images/alert.svg', mime = 'image/svg+xml'},
    ['/images/info.svg'] = {path = 'images/info.svg', mime = 'image/svg+xml'},
}

local function onStream(server, stream)
    local headers = stream:get_headers()
    
    if headers then
        local path = tostring(headers:get(':path'))
        local method = tostring(headers:get(':method'))
        local url = netUrl.parse('https://purpletrain.net' .. path)
        
        local _, ip = stream:peername()
        if method == 'GET' then            
            for allowedPath, data in pairs(allowedPaths) do
                if url.path == allowedPath then
                    if data.stat then data.stat() end
                    sendFile(stream, data.path, data.mime, method)
                    break
                end
            end

            if url.path == '/stops' then
                send(stream, json.encode(api:getStopNames()), 'application/json', method)
            end
        end

        if method == 'POST' then
            local body = json.decode(stream:get_body_as_string())

            if not body then return end

            if url.path == '/getTrainTime' then
                send(stream, json.encode(api:getTrainTimes(body.from, body.to, body.date, body.includeDeparted)), 'application/json', method)
            elseif url.path == '/getTripInfo' then
                local tripInfo = json.encode(api:getTripInfo(body.carrier, body.id, body.to, body.from))

                if tripInfo and tripInfo ~= 'null' then
                    send(stream, tripInfo, 'application/json', method)
                end
            end
        end
    end
end


--/HTTPS Certificates/----------------------------------------------------------
local caCert = chain.new()
caCert:add(x509.new(io.open('/etc/letsencrypt/live/purpletrain.net/chain.pem'):read('*a'), 'PEM'))

local context = tls:new_server_context()
context:setCertificate(x509.new(io.open('/etc/letsencrypt/live/purpletrain.net/cert.pem'):read('*a'), 'PEM'))
local privateKey = assert(io.open('/etc/letsencrypt/live/purpletrain.net/privkey.pem'), 'Run as sudo')
context:setPrivateKey(pkey.new(privateKey:read('*a')), 'PEM')
context:setCertificateChain(caCert)
context:setVerify(opensslContext.VERIFY_NONE) --do this to prevent crashing


--/Server Loop/-----------------------------------------------------------------
local interface = 'enp2s0' --get local IP from this interface
local ipWithSubnet = io.popen("ip -4 -o address show dev " .. interface .. " | awk '{print $4}'")
local ip = string.match(ipWithSubnet:read("*a"), '(.-)/')
ipWithSubnet:close()

local server = assert(httpServer.listen({
    host = ip,
    port = port,
    tls = true,
    ctx = context,
    onstream = onStream
}))

api:getStopNames()

assert(server:listen())

while 1 do
    local _, err
    if serverPath == 'main' then
        _, err = pcall(server:loop()) --pcall if production
    else
        _, err = assert(server:loop()) --assert for staging errors
    end
end
