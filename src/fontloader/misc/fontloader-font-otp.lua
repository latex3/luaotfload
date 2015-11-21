if not modules then modules = { } end modules ['font-otp'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (packing)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: pack math (but not that much to share)
--
-- pitfall 5.2: hashed tables can suddenly become indexed with nil slots
--
-- unless we sort all hashes we can get a different pack order (no big deal but size can differ)

local next, type, tostring = next, type, tostring
local sort, concat = table.sort, table.concat

local trace_packing = false  trackers.register("otf.packing", function(v) trace_packing = v end)
local trace_loading = false  trackers.register("otf.loading", function(v) trace_loading = v end)

local report_otf    = logs.reporter("fonts","otf loading")

-- also used in other scripts so we need to check some tables:

fonts               = fonts or { }

local handlers      = fonts.handlers or { }
fonts.handlers      = handlers

local otf           = handlers.otf or { }
handlers.otf        = otf

local enhancers     = otf.enhancers or { }
otf.enhancers       = enhancers

local glists        = otf.glists or { "gsub", "gpos" }
otf.glists          = glists

local criterium     = 1
local threshold     = 0

local function tabstr_normal(t)
    local s = { }
    local n = 0
    for k, v in next, t do
        n = n + 1
        if type(v) == "table" then
            s[n] = k .. ">" .. tabstr_normal(v)
        elseif v == true then
            s[n] = k .. "+" -- "=true"
        elseif v then
            s[n] = k .. "=" .. v
        else
            s[n] = k .. "-" -- "=false"
        end
    end
    if n == 0 then
        return ""
    elseif n == 1 then
        return s[1]
    else
        sort(s) -- costly but needed (occasional wrong hit otherwise)
        return concat(s,",")
    end
end

local function tabstr_flat(t)
    local s = { }
    local n = 0
    for k, v in next, t do
        n = n + 1
        s[n] = k .. "=" .. v
    end
    if n == 0 then
        return ""
    elseif n == 1 then
        return s[1]
    else
        sort(s) -- costly but needed (occasional wrong hit otherwise)
        return concat(s,",")
    end
end

local function tabstr_mixed(t) -- indexed
    local s = { }
    local n = #t
    if n == 0 then
        return ""
    elseif n == 1 then
        local k = t[1]
        if k == true then
            return "++" -- we need to distinguish from "true"
        elseif k == false then
            return "--" -- we need to distinguish from "false"
        else
            return tostring(k) -- number or string
        end
    else
        for i=1,n do
            local k = t[i]
            if k == true then
                s[i] = "++" -- we need to distinguish from "true"
            elseif k == false then
                s[i] = "--" -- we need to distinguish from "false"
            else
                s[i] = k -- number or string
            end
        end
        return concat(s,",")
    end
end

local function tabstr_boolean(t)
    local s = { }
    local n = 0
    for k, v in next, t do
        n = n + 1
        if v then
            s[n] = k .. "+"
        else
            s[n] = k .. "-"
        end
    end
    if n == 0 then
        return ""
    elseif n == 1 then
        return s[1]
    else
        sort(s) -- costly but needed (occasional wrong hit otherwise)
        return concat(s,",")
    end
end

-- tabstr_boolean_x = tabstr_boolean

-- tabstr_boolean = function(t)
--     local a = tabstr_normal(t)
--     local b = tabstr_boolean_x(t)
--     print(a)
--     print(b)
--     return b
-- end

-- beware: we cannot unpack and repack the same table because then sharing
-- interferes (we could catch this if needed) .. so for now: save, reload
-- and repack in such cases (never needed anyway) .. a tricky aspect is that
-- we then need to sort more thanks to random hashing

local function packdata(data)

    if data then
     -- stripdata(data)
        local h, t, c = { }, { }, { }
        local hh, tt, cc = { }, { }, { }
        local nt, ntt = 0, 0
        local function pack_normal(v)
            local tag = tabstr_normal(v)
            local ht = h[tag]
            if ht then
                c[ht] = c[ht] + 1
                return ht
            else
                nt = nt + 1
                t[nt] = v
                h[tag] = nt
                c[nt] = 1
                return nt
            end
        end
        local function pack_flat(v)
            local tag = tabstr_flat(v)
            local ht = h[tag]
            if ht then
                c[ht] = c[ht] + 1
                return ht
            else
                nt = nt + 1
                t[nt] = v
                h[tag] = nt
                c[nt] = 1
                return nt
            end
        end
        local function pack_boolean(v)
            local tag = tabstr_boolean(v)
            local ht = h[tag]
            if ht then
                c[ht] = c[ht] + 1
                return ht
            else
                nt = nt + 1
                t[nt] = v
                h[tag] = nt
                c[nt] = 1
                return nt
            end
        end
        local function pack_indexed(v)
            local tag = concat(v," ")
            local ht = h[tag]
            if ht then
                c[ht] = c[ht] + 1
                return ht
            else
                nt = nt + 1
                t[nt] = v
                h[tag] = nt
                c[nt] = 1
                return nt
            end
        end
        local function pack_mixed(v)
            local tag = tabstr_mixed(v)
            local ht = h[tag]
            if ht then
                c[ht] = c[ht] + 1
                return ht
            else
                nt = nt + 1
                t[nt] = v
                h[tag] = nt
                c[nt] = 1
                return nt
            end
        end
        local function pack_final(v)
            -- v == number
            if c[v] <= criterium then
                return t[v]
            else
                -- compact hash
                local hv = hh[v]
                if hv then
                    return hv
                else
                    ntt = ntt + 1
                    tt[ntt] = t[v]
                    hh[v] = ntt
                    cc[ntt] = c[v]
                    return ntt
                end
            end
        end
        local function success(stage,pass)
            if nt == 0 then
                if trace_loading or trace_packing then
                    report_otf("pack quality: nothing to pack")
                end
                return false
            elseif nt >= threshold then
                local one, two, rest = 0, 0, 0
                if pass == 1 then
                    for k,v in next, c do
                        if v == 1 then
                            one = one + 1
                        elseif v == 2 then
                            two = two + 1
                        else
                            rest = rest + 1
                        end
                    end
                else
                    for k,v in next, cc do
                        if v > 20 then
                            rest = rest + 1
                        elseif v > 10 then
                            two = two + 1
                        else
                            one = one + 1
                        end
                    end
                    data.tables = tt
                end
                if trace_loading or trace_packing then
                    report_otf("pack quality: stage %s, pass %s, %s packed, 1-10:%s, 11-20:%s, rest:%s (criterium: %s)", stage, pass, one+two+rest, one, two, rest, criterium)
                end
                return true
            else
                if trace_loading or trace_packing then
                    report_otf("pack quality: stage %s, pass %s, %s packed, aborting pack (threshold: %s)", stage, pass, nt, threshold)
                end
                return false
            end
        end
        local function packers(pass)
            if pass == 1 then
                return pack_normal, pack_indexed, pack_flat, pack_boolean, pack_mixed
            else
                return pack_final, pack_final, pack_final, pack_final, pack_final
            end
        end
        local resources = data.resources
        local lookuptypes = resources.lookuptypes
        for pass=1,2 do
            if trace_packing then
                report_otf("start packing: stage 1, pass %s",pass)
            end
            local pack_normal, pack_indexed, pack_flat, pack_boolean, pack_mixed = packers(pass)
            for unicode, description in next, data.descriptions do
                local boundingbox = description.boundingbox
                if boundingbox then
                    description.boundingbox = pack_indexed(boundingbox)
                end
                local slookups = description.slookups
                if slookups then
                    for tag, slookup in next, slookups do
                        local what = lookuptypes[tag]
                        if what == "pair" then
                            local t = slookup[2] if t then slookup[2] = pack_indexed(t) end
                            local t = slookup[3] if t then slookup[3] = pack_indexed(t) end
                        elseif what ~= "substitution" then
                            slookups[tag] = pack_indexed(slookup) -- true is new
                        end
                    end
                end
                local mlookups = description.mlookups
                if mlookups then
                    for tag, mlookup in next, mlookups do
                        local what = lookuptypes[tag]
                        if what == "pair" then
                            for i=1,#mlookup do
                                local lookup = mlookup[i]
                                local t = lookup[2] if t then lookup[2] = pack_indexed(t) end
                                local t = lookup[3] if t then lookup[3] = pack_indexed(t) end
                            end
                        elseif what ~= "substitution" then
                            for i=1,#mlookup do
                                mlookup[i] = pack_indexed(mlookup[i]) -- true is new
                            end
                        end
                    end
                end
                local kerns = description.kerns
                if kerns then
                    for tag, kern in next, kerns do
                        kerns[tag] = pack_flat(kern)
                    end
                end
                local math = description.math
                if math then
                    local kerns = math.kerns
                    if kerns then
                        for tag, kern in next, kerns do
                            kerns[tag] = pack_normal(kern)
                        end
                    end
                end
                local anchors = description.anchors
                if anchors then
                    for what, anchor in next, anchors do
                        if what == "baselig" then
                            for _, a in next, anchor do
                                for k=1,#a do
                                    a[k] = pack_indexed(a[k])
                                end
                            end
                        else
                            for k, v in next, anchor do
                                anchor[k] = pack_indexed(v)
                            end
                        end
                    end
                end
                local altuni = description.altuni
                if altuni then
                    for i=1,#altuni do
                        altuni[i] = pack_flat(altuni[i])
                    end
                end
            end
            local lookups = data.lookups
            if lookups then
                for _, lookup in next, lookups do
                    local rules = lookup.rules
                    if rules then
                        for i=1,#rules do
                            local rule = rules[i]
                            local r = rule.before       if r then for i=1,#r do r[i] = pack_boolean(r[i]) end end
                            local r = rule.after        if r then for i=1,#r do r[i] = pack_boolean(r[i]) end end
                            local r = rule.current      if r then for i=1,#r do r[i] = pack_boolean(r[i]) end end
                            local r = rule.replacements if r then rule.replacements  = pack_flat   (r)    end -- can have holes
                            local r = rule.lookups      if r then rule.lookups       = pack_indexed(r)    end -- can have ""
                         -- local r = rule.lookups      if r then rule.lookups       = pack_flat(r)       end -- can have holes (already taken care of some cases)
                        end
                    end
                end
            end
            local anchor_to_lookup  = resources.anchor_to_lookup
            if anchor_to_lookup then
                for anchor, lookup in next, anchor_to_lookup do
                    anchor_to_lookup[anchor] = pack_normal(lookup)
                end
            end
            local lookup_to_anchor = resources.lookup_to_anchor
            if lookup_to_anchor then
                for lookup, anchor in next, lookup_to_anchor do
                    lookup_to_anchor[lookup] = pack_normal(anchor)
                end
            end
            local sequences = resources.sequences
            if sequences then
                for feature, sequence in next, sequences do
                    local flags = sequence.flags
                    if flags then
                        sequence.flags = pack_normal(flags)
                    end
                    local subtables = sequence.subtables
                    if subtables then
                        sequence.subtables = pack_normal(subtables)
                    end
                    local features = sequence.features
                    if features then
                        for script, feature in next, features do
                            features[script] = pack_normal(feature)
                        end
                    end
                    local order = sequence.order
                    if order then
                        sequence.order = pack_indexed(order)
                    end
                    local markclass = sequence.markclass
                    if markclass then
                        sequence.markclass = pack_boolean(markclass)
                    end
                end
            end
            local lookups = resources.lookups
            if lookups then
                for name, lookup in next, lookups do
                    local flags = lookup.flags
                    if flags then
                        lookup.flags = pack_normal(flags)
                    end
                    local subtables = lookup.subtables
                    if subtables then
                        lookup.subtables = pack_normal(subtables)
                    end
                end
            end
            local features = resources.features
            if features then
                for _, what in next, glists do
                    local list = features[what]
                    if list then
                        for feature, spec in next, list do
                            list[feature] = pack_normal(spec)
                        end
                    end
                end
            end
            if not success(1,pass) then
                return
            end
        end
        if nt > 0 then
            for pass=1,2 do
                if trace_packing then
                    report_otf("start packing: stage 2, pass %s",pass)
                end
                local pack_normal, pack_indexed, pack_flat, pack_boolean, pack_mixed = packers(pass)
                for unicode, description in next, data.descriptions do
                    local kerns = description.kerns
                    if kerns then
                        description.kerns = pack_normal(kerns)
                    end
                    local math = description.math
                    if math then
                        local kerns = math.kerns
                        if kerns then
                            math.kerns = pack_normal(kerns)
                        end
                    end
                    local anchors = description.anchors
                    if anchors then
                        description.anchors = pack_normal(anchors)
                    end
                    local mlookups = description.mlookups
                    if mlookups then
                        for tag, mlookup in next, mlookups do
                            mlookups[tag] = pack_normal(mlookup)
                        end
                    end
                    local altuni = description.altuni
                    if altuni then
                        description.altuni = pack_normal(altuni)
                    end
                end
                local lookups = data.lookups
                if lookups then
                    for _, lookup in next, lookups do
                        local rules = lookup.rules
                        if rules then
                            for i=1,#rules do -- was next loop
                                local rule = rules[i]
                                local r = rule.before  if r then rule.before  = pack_normal(r) end
                                local r = rule.after   if r then rule.after   = pack_normal(r) end
                                local r = rule.current if r then rule.current = pack_normal(r) end
                            end
                        end
                    end
                end
                local sequences = resources.sequences
                if sequences then
                    for feature, sequence in next, sequences do
                        sequence.features = pack_normal(sequence.features)
                    end
                end
                if not success(2,pass) then
                 -- return
                end
            end

            for pass=1,2 do
                local pack_normal, pack_indexed, pack_flat, pack_boolean, pack_mixed = packers(pass)
                for unicode, description in next, data.descriptions do
                    local slookups = description.slookups
                    if slookups then
                        description.slookups = pack_normal(slookups)
                    end
                    local mlookups = description.mlookups
                    if mlookups then
                        description.mlookups = pack_normal(mlookups)
                    end
                end
            end

        end
    end
end

local unpacked_mt = {
    __index =
        function(t,k)
            t[k] = false
            return k -- next time true
        end
}

local function unpackdata(data)

    if data then
        local tables = data.tables
        if tables then
            local resources = data.resources
            local lookuptypes = resources.lookuptypes
            local unpacked = { }
            setmetatable(unpacked,unpacked_mt)
            for unicode, description in next, data.descriptions do
                local tv = tables[description.boundingbox]
                if tv then
                    description.boundingbox = tv
                end
                local slookups = description.slookups
                if slookups then
                    local tv = tables[slookups]
                    if tv then
                        description.slookups = tv
                        slookups = unpacked[tv]
                    end
                    if slookups then
                        for tag, lookup in next, slookups do
                            local what = lookuptypes[tag]
                            if what == "pair" then
                                local tv = tables[lookup[2]]
                                if tv then
                                    lookup[2] = tv
                                end
                                local tv = tables[lookup[3]]
                                if tv then
                                    lookup[3] = tv
                                end
                            elseif what ~= "substitution" then
                                local tv = tables[lookup]
                                if tv then
                                    slookups[tag] = tv
                                end
                            end
                        end
                    end
                end
                local mlookups = description.mlookups
                if mlookups then
                    local tv = tables[mlookups]
                    if tv then
                        description.mlookups = tv
                        mlookups = unpacked[tv]
                    end
                    if mlookups then
                        for tag, list in next, mlookups do
                            local tv = tables[list]
                            if tv then
                                mlookups[tag] = tv
                                list = unpacked[tv]
                            end
                            if list then
                                local what = lookuptypes[tag]
                                if what == "pair" then
                                    for i=1,#list do
                                        local lookup = list[i]
                                        local tv = tables[lookup[2]]
                                        if tv then
                                            lookup[2] = tv
                                        end
                                        local tv = tables[lookup[3]]
                                        if tv then
                                            lookup[3] = tv
                                        end
                                    end
                                elseif what ~= "substitution" then
                                    for i=1,#list do
                                        local tv = tables[list[i]]
                                        if tv then
                                            list[i] = tv
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                local kerns = description.kerns
                if kerns then
                    local tm = tables[kerns]
                    if tm then
                        description.kerns = tm
                        kerns = unpacked[tm]
                    end
                    if kerns then
                        for k, kern in next, kerns do
                            local tv = tables[kern]
                            if tv then
                                kerns[k] = tv
                            end
                        end
                    end
                end
                local math = description.math
                if math then
                    local kerns = math.kerns
                    if kerns then
                        local tm = tables[kerns]
                        if tm then
                            math.kerns = tm
                            kerns = unpacked[tm]
                        end
                        if kerns then
                            for k, kern in next, kerns do
                                local tv = tables[kern]
                                if tv then
                                    kerns[k] = tv
                                end
                            end
                        end
                    end
                end
                local anchors = description.anchors
                if anchors then
                    local ta = tables[anchors]
                    if ta then
                        description.anchors = ta
                        anchors = unpacked[ta]
                    end
                    if anchors then
                        for tag, anchor in next, anchors do
                            if tag == "baselig" then
                                for _, list in next, anchor do
                                    for i=1,#list do
                                        local tv = tables[list[i]]
                                        if tv then
                                            list[i] = tv
                                        end
                                    end
                                end
                            else
                                for a, data in next, anchor do
                                    local tv = tables[data]
                                    if tv then
                                        anchor[a] = tv
                                    end
                                end
                            end
                        end
                    end
                end
                local altuni = description.altuni
                if altuni then
                    local altuni = tables[altuni]
                    if altuni then
                        description.altuni = altuni
                        for i=1,#altuni do
                            local tv = tables[altuni[i]]
                            if tv then
                                altuni[i] = tv
                            end
                        end
                    end
                end
            end
            local lookups = data.lookups
            if lookups then
                for _, lookup in next, lookups do
                    local rules = lookup.rules
                    if rules then
                        for i=1,#rules do -- was next loop
                            local rule = rules[i]
                            local before = rule.before
                            if before then
                                local tv = tables[before]
                                if tv then
                                    rule.before = tv
                                    before = unpacked[tv]
                                end
                                if before then
                                    for i=1,#before do
                                        local tv = tables[before[i]]
                                        if tv then
                                            before[i] = tv
                                        end
                                    end
                                end
                            end
                            local after = rule.after
                            if after then
                                local tv = tables[after]
                                if tv then
                                    rule.after = tv
                                    after = unpacked[tv]
                                end
                                if after then
                                    for i=1,#after do
                                        local tv = tables[after[i]]
                                        if tv then
                                            after[i] = tv
                                        end
                                    end
                                end
                            end
                            local current = rule.current
                            if current then
                                local tv = tables[current]
                                if tv then
                                    rule.current = tv
                                    current = unpacked[tv]
                                end
                                if current then
                                    for i=1,#current do
                                        local tv = tables[current[i]]
                                        if tv then
                                            current[i] = tv
                                        end
                                    end
                                end
                            end
                            local replacements = rule.replacements
                            if replacements then
                                local tv = tables[replacements]
                                if tv then
                                    rule.replacements = tv
                                end
                            end
                         -- local fore = rule.fore
                         -- if fore then
                         --     local tv = tables[fore]
                         --     if tv then
                         --         rule.fore = tv
                         --     end
                         -- end
                         -- local back = rule.back
                         -- if back then
                         --     local tv = tables[back]
                         --     if tv then
                         --         rule.back = tv
                         --     end
                         -- end
                         -- local names = rule.names
                         -- if names then
                         --     local tv = tables[names]
                         --     if tv then
                         --         rule.names = tv
                         --     end
                         -- end
                            --
                            local lookups = rule.lookups
                            if lookups then
                                local tv = tables[lookups]
                                if tv then
                                    rule.lookups = tv
                                end
                            end
                        end
                    end
                end
            end
            local anchor_to_lookup = resources.anchor_to_lookup
            if anchor_to_lookup then
                for anchor, lookup in next, anchor_to_lookup do
                    local tv = tables[lookup]
                    if tv then
                        anchor_to_lookup[anchor] = tv
                    end
                end
            end
            local lookup_to_anchor = resources.lookup_to_anchor
            if lookup_to_anchor then
                for lookup, anchor in next, lookup_to_anchor do
                    local tv = tables[anchor]
                    if tv then
                        lookup_to_anchor[lookup] = tv
                    end
                end
            end
            local ls = resources.sequences
            if ls then
                for _, feature in next, ls do
                    local flags = feature.flags
                    if flags then
                        local tv = tables[flags]
                        if tv then
                            feature.flags = tv
                        end
                    end
                    local subtables = feature.subtables
                    if subtables then
                        local tv = tables[subtables]
                        if tv then
                            feature.subtables = tv
                        end
                    end
                    local features = feature.features
                    if features then
                        local tv = tables[features]
                        if tv then
                            feature.features = tv
                            features = unpacked[tv]
                        end
                        if features then
                            for script, data in next, features do
                                local tv = tables[data]
                                if tv then
                                    features[script] = tv
                                end
                            end
                        end
                    end
                    local order = feature.order
                    if order then
                        local tv = tables[order]
                        if tv then
                            feature.order = tv
                        end
                    end
                    local markclass = feature.markclass
                    if markclass then
                        local tv = tables[markclass]
                        if tv then
                            feature.markclass = tv
                        end
                    end
                end
            end
            local lookups = resources.lookups
            if lookups then
                for _, lookup in next, lookups do
                    local flags = lookup.flags
                    if flags then
                        local tv = tables[flags]
                        if tv then
                            lookup.flags = tv
                        end
                    end
                    local subtables = lookup.subtables
                    if subtables then
                        local tv = tables[subtables]
                        if tv then
                            lookup.subtables = tv
                        end
                    end
                end
            end
            local features = resources.features
            if features then
                for _, what in next, glists do
                    local feature = features[what]
                    if feature then
                        for tag, spec in next, feature do
                            local tv = tables[spec]
                            if tv then
                                feature[tag] = tv
                            end
                        end
                    end
                end
            end
            data.tables = nil
        end
    end
end

if otf.enhancers.register then

    otf.enhancers.register(  "pack",  packdata)
    otf.enhancers.register("unpack",unpackdata)

-- todo: directive

end

otf.enhancers.unpack = unpackdata -- used elsewhere
otf.enhancers.pack   = packdata   -- used elsewhere
