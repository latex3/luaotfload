if not modules then modules = { } end modules ['font-otb'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}
local concat = table.concat
local format, gmatch, gsub, find, match, lower, strip = string.format, string.gmatch, string.gsub, string.find, string.match, string.lower, string.strip
local type, next, tonumber, tostring, rawget = type, next, tonumber, tostring, rawget
local lpegmatch = lpeg.match
local utfchar = utf.char

local trace_baseinit         = false  trackers.register("otf.baseinit",         function(v) trace_baseinit         = v end)
local trace_singles          = false  trackers.register("otf.singles",          function(v) trace_singles          = v end)
local trace_multiples        = false  trackers.register("otf.multiples",        function(v) trace_multiples        = v end)
local trace_alternatives     = false  trackers.register("otf.alternatives",     function(v) trace_alternatives     = v end)
local trace_ligatures        = false  trackers.register("otf.ligatures",        function(v) trace_ligatures        = v end)
local trace_ligatures_detail = false  trackers.register("otf.ligatures.detail", function(v) trace_ligatures_detail = v end)
local trace_kerns            = false  trackers.register("otf.kerns",            function(v) trace_kerns            = v end)
local trace_preparing        = false  trackers.register("otf.preparing",        function(v) trace_preparing        = v end)

local report_prepare         = logs.reporter("fonts","otf prepare")

local fonts                  = fonts
local otf                    = fonts.handlers.otf

local otffeatures            = otf.features
local registerotffeature     = otffeatures.register

otf.defaultbasealternate     = "none" -- first last

local wildcard               = "*"
local default                = "dflt"

local formatters             = string.formatters
local f_unicode              = formatters["%U"]
local f_uniname              = formatters["%U (%s)"]
local f_unilist              = formatters["% t (% t)"]

local function gref(descriptions,n)
    if type(n) == "number" then
        local name = descriptions[n].name
        if name then
            return f_uniname(n,name)
        else
            return f_unicode(n)
        end
    elseif n then
        local num, nam, j = { }, { }, 0
        for i=1,#n do
            local ni = n[i]
            if tonumber(ni) then -- first is likely a key
                j = j + 1
                local di = descriptions[ni]
                num[j] = f_unicode(ni)
                nam[j] = di and di.name or "-"
            end
        end
        return f_unilist(num,nam)
    else
        return "<error in base mode tracing>"
    end
end

local function cref(feature,lookuptags,lookupname)
    if lookupname then
        return formatters["feature %a, lookup %a"](feature,lookuptags[lookupname])
    else
        return formatters["feature %a"](feature)
    end
end

local function report_alternate(feature,lookuptags,lookupname,descriptions,unicode,replacement,value,comment)
    report_prepare("%s: base alternate %s => %s (%S => %S)",
        cref(feature,lookuptags,lookupname),
        gref(descriptions,unicode),
        replacement and gref(descriptions,replacement),
        value,
        comment)
end

local function report_substitution(feature,lookuptags,lookupname,descriptions,unicode,substitution)
    report_prepare("%s: base substitution %s => %S",
        cref(feature,lookuptags,lookupname),
        gref(descriptions,unicode),
        gref(descriptions,substitution))
end

local function report_ligature(feature,lookuptags,lookupname,descriptions,unicode,ligature)
    report_prepare("%s: base ligature %s => %S",
        cref(feature,lookuptags,lookupname),
        gref(descriptions,ligature),
        gref(descriptions,unicode))
end

local function report_kern(feature,lookuptags,lookupname,descriptions,unicode,otherunicode,value)
    report_prepare("%s: base kern %s + %s => %S",
        cref(feature,lookuptags,lookupname),
        gref(descriptions,unicode),
        gref(descriptions,otherunicode),
        value)
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
 -- report_prepare("fullname base hash '%a, featureset %a",tfmdata.properties.fullname,hash)
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
-- We can have changed[first] or changed[second] but it quickly becomes
-- messy if we need to take that into account.

local trace = false

local function finalize_ligatures(tfmdata,ligatures)
    local nofligatures = #ligatures
    if nofligatures > 0 then
        local characters   = tfmdata.characters
        local descriptions = tfmdata.descriptions
        local resources    = tfmdata.resources
        local unicodes     = resources.unicodes -- we use rawget in order to avoid bulding the table
        local private      = resources.private
        local alldone      = false
        while not alldone do
            local done = 0
            for i=1,nofligatures do
                local ligature = ligatures[i]
                if ligature then
                    local unicode, lookupdata = ligature[1], ligature[2]
                    if trace_ligatures_detail then
                        report_prepare("building % a into %a",lookupdata,unicode)
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
                                if trace_ligatures_detail then
                                    report_prepare("defining %a as %a",firstname,firstcode)
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
                                if not rawget(unicodes,secondname) then
                                    unicodes[secondname] = unicode -- map final ligature onto intermediates
                                end
                                okay = true
                            else
                                target = rawget(unicodes,secondname)
                                if not target then
                                    break
                                end
                            end
                            if trace_ligatures_detail then
                                report_prepare("codes (%a,%a) + (%a,%a) -> %a",firstname,firstcode,secondname,secondcode,target)
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
                    elseif trace_ligatures_detail then
                        report_prepare("no glyph (%a,%a) for building %a",firstname,firstcode,target)
                    end
                    if okay then
                        ligatures[i] = false
                        done = done + 1
                    end
                end
            end
            alldone = done == 0
        end
        if trace_ligatures_detail then
            for k, v in table.sortedhash(characters) do
                if v.ligatures then
                    table.print(v,k)
                end
            end
        end
        resources.private = private
        return true
    end
end

local function preparesubstitutions(tfmdata,feature,value,validlookups,lookuplist)
    local characters   = tfmdata.characters
    local descriptions = tfmdata.descriptions
    local resources    = tfmdata.resources
    local properties   = tfmdata.properties
    local changed      = tfmdata.changed
    local lookuphash   = resources.lookuphash
    local lookuptypes  = resources.lookuptypes
    local lookuptags   = resources.lookuptags

    local ligatures    = { }
    local alternate    = tonumber(value) or true and 1
    local defaultalt   = otf.defaultbasealternate

    local trace_singles      = trace_baseinit and trace_singles
    local trace_alternatives = trace_baseinit and trace_alternatives
    local trace_ligatures    = trace_baseinit and trace_ligatures

    local actions      = {
        substitution = function(lookupdata,lookuptags,lookupname,description,unicode)
            if trace_singles then
                report_substitution(feature,lookuptags,lookupname,descriptions,unicode,lookupdata)
            end
            changed[unicode] = lookupdata
        end,
        alternate = function(lookupdata,lookuptags,lookupname,description,unicode)
            local replacement = lookupdata[alternate]
            if replacement then
                changed[unicode] = replacement
                if trace_alternatives then
                    report_alternate(feature,lookuptags,lookupname,descriptions,unicode,replacement,value,"normal")
                end
            elseif defaultalt == "first" then
                replacement = lookupdata[1]
                changed[unicode] = replacement
                if trace_alternatives then
                    report_alternate(feature,lookuptags,lookupname,descriptions,unicode,replacement,value,defaultalt)
                end
            elseif defaultalt == "last" then
                replacement = lookupdata[#data]
                if trace_alternatives then
                    report_alternate(feature,lookuptags,lookupname,descriptions,unicode,replacement,value,defaultalt)
                end
            else
                if trace_alternatives then
                    report_alternate(feature,lookuptags,lookupname,descriptions,unicode,replacement,value,"unknown")
                end
            end
        end,
        ligature = function(lookupdata,lookuptags,lookupname,description,unicode)
            if trace_ligatures then
                report_ligature(feature,lookuptags,lookupname,descriptions,unicode,lookupdata)
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
                        action(lookupdata,lookuptags,lookupname,description,unicode)
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
                            action(lookuplist[i],lookuptags,lookupname,description,unicode)
                        end
                    end
                end
            end
        end
    end
    properties.hasligatures = finalize_ligatures(tfmdata,ligatures)
end

local function preparepositionings(tfmdata,feature,value,validlookups,lookuplist) -- todo what kind of kerns, currently all
    local characters   = tfmdata.characters
    local descriptions = tfmdata.descriptions
    local resources    = tfmdata.resources
    local properties   = tfmdata.properties
    local lookuptags   = resources.lookuptags
    local sharedkerns  = { }
    local traceindeed  = trace_baseinit and trace_kerns
    local haskerns     = false
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
                                    report_kern(feature,lookuptags,lookup,descriptions,unicode,otherunicode,value)
                                end
                            elseif not newkerns[otherunicode] then -- first wins
                                newkerns[otherunicode] = value
                                done = true
                                if traceindeed then
                                    report_kern(feature,lookuptags,lookup,descriptions,unicode,otherunicode,value)
                                end
                            end
                        end
                    end
                end
                if done then
                    sharedkerns[rawkerns] = newkerns
                    character.kerns       = newkerns -- no empty assignments
                    haskerns              = true
                else
                    sharedkerns[rawkerns] = false
                end
            end
        end
    end
    properties.haskerns = haskerns
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

local function make_2(present,tfmdata,characters,tree,name,preceding,unicode,done,lookuptags,lookupname)
    for k, v in next, tree do
        if k == "ligature" then
            local character = characters[preceding]
            if not character then
                if trace_baseinit then
                    report_prepare("weird ligature in lookup %a, current %C, preceding %C",lookuptags[lookupname],v,preceding)
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
            make_2(present,tfmdata,characters,v,name,code,k,done,lookuptags,lookupname)
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
    local lookuptags   = resources.lookuptags

    local ligatures    = { }
    local alternate    = tonumber(value) or true and 1
    local defaultalt   = otf.defaultbasealternate

    local trace_singles      = trace_baseinit and trace_singles
    local trace_alternatives = trace_baseinit and trace_alternatives
    local trace_ligatures    = trace_baseinit and trace_ligatures

    for l=1,#lookuplist do
        local lookupname = lookuplist[l]
        local lookupdata = lookuphash[lookupname]
        local lookuptype = lookuptypes[lookupname]
        for unicode, data in next, lookupdata do
            if lookuptype == "substitution" then
                if trace_singles then
                    report_substitution(feature,lookuptags,lookupname,descriptions,unicode,data)
                end
                changed[unicode] = data
            elseif lookuptype == "alternate" then
                local replacement = data[alternate]
                if replacement then
                    changed[unicode] = replacement
                    if trace_alternatives then
                        report_alternate(feature,lookuptags,lookupname,descriptions,unicode,replacement,value,"normal")
                    end
                elseif defaultalt == "first" then
                    replacement = data[1]
                    changed[unicode] = replacement
                    if trace_alternatives then
                        report_alternate(feature,lookuptags,lookupname,descriptions,unicode,replacement,value,defaultalt)
                    end
                elseif defaultalt == "last" then
                    replacement = data[#data]
                    if trace_alternatives then
                        report_alternate(feature,lookuptags,lookupname,descriptions,unicode,replacement,value,defaultalt)
                    end
                else
                    if trace_alternatives then
                        report_alternate(feature,lookuptags,lookupname,descriptions,unicode,replacement,value,"unknown")
                    end
                end
            elseif lookuptype == "ligature" then
                ligatures[#ligatures+1] = { unicode, data, lookupname }
                if trace_ligatures then
                    report_ligature(feature,lookuptags,lookupname,descriptions,unicode,data)
                end
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
            make_2(present,tfmdata,characters,tree,"ctx_"..unicode,unicode,unicode,done,lookuptags,lookupname)
        end

    end

end

local function preparepositionings(tfmdata,feature,value,validlookups,lookuplist)
    local characters   = tfmdata.characters
    local descriptions = tfmdata.descriptions
    local resources    = tfmdata.resources
    local properties   = tfmdata.properties
    local lookuphash   = resources.lookuphash
    local lookuptags   = resources.lookuptags
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
                        report_kern(feature,lookuptags,lookup,descriptions,unicode,otherunicode,kern)
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
        local starttime = trace_preparing and os.clock()
        local features  = tfmdata.shared.features
        local fullname  = tfmdata.properties.fullname or "?"
        if features then
            applybasemethod("initializehashes",tfmdata)
            local collectlookups    = otf.collectlookups
            local rawdata           = tfmdata.shared.rawdata
            local properties        = tfmdata.properties
            local script            = properties.script
            local language          = properties.language
            local basesubstitutions = rawdata.resources.features.gsub
            local basepositionings  = rawdata.resources.features.gpos
            --
         -- if basesubstitutions then
         --     for feature, data in next, basesubstitutions do
         --         local value = features[feature]
         --         if value then
         --             local validlookups, lookuplist = collectlookups(rawdata,feature,script,language)
         --             if validlookups then
         --                 applybasemethod("preparesubstitutions",tfmdata,feature,value,validlookups,lookuplist)
         --                 registerbasefeature(feature,value)
         --             end
         --         end
         --     end
         -- end
         -- if basepositionings then
         --     for feature, data in next, basepositionings do
         --         local value = features[feature]
         --         if value then
         --             local validlookups, lookuplist = collectlookups(rawdata,feature,script,language)
         --             if validlookups then
         --                 applybasemethod("preparepositionings",tfmdata,feature,features[feature],validlookups,lookuplist)
         --                 registerbasefeature(feature,value)
         --             end
         --         end
         --     end
         -- end
            --
            if basesubstitutions or basepositionings then
                local sequences = tfmdata.resources.sequences
                for s=1,#sequences do
                    local sequence = sequences[s]
                    local sfeatures = sequence.features
                    if sfeatures then
                        local order = sequence.order
                        if order then
                            for i=1,#order do --
                                local feature = order[i]
                                local value = features[feature]
                                if value then
                                    local validlookups, lookuplist = collectlookups(rawdata,feature,script,language)
                                    if not validlookups then
                                        -- skip
                                    elseif basesubstitutions and basesubstitutions[feature] then
                                        if trace_preparing then
                                            report_prepare("filtering base %s feature %a for %a with value %a","sub",feature,fullname,value)
                                        end
                                        applybasemethod("preparesubstitutions",tfmdata,feature,value,validlookups,lookuplist)
                                        registerbasefeature(feature,value)
                                    elseif basepositionings and basepositionings[feature] then
                                        if trace_preparing then
                                            report_prepare("filtering base %a feature %a for %a with value %a","pos",feature,fullname,value)
                                        end
                                        applybasemethod("preparepositionings",tfmdata,feature,value,validlookups,lookuplist)
                                        registerbasefeature(feature,value)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            --
            registerbasehash(tfmdata)
        end
        if trace_preparing then
            report_prepare("preparation time is %0.3f seconds for %a",os.clock()-starttime,fullname)
        end
    end
end

registerotffeature {
    name         = "features",
    description  = "features",
    default      = true,
    initializers = {
 --     position = 1, -- after setscript (temp hack ... we need to force script / language to 1
        base     = featuresinitializer,
    }
}

-- independent : collect lookups independently (takes more runtime ... neglectable)
-- shared      : shares lookups with node mode (takes more memory unless also a node mode variant is used ... noticeable)

directives.register("fonts.otf.loader.basemethod", function(v)
    if basemethods[v] then
        basemethod = v
    end
end)
