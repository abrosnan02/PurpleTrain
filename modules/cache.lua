--[[
    API Connector Caching Module
    Anthony Brosnan, Febrary 2023
]]--

--/External Variables/----------------------------------------------------------
local httpRequest = require("http.request")
local json = require('dkjson')


--/Module/----------------------------------------------------------------------
local cache = {
    items = {},
    cacheTime = 3600, --default cache time (1 hour)
    predictionCacheTime = 15,
    cacheExpires = 0, --will re-cache stops/routes after this time
}

function cache.clean(self)
    local time = os.time()
    if time > self.cacheExpires then
        for name, item in pairs(self.items) do
            if time > self.items[name].expires then
                self.items[name] = nil
            end
        end

        self.cacheExpires = time + self.cacheTime
    end
end

function cache.set(self, uri, body, expires)
    self.items[uri] = {body = body, expires = os.time() + (expires or self.cacheTime)}
end

function cache.get(self, uri)
    self:clean()

    local time = os.time()
    local item = cache.items[uri]

    if item then
        if item.expires > time then 
            return self.items[uri].body --return cached if not expired
        else 
            self.items[uri] = nil --delete if past expire time
        end
    end
end

--/Return Module/---------------------------------------------------------------
return cache