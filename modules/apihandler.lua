--[[
    PurpleTrain API Wrangler
    Anthony Brosnan, February 2023
]]--

--/Main Variables/--------------------------------------------------------------
local carriers = {
    amtrak = require('modules/amtrak'),
    mbta = require('modules/mbta'),
}


--/Functions/-------------------------------------------------------------------
local function convertTimeStamp(timeStamp)
    assert(tostring(timeStamp), 'Malformed or no timestamp string given')
    local dateTime = {}

    --format timestamp components into table
    dateTime.year, dateTime.month, dateTime.day, dateTime.hour, dateTime.min =
        timeStamp:match('^(%d+)%-(%d+)%-(%d+)%T(%d+):(%d+):') --regex magic
    
    for name, value in pairs(dateTime) do
        dateTime[name] = tonumber(value) --convert components to numbers
    end

    return dateTime --returns date table
end

local function epochToString(epoch, noNegative)
    epoch = math.ceil(epoch / 60) --convert to minutes
    if noNegative and epoch < 0 then return end --Train is due

    local epochAbs = math.abs(epoch) --Absolute for if statement brevity

    if epochAbs == 0 then --min(s), hour(s), day(s), if statement tedium
        return '', epoch
    elseif epochAbs == 1 then
        return '1 min', epoch
    elseif epochAbs < 60 then
        return tostring(epochAbs) .. ' mins', epoch
    elseif epochAbs == 60 then
        return '1 hour', epoch
    elseif epochAbs > 60 and epochAbs < 1440 then
        local hour = math.floor(epoch / 60)
        local min = epochAbs - (hour * 60)
        if hour == 1 then
            return tostring(hour) .. 'h ' .. tostring(min) .. 'm', epoch
        elseif hour ~= 1 and min == 0 then
            return tostring(hour) .. ' hours', epoch
        elseif hour ~= 1 then
            return tostring(hour) .. 'h ' .. tostring(min) .. 'm', epoch
        end
    elseif epochAbs > 1440 then
        local days = math.floor((epochAbs / 1440))
        if days == 1 then
            return 'Over 1 day', epoch
        else
            return 'Over ' .. tostring(days) .. ' days', epoch
        end
    end
end

local function dateTimeTo12Hour(dateTime)
    local epoch = os.time(dateTime) 

    return {hour = tonumber(os.date('%I', epoch)), min = dateTime.min, ampm = os.date('%p', epoch)}
end

local function normalizeTrip(trip)
    --convert string timestamp to datetime
    trip.scheduledTime = convertTimeStamp(trip.scheduledTime)
    trip.arrivalTime = convertTimeStamp(trip.arrivalTime)

    --convert datetimes to unix time
    trip.scheduledTime = os.time(trip.scheduledTime)
    trip.arrivalTime = os.time(trip.arrivalTime)

    if trip.predictedTime then --if prediction assign anticipated time
        trip.predictedTime = os.time(convertTimeStamp(trip.predictedTime))
    else --if no prediction set scheduled time as prediction (field is never nil)
        trip.predictedTime = trip.scheduledTime
    end

    trip.prediction = trip.predictedTime - trip.scheduledTime --number of seconds late
    trip.duration = trip.arrivalTime - trip.scheduledTime --length of trip
    trip.arrivalTime = trip.predictedTime + trip.duration
    trip.wait = trip.predictedTime - os.time()

    --if trip is over 1/2 hour away dont show predictions <= 5 min
    if trip.wait >= 1800 and trip.prediction <= 300 then
        trip.prediction = 0
        
        trip.predictedTime = trip.scheduledTime
    elseif not trip.prediction then --just in case
        trip.prediction = 0
    end

    trip.scheduledTime = nil --remove if present
    trip.stopSequence = nil

    return trip
end

local function finalizeTrip(trip) --make everything human readable
    trip.scheduledTime = dateTimeTo12Hour(os.date('*t', trip.scheduledTime))

    trip.predictedTime = dateTimeTo12Hour(os.date('*t', trip.predictedTime))
    trip.predictedTime.min = string.format("%02d", trip.predictedTime.min)

    trip.arrivalTime = dateTimeTo12Hour(os.date('*t', trip.arrivalTime))
    trip.arrivalTime.min = string.format("%02d", trip.arrivalTime.min)
    trip.duration = epochToString(trip.duration)

    trip.wait, epoch = epochToString(trip.wait)
    trip.prediction, predictionEpoch = epochToString(trip.prediction)

    if predictionEpoch > 0 then
        trip.prediction = trip.prediction .. ' late'
    elseif predictionEpoch < 0 then
        trip.prediction = trip.prediction .. ' early'
    end

    if trip.vehiclePassed then
        trip.wait = 'Departed'
    elseif epoch == 0 then
        trip.wait = 'Due'
    elseif epoch > 0 then
        trip.wait = trip.wait .. ' away'
    elseif vehiclePassed or epoch < 0  then 
        trip.wait = 'Departed'
    end

    trip.type = 'trip'
end

local function getCarrierTrips(from, to, date, carrier)
    local trips, stationNames = carrier:request(from, to, date)
    if trips then
        for trip = 1, #trips do --normalize trips
            trips[trip] = normalizeTrip(trips[trip])
        end

        return trips, stationNames
    end
end


--/Module/----------------------------------------------------------------------
local api = {}

function api.getStopNames(self)
    carriers.mbta:cache()
    return carriers.mbta.stopNames
end

function api.getTripInfo(self, carrier, id, to, from)
    local carrierModule = carriers[string.lower(tostring(carrier))]
    
    if carrierModule.getTripInfo then
        local tripInfo = carrierModule:getTripInfo(carrier, id, to, from)

        if not tripInfo then return {error = 'No data for this trip yet'} end

        for _, stop in pairs(tripInfo.path) do
            stop.time = dateTimeTo12Hour(convertTimeStamp(stop.time))
            stop.time.min = string.format("%02d", stop.time.min)
        end

        return tripInfo
    else
        return {error = 'No data for ' .. carrier .. ' :('}
    end
end

function api.getTrainTimes(self, from, to, date, includeDeparted)
    if #date ~= 10 then
        return {type = 'title', text = 'Invalid date'}
    end
    
    local carrierTrips = {} --contains tables of each carrier's trips
    local stationNames
    for index, carrier in pairs(carriers) do --get trips for each carrier
        carrierTrips[carrier.name], stations = getCarrierTrips(from, to, date, carrier)
        if carrier.name == 'MBTA' then stationNames = stations end
    end

    local mergedTrips = {}
    for _, carrier in pairs(carrierTrips) do
        for _, trip in pairs(carrier) do
            table.insert(mergedTrips, trip)
        end
    end

    table.sort( --sort trips by time
        mergedTrips,
        function(trip1, trip2)
            if trip2.predictedTime > trip1.predictedTime then return true end
        end
    )
    
    local today = os.date("%Y-%m-%d")
    local finalTrips = {}
    if today == date and not includeDeparted then
        for index, trip in pairs(mergedTrips) do
            if os.time() <= trip.predictedTime + 60 then --add 60 to display on predicted min
                table.insert(finalTrips, mergedTrips[index])
            end
        end
    else
        finalTrips = mergedTrips
    end

    --Make trip human readable
    for index = 1, #finalTrips do
        finalizeTrip(finalTrips[index])
    end
    
    local addFiller = true
    --Insert titles
    if #mergedTrips == 0 then
        finalTrips[1] = {type = 'info', title = 'INFO', text = 'No direct service between stops.'}
        addFiller = false
    elseif #finalTrips == 0 then
        finalTrips[1] = {type = 'info', title = 'INFO', text = 'No more trains scheduled today :('}
        addFiller = false
    elseif today == date then --if today
        if not includeDeparted then
            if #finalTrips >= 1 then
                table.insert(finalTrips, 1, {type = 'title', text = 'Next train'})
            end
            if #finalTrips > 2 then
                table.insert(finalTrips, 3, {type = 'title', text = 'Upcoming'})
            end
        else
            table.insert(finalTrips, 1, {type = 'title', text = 'Today'})
        end
    else
        local time =
            os.time({year = date:sub(1, 4), month = date:sub(6, 7), day = date:sub(9, 10)})
        local todaysDate = os.date('*t')
        todaysDate = os.time({year = todaysDate.year, month = todaysDate.month, day = todaysDate.day})

        if time - 86400 == todaysDate then
            table.insert(finalTrips, 1, {type = 'title', text = 'Tomorrow'})
        elseif time + 86400 == todaysDate then
            table.insert(finalTrips, 1, {type = 'title', text = 'Yesterday'})
        else
            table.insert(finalTrips, 1, {type = 'title', text =
                os.date('%A, %b. ', time) .. tostring(tonumber(os.date('%d', time)))})
        end
    end

    if stationNames then
        table.insert(finalTrips, {type = 'stations', names = stationNames})
    end

    if addFiller then
        table.insert(finalTrips, {type = 'filler'})
    end

    return finalTrips
end


--/Return Module/---------------------------------------------------------------
return api