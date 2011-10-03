if not modules then modules = { } end modules ['font-otb'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}
local concat = table.concat
local format, gmatch, gsub, find, match, lower, strip = string.format, string.gmatch, string.gsub, string.find, string.match, string.lower, string.strip
local type, next, tonumber, tostring = type, next, tonumber, tostring
local lpegmatch = lpeg.match
local utfchar = utf.char

local trace_baseinit      = false  trackers.register("otf.baseinit",     function(v) trace_baseinit     = v end)
local trace_singles       = false  trackers.register("otf.singles",      function(v) trace_singles      = v end)
local trace_multiples     = false  trackers.register("otf.multiples",    function(v) trace_multiples    = v end)
local trace_alternatives  = false  trackers.register("otf.alternatives", function(v) trace_alternatives = v end)
local trace_ligatures     = false  trackers.register("otf.ligatures",    function(v) trace_ligatures    = v end)
local trace_kerns         = false  trackers.register("otf.kerns",        function(v) trace_kerns        = v end)
local trace_preparing     = false  trackers.register("otf.preparing",    function(v) trace_preparing    = v end)

local report_prepare      = logs.reporter("fonts","otf prepare")

local fonts               = fonts
local otf                 = fonts.handlers.otf

local otffeatures         = fonts.constructors.newfeatures("otf")
local registerotffeature  = otffeatures.register

local wildcard = "*"
local default  = "dflt"

local function gref(descriptions,n)
    if type(n) == "number" then
        local name = descriptions[n].name
        if name then
            return format("U+%05X (%s)",n,name)
        else
            return format("U+%05X")
        end
    elseif n then
        local num, nam = { }, { }
        for i=2,#n do -- first is likely a key
            local ni = n[i]
            num[i] = format("U+%05X",ni)
            nam[i] = descriptions[ni].name or "?"
        end
        return format("%s (%s)",concat(num," "), concat(nam," "))
    else
        return "?"
    end
end

local function cref(feature,lookupname)
    if lookupname then
        return format("feature %s, lookup %s",feature,lookupname)
    else
        return format("feature %s",feature)
    end
end

local basemethods = { }
local basemethod  = "<unset>"

local function applybasemethod(what,...)
    local m = basemethods[basemethod][what]
    if m then
        return m(...)
    end
end

-- We need to make sure that luatex sees the difference between
-- base fonts that have different glyphs in the same slots in fonts
-- that have the same fullname (or filename). LuaTeX will merge fonts
-- eventually (and subset later on). If needed we can use a more
-- verbose name as long as we don't use <()<>[]{}/%> and the length
-- is < 128.

local basehash, basehashes, applied = { }, 1, { }

local function registerbasehash(tfmdata)
    local properties = tfmdata.properties
    local hash = concat(applied," ")
    local base = basehash[hash]
    if not base then
        basehashes     = basehashes + 1
        base           = basehashes
        basehash[hash] = base
    end
    properties.basehash = base
    properties.fullname = properties.fullname .. "-" .. base
 -- report_prepare("fullname base hash: '%s', featureset '%s'",tfmdata.properties.fullname,hash)
    applied = { }
end

local function registerbasefeature(feature,value)
    applied[#applied+1] = feature  .. "=" .. tostring(value)
end

-- The original basemode ligature builder used the names of components
-- and did some expression juggling to get the chain right. The current
-- variant starts with unicodes but still uses names to make the chain.
-- This is needed because we have to create intermediates when needed
-- but use predefined snippets when available. To some extend the
-- current builder is more stupid but I don't worry that much about it
-- as ligatures are rather predicatable.
--
-- Personally I think that an ff + i == ffi rule as used in for instance
-- latin modern is pretty weird as no sane person will key that in and
-- expect a glyph for that ligature plus the following character. Anyhow,
-- as we need to deal with this, we do, but no guarantes are given.
--
--         latin modern       dejavu
--
-- f+f       102 102             102 102
-- f+i       102 105             102 105
-- f+l       102 108             102 108
-- f+f+i                         102 102 105
-- f+f+l     102 102 108         102 102 108
-- ff+i    64256 105           64256 105
-- ff+l                        64256 108
--
-- As you can see here, latin modern is less complete than dejavu but
-- in practice one will not notice it.
--
-- The while loop is needed because we need to resolve for instance
-- pseudo names like hyphen_hyphen to endash so in practice we end
-- up with a bit too many definitions but the overhead is neglectable.
--
-- Todo: if changed[first] or changed[second] then ... end

local trace = false

local function finalize_ligatures(tfmdata,ligatures)
    local nofligatures = #ligatures
    if nofligatures > 0 then
        local characters   = tfmdata.characters
        local descriptions = tfmdata.descriptions
        local resources    = tfmdata.resources
        local unicodes     = resources.unicodes
        local private      = resources.private
        local alldone      = false
        while not alldone do
            local done = 0
            for i=1,nofligatures do
                local ligature = ligatures[i]
                if ligature then
                    local unicode, lookupdata = ligature[1], ligature[2]
                    if trace then
                        print("BUILDING",concat(lookupdata," "),unicode)
                    end
                    local size = #lookupdata
                    local firstcode = lookupdata[1] -- [2]
                    local firstdata = characters[firstcode]
                    local okay = false
                    if firstdata then
                        local firstname = "ctx_" .. firstcode
                        for i=1,size-1 do -- for i=2,size-1 do
                            local firstdata = characters[firstcode]
                            if not firstdata then
                                firstcode = private
                                if trace then
                                    print(" DEFINING",firstname,firstcode)
                                end
                                unicodes[firstname] = firstcode
                                firstdata = { intermediate = true, ligatures = { } }
                                characters[firstcode] = firstdata
                                descriptions[firstcode] = { name = firstname }
                                private = private + 1
                            end
                            local target
                            local secondcode = lookupdata[i+1]
                            local secondname = firstname .. "_" .. secondcode
                            if i == size - 1 then
                                target = unicode
                                if not unicodes[secondname] then
                                    unicodes[secondname] = unicode -- map final ligature onto intermediates
                                end
                                okay = true
                            else
                                target = unicodes[secondname]
                                if not target then
                                    break
                                end
                            end
                            if trace then
                                print("CODES",firstname,firstcode,secondname,secondcode,target)
                            end
                            local firstligs = firstdata.ligatures
                            if firstligs then
                                firstligs[secondcode] = { char = target }
                            else
                                firstdata.ligatures = { [secondcode] = { char = target } }
                            end
                            firstcode = target
                            firstname = secondname
                        end
                    end
                    if okay then
                        ligatures[i] = false
                        done = done + 1
                    end
                end
            end
            alldone = done == 0
        end
        if trace then
            for k, v in next, characters do
                if v.ligatures then table.print(v,k) end
            end
        end
        tfmdata.resources.private = private
    end
end

local function preparesubstitutions(tfmdata,feature,value,validlookups,lookuplist)
    local characters   = tfmdata.characters
    local descriptions = tfmdata.descriptions
    local resources    = tfmdata.resources
    local changed      = tfmdata.changed
    local unicodes     = resources.unicodes
    local lookuphash   = resources.lookuphash
    local lookuptypes  = resources.lookuptypes

    local ligatures    = { }

    local actions      = {
        substitution = function(lookupdata,lookupname,description,unicode)
            if trace_baseinit and trace_singles then
                report_prepare("%s: base substitution %s => %s",cref(feature,lookupname),
                    gref(descriptions,unicode),gref(descriptions,lookupdatat))
            end
            changed[unicode] = lookupdata
        end,
        alternate = function(lookupdata,lookupname,description,unicode)
            local replacement = lookupdata[value] or lookupdata[#lookupdata]
            if trace_baseinit and trace_alternatives then
                report_prepare("%s: base alternate %s %s => %s",cref(feature,lookupname),
                    tostring(value),gref(descriptions,unicode),gref(descriptions,replacement))
            end
            changed[unicode] = replacement
        end,
        ligature = function(lookupdata,lookupname,description,unicode)
            if trace_baseinit and trace_alternatives then
                report_prepare("%s: base ligature %s %s => %s",cref(feature,lookupname),
                    tostring(value),gref(descriptions,lookupdata),gref(descriptions,unicode))
            end
            ligatures[#ligatures+1] = { unicode, lookupdata }
        end,
    }

    for unicode, character in next, characters do
        local description = descriptions[unicode]
        local lookups = description.slookups
        if lookups then
            for l=1,#lookuplist do
                local lookupname = lookuplist[l]
                local lookupdata = lookups[lookupname]
                if lookupdata then
                    local lookuptype = lookuptypes[lookupname]
                    local action = actions[lookuptype]
                    if action then
                        action(lookupdata,lookupname,description,unicode)
                    end
                end
            end
        end
        local lookups = description.mlookups
        if lookups then
            for l=1,#lookuplist do
                local lookupname = lookuplist[l]
                local lookuplist = lookups[lookupname]
                if lookuplist then
                    local lookuptype = lookuptypes[lookupname]
                    local action = actions[lookuptype]
                    if action then
                        for i=1,#lookuplist do
                            action(lookuplist[i],lookupname,description,unicode)
                        end
                    end
                end
            end
        end
    end

    finalize_ligatures(tfmdata,ligatures)
end

local function preparepositionings(tfmdata,feature,value,validlookups,lookuplist) -- todo what kind of kerns, currently all
    local characters   = tfmdata.characters
    local descriptions = tfmdata.descriptions
    local resources    = tfmdata.resources
    local unicodes     = resources.unicodes
    local sharedkerns  = { }
    local traceindeed  = trace_baseinit and trace_kerns
    for unicode, character in next, characters do
        local description = descriptions[unicode]
        local rawkerns = description.kerns -- shared
        if rawkerns then
            local s = sharedkerns[rawkerns]
            if s == false then
                -- skip
            elseif s then
                character.kerns = s
            else
                local newkerns = character.kerns
                local done     = false
                for l=1,#lookuplist do
                    local lookup = lookuplist[l]
                    local kerns  = rawkerns[lookup]
                    if kerns then
                        for otherunicode, value in next, kerns do
                            if value == 0 then
                                -- maybe no 0 test here
                            elseif not newkerns then
                                newkerns = { [otherunicode] = value }
                                done = true
                                if traceindeed then
                                    report_prepare("%s: base kern %s + %s => %s",cref(feature,lookup),
                                        gref(descriptions,unicode),gref(descriptions,otherunicode),value)
                                end
                            elseif not newkerns[otherunicode] then -- first wins
                                newkerns[otherunicode] = value
                                done = true
                                if traceindeed then
                                    report_prepare("%s: base kern %s + %s => %s",cref(feature,lookup),
                                        gref(descriptions,unicode),gref(descriptions,otherunicode),value)
                                end
                            end
                        end
                    end
                end
                if done then
                    sharedkerns[rawkerns] = newkerns
                    character.kerns       = newkerns -- no empty assignments
                else
                    sharedkerns[rawkerns] = false
                end
            end
        end
    end
end

basemethods.independent = {
    preparesubstitutions = preparesubstitutions,
    preparepositionings  = preparepositionings,
}

local function makefake(tfmdata,name,present)
    local resources = tfmdata.resources
    local private   = resources.private
    local character = { intermediate = true, ligatures = { } }
    resources.unicodes[name] = private
    tfmdata.characters[private] = character
    tfmdata.descriptions[private] = { name = name }
    resources.private = private + 1
    present[name] = private
    return character
end

local function make_1(present,tree,name)
    for k, v in next, tree do
        if k == "ligature" then
            present[name] = v
        else
            make_1(present,v,name .. "_" .. k)
        end
    end
end

local function make_2(present,tfmdata,characters,tree,name,preceding,unicode,done,lookupname)
    for k, v in next, tree do
        if k == "ligature" then
            local character = characters[preceding]
            if not character then
                if trace_baseinit then
                    report_prepare("weird ligature in lookup %s: U+%05X (%s), preceding U+%05X (%s)",lookupname,v,utfchar(v),preceding,utfchar(preceding))
                end
                character = makefake(tfmdata,name,present)
            end
            local ligatures = character.ligatures
            if ligatures then
                ligatures[unicode] = { char = v }
            else
                character.ligatures = { [unicode] = { char = v } }
            end
            if done then
                local d = done[lookupname]
                if not d then
                    done[lookupname] = { "dummy", v }
                else
                    d[#d+1] = v
                end
            end
        else
            local code = present[name] or unicode
            local name = name .. "_" .. k
            make_2(present,tfmdata,characters,v,name,code,k,done,lookupname)
        end
    end
end

local function preparesubstitutions(tfmdata,feature,value,validlookups,lookuplist)
    local characters   = tfmdata.characters
    local descriptions = tfmdata.descriptions
    local resources    = tfmdata.resources
    local changed      = tfmdata.changed
    local lookuphash   = resources.lookuphash
    local lookuptypes  = resources.lookuptypes

    local ligatures    = { }

    for l=1,#lookuplist do
        local lookupname = lookuplist[l]
        local lookupdata = lookuphash[lookupname]
        local lookuptype = lookuptypes[lookupname]
        for unicode, data in next, lookupdata do
            if lookuptype == "substitution" then
                if trace_baseinit and trace_singles then
                    report_prepare("%s: base substitution %s => %s",cref(feature,lookupname),
                        gref(descriptions,unicode),gref(descriptions,data))
                end
                changed[unicode] = data
            elseif lookuptype == "alternate" then
                local replacement = data[value] or data[#data]
                if trace_baseinit and trace_alternatives then
                    report_prepare("%s: base alternate %s %s => %s",cref(feature,lookupname),
                        tostring(value),gref(descriptions,unicode),gref(descriptions,replacement))
                end
                changed[unicode] = replacement
            elseif lookuptype == "ligature" then
                ligatures[#ligatures+1] = { unicode, data, lookupname }
            end
        end
    end

    local nofligatures = #ligatures

    if nofligatures > 0 then

        local characters = tfmdata.characters
        local present    = { }
        local done       = trace_baseinit and trace_ligatures and { }

        for i=1,nofligatures do
            local ligature = ligatures[i]
            local unicode, tree = ligature[1], ligature[2]
            make_1(present,tree,"ctx_"..unicode)
        end

        for i=1,nofligatures do
            local ligature = ligatures[i]
            local unicode, tree, lookupname = ligature[1], ligature[2], ligature[3]
            make_2(present,tfmdata,characters,tree,"ctx_"..unicode,unicode,unicode,done,lookupname)
        end

        if done then
            for lookupname, list in next, done do
                report_prepare("%s: base ligatures %s => %s",cref(feature,lookupname),
                    tostring(value),gref(descriptions,done))
            end
        end

    end

end

local function preparepositionings(tfmdata,feature,value,validlookups,lookuplist)
    local characters   = tfmdata.characters
    local descriptions = tfmdata.descriptions
    local resources    = tfmdata.resources
    local lookuphash   = resources.lookuphash
    local traceindeed  = trace_baseinit and trace_kerns

    -- check out this sharedkerns trickery

    for l=1,#lookuplist do
        local lookupname = lookuplist[l]
        local lookupdata = lookuphash[lookupname]
        for unicode, data in next, lookupdata do
            local character = characters[unicode]
            local kerns = character.kerns
            if not kerns then
                kerns = { }
                character.kerns = kerns
            end
            if traceindeed then
                for otherunicode, kern in next, data do
                    if not kerns[otherunicode] and kern ~= 0 then
                        kerns[otherunicode] = kern
                        report_prepare("%s: base kern %s + %s => %s",cref(feature,lookup),
                            gref(descriptions,unicode),gref(descriptions,otherunicode),kern)
                    end
                end
            else
                for otherunicode, kern in next, data do
                    if not kerns[otherunicode] and kern ~= 0 then
                        kerns[otherunicode] = kern
                    end
                end
            end
        end
    end

end

local function initializehashes(tfmdata)
    nodeinitializers.features(tfmdata)
end

basemethods.shared = {
    initializehashes     = initializehashes,
    preparesubstitutions = preparesubstitutions,
    preparepositionings  = preparepositionings,
}

basemethod = "independent"

local function featuresinitializer(tfmdata,value)
    if true then -- value then
        local t = trace_preparing and os.clock()
        local features = tfmdata.shared.features
        if features then
            applybasemethod("initializehashes",tfmdata)
            local collectlookups    = otf.collectlookups
            local rawdata           = tfmdata.shared.rawdata
            local properties        = tfmdata.properties
            local script            = properties.script
            local language          = properties.language
            local basesubstitutions = rawdata.resources.features.gsub
            local basepositionings  = rawdata.resources.features.gpos
            if basesubstitutions then
                for feature, data in next, basesubstitutions do
                    local value = features[feature]
                    if value then
                        local validlookups, lookuplist = collectlookups(rawdata,feature,script,language)
                        if validlookups then
                            applybasemethod("preparesubstitutions",tfmdata,feature,value,validlookups,lookuplist)
                            registerbasefeature(feature,value)
                        end
                    end
                end
            end
            if basepositions then
                for feature, data in next, basepositions do
                    local value = features[feature]
                    if value then
                        local validlookups, lookuplist = collectlookups(rawdata,feature,script,language)
                        if validlookups then
                            applybasemethod("preparepositionings",tfmdata,feature,features[feature],validlookups,lookuplist)
                            registerbasefeature(feature,value)
                        end
                    end
                end
            end
            registerbasehash(tfmdata)
        end
        if trace_preparing then
            report_prepare("preparation time is %0.3f seconds for %s",os.clock()-t,tfmdata.properties.fullname or "?")
        end
    end
end

registerotffeature {
    name         = "features",
    description  = "features",
    default      = true,
    initializers = {
--~         position = 1, -- after setscript (temp hack ... we need to force script / language to 1
        base     = featuresinitializer,
    }
}

-- independent : collect lookups independently (takes more runtime ... neglectable)
-- shared      : shares lookups with node mode (takes more memory  ... noticeable)

directives.register("fonts.otf.loader.basemethod", function(v)
    if basemethods[v] then
        basemethod = v
    end
end)
