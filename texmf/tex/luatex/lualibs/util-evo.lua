if not modules then modules = { } end modules ['util-evo'] = {
    version   = 1.002,
    comment   = "library for fetching data from an evohome device",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE",
    license   = "see context related readme files"
}

-- When I needed a new boiler for heating I decided to replace a partial
-- (experimental) zwave few-zone solution by the honeywell evohome system that can
-- drive opentherm. I admit that I was not that satified beforehand with the fact
-- that one has to go via some outside portal to communicate with the box but lets
-- hope that this will change (I will experiment with the additional usb interface
-- later). Anyway, apart from integrating it into my home automation setup so that I
-- can add control based on someone present in a zone, I wanted to be able to render
-- statistics. So that's why we have a module in ConTeXt for doing that. It's also
-- an example of Lua and abusing LuaTeX for something not related to typesetting.
--
-- As with other scripts, it assumes that mtxrun is used so that we have the usual
-- Lua libraries present.
--
-- The code is not that complex but figuring out the right request takes bit of
-- searching the web. There is an api specification at:
--
--   https://developer.honeywell.com/api-methods?field_smart_method_tags_tid=All
--
-- Details like the application id can be found in several places. There are snippets
-- of (often partial or old) code on the web but still one needs to experiment and
-- combine information. We assume unique zone names and ids across gateways; I only
-- have one installed anyway.
--
-- The original application was to just get the right information for generating
-- statistics but in the meantime I also use this code to add additional functionality
-- to the system, for instance switching between rooms (office, living room, attic) and
-- absence for one or more rooms.

-- todo: %path% in filenames

require("util-jsn")

local next, type, setmetatable, rawset, rawget = next, type, setmetatable, rawset, rawget
local json = utilities.json
local formatters = string.formatters
local floor, div = math.floor, math.div
local resultof, ostime, osdate, ossleep = os.resultof, os.time, os.date, os.sleep
local jsontolua, jsontostring = json.tolua, json.tostring
local savetable, loadtable, sortedkeys = table.save, table.load, table.sortedkeys
local setmetatableindex, setmetatablenewindex = table.setmetatableindex, table.setmetatablenewindex
local replacer = utilities.templates.replacer
local lower = string.lower -- no utf support yet (encoding needs checking in evohome)

local applicationid = "b013aa26-9724-4dbd-8897-048b9aada249"
----- applicationid = "91db1612-73fd-4500-91b2-e63b069b185c"

local report = logs.reporter("evohome")
local trace  = false

trackers.register("evohome.trace",function(v) trace = v end) -- not yet used

local defaultpresets = {
    interval    = 30 * 60,
    files       = {
        everything  = "evohome-everything.lua",
        history     = "evohome-history.lua",
        latest      = "evohome-latest.lua",
        schedules   = "evohome-schedules.lua",
        actions     = "evohome-actions.lua",
        template    = "evohome.lmx",
    },
    credentials = {
      -- username    = "unset",
      -- password    = "unset",
      -- accesstoken = "unset",
      -- userid      = "unset",
    },
}

local validzonetypes = {
    ZoneTemperatureControl = true,
    RadiatorZone           = true,
    ZoneValves             = true,
}

local function validfile(presets,filename)
    if lfs.isfile(filename) then
        -- we're okay
        return filename
    end
    if file.pathpart(filename) ~= "" then
        -- can be a file that has to be created
        return filename
    end
    local presetsname = presets.filename
    if not presetsname then
        -- hope for the best
        return filename
    end
    -- we now have the full path
    return file.join(file.pathpart(presetsname),filename)
end

local function validpresets(presets)
    if type(presets) ~= "table" then
        report("invalid presets, no table")
        return
    end
    local credentials = presets.credentials
    if not credentials then
        report("invalid presets, no credentials")
        return
    end
    local gateways = presets.gateways
    if not gateways then
        report("invalid presets, no gateways")
        return
    end
    local files = presets.files
    if not files then
        report("invalid presets, no files")
        return
    end
    for k, v in next, files do
        files[k] = validfile(presets,v) or v
    end
    local data = presets.data
    if not data then
        data = { }
        presets.data = data
    end
    local g = data.gateways
    if not g then
        local g = { }
        data.gateways = g
        for i=1,#gateways do
            local gi = gateways[i]
            g[gi.macaddress] = gi
        end
    end
    local zones = data.zones
    if not zones then
        zones = { }
        data.zones = zones
        setmetatablenewindex(zones,function(t,k,v)        rawset(t,lower(k),v) end)
        setmetatableindex   (zones,function(t,k)   return rawget(t,lower(k))   end)
    end
    local states = data.states
    if not states then
        states = { }
        data.states = states
        setmetatablenewindex(states,function(t,k,v)        rawset(t,lower(k),v) end)
        setmetatableindex   (states,function(t,k)   return rawget(t,lower(k))   end)
    end
    setmetatableindex(presets,defaultpresets)
    setmetatableindex(credentials,defaultpresets.credentials)
    setmetatableindex(files,defaultpresets.files)
    return presets
end

local function loadedtable(filename)
    if type(filename) == "string" then
        for i=1,10 do
            local t = loadtable(filename)
            if t then
                report("file %a loaded",filename)
                return t
            else
                ossleep(1/4)
            end
        end
    end
    report("file %a not loaded",filename)
    return { }
end

local function savedtable(filename,data)
    savetable(filename,data)
    report("file %a saved",filename)
end

local function loadpresets(filename)
    local presets = loadtable(filename)
    if presets then
        presets.filename = filename
        presets.filepath = file.expandname(file.pathpart(filename))
     -- package.extraluapath(presets.filepath) -- better do that elsewhere and once
    end
    return presets
end

local function loadhistory(filename)
    if type(filename) == "table" and validpresets(filename) then
        filename = filename.files and filename.files.history
    end
    return loadedtable(filename)
end

local function loadeverything(filename)
    if type(filename) == "table" and validpresets(filename) then
        filename = filename.files and filename.files.everything
    end
    return loadedtable(filename)
end

local function loadlatest(filename)
    if type(filename) == "table" and validpresets(filename) then
        filename = filename.files and filename.files.latest
    end
    return loadedtable(filename)
end

local function result(t,fmt,a,b,c)
    if t then
        report(fmt,a or "done",b or "done",c or "done","done")
        return t
    else
        report(fmt,a or "failed",b or "failed",c or "failed","failed")
    end
end

local f = replacer (
    [[curl ]] ..
    [[--silent --insecure ]] ..
    [[-X POST ]] ..
    [[-H "Authorization: Basic YjAxM2FhMjYtOTcyNC00ZGJkLTg4OTctMDQ4YjlhYWRhMjQ5OnRlc3Q=" ]] ..
    [[-H "Accept: application/json, application/xml, text/json, text/x-json, text/javascript, text/xml" ]] ..
    [[-d "Content-Type=application/x-www-form-urlencoded; charset=utf-8" ]] ..
    [[-d "Host=rs.alarmnet.com/" ]] ..
    [[-d "Cache-Control=no-store no-cache" ]] ..
    [[-d "Pragma=no-cache" ]] ..
    [[-d "grant_type=password" ]] ..
    [[-d "scope=EMEA-V1-Basic EMEA-V1-Anonymous EMEA-V1-Get-Current-User-Account" ]] ..
    [[-d "Username=%username%" ]] ..
    [[-d "Password=%password%" ]] ..
    [[-d "Connection=Keep-Alive" ]] ..
    [["https://tccna.honeywell.com/Auth/OAuth/Token"]]
)

local function getaccesstoken(presets)
    if validpresets(presets) then
        local c = presets.credentials
        local s = c and f {
            username      = c.username,
            password      = c.password,
            applicationid = applicationid,
        }
        local r = s and resultof(s)
        local t = r and jsontolua(r)
        return result(t,"getting access token %a")
    end
    return result(false,"getting access token %a")
end

local f = replacer (
    [[curl ]] ..
    [[--silent --insecure ]] ..
    [[-H "Authorization: bearer %accesstoken%" ]] ..
    [[-H "Accept: application/json, application/xml, text/json, text/x-json, text/javascript, text/xml" ]] ..
    [[-H "applicationId: %applicationid%" ]] ..
    [["https://tccna.honeywell.com/WebAPI/emea/api/v1/userAccount"]]
)

local function getuserinfo(presets)
    if validpresets(presets) then
        local c = presets.credentials
        local s = c and f {
            accesstoken   = c.accesstoken,
            applicationid = c.applicationid,
        }
        local r = s and resultof(s)
        local t = r and jsontolua(r)
        return result(t,"getting user info for %a")
    end
    return result(false,"getting user info for %a")
end

local f = replacer (
    [[curl ]] ..
    [[--silent --insecure ]] ..
    [[-H "Authorization: bearer %accesstoken%" ]] ..
    [[-H "Accept: application/json, application/xml, text/json, text/x-json, text/javascript, text/xml" ]] ..
    [[-H "applicationId: %applicationid%" ]] ..
    [["https://tccna.honeywell.com/WebAPI/emea/api/v1/location/installationInfo?userId=%userid%&includeTemperatureControlSystems=True"]]
)

local function getlocationinfo(presets)
    if validpresets(presets) then
        local c = presets.credentials
        local s = c and f {
            accesstoken   = c.accesstoken,
            applicationid = applicationid,
            userid        = c.userid,
        }
        local r = s and resultof(s)
        local t = r and jsontolua(r)
        return result(t,"getting location info for %a")
    end
    return result(false,"getting location info for %a")
end

local f = replacer (
    [[curl ]] ..
    [[--silent --insecure ]] ..
    [[-H "Authorization: bearer %accesstoken%" ]] ..
    [[-H "Accept: application/json, application/xml, text/json, text/x-json, text/javascript, text/xml" ]] ..
    [[-H "applicationId: %applicationid%" ]] ..
    [["https://tccna.honeywell.com/WebAPI/emea/api/v1/temperatureZone/%zoneid%/schedule"]]
)

local function getschedule(presets,zonename)
    if validpresets(presets) then
        local zoneid = presets.data.zones[zonename].zoneId
        if zoneid then
            local c = presets.credentials
            local s = c and f {
                accesstoken   = c.accesstoken,
                applicationid = applicationid,
                zoneid        = zoneid,
            }
            local r = s and resultof(s)
            local t = r and jsontolua(r)
            return result(t,"getting schedule for zone %a, %s",zonename or "?")
        end
    end
    return result(false,"getting schedule for zone %a, %s",zonename or "?")
end

local f = replacer (
    [[curl ]] ..
    [[--silent --insecure ]] ..
    [[-H "Authorization: bearer %accesstoken%" ]] ..
    [[-H "Accept: application/json, application/xml, text/json, text/x-json, text/javascript, text/xml" ]] ..
    [[-H "applicationId: %applicationid%" ]] ..
    [["https://tccna.honeywell.com/WebAPI/emea/api/v1/location/%locationid%/status?includeTemperatureControlSystems=True" ]]
)

local function getstatus(presets,locationid,locationname)
    if locationid and validpresets(presets) then
        local c = presets.credentials
        local s = c and f {
            accesstoken   = c.accesstoken,
            applicationid = applicationid,
            locationid    = locationid,
        }
        local r = s and resultof(s)
        local t = r and jsontolua(r)
        return result(t and t.gateways and t,"getting status for location %a, %s",locationname or "?")
    end
    return result(false,"getting status for location %a, %s",locationname or "?")
end

local function validated(presets)
    if validpresets(presets) then
        local data = getlocationinfo(presets)
        if data and type(data) == "table" and data[1] and data[1].locationInfo then
            return true
        else
            local data = getaccesstoken(presets)
            if data then
                presets.credentials.accesstoken = data.access_token
                local data = getuserinfo(presets)
                if data then
                    presets.credentials.userid = data.userId
                    return true
                end
            end
        end
    end
end

local function findzone(presets,name)
    if not presets then
        return
    end
    local data = presets.data
    if not data then
        return
    end
    local usedzones = data.zones
    return usedzones and usedzones[name]
end

local function gettargets(zone) -- maybe also for a day
    local schedule = zone.schedule
    local min      = false
    local max      = false
    if schedule then
        local schedules = schedule.dailySchedules
        if schedules then
            for i=1,#schedules do
                local switchpoints = schedules[i].switchpoints
                for i=1,#switchpoints do
                    local m = switchpoints[i].temperature
                    if not min or m < min then
                        min = m
                    end
                    if not max or m > max then
                        max = m
                    end
                end
            end
        else
            report("zone %a has no schedule",name)
        end
    end
    return min, max
end

local function updatezone(presets,name,zone)
    if not zone then
        zone = findzone(presets,name)
    end
    if zone then
        local oldtarget = presets.data.states[name]
        local min = zone.heatSetpointCapabilities.minHeatSetpoint or  5
        local max = zone.heatSetpointCapabilities.maxHeatSetpoint or 12
        local mintarget, maxtarget = gettargets(zone)
        -- todo: maybe get these from presets
        if mintarget == false then
            if min < 5 then
                mintarget = 5
             -- report("zone %a, min target limited to %a",name,mintarget)
            else
                mintarget = min
            end
        end
        if maxtarget == false then
            if max > 18.5 then
                maxtarget = 18.5
             -- report("zone %a, max target limited to %a",name,maxtarget)
            else
                maxtarget = max
            end
        end
        local current = zone.temperatureStatus.temperature or 0
        local target  = zone.heatSetpointStatus.targetTemperature
        local mode    = zone.heatSetpointStatus.setpointMode
        local state   = (mode == "FollowSchedule"                            and "schedule" ) or
                        (mode == "PermanentOverride" and target <= mintarget and "permanent") or
                        (mode == "TemporaryOverride" and target <= mintarget and "off"      ) or
                        (mode == "TemporaryOverride" and target >= maxtarget and "on"       ) or
                        (                                                        "unknown"  )
        local t = {
            name      = zone.name,
            id        = zone.zoneId,
            schedule  = zone.schedule,
            mode      = mode,
            current   = current,
            target    = target,
            min       = min,
            max       = max,
            state     = state,
            lowest    = mintarget,
            highest   = maxtarget,
        }
     -- report("zone %a, current %a, target %a",name,current,target)
        presets.data.states[name] = t
        return t
    end
end


local function geteverything(presets,noschedules)
    if validated(presets) then
        local data = getlocationinfo(presets)
        if data then
            local usedgateways = presets.data.gateways
            local usedzones    = presets.data.zones
            for i=1,#data do
                local gateways     = data[i].gateways
                local locationinfo = data[i].locationInfo
                local locationid   = locationinfo and locationinfo.locationId
                if gateways and locationid then
                    local status = getstatus(presets,locationid,locationinfo.name)
                    if status then
                        for i=1,#gateways do
                            local gatewaystatus  = status.gateways[i]
                            local gatewayinfo    = gateways[i]
                            local gatewaysystems = gatewayinfo.temperatureControlSystems
                            local info           = gatewayinfo.gatewayInfo
                            local statussystems  = gatewaystatus.temperatureControlSystems
                            if gatewaysystems and statussystems and info then
                                local mac = info.mac
                                if usedgateways[mac] then
                                    report("%s gateway with mac address %a","using",mac)
                                    for j=1,#gatewaysystems do
                                        local gatewayzones = gatewaysystems[j].zones
                                        local zonestatus   = statussystems[j].zones
                                        if gatewayzones and zonestatus then
                                            for k=1,#gatewayzones do
                                                local zonestatus  = zonestatus[k]
                                                local gatewayzone = gatewayzones[k]
                                                if zonestatus and gatewayzone then
                                                    local zonename = zonestatus.name
                                                    local zoneid   = zonestatus.zoneId
                                                    if validzonetypes[gatewayzone.zoneType] and zonename == gatewayzone.name then
                                                        gatewayzone.heatSetpointStatus = zonestatus.heatSetpointStatus
                                                        gatewayzone.temperatureStatus  = zonestatus.temperatureStatus
                                                        local zonestatus = usedzones[zonename] -- findzone(states,zonename)
                                                        local schedule   = zonestatus and zonestatus.schedule
                                                        usedzones[zonename] = gatewayzone
                                                        if schedule and noschedules then
                                                            gatewayzone.schedule = schedule
                                                        else
                                                            gatewayzone.schedule = getschedule(presets,zonename)
                                                        end
                                                        updatezone(presets,zonename,gatewayzone)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                else
                                    report("%s gateway with mac address %a","skipping",mac)
                                end
                            end
                        end
                    end
                end
            end
            savedtable(presets.files.everything,data)
            return result(data,"getting everything, %s")
        end
    end
    return result(false,"getting everything, %s")
end

local function gettemperatures(presets)
    if validated(presets) then
        local data = loadeverything(presets)
        if not data or not next(data) then
            data = geteverything(presets)
        end
        if data then
            local updated = false
            for i=1,#data do
                local gateways     = data[i].gateways
                local locationinfo = data[i].locationInfo
                local locationid   = locationinfo.locationId
                if gateways then
                    local status = getstatus(presets,locationid,locationinfo.name)
                    if status then
                        for i=1,#gateways do
                            local g = status.gateways[i]
                            local gateway = gateways[i]
                            local systems = gateway.temperatureControlSystems
                            if systems then
                                local s = g.temperatureControlSystems
                                for i=1,#systems do
                                    local zones = systems[i].zones
                                    if zones then
                                        local z = s[i].zones
                                        for i=1,#zones do
                                            local zone = zones[i]
                                            if validzonetypes[zone.zoneType] then
                                                local z = z[i]
                                                if z.name == zone.name then
                                                    zone.temperatureStatus = z.temperatureStatus
                                                    updated = true
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if updated then
                data.time = ostime()
                savedtable(presets.files.latest,data)
            end
            return result(data,"getting temperatures, %s")
        end
    end
    return result(false,"getting temperatures, %s")
end

local function setmoment(target,time,data)
    if not time then
        time = ostime()
    end
    local t = osdate("*t",time )
    local c_year, c_month, c_day, c_hour, c_minute = t.year, t.month, t.day, t.hour, t.min
    --
    local years   = target.years    if not years   then years   = { } target.years    = years   end
    local d_year  = years[c_year]   if not d_year  then d_year  = { } years[c_year]   = d_year  end
    local months  = d_year.months   if not months  then months  = { } d_year.months   = months  end
    local d_month = months[c_month] if not d_month then d_month = { } months[c_month] = d_month end
    local days    = d_month.days    if not days    then days    = { } d_month.days    = days    end
    local d_day   = days[c_day]     if not d_day   then d_day   = { } days[c_day]     = d_day   end
    local hours   = d_day.hours     if not hours   then hours   = { } d_day.hours     = hours   end
    local d_hour  = hours[c_hour]   if not d_hour  then d_hour  = { } hours[c_hour]   = d_hour  end
    --
    c_minute = div(c_minute,15) + 1
    --
    local d_last = d_hour[c_minute]
    if d_last then
        for k, v in next, data do
            local d = d_last[k]
            if d then
                data[k] = (d + v) / 2
            end
        end
    end
    d_hour[c_minute] = data
    --
    target.lasttime = {
        year   = c_year,
        month  = c_month,
        day    = c_day,
        hour   = c_hour,
        minute = c_minute,
    }
end

local function loadtemperatures(presets)
    if validpresets(presets) then
        local status = loadlatest(presets)
        if not status or not next(status) then
            status = loadeverything(presets)
        end
        if status then
            local usedgateways = presets.data.gateways
            for i=1,#status do
                local gateways = status[i].gateways
                if gateways then
                    for i=1,#gateways do
                        local gatewayinfo = gateways[i]
                        local systems     = gatewayinfo.temperatureControlSystems
                        local info        = gatewayinfo.gatewayInfo
                        if systems and info and usedgateways[info.mac] then
                            for i=1,#systems do
                                local zones = systems[i].zones
                                if zones then
                                    local summary = { time = status.time }
                                    for i=1,#zones do
                                        local zone = zones[i]
                                        if validzonetypes[zone.zoneType] then
                                            summary[#summary+1] = updatezone(presets,zone.name,zone)
                                        end
                                    end
                                    return result(summary,"loading temperatures, %s")
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return result(false,"loading temperatures, %s")
end

local function updatetemperatures(presets)
    if validpresets(presets) then
        local everythingname = presets.files.everything
        local latestname     = presets.files.latest
        local historyname    = presets.files.history
        if (everythingname or latestname) and historyname then
            gettemperatures(presets)
            local t = loadtemperatures(presets)
            if t then
                local data = { }
                for i=1,#t do
                    local ti = t[i]
                    data[ti.name] = ti.current
                end
                local history = loadhistory(historyname) or { }
                setmoment(history,ostime(),data)
                savedtable(historyname,history)
                return result(t,"updating temperatures, %s")
            end
        end
    end
    return result(false,"updating temperatures, %s")
end

local function getzonestate(presets,name)
    return validpresets(presets) and presets.data.states[name]
end

local f = replacer (
    [[curl ]] ..
    [[--silent --insecure ]] ..
    [[-X PUT ]] ..
    [[-H "Authorization: bearer %accesstoken%" ]] ..
    [[-H "Accept: application/json, application/xml, text/json, text/x-json, text/javascript, text/xml" ]] ..
    [[-H "applicationId: %applicationid%" ]] ..
    [[-H "Content-Type: application/json" ]] ..
    [[-d "%[settings]%" ]] ..
    [["https://tccna.honeywell.com/WebAPI/emea/api/v1/temperatureZone/%zoneid%/heatSetpoint"]]
)

local function untilmidnight()
    local t = osdate("*t")
    t.hour = 23
    t.min  = 59
    t.sec  = 59
    return osdate("%Y-%m-%dT%H:%M:%SZ",ostime(t))
end

local followschedule = {
 -- HeatSetpointValue = 0,
    SetpointMode      = "FollowSchedule",
}

local function setzonestate(presets,name,temperature,permanent)
    local zone = findzone(presets,name)
    if zone then
        local m = followschedule
        if type(temperature) == "number" and temperature > 0 then
            if permanent then
                m = {
                    HeatSetpointValue = temperature,
                    SetpointMode      = "PermanentOverride",
                }
            else
                m = {
                    HeatSetpointValue = temperature,
                    SetpointMode      = "TemporaryOverride",
                    TimeUntil         = untilmidnight(),
                }
            end
        end
        local s = f {
            accesstoken   = presets.credentials.accesstoken,
            applicationid = applicationid,
            zoneid        = zone.zoneId,
            settings      = jsontostring(m),
        }
        local r = s and resultof(s)
        local t = r and jsontolua(r)
-- inspect(r)
-- inspect(t)
        return result(t,"setting state of zone %a, %s",name)
    end
    return result(false,"setting state of zone %a, %s",name)
end

local function resetzonestate(presets,name)
    setzonestate(presets,name)
end

--

local function update(presets,noschedules)
    local everything = geteverything(presets,noschedules)
    if everything then
        presets.data.everything = everything
        return presets
    end
end

local function initialize(filename)
    local presets = loadpresets(filename)
    if presets then
        return update(presets)
    end
end

local function off(presets,name)
    local zone = presets and getzonestate(presets,name)
    if zone then
        setzonestate(presets,name,zone.lowest)
    end
end

local function on(presets,name)
    local zone = presets and getzonestate(presets,name)
    if zone then
        setzonestate(presets,name,zone.highest)
    end
end

local function schedule(presets,name)
    local zone = presets and getzonestate(presets,name)
    if zone then
        resetzonestate(presets,name)
    end
end

local function permanent(presets,name)
    local zone = presets and getzonestate(presets,name)
    if zone then
        setzonestate(presets,name,zone.lowest,true)
    end
end

-- tasks

local function settask(presets,when,tag,action)
    if when == "tomorrow" then
        local list = presets.scheduled
        if not list then
            list = loadtable(presets.files.schedules) or { }
            presets.scheduled = list
        end
        if action then
            list[tag] = {
                time     = ostime() + 24*60*60,
                done     = false,
                category = category,
                action   = action,
            }
        else
            list[tag] = nil
        end
        savedtable(presets.files.schedules,list)
    end
end

local function gettask(presets,when,tag)
    if when == "tomorrow" then
        local list = presets.scheduled
        if not list then
            list = loadtable(presets.files.schedules) or { }
            presets.scheduled = list
        end
        return list[tag]
    end
end

local function resettask(presets,when,tag)
    settask(presets,when,tag)
end

local function checktasks(presets)
    local list = presets.scheduled
    if not list then
        list = loadtable(presets.files.schedules) or { }
        presets.scheduled = list
    end
    if list then
        local t = osdate("*t")
        local q = { }
        for k, v in next, list do
            local d = osdate("*t",v.time)
            if not v.done and d.year == t.year and d.month == t.month and d.day == t.day then
                local a = v.action
                if type(a) == "function" then
                    a()
                end
                v.done = true
            end
            if d.year <= t.year and d.month <= t.month and d.day < t.day then
                q[k] = true
            end
        end
        if next(q) then
            for k, v in next, q do
                list[q] = nil
            end
            savedtable(presets.files.schedules,list)
        end
        return list
    end
end

-- predefined tasks

local function settomorrow(presets,tag,action)
    settask(presets,"tomorrow",tag,action)
end

local function resettomorrow(presets,tag)
    settask(presets,"tomorrow",tag)
end

local function tomorrowset(presets,tag)
    return gettask(presets,"tomorrow",tag) and true or false
end

--

local evohome

local function poller(presets)
    --
    if type(presets) ~= "string" then
        report("invalid presets file")
        os.exit()
    end
    report("loading presets from %a",presets)
    local presets = loadpresets(presets)
    if not validpresets(presets) then
        report("invalid presets, aborting")
        os.exit()
    end
    --
    local actions = presets.files.actions
    if type(actions) ~= "string" then
        report("invalid actions file")
        os.exit()
    end
    report("loading actions from %a",actions)
    local actions = loadtable(actions)
    if type(actions) ~= "table" then
        report("invalid actions, aborting")
        os.exit()
    end
    actions = actions.actions
    if type(actions) ~= "table" then
        report("invalid actions file, no actions subtable")
        os.exit()
    end
    --
    report("updating device status")
    update(presets)
    --
    presets.report     = report
    presets.evohome    = evohome
    presets.results    = { }
    --
    function presets.getstate(name)
        return getzonestate(presets,name)
    end
    function presets.tomorrowset(name)
        return tomorrowset(presets,name)
    end
    --
    local template = actions.template or presets.files.template
    --
    local process = function(t)
        local category = t.category
        local action   = t.action
        if category and action then
            local c = actions[category]
            if c then
                local a = c[action]
                if type(a) == "function" then
                    report("category %a, action %a, executing",category,action)
                    presets.results.template = template -- can be overloaded by action
                    a(presets)
                    update(presets,true)
                else
                    report("category %a, action %a, invalid action, known: %, t",category,action,sortedkeys(c))
                end
            else
                report("category %a, action %a, invalid category, known categories: %, t",category,action,sortedkeys(actions))
            end
        else
         -- logs.report("invalid category and action")
        end
    end
    --
    local delay    = presets.delay or 10
    local interval = 15 * 60 -- 15 minutes
    local interval = 60 * 60 -- 60 minutes
    local refresh  =  5 * 60
    local passed   =  0
    local step = function()
        if passed > interval then
            report("refreshing states, every %i seconds",interval)
            -- todo: update stepwise as this also updates the schedules that we don't really
            -- change often and definitely not in the middle of the night, so maybe just
            -- update 9:00 12:00 15:00 18:00 21:00
            update(presets)
            passed = 0
        else
            passed = passed + delay
        end
        checktasks(presets)
        return delay
    end
    --
    presets.refreshtime = refresh
    --
    return step, process, presets
end

--

evohome = {
    helpers = {
        getaccesstoken     = getaccesstoken,    -- presets
        getuserinfo        = getuserinfo,       -- presets
        getlocationinfo    = getlocationinfo,   -- presets
        getschedule        = getschedule,       -- presets, name
        --
        geteverything      = geteverything,      -- presets, noschedules
        gettemperatures    = gettemperatures,    -- presets
        getzonestate       = getzonestate,       -- presets, name
        setzonestate       = setzonestate,       -- presets, name, temperature
        resetzonestate     = resetzonestate,     -- presets, name
        getzonedata        = findzone,           -- presets, name
        --
        loadpresets        = loadpresets,        -- filename
        loadhistory        = loadhistory,        -- presets | filename
        loadeverything     = loadeverything,     -- presets | filename
        loadtemperatures   = loadtemperatures,   -- presets | filename
        --
        updatetemperatures = updatetemperatures, -- presets
    },
    actions= {
        initialize         = initialize,         -- filename
        update             = update,             -- presets
        --
        off                = off,                -- presets, name
        on                 = on,                 -- presets, name
        schedule           = schedule,           -- presets, name
        permanent          = permanent,          -- presets, name
        --
        settomorrow        = settomorrow,        -- presets, tag, function
        resettomorrow      = resettomorrow,      -- presets, tag
        tomorrowset        = tomorrowset,        -- presets, tag
        --
        poller             = poller,             -- presets
    }
}

if utilities then
    utilities.evohome = evohome
end

-- local presets = evohome.helpers.loadpresets("c:/data/develop/domotica/code/evohome-presets.lua")
-- evohome.helpers.setzonestate(presets,"Voorkamer",22)
-- evohome.helpers.setzonestate(presets,"Voorkamer")

return evohome

