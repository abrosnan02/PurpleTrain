--[[
    MBTA API Connector
    Anthony Brosnan, Febrary 2023
]]--

--/Main Variables/--------------------------------------------------------------
local httpRequest = require("http.request")
local json = require('dkjson')
local cache = require('modules/cache')
local key = 'fa403d1654634a9685735503c3ff5d49' --API key, inserted every request
local fares = {
    zone = { --use these fares if going to or from zone 1A
        ['CR-zone-1A'] = '2.40',
        ['CR-zone-1'] = '6.50',
        ['CR-zone-2'] = '7.00',
        ['CR-zone-3'] = '8.00',
        ['CR-zone-4'] = '8.75',
        ['CR-zone-5'] = '9.75',
        ['CR-zone-6'] = '10.50',
        ['CR-zone-7'] = '11.00',
        ['CR-zone-8'] = '12.25',
        ['CR-zone-9'] = '12.75',
        ['CR-zone-10'] = '13.25',
    },

    interzone = { --use these if going anywhere else
        [1] = '2.75',
        [2] = '3.25',
        [3] = '3.50',
        [4] = '4.25',
        [5] = '4.75',
        [6] = '5.25',
        [7] = '5.75',
        [8] = '6.25',
        [9] = '6.75',
        [10] = '7.25',
    },

}


--/Functions/-------------------------------------------------------------------
local function request(path, query, cacheTime)
    local uri = { --build URI table
        scheme = 'https',
        host = 'api-v3.mbta.com',
        path = '/' .. path,
        query = 'api_key=' .. key .. '&' .. query,
        authority = 'api-v3.mbta.com'
    }
    --print(uri.host .. uri.path .. '?' .. uri.query)

    local uriString = 'https://api-v3.mbta.com/' 
        .. path
        .. '?api_key=' .. key
        .. '&' .. query --for some reason http doesn't like the string
    
    local body = cache:get(uriString)
    if not body then
        local request = httpRequest.new_from_uri(uri)
        request.headers:upsert(":method", "GET")

        local headers, stream = request:go(10)
        body = stream:get_body_as_string(10)
    end
    
    if body then --returns decoded body or nil
        cache:set(uriString, body, cacheTime or cache.cacheTime)
        local data = json.decode(body).data

        return data
    end
end


--/Module/----------------------------------------------------------------------
local mbta = {
    name = 'MBTA',
    routes = {}, --All CR stops
    stops = {}, --All CR route names
    stopNames = {}, --Array of stop names and/or cities for autocomplete]]

    cacheExpires = 0
}


function mbta.cache(self)
    if self.cacheExpires > os.time() then return end --dont cache if not expired

    print('Getting CR stops...')
    self.stops = request('stops', 'sort=name&filter[route_type]=2')
    print('Getting CR routes...')
    self.routes = request('routes', 'filter[type]=2')

    self.stopNames = {} --Clear all stop names

    for _, stop in pairs(self.stops) do --insert name strings for autocomplete
        local name = stop.attributes.name
        local municipality = stop.attributes.municipality
        if name ~= municipality then --include city name if not same as station name
            table.insert(self.stopNames, {name = name, municipality = municipality})
        else
            table.insert(self.stopNames, {name = name})
        end
    end

    self.cacheExpires = os.time() + 3600
end

function mbta.nameToId(self, name)
    name = name:lower() --lower for matching

    for _, stop in pairs(self.stops) do --Iterate through ids/names and check for match
        if stop.attributes.name:lower() == name then 
            return stop.id, stop.attributes.name --return ID and normalized name
        end
    end
end

function mbta.idToName(self, id)
    id = id:lower() --lower for matching

    for _, stop in pairs(self.stops) do --Iterate through ids/names and check for match
        if stop.id:lower() == id then 
            return stop.attributes.name 
        end
    end
end

function mbta.getDirectionAndRouteNames(self, routeId, direction)
    direction = direction + 1

    for _, route in pairs(self.routes) do
        if route.id == routeId then
            return route.attributes.direction_names[direction],
                route.attributes.long_name
        end
    end
end

function mbta.getFare(self, toId, fromId)
    local zones = {}
    for _, stop in pairs(self.stops) do
        if stop.id == toId then
            zones.to = stop.relationships.zone.data.id
        elseif stop.id == fromId then
            zones.from = stop.relationships.zone.data.id
        end
    end
    
    local notInterzone = false
    for index, zone in pairs(zones) do
        if not tonumber(zone:sub(-1)) then --zone 1A
            notInterzone = index
        end
    end

    if not notInterzone then
        return fares.interzone[math.abs(tonumber(zones.to:sub(-1)) - tonumber(zones.from:sub(-1))) + 1]
    else
        if notInterzone == 'from' then
            return fares.zone[zones.to]
        elseif notInterzone == 'to' then
            return fares.zone[zones.from]
        end
    end
end

function mbta.getTripInfo(self, carrier, id, to, from)
    print(to, from)
    local tripSchedules = request('schedules', --get full path for train selected
        'sort=time&filter[trip]=' .. tostring(id))

    local tripInfo = {
        path = {} --contains tables containing stop ID and time
    }

    to = self:nameToId(to)
    from = self:nameToId(from)

    local tripStarted = false
    for stop, schedule in pairs(tripSchedules) do
        local id = schedule.relationships.stop.data.id

        if not tripStarted then
            print(id, from)
            if id == from then
                tripStarted = true
            end
        end

        --headsign may not be on all stops, find first stop w/ headsign and assign
        local headsign = schedule.attributes.stop_headsign
        if not tripInfo.headsign and headsign then tripInfo.headsign = headsign end

        if tripStarted then
            local pathStop = {
                name = self:idToName(id)
            }

            local departureTime = schedule.attributes.departure_time

            if not departureTime then --time of the stop
                pathStop.time = schedule.attributes.arrival_time
            else
                pathStop.time = departureTime
            end


            table.insert(tripInfo.path, pathStop)
            if id == to then
                tripStarted = false

                if not tripInfo.headsign then tripInfo.headsign = 'No headsign' end

                return tripInfo
            end
        end
    end
end

function mbta.request(self, from, to, date)
    self:cache() --recache if needed

    local from, fromName = self:nameToId(from)
    local to, toName = self:nameToId(to)

    if (from and to) then
        local possibleSchedules = request('schedules', --get all schedules for both stations
        'sort=time' ..
        '&filter[date]=' .. date ..
        '&filter[stop]=' .. from .. ',' .. to) or {} --or {} in case of no schedules

        local trips = {}
        local possibleTripSchedules = {}
        local predictionTripIds = '' --appended as prediction query

        for _, schedule in pairs(possibleSchedules) do
            local id = schedule.relationships.trip.data.id
            
            --2. if corresponding schedule is found make trip table
            local correspondingSchedule = possibleTripSchedules[id]
            if correspondingSchedule then
                if schedule.relationships.stop.data.id == to and schedule.attributes.stop_sequence > correspondingSchedule.attributes.stop_sequence then
                    predictionTripIds =  predictionTripIds .. id .. ','

                    local direction, route =
                        self:getDirectionAndRouteNames(correspondingSchedule.relationships.route.data.id,
                        correspondingSchedule.attributes.direction_id)

                    local trip = { --assign information
                        carrier = self.name,
                        id = id,
                        route = route,
                        number = tonumber(string.match(id, '%w+$')),
                        direction = direction,
                        fare = '$' .. 
                            tostring(self:getFare(schedule.relationships.stop.data.id,
                            correspondingSchedule.relationships.stop.data.id)),

                        from = fromName,
                        to = toName, --from station stop sequence
                        stopSequence = correspondingSchedule.attributes.stop_sequence,

                        scheduledTime = correspondingSchedule.attributes.departure_time,
                        arrivalTime = schedule.attributes.arrival_time,
                    }

                    table.insert(trips, trip)
                end
            else --1. insert a possible trip schedule
                possibleTripSchedules[id] = schedule 
            end
        end
        

        if os.date("%Y-%m-%d") == date then --if today get predictions
            local predictions = request(
                'predictions',
                'sort=time&filter[trip]=' .. predictionTripIds,
                cache.predictionCacheTime
            )
        end

        if predictions then --if prediction response
            for index = 1, #trips do --go through all trips
                for _, prediction in pairs(predictions) do
                    if trips[index].id == prediction.relationships.trip.data.id then
                        if prediction.relationships.stop.data.id == trips[index].from then
                            --if prediction then set predictedTime
                            predictedTime = prediction.attributes.departure_time
                            break
                        end
                        if prediction.attributes.stop_sequence > trips[index].stopSequence then
                            --if train is early, mark as passed so schedule is not shown
                            trips[index].vehiclePassed = true
                            break
                        end
                    end
                end
            end
        end

        return trips, {from = fromName, to = toName}
    end
end


--/Return Module/---------------------------------------------------------------
return mbta