--[[
    Amtrak API Connector
    Anthony Brosnan, Febrary 2023
]]--

--/Main Variables/--------------------------------------------------------------
local httpRequest = require("http.request")
local json = require('dkjson')
local cache = require('modules/cache')


--/Module/----------------------------------------------------------------------
local amtrak = {
    name = 'Amtrak',
    stops = { --MBTA string names to Amtrak codes
        ['South Station'] = 'BOS',
        ['Back Bay'] = 'BBY',
        ['Route 128'] = 'RTE',
        ['Providence'] = 'PVD',
    }
}

function amtrak.getAmtrakCode(self, station)
    for name, stop in pairs(self.stops) do
        if name:lower() == station:lower() then
            return stop
        end
    end
end

function amtrak.request(self, from, to, date)
    from = self:getAmtrakCode(from)
    to = self:getAmtrakCode(to)

    if (from and to) then --if stops correspond to amtrak codes
        local uri = 'https://rider.amtrak.com/v2/travel-service/statuses/stations'
        .. '?origin-code=' .. from --3 letter Amtrak code
        .. '&destination-code=' .. to --3 letter Amtrak code
        .. '&departure-date=' .. date --date as 'YYYY--MM--DD'

        local body = cache:get(uri) --get cached if possible

        if not body then --no cached, get response
            --May error if appType is not present
            --This will respond with JSON regardless of the accept header
            local request = httpRequest.new_from_uri(uri)
            request.headers:upsert(":method", "GET")
            request.headers:upsert("Accept", "application/json") 
            request.headers:upsert("appType", "IOS") --Pretend we're an iPhone
            request.tls = true --force encryption

            local headers, stream = request:go(10)
            body = stream:get_body_as_string(10)
        end

        local data
        if body then
            cache:set(uri, body, cache.predictionCacheTime) --cache response
            data = json.decode(body).data
        end

        if data then
            local trips = {}

            for _, schedule in pairs(data) do
                if #schedule.travelLegs == 1 then --just in case
                    local trip = { --assign information
                        carrier = self.name,
                        id = schedule.travelLegs[1].travelService.id,
                        route = self.name .. ' ' .. schedule.travelLegs[1].travelService.name.description,
                        number = schedule.travelLegs[1].travelService.number,
                        direction = schedule.travelLegs[1].travelService.destination.name,
                        fare = 'No price data',

                        from = schedule.travelLegs[1].origin.station.code,
                        to = schedule.travelLegs[1].destination.station.code,

                        scheduledTime = schedule.travelLegs[1].origin.departure.schedule.dateTime,
                        arrivalTime = schedule.travelLegs[1].destination.arrival.schedule.dateTime,
                    }

                    --if train hasn't left add prediction
                    if schedule.travelLegs[1].origin.departure.statusInfo.displayStatus ~= 'Departed' then
                        trip.predictedTime = schedule.travelLegs[1].origin.departure.statusInfo.dateTime
                    end
                    
                    table.insert(trips, trip)
                end
            end

            return trips
        end
    end
end


--/Return Module/---------------------------------------------------------------
return amtrak