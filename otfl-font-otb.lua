if not modules then modules = { } end modules ['font-otb'] = {
    version   = 1.001,
    comment   = "companion to font-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat = table.concat
local format, gmatch, gsub, find, match, lower, strip = string.format, string.gmatch, string.gsub, string.find, string.match, string.lower, string.strip
local type, next, tonumber, tostring = type, next, tonumber, tostring

local otf = fonts.otf
local tfm = fonts.tfm

local trace_baseinit     = false  trackers.register("otf.baseinit",     function(v) trace_baseinit     = v end)
local trace_singles      = false  trackers.register("otf.singles",      function(v) trace_singles      = v end)
local trace_multiples    = false  trackers.register("otf.multiples",    function(v) trace_multiples    = v end)
local trace_alternatives = false  trackers.register("otf.alternatives", function(v) trace_alternatives = v end)
local trace_ligatures    = false  trackers.register("otf.ligatures",    function(v) trace_ligatures    = v end)
local trace_kerns        = false  trackers.register("otf.kerns",        function(v) trace_kerns        = v end)
local trace_preparing    = false  trackers.register("otf.preparing",    function(v) trace_preparing    = v end)

local wildcard = "*"
local default  = "dflt"

local split_at_space = lpeg.Ct(lpeg.splitat(" ")) -- no trailing or multiple spaces anyway

local pcache, fcache = { }, { } -- could be weak

local function gref(descriptions,n)
    if type(n) == "number" then
        local name = descriptions[n].name
        if name then
            return format("U+%04X (%s)",n,name)
        else
            return format("U+%04X")
        end
    elseif n then
        local num, nam = { }, { }
        for i=1,#n do
            local ni = n[i]
            num[i] = format("U+%04X",ni)
            nam[i] = descriptions[ni].name or "?"
        end
        return format("%s (%s)",concat(num," "), concat(nam," "))
    else
        return "?"
    end
end

local function cref(kind,lookupname)
    if lookupname then
        return format("feature %s, lookup %s",kind,lookupname)
    else
        return format("feature %s",kind)
    end
end

local function resolve_ligatures(tfmdata,ligatures,kind)
    kind = kind or "unknown"
    local unicodes = tfmdata.unicodes
    local characters = tfmdata.characters
    local descriptions = tfmdata.descriptions
    local changed = tfmdata.changed
    local done  = { }
    while true do
        local ok = false
        for k,v in next, ligatures do
            local lig = v[1]
            if not done[lig] then
                local ligs = split_at_space:match(lig)
                if #ligs == 2 then
                    local uc = v[2]
                    local c, f, s = characters[uc], ligs[1], ligs[2]
                    local uft, ust = unicodes[f] or 0, unicodes[s] or 0
                    if not uft or not ust then
                        logs.report("define otf","%s: unicode problem with base ligature %s = %s + %s",cref(kind),gref(descriptions,uc),gref(descriptions,uft),gref(descriptions,ust))
                        -- some kind of error
                    else
                        if type(uft) == "number" then uft = { uft } end
                        if type(ust) == "number" then ust = { ust } end
                        for ufi=1,#uft do
                            local uf = uft[ufi]
                            for usi=1,#ust do
                                local us = ust[usi]
                                if changed[uf] or changed[us] then
                                    if trace_baseinit and trace_ligatures then
                                        logs.report("define otf","%s: base ligature %s + %s ignored",cref(kind),gref(descriptions,uf),gref(descriptions,us))
                                    end
                                else
                                    local first, second = characters[uf], us
                                    if first and second then
                                        local t = first.ligatures
                                        if not t then
                                            t = { }
                                            first.ligatures = t
                                        end
                                        if type(uc) == "number" then
                                            t[second] = { type = 0, char = uc }
                                        else
                                            t[second] = { type = 0, char = uc[1] } -- can this still happen?
                                        end
                                        if trace_baseinit and trace_ligatures then
                                            logs.report("define otf","%s: base ligature %s + %s => %s",cref(kind),gref(descriptions,uf),gref(descriptions,us),gref(descriptions,uc))
                                        end
                                    end
                                end
                            end
                        end
                    end
                    ok, done[lig] = true, descriptions[uc].name
                end
            end
        end
        if ok then
            -- done has "a b c" = "a_b_c" and ligatures the already set ligatures: "a b" = 123
            -- and here we add extras (f i i = fi + i and alike)
            --
            -- we could use a hash for fnc and pattern
            --
            -- this might be interfering !
            for d,n in next, done do
                local pattern = pcache[d] if not pattern then pattern = "^(" .. d .. ") "              pcache[d] = pattern end
                local fnc     = fcache[n] if not fnc     then fnc     = function() return n .. " " end fcache[n] = fnc     end
                for k,v in next, ligatures do
                    v[1] = gsub(v[1],pattern,fnc)
                end
            end
        else
            break
        end
    end
end

local function collect_lookups(otfdata,kind,script,language)
    -- maybe store this  in the font
    local sequences = otfdata.luatex.sequences
    if sequences then
        local featuremap, featurelist = { }, { }
        for s=1,#sequences do
            local sequence = sequences[s]
            local features = sequence.features
            features = features and features[kind]
            features = features and (features[script]   or features[default] or features[wildcard])
            features = features and (features[language] or features[default] or features[wildcard])
            if features then
                local subtables = sequence.subtables
                if subtables then
                    for s=1,#subtables do
                        local ss = subtables[s]
                        if not featuremap[s] then
                            featuremap[ss] = true
                            featurelist[#featurelist+1] = ss
                        end
                    end
                end
            end
        end
        if #featurelist > 0 then
            return featuremap, featurelist
        end
    end
    return nil, nil
end

local splitter = lpeg.splitat(" ")

function prepare_base_substitutions(tfmdata,kind,value) -- we can share some code with the node features
    if value then
        local otfdata = tfmdata.shared.otfdata
        local validlookups, lookuplist = collect_lookups(otfdata,kind,tfmdata.script,tfmdata.language)
        if validlookups then
            local ligatures = { }
            local unicodes = tfmdata.unicodes -- names to unicodes
            local indices = tfmdata.indices
            local characters = tfmdata.characters
            local descriptions = tfmdata.descriptions
            local changed = tfmdata.changed
            for k,c in next, characters do
                local glyph = descriptions[k]
                local lookups = glyph.lookups
                if lookups then
                    for l=1,#lookuplist do
                        local lookup = lookuplist[l]
                        local ps = lookups[lookup]
                        if ps then
                            for i=1,#ps do
                                local p = ps[i]
                                local t = p[1]
                                if t == 'substitution' then
                                    local pv = p[2] -- p.variant
                                    if pv then
                                        local upv = unicodes[pv]
                                        if upv then
                                            if type(upv) == "table" then
                                                upv = upv[1]
                                            end
                                            if characters[upv] then
                                                if trace_baseinit and trace_singles then
                                                    logs.report("define otf","%s: base substitution %s => %s",cref(kind,lookup),gref(descriptions,k),gref(descriptions,upv))
                                                end
                                                changed[k] = upv
                                            end
                                        end
                                    end
                                elseif t == 'alternate' then
                                    local pc = p[2] -- p.components
                                    if pc then
                                        -- a bit optimized ugliness
                                        if value == 1 then
                                            pc = splitter:match(pc)
                                        elseif value == 2 then
                                            local a, b = splitter:match(pc)
                                            pc = b or a
                                        else
                                            pc = { splitter:match(pc) }
                                            pc = pc[value] or pc[#pc]
                                        end
                                        if pc then
                                            local upc = unicodes[pc]
                                            if upc then
                                                if type(upc) == "table" then
                                                    upc = upc[1]
                                                end
                                                if characters[upc] then
                                                    if trace_baseinit and trace_alternatives then
                                                        logs.report("define otf","%s: base alternate %s => %s",cref(kind,lookup),gref(descriptions,k),gref(descriptions,upc))
                                                    end
                                                    changed[k] = upc
                                                end
                                            end
                                        end
                                    end
                                elseif t == 'ligature' and not changed[k] then
                                    local pc = p[2]
                                    if pc then
                                        if trace_baseinit and trace_ligatures then
                                            local upc = { splitter:match(pc) }
                                            for i=1,#upc do upc[i] = unicodes[upc[i]] end
                                            -- we assume that it's no table
                                            logs.report("define otf","%s: base ligature %s => %s",cref(kind,lookup),gref(descriptions,upc),gref(descriptions,k))
                                        end
                                        ligatures[#ligatures+1] = { pc, k }
                                    end
                                end
                            end
                        end
                    end
                end
            end
            resolve_ligatures(tfmdata,ligatures,kind)
        end
    else
        tfmdata.ligatures = tfmdata.ligatures or { } -- left over from what ?
    end
end

local function prepare_base_kerns(tfmdata,kind,value) -- todo what kind of kerns, currently all
    if value then
        local otfdata = tfmdata.shared.otfdata
        local validlookups, lookuplist = collect_lookups(otfdata,kind,tfmdata.script,tfmdata.language)
        if validlookups then
            local unicodes = tfmdata.unicodes -- names to unicodes
            local indices = tfmdata.indices
            local characters = tfmdata.characters
            local descriptions = tfmdata.descriptions
            for u, chr in next, characters do
                local d = descriptions[u]
                if d then
                    local dk = d.mykerns
                    if dk then
                        local t, done = chr.kerns or { }, false
                        for l=1,#lookuplist do
                            local lookup = lookuplist[l]
                            local kerns = dk[lookup]
                            if kerns then
                                for k, v in next, kerns do
                                    if v ~= 0 and not t[k] then -- maybe no 0 test here
                                        t[k], done = v, true
                                        if trace_baseinit and trace_kerns then
                                            logs.report("define otf","%s: base kern %s + %s => %s",cref(kind,lookup),gref(descriptions,u),gref(descriptions,k),v)
                                        end
                                    end
                                end
                            end
                        end
                        if done then
                            chr.kerns = t -- no empty assignments
                        end
                --  elseif d.kerns then
                --      logs.report("define otf","%s: invalid mykerns for %s",cref(kind),gref(descriptions,u))
                    end
                end
            end
        end
    end
end

-- In principle we could register each feature individually which was
-- what we did in earlier versions. However, after the rewrite it
-- made more sense to collect them in an overall features initializer
-- just as with the node variant. There it was needed because we need
-- to do complete mixed runs and not run featurewise (as we did before).

local supported_gsub = {
    'liga','dlig','rlig','hlig',
    'pnum','onum','tnum','lnum',
    'zero',
    'smcp','cpsp','c2sc','ornm','aalt',
    'hwid','fwid',
    'ssty', -- math
}

local supported_gpos = {
    'kern'
}

function otf.features.register_base_substitution(tag)
    supported_gsub[#supported_gsub+1] = tag
end
function otf.features.register_base_kern(tag)
    supported_gsub[#supported_gpos+1] = tag
end

local basehash, basehashes = { }, 1

function fonts.initializers.base.otf.features(tfmdata,value)
    if true then -- value then
        -- not shared
        local t = trace_preparing and os.clock()
        local features = tfmdata.shared.features
        if features then
            local h = { }
            for f=1,#supported_gsub do
                local feature = supported_gsub[f]
                local value = features[feature]
                prepare_base_substitutions(tfmdata,feature,value)
                if value then
                    h[#h+1] = feature  .. "=" .. tostring(value)
                end
            end
            for f=1,#supported_gpos do
                local feature = supported_gpos[f]
                local value = features[feature]
                prepare_base_kerns(tfmdata,feature,features[feature])
                if value then
                    h[#h+1] = feature  .. "=" .. tostring(value)
                end
            end
            local hash = concat(h," ")
            local base = basehash[hash]
            if not base then
                basehashes = basehashes + 1
                base = basehashes
                basehash[hash] = base
            end
            -- We need to make sure that luatex sees the difference between
            -- base fonts that have different glyphs in the same slots in fonts
            -- that have the same fullname (or filename). LuaTeX will merge fonts
            -- eventually (and subset later on). If needed we can use a more
            -- verbose name as long as we don't use <()<>[]{}/%> and the length
            -- is < 128.
            tfmdata.fullname = tfmdata.fullname .. "-" .. base
--~ logs.report("otf define","fullname base hash: '%s', featureset '%s'",tfmdata.fullname,hash)
        end
        if trace_preparing then
            logs.report("otf define","preparation time is %0.3f seconds for %s",os.clock()-t,tfmdata.fullname or "?")
        end
    end
end
